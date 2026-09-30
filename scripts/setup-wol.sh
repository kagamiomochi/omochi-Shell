#!/usr/bin/env bash
#
# setup-wol.sh
# NetworkManager管理下の有線インターフェースに対してWake on LAN(magicパケット)を自動で有効化するスクリプト。
#
# 使い方:
#   sudo ./setup-wol.sh            # 自動検出した有線接続すべてに設定
#   sudo ./setup-wol.sh eth0       # インターフェース名を指定して設定
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Please run it with root authority (sudo ./setup-wol.sh)" >&2
    exit 1
fi

if ! command -v nmcli &>/dev/null; then
    echo "nmcli cannot be found. Please check if NetworkManager is installed." >&2
    exit 1
fi

TARGET_IFACE="${1:-}"

echo "=== Wired interface is being detected ==="

# ethernetタイプのdeviceを取得
mapfile -t ETH_DEVICES < <(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="ethernet"{print $1}')

if [[ ${#ETH_DEVICES[@]} -eq 0 ]]; then
    echo "The wired (ethernet) interface could not be found." >&2
    exit 1
fi

# 対象を絞り込み
if [[ -n "$TARGET_IFACE" ]]; then
    if [[ ! " ${ETH_DEVICES[*]} " =~ " ${TARGET_IFACE} " ]]; then
        echo "The specified interface '$TARGET_IFACE' was not detected as wired." >&2
        echo "Detected candidate: ${ETH_DEVICES[*]}" >&2
        exit 1
    fi
    ETH_DEVICES=("$TARGET_IFACE")
fi

echo "Target interface: ${ETH_DEVICES[*]}"
echo

for iface in "${ETH_DEVICES[@]}"; do
    echo "--- $iface ---"

    # このインターフェースに紐づく接続プロファイル名を取得
    conn_name=$(nmcli -t -f NAME,DEVICE connection show | awk -F: -v d="$iface" '$2==d{print $1; exit}')

    if [[ -z "$conn_name" ]]; then
        # アクティブでない場合、device指定から接続プロファイル候補を探す
        conn_name=$(nmcli -t -f NAME,TYPE connection show | awk -F: '$2=="802-3-ethernet"{print $1; exit}')
    fi

    if [[ -z "$conn_name" ]]; then
        echo "  [Warning] No connection profile corresponding to $iface was found. skipping."
        continue
    fi

    echo "  Connection profile: $conn_name"

    # 現在の設定を確認
    current=$(nmcli -g 802-3-ethernet.wake-on-lan connection show "$conn_name" 2>/dev/null || echo "")
    echo "  Current wake-on-lan setting: ${current:-Not set}"

    # magicパケットを有効化
    nmcli connection modify "$conn_name" 802-3-ethernet.wake-on-lan magic

    # 反映(すでにアクティブな接続のみ再起動)
    if nmcli -t -f NAME connection show --active | grep -qx "$conn_name"; then
        echo "  Reconnect to reflect the settings..."
        nmcli connection down "$conn_name" >/dev/null
        nmcli connection up "$conn_name" >/dev/null
    fi

    new_value=$(nmcli -g 802-3-ethernet.wake-on-lan connection show "$conn_name")
    echo "  Wake-on-lan after setting: $new_value"

    # MACアドレスも表示しておく(マジックパケット送信時に必要)
    mac=$(nmcli -g GENERAL.HWADDR device show "$iface" | tr -d '\\')
    echo "  MAC address: $mac"
    echo
done

echo "=== done ==="
