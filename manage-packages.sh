#!/bin/bash

if [ -z "$1" ] || [ ! -f "$1" ]; then
    echo "Error: Please specify a valid input file."
    echo "$0 <File name>"
    exit 1
fi

INPUT_FILE="$1"
BASE_NAME="${INPUT_FILE%.txt}"

FILTERED_OUT="filtered-${BASE_NAME}.txt"
OFFICIAL_OUT="official-${BASE_NAME}.txt"
AUR_OUT="aur-${BASE_NAME}.txt"

> "$FILTERED_OUT"
> "$OFFICIAL_OUT"
> "$AUR_OUT"

PKGS=($(cat "$INPUT_FILE"))

ALL_DEPS=()
for pkg in "${PKGS[@]}"; do
    deps=$(pactree -u -s "$pkg" 2>/dev/null | tail -n +2)
    ALL_DEPS+=($deps)
done

DEPS_SET=($(printf '%s\n' "${ALL_DEPS[@]}" | sort -u))

filtered_count=0
official_count=0
aur_count=0

for pkg in "${PKGS[@]}"; do
    if ! printf '%s\n' "${DEPS_SET[@]}" | grep -qx "$pkg"; then
        
        echo "$pkg" >> "$FILTERED_OUT"
        ((filtered_count++))
        
        if pacman -Si "$pkg" &>/dev/null; then
            echo "$pkg" >> "$OFFICIAL_OUT"
            ((official_count++))
        else
            echo "$pkg" >> "$AUR_OUT"
            ((aur_count++))
        fi
        
    fi
done

echo "Filtered list: $FILTERED_OUT ($filtered_count packages)"
echo "Official package: $OFFICIAL_OUT ($official_count packages)"
echo "AUR packages: $AUR_OUT ($aur_count packages)"