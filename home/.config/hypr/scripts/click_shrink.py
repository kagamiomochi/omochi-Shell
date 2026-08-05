#!/usr/bin/env python3
"""
要件:
    sudo pacman -S python-evdev
    実行ユーザーが `input` グループに所属していること
    (/dev/input/event* の読み取り権限のため)
"""

from __future__ import annotations

import argparse
import errno
import selectors
import subprocess
import sys
import time

import evdev
from evdev import ecodes

DEBOUNCE_SEC = 0.02
RESCAN_INTERVAL_SEC = 10
RECONNECT_WAIT_SEC = 5

PRESS_CMD = [
    "hyprctl",
    "dispatch",
    "hl.plugin.dynamic_cursors.dsp_magnify({ duration = 60000, size = 0.6 })",
]
RELEASE_CMD = [
    "hyprctl",
    "dispatch",
    "hl.plugin.dynamic_cursors.dsp_magnify({ duration = 150, size = 1.0 })",
]


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def run_dispatch(cmd: list[str]) -> None:
    try:
        subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        log("hyprctl not found. Please check your PATH.")


def find_pointer_devices() -> list[evdev.InputDevice]:
    devices = []
    for path in evdev.list_devices():
        try:
            d = evdev.InputDevice(path)
        except OSError:
            continue
        caps = d.capabilities()
        if ecodes.EV_KEY in caps and ecodes.BTN_LEFT in caps[ecodes.EV_KEY]:
            devices.append(d)
    return devices


def watch(debug: bool) -> None:
    sel = selectors.DefaultSelector()
    devices = find_pointer_devices()
    if not devices:
        raise RuntimeError(
            "No device with BTN_LEFT was found. Please check if you are in the `input` group."
        )

    for d in devices:
        sel.register(d, selectors.EVENT_READ)
        log(f"Add to monitored items: {d.path} ({d.name})")

    last_press = 0.0
    last_release = 0.0
    last_rescan = time.monotonic()

    while True:
        for key, _mask in sel.select(timeout=1.0):
            dev = key.fileobj
            assert isinstance(dev, evdev.InputDevice)
            try:
                for event in dev.read():
                    if debug and event.type == ecodes.EV_KEY:
                        log(f"[debug] {dev.path}: {evdev.categorize(event)}")

                    if event.type != ecodes.EV_KEY or event.code != ecodes.BTN_LEFT:
                        continue

                    now = time.monotonic()

                    if event.value == 1:  # press
                        if now - last_press < DEBOUNCE_SEC:
                            continue
                        last_press = now
                        run_dispatch(PRESS_CMD)
                    elif event.value == 0:  # release
                        if now - last_release < DEBOUNCE_SEC:
                            continue
                        last_release = now
                        run_dispatch(RELEASE_CMD)
            except OSError as e:
                if e.errno == errno.ENODEV:
                    log(f"Device disconnection detected. Removing from monitoring: {dev.path}")
                    sel.unregister(dev)
                else:
                    raise

        now = time.monotonic()
        if now - last_rescan > RESCAN_INTERVAL_SEC:
            last_rescan = now
            current_paths = {
                key.fileobj.path for key in sel.get_map().values()  # type: ignore[union-attr]
            }
            for d in find_pointer_devices():
                if d.path not in current_paths:
                    sel.register(d, selectors.EVENT_READ)
                    log(f"New device detected. Add to monitored devices: {d.path} ({d.name})")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Log the full contents of EV_KEY events (for verifying operation).",
    )
    args = parser.parse_args()

    while True:
        try:
            watch(debug=args.debug)
        except Exception as e:
            log(f"The monitoring process has crashed. {RECONNECT_WAIT_SEC} will try again in seconds: {e}")
            time.sleep(RECONNECT_WAIT_SEC)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nStopped.")
