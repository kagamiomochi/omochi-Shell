#!/bin/bash

official_updates=$(checkupdates 2>/dev/null)
aur_updates=$(paru -Qu --aur 2>/dev/null)
updates=$(printf "%s\n%s" "$official_updates" "$aur_updates" | sed '/^\s*$/d')

if [ -z "$updates" ]; then
    exit 0
fi

important_updates=$(echo "$updates" | grep -E "linux|systemd|nvidia|hyprland|networkmanager|pacman|quickshell" || echo "")

if [ -n "$important_updates" ]; then
    msg_title="重要な更新があります"
    display_text=$(echo "$important_updates" | head -n 8)
else
    msg_title="アップデートが利用可能です"
    display_text=$(echo "$updates" | head -n 5)
fi

res=$(notify-send "$msg_title" "$display_text" \
    --icon=software-update-available \
    --action="update=今すぐ更新")

if [ "$res" = "update" ]; then
    kitty sh -c "
        paru -Syu --noconfirm;
        echo '';
        
        if sudo needrestart -b | grep -q 'NEEDRESTART-KSTAT: 2'; then
            notify-send '再起動が必要です' 'カーネルの更新が適用されました。システムを再起動してください。' --urgency=critical --icon=system-reboot
        elif sudo needrestart -b | grep -q 'NEEDRESTART-SVC:'; then
            notify-send 'サービスの再起動を推奨' '一部のサービスで古いライブラリが参照されています。' --icon=dialog-information
        fi

        read -p 'Enterキーで閉じます...'
    "
fi
