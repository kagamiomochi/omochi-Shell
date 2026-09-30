#!/usr/bin/env bash
#
# setup-wol.sh
# NetworkManager管理下の有線インターフェースに対してWake on LAN(magicパケット)を
# 自動で有効化するスクリプト。
#
# 使い方:
#   sudo ./setup-wol.sh            # 自動検出した有線接続すべてに設定
#   sudo ./setup-wol.sh eth0       # インターフェース名を指定して設定
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "root権限で実行してください (sudo ./setup-wol.sh)" >&2
    exit 1
fi

if ! command -v nmcli &>/dev/null; then
    echo "nmcli が見つかりません。NetworkManager がインストールされているか確認してください。" >&2
    exit 1
fi

TARGET_IFACE="${1:-}"

echo "=== 有線インターフェースを検出中 ==="

# ethernetタイプのdeviceを取得
mapfile -t ETH_DEVICES < <(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="ethernet"{print $1}')

if [[ ${#ETH_DEVICES[@]} -eq 0 ]]; then
    echo "有線(ethernet)インターフェースが見つかりませんでした。" >&2
    exit 1
fi

# 対象を絞り込み
if [[ -n "$TARGET_IFACE" ]]; then
    if [[ ! " ${ETH_DEVICES[*]} " =~ " ${TARGET_IFACE} " ]]; then
        echo "指定されたインターフェース '$TARGET_IFACE' は有線として検出されませんでした。" >&2
        echo "検出された候補: ${ETH_DEVICES[*]}" >&2
        exit 1
    fi
    ETH_DEVICES=("$TARGET_IFACE")
fi

echo "対象インターフェース: ${ETH_DEVICES[*]}"
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
        echo "  [警告] $iface に対応する接続プロファイルが見つかりませんでした。スキップします。"
        continue
    fi

    echo "  接続プロファイル: $conn_name"

    # 現在の設定を確認
    current=$(nmcli -g 802-3-ethernet.wake-on-lan connection show "$conn_name" 2>/dev/null || echo "")
    echo "  現在のwake-on-lan設定: ${current:-未設定}"

    # magicパケットを有効化
    nmcli connection modify "$conn_name" 802-3-ethernet.wake-on-lan magic

    # 反映(すでにアクティブな接続のみ再起動)
    if nmcli -t -f NAME connection show --active | grep -qx "$conn_name"; then
        echo "  設定を反映するため再接続します..."
        nmcli connection down "$conn_name" >/dev/null
        nmcli connection up "$conn_name" >/dev/null
    fi

    new_value=$(nmcli -g 802-3-ethernet.wake-on-lan connection show "$conn_name")
    echo "  設定後のwake-on-lan: $new_value"

    # MACアドレスも表示しておく(マジックパケット送信時に必要)
    mac=$(nmcli -g GENERAL.HWADDR device show "$iface" | tr -d '\\')
    echo "  MACアドレス: $mac"
    echo
done

echo "=== 完了 ==="
echo "他の端末からマジックパケットを送る例:"
echo "  wakeonlan <上記のMACアドレス>"
