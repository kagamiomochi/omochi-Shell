#!/usr/bin/env python3
"""Print one line to stdout every time a mouse button is pressed.

Reads evdev directly (same approach as hypr/scripts/click_shrink.py), so the
user must be in the `input` group. Devices are never grabbed, so normal input
handling is not affected. Output format: "press <button code>".
"""
import selectors
import sys
import time

import evdev
from evdev import ecodes

BUTTONS = {ecodes.BTN_LEFT, ecodes.BTN_RIGHT, ecodes.BTN_MIDDLE}
RESCAN_INTERVAL = 5  # seconds, picks up hot-plugged mice


def is_pointer(dev: evdev.InputDevice) -> bool:
    keys = dev.capabilities().get(ecodes.EV_KEY, [])
    return ecodes.BTN_LEFT in keys


def main() -> None:
    sel = selectors.DefaultSelector()
    devices: dict[str, evdev.InputDevice] = {}
    last_scan = 0.0

    while True:
        now = time.monotonic()
        if now - last_scan >= RESCAN_INTERVAL:
            last_scan = now
            for path in evdev.list_devices():
                if path in devices:
                    continue
                try:
                    dev = evdev.InputDevice(path)
                    if not is_pointer(dev):
                        dev.close()
                        continue
                    sel.register(dev, selectors.EVENT_READ)
                    devices[path] = dev
                except OSError:
                    continue

        if not devices:
            time.sleep(1.0)
            continue

        for key, _mask in sel.select(timeout=1.0):
            dev = key.fileobj
            try:
                for ev in dev.read():
                    if ev.type == ecodes.EV_KEY and ev.value == 1 and ev.code in BUTTONS:
                        sys.stdout.write(f"press {ev.code}\n")
                        sys.stdout.flush()
            except OSError:
                # Device was unplugged; forget it and let the rescan find it again
                sel.unregister(dev)
                devices.pop(dev.path, None)
                dev.close()


if __name__ == "__main__":
    main()
