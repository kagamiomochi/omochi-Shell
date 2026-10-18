#!/usr/bin/env python3
"""Heuristically detect pointer lock and print "locked" / "unlocked".

Hyprland does not expose pointer constraint state over IPC, so we infer it:
while the pointer is locked, relative motion events keep arriving from the
mouse (evdev) but the compositor cursor position does not change.

Requires membership in the `input` group (same as click-stream.py).
Devices are never grabbed.
"""
import os
import selectors
import socket
import sys
import time

import evdev
from evdev import ecodes

CHECK_INTERVAL = 0.05   # seconds between position checks
STALL_REQUIRED = 0.3    # seconds of "moving but not moving" before declaring lock
MIN_MOTION = 4          # min summed |rel| counts per check to count as motion
RESCAN_INTERVAL = 5     # seconds, picks up hot-plugged mice

sig = os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
SOCK_PATH = f"{runtime}/hypr/{sig}/.socket.sock"


def query_pos():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.connect(SOCK_PATH)
        s.sendall(b"cursorpos")
        x, y = (float(v) for v in s.recv(256).decode().strip().split(","))
        return (x, y)
    except (OSError, ValueError):
        return None
    finally:
        s.close()


def is_mouse(dev):
    caps = dev.capabilities()
    keys = caps.get(ecodes.EV_KEY, [])
    rel = caps.get(ecodes.EV_REL, [])
    return ecodes.BTN_LEFT in keys and ecodes.REL_X in rel


def emit(msg):
    sys.stdout.write(msg + "\n")
    sys.stdout.flush()


def main():
    sel = selectors.DefaultSelector()
    devices = {}
    last_scan = 0.0
    last_check = time.monotonic()
    last_pos = None
    motion = 0
    stall = 0.0
    locked = False

    emit("unlocked")

    while True:
        now = time.monotonic()
        if now - last_scan >= RESCAN_INTERVAL:
            last_scan = now
            for path in evdev.list_devices():
                if path in devices:
                    continue
                try:
                    dev = evdev.InputDevice(path)
                    if not is_mouse(dev):
                        dev.close()
                        continue
                    sel.register(dev, selectors.EVENT_READ)
                    devices[path] = dev
                except OSError:
                    continue

        if not devices:
            time.sleep(1.0)
            continue

        for key, _mask in sel.select(timeout=CHECK_INTERVAL):
            dev = key.fileobj
            try:
                for ev in dev.read():
                    if ev.type == ecodes.EV_REL and ev.code in (ecodes.REL_X, ecodes.REL_Y):
                        motion += abs(ev.value)
            except OSError:
                # Device was unplugged; forget it and let the rescan find it again
                sel.unregister(dev)
                devices.pop(dev.path, None)
                dev.close()

        now = time.monotonic()
        if now - last_check < CHECK_INTERVAL:
            continue
        dt = now - last_check
        last_check = now

        pos = query_pos()
        if pos is None:
            continue

        if pos != last_pos:
            # Cursor moved: not locked (or the lock was just released)
            last_pos = pos
            stall = 0.0
            if locked:
                locked = False
                emit("unlocked")
        elif motion >= MIN_MOTION:
            # Mouse is moving but the cursor is not
            stall += dt
            if not locked and stall >= STALL_REQUIRED:
                locked = True
                emit("locked")
        motion = 0


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
