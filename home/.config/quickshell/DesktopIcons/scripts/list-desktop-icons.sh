#!/usr/bin/env bash
# 指定ディレクトリ(デフォルトは ~/Desktop)直下のファイルを列挙し、
# .desktop ファイルは Name/Icon/Exec を抜き出して1本のJSON配列として出力する。
# python3 をJSON文字列エスケープに使うので、python3 が入っている前提。

set -euo pipefail

DESKTOP_DIR="${1:-$HOME/Desktop}"
mkdir -p "$DESKTOP_DIR"

json_escape() {
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip(chr(10))))'
}

echo "["
first=1
shopt -s nullglob
for f in "$DESKTOP_DIR"/*; do
    [ -f "$f" ] || continue
    fname=$(basename "$f")

    if [ "$first" -eq 0 ]; then
        echo ","
    fi
    first=0

    if [[ "$fname" == *.desktop ]]; then
        disp_name=$(grep -m1 '^Name=' "$f" | cut -d= -f2- || true)
        icon=$(grep -m1 '^Icon=' "$f" | cut -d= -f2- || true)
        exec_cmd=$(grep -m1 '^Exec=' "$f" | cut -d= -f2- | sed -E 's/%[a-zA-Z]//g' || true)
        [ -z "$disp_name" ] && disp_name="$fname"
        [ -z "$icon" ] && icon="application-x-executable"

        printf '{"file":%s,"name":%s,"icon":%s,"exec":%s,"isDesktop":true}' \
            "$(printf '%s' "$fname" | json_escape)" \
            "$(printf '%s' "$disp_name" | json_escape)" \
            "$(printf '%s' "$icon" | json_escape)" \
            "$(printf '%s' "$exec_cmd" | json_escape)"
    else
        printf '{"file":%s,"name":%s,"icon":"text-x-generic","exec":"","isDesktop":false}' \
            "$(printf '%s' "$fname" | json_escape)" \
            "$(printf '%s' "$fname" | json_escape)"
    fi
done
echo "]"
