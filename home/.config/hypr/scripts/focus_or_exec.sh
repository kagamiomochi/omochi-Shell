#!/usr/bin/env bash
# focus_or_exec.sh <exec_cmd> [class_pattern]

cmd="$1"
class_pattern="$2"
cmdline_match="$(basename "${cmd%% *}")"

addr=""
if [ -n "$class_pattern" ]; then
    addr=$(hyprctl clients -j | jq -r --arg cp "$class_pattern" '
      .[] | select(.class | test($cp; "i")) | .address
    ' | head -n1)
fi

if [ -z "$addr" ]; then
    while IFS=$'\t' read -r pid address; do
        if [ -r "/proc/$pid/cmdline" ] && tr '\0' ' ' < "/proc/$pid/cmdline" | grep -q -- "$cmdline_match"; then
            addr="$address"
            break
        fi
    done < <(hyprctl clients -j | jq -r '.[] | "\(.pid)\t\(.address)"')
fi

if [ -n "$addr" ]; then
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })"
else
    setsid -f $cmd >/dev/null 2>&1
fi