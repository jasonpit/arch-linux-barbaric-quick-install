#!/bin/bash
set -euo pipefail

CHROOT="/usr/bin/arch-chroot"

if [ ! -x "$CHROOT" ]; then
  echo "[✗] arch-chroot not found at $CHROOT"
  echo "    Install it with: pacman -Sy arch-install-scripts"
  exit 1
fi

echo "[*] Mounting target system..."
mount /dev/sda2 /mnt
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/boot

echo "[*] Mounting pseudo-filesystems..."
for fs in proc sys dev run; do
  mkdir -p "/mnt/$fs"
  mount --bind "/$fs" "/mnt/$fs"
done

echo "[*] Fetching and executing phase2.sh in chroot..."
curl -fsSL https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/phase2.sh -o /mnt/phase2.sh
chmod +x /mnt/phase2.sh
$CHROOT /mnt /phase2.sh