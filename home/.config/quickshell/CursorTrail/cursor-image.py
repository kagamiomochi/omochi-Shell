#!/usr/bin/env python3
"""Xcursor テーマの標準矢印カーソルを PNG に変換し、情報を JSON で1行出力する。

使い方: cursor-image.py [テーマ名] [サイズ]
引数が空なら XCURSOR_THEME / XCURSOR_SIZE を使い、それも無ければ default / 24。
依存は標準ライブラリのみ。
"""
import configparser
import json
import os
import struct
import sys
import zlib
from pathlib import Path

NAMES = ["left_ptr", "default", "arrow", "top_left_arrow"]


def arg(i):
    return sys.argv[i] if len(sys.argv) > i and sys.argv[i] else ""


theme = arg(1) or os.environ.get("XCURSOR_THEME") or "default"
size = int(arg(2) or os.environ.get("XCURSOR_SIZE") or 24)

home = Path.home()
data_home = Path(os.environ.get("XDG_DATA_HOME") or home / ".local/share")
search = [home / ".icons", data_home / "icons"]
for d in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":"):
    if d:
        search.append(Path(d) / "icons")


def find_cursor(name, seen=None):
    """テーマと、その Inherits を辿ってカーソルファイルを探す。"""
    seen = seen or set()
    if name in seen:
        return None
    seen.add(name)
    for base in search:
        for cname in NAMES:
            p = base / name / "cursors" / cname
            if p.is_file():
                return p
    for base in search:
        index = base / name / "index.theme"
        if not index.is_file():
            continue
        cp = configparser.ConfigParser(strict=False, interpolation=None)
        try:
            cp.read(index, encoding="utf-8")
        except configparser.Error:
            continue
        for parent in cp.get("Icon Theme", "Inherits", fallback="").split(","):
            parent = parent.strip()
            if parent:
                found = find_cursor(parent, seen)
                if found:
                    return found
    return None


def load_xcursor(path, want):
    data = path.read_bytes()
    magic, _header, _version, ntoc = struct.unpack_from("<4sIII", data, 0)
    if magic != b"Xcur":
        raise ValueError("not an Xcursor file")
    best = None
    for i in range(ntoc):
        ctype, subtype, pos = struct.unpack_from("<III", data, 16 + 12 * i)
        if ctype != 0xFFFD0002:  # 画像チャンクのみ
            continue
        # アニメーションの場合は同サイズの先頭フレームを使う
        if best is None or abs(subtype - want) < abs(best[0] - want):
            best = (subtype, pos)
    if best is None:
        raise ValueError("no image chunk")
    nominal, pos = best
    w, h, xhot, yhot, _delay = struct.unpack_from("<5I", data, pos + 16)
    px = data[pos + 36 : pos + 36 + w * h * 4]
    return nominal, w, h, xhot, yhot, px


def to_png(w, h, px):
    """premultiplied ARGB(リトルエンディアン = B,G,R,A) を非premultiplied RGBA の PNG へ。"""
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            i = (y * w + x) * 4
            b, g, r, a = px[i], px[i + 1], px[i + 2], px[i + 3]
            if 0 < a < 255:
                r = min(255, r * 255 // a)
                g = min(255, g * 255 // a)
                b = min(255, b * 255 // a)
            raw += bytes((r, g, b, a))

    def chunk(tag, body):
        c = struct.pack(">I", len(body)) + tag + body
        return c + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def main():
    path = find_cursor(theme)
    if path is None:
        sys.stderr.write(f"cursor not found in theme '{theme}'\n")
        return 1
    nominal, w, h, xhot, yhot, px = load_xcursor(path, size)
    out_dir = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp") / "cursor-trail"
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / "cursor.png"
    out.write_bytes(to_png(w, h, px))
    print(
        json.dumps(
            {
                "path": str(out),
                "w": w,
                "h": h,
                "xhot": xhot,
                "yhot": yhot,
                # 要求サイズと実ファイルの公称サイズの比。描画サイズの補正に使う
                "scale": size / nominal if nominal else 1.0,
            }
        ),
        flush=True,
    )
    return 0


sys.exit(main())
