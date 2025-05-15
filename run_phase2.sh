#!/bin/bash

set -euo pipefail

if ! command -v chroot &> /dev/null; then
  echo "[✗] chroot not found. Installing..."
  pacman -Sy --noconfirm arch-install-scripts dosfstools
fi

echo "[*] Mounting target system..."
mountpoint -q /mnt || mount /dev/sda2 /mnt

# Mount and check/format ESP
ESP_PARTITION="/dev/sda1"
BOOT_MOUNT="/mnt/boot"

mkdir -p "$BOOT_MOUNT"
mountpoint -q $BOOT_MOUNT || mount "$ESP_PARTITION" "$BOOT_MOUNT"

if ! blkid "$ESP_PARTITION" | grep -q "vfat"; then
  echo "[!] ESP not formatted correctly. Formatting as FAT32..."
  mkfs.fat -F32 "$ESP_PARTITION"
  mount "$ESP_PARTITION" "$BOOT_MOUNT"
fi

echo "[*] Mounting pseudo-filesystems..."
for fs in dev proc sys run; do
  target="/mnt/$fs"
  mkdir -p "$target"
  mount --bind "/$fs" "$target"
done

echo "[*] Installing systemd-boot..."
arch-chroot /mnt bootctl --path=/boot install

echo "[*] Fetching and executing phase2.sh in chroot..."
curl -sSL -o /mnt/phase2.sh https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/phase2.sh
chmod +x /mnt/phase2.sh

echo "[*] Checking swap status..."
if swapon --show | grep -q /mnt/swapfile; then
  echo "[*] Swap already active, skipping."
else
  echo "[*] Swap appears already in use, skipping swapon."
elif ! grep -q "/mnt/swapfile" /proc/swaps && swapon /mnt/swapfile 2>/dev/null; then
  echo "[*] Swap successfully activated."
else
  echo "[!] Swap could not be activated (likely already active or in use)."
fi

chroot /mnt /phase2.sh
