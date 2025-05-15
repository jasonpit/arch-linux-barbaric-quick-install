#!/bin/bash

set -euo pipefail

if ! command -v chroot &> /dev/null; then
  echo "[✗] chroot not found. Installing..."
  pacman -Sy --noconfirm arch-install-scripts
fi

echo "[*] Mounting target system..."
mountpoint -q /mnt || mount /dev/sda2 /mnt
mountpoint -q /mnt/boot || mount /dev/sda1 /mnt/boot

echo "[*] Mounting pseudo-filesystems..."
for fs in dev proc sys run; do
  target="/mnt/$fs"
  mkdir -p "$target"
  mount --bind "/$fs" "$target"
  done

echo "[*] Fetching and executing phase2.sh in chroot..."
curl -sSL -o /mnt/phase2.sh https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/phase2.sh
chmod +x /mnt/phase2.sh

# Ensure swap is not already active
if swapon --show | grep -q /mnt/swapfile; then
  echo "[*] Swap already active, skipping swapon."
else
  swapon /mnt/swapfile || echo "[*] Swap not activated."
fi

chroot /mnt /phase2.sh
