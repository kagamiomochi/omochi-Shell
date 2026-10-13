#!/usr/bin/env python3
"""Hyprland の IPC ソケットを直接叩いてカーソル位置を標準出力へ流す。

hyprctl をプロセス起動するより桁違いに軽い。位置が変わったときだけ
"x y" を1行で出力する。
"""
import os
import socket
import sys
import time

sig = os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
path = f"{runtime}/hypr/{sig}/.socket.sock"

INTERVAL = 1 / 60  # 取得間隔(秒)。モニターのリフレッシュレートに合わせる
last = None


def query() -> str:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.connect(path)
        s.sendall(b"cursorpos")
        return s.recv(256).decode().strip()
    finally:
        s.close()


while True:
    try:
        # 返り値は "123, 456" 形式
        x, y = (float(v) for v in query().split(","))
        cur = (x, y)
        if cur != last:
            sys.stdout.write(f"{x} {y}\n")
            sys.stdout.flush()
            last = cur
    except (OSError, ValueError):
        pass
    time.sleep(INTERVAL)
