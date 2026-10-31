#!/usr/bin/env bash
#
# setup-tpm2.sh
# Enroll the LUKS2 volume that backs the root filesystem of THIS machine into
# the TPM2 and enable automatic unlock at boot.
#
# Skipped (no changes) when:
#   - root is not on LUKS2
#   - no usable TPM2 device
#   - a systemd-tpm2 token is already enrolled
#   - the initramfs is not systemd based (sd-encrypt hook missing)
#
set -euo pipefail

info() { echo "[tpm2] $*"; }
skip() { info "Skipped: $*"; exit 0; }

# ------------------------------------------------------------
# 1. Find the LUKS device backing "/"
# ------------------------------------------------------------
# Strip the btrfs subvolume suffix, e.g. /dev/mapper/luks-xxx[/@]
root_src=$(findmnt -no SOURCE / | sed 's/\[.*\]$//')
[[ -b "$root_src" ]] || skip "cannot resolve the root block device ($root_src)"

# lsblk -s lists the device first, then its parents. The entry right after the
# first "crypt" line is the underlying (encrypted) partition.
mapfile -t chain < <(lsblk -nsrpo NAME,TYPE "$root_src")

crypt_name=""
luks_dev=""
for i in "${!chain[@]}"; do
    read -r name type <<< "${chain[$i]}"
    if [[ "$type" == "crypt" ]]; then
        crypt_name=$(basename "$name")
        next="${chain[$((i + 1))]:-}"
        luks_dev="${next%% *}"
        break
    fi
done

[[ -n "$luks_dev" && -b "$luks_dev" ]] || skip "root filesystem is not on a LUKS volume"

# ------------------------------------------------------------
# 2. LUKS2 check
# ------------------------------------------------------------
sudo cryptsetup isLuks --type luks2 "$luks_dev" || skip "$luks_dev is not LUKS2"
info "Target: $luks_dev (mapping: $crypt_name)"

# ------------------------------------------------------------
# 3. TPM2 check
# ------------------------------------------------------------
[[ -c /dev/tpmrm0 ]] || skip "no TPM2 resource manager device (/dev/tpmrm0)"
sudo systemd-cryptenroll --tpm2-device=list 2>/dev/null | grep -q '^/dev/' \
    || skip "no usable TPM2 device found"

# ------------------------------------------------------------
# 4. Already enrolled?
# ------------------------------------------------------------
if sudo cryptsetup luksDump "$luks_dev" | grep -q 'systemd-tpm2'; then
    skip "a TPM2 token is already enrolled on $luks_dev"
fi

# ------------------------------------------------------------
# 5. initramfs must be systemd based, otherwise TPM2 unlock cannot work
# ------------------------------------------------------------
hooks=$(grep -hE '^\s*HOOKS' /etc/mkinitcpio.conf /etc/mkinitcpio.conf.d/*.conf 2>/dev/null || true)
if ! grep -qw 'sd-encrypt' <<< "$hooks"; then
    if grep -qw 'encrypt' <<< "$hooks"; then
        skip "initramfs uses the legacy 'encrypt' hook (needs 'systemd' + 'sd-encrypt' hooks for TPM2)"
    fi
    skip "could not find the 'sd-encrypt' hook in mkinitcpio HOOKS"
fi

# ------------------------------------------------------------
# 6. Secure Boot warning (PCR 7 reflects the Secure Boot state)
# ------------------------------------------------------------
if ! bootctl status 2>/dev/null | grep -qi 'Secure Boot: enabled'; then
    info "WARNING: Secure Boot is not enabled. Binding to PCR 7 gives weak protection."
    if [[ -t 0 ]]; then
        read -rp "[tpm2] Continue anyway? [y/N] " ans
        [[ "$ans" =~ ^[Yy]$ ]] || skip "cancelled by user"
    else
        skip "Secure Boot is disabled and no terminal is available to confirm"
    fi
fi

# ------------------------------------------------------------
# 7. Enroll (asks for the existing passphrase on the terminal)
# ------------------------------------------------------------
info "Enrolling into TPM2 (PCR 7). Enter your current LUKS passphrase when asked."
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 "$luks_dev"

# ------------------------------------------------------------
# 8. Enable automatic unlock in the initramfs
# ------------------------------------------------------------
uuid=$(sudo cryptsetup luksUUID "$luks_dev")
crypttab=/etc/crypttab.initramfs

if sudo grep -q "UUID=${uuid}" "$crypttab" 2>/dev/null; then
    # Entry exists: add tpm2-device=auto to its options column if missing
    tmp=$(mktemp)
    sudo awk -v u="UUID=${uuid}" '
        $2 == u {
            if (NF < 3) $3 = "none"
            if (NF < 4) $4 = "tpm2-device=auto"
            else if ($4 !~ /tpm2-device=/) $4 = $4 ",tpm2-device=auto"
        }
        { print }
    ' "$crypttab" > "$tmp"
    sudo install -m 0644 "$tmp" "$crypttab"
    rm -f "$tmp"
else
    echo "${crypt_name} UUID=${uuid} none tpm2-device=auto" | sudo tee -a "$crypttab" > /dev/null
fi

info "Rebuilding initramfs..."
sudo mkinitcpio -P

info "Done. Reboot to verify. The passphrase still works as a fallback."
