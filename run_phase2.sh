#!/bin/bash

set -euo pipefail

if ! command -v chroot &> /dev/null; then
  echo "[✗] chroot not found. Installing..."
  pacman -Sy --noconfirm arch-install-scripts dosfstools
fi

ESP_PARTITION="/dev/sda1"
ROOT_PARTITION="/dev/sda2"
BOOT_MOUNT="/mnt/boot"

echo "[*] Mounting target system..."
mkdir -p /mnt "$BOOT_MOUNT"
mountpoint -q /mnt || mount "$ROOT_PARTITION" /mnt
mountpoint -q "$BOOT_MOUNT" || mount "$ESP_PARTITION" "$BOOT_MOUNT"

# Ensure ESP is formatted as FAT32
if ! blkid "$ESP_PARTITION" | grep -q "vfat"; then
  echo "[!] ESP not formatted correctly. Formatting as FAT32..."
  mkfs.fat -F32 "$ESP_PARTITION"
  mount "$ESP_PARTITION" "$BOOT_MOUNT"
fi

echo "[*] Mounting pseudo-filesystems..."
for fs in dev proc sys run; do
  mkdir -p "/mnt/$fs"
  mount --bind "/$fs" "/mnt/$fs"
done

echo "[*] Installing systemd-boot..."
arch-chroot /mnt bootctl install

echo "[*] Fetching and executing phase2.sh in chroot..."
curl -sSL -o /mnt/phase2.sh https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/phase2.sh
chmod +x /mnt/phase2.sh

echo "[*] Delegating execution to phase2.sh in chroot..."
arch-chroot /mnt /phase2.sh