#!/bin/bash
set -euo pipefail

TARGET_USER="kagamimochi"
USER_UID=$(id -u "$TARGET_USER")
USER_GID=$(id -g "$TARGET_USER")

MOUNT_BASE="/run/media/$TARGET_USER"
mkdir -p "$MOUNT_BASE"

# 除外したいパーティション種別名・ラベル(小文字で判定)
EXCLUDE_PATTERNS="microsoft reserved|windows recovery environment|efi system"

while IFS= read -r line; do
    eval "$line"

    [ "$TYPE" != "part" ] && continue
    [ -z "$FSTYPE" ] && continue
    [ "$FSTYPE" = "swap" ] && continue
    [ -n "$MOUNTPOINT" ] && continue

    # パーティション種別名やラベルで除外判定(大文字小文字無視)
    check_str=$(echo "${PARTTYPENAME:-} ${PARTLABEL:-} ${LABEL:-}" | tr '[:upper:]' '[:lower:]')
    if echo "$check_str" | grep -qE "$EXCLUDE_PATTERNS"; then
        echo "Skipping $NAME (excluded: $check_str)"
        continue
    fi

    uuid=$(blkid -s UUID -o value "$NAME" || true)
    label=$(blkid -s LABEL -o value "$NAME" || true)

    if [ -n "$label" ]; then
        dirname="$label"
    elif [ -n "$uuid" ]; then
        dirname="$uuid"
    else
        dirname=$(basename "$NAME")
    fi

    target="$MOUNT_BASE/$dirname"
    mkdir -p "$target"

    case "$FSTYPE" in
        ntfs)
            OPTS="defaults,nofail,uid=$USER_UID,gid=$USER_GID,windows_names"
            ;;
        vfat)
            OPTS="defaults,nofail,uid=$USER_UID,gid=$USER_GID"
            ;;
        exfat)
            OPTS="defaults,nofail,uid=$USER_UID,gid=$USER_GID"
            ;;
        *)
            OPTS="defaults,nofail"
            ;;
    esac

    echo "Mounting $NAME ($FSTYPE) -> $target"
    systemd-mount --no-block -o "$OPTS" "$NAME" "$target" || echo "Failed to mount $NAME"

    if [ "$FSTYPE" = "btrfs" ] || [ "$FSTYPE" = "ext4" ]; then
        chown "$USER_UID:$USER_GID" "$target" || true
    fi
done < <(lsblk -po NAME,FSTYPE,MOUNTPOINT,TYPE,PARTTYPENAME,PARTLABEL,LABEL -P)
