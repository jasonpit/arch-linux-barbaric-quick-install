#!/usr/bin/env bash
set -e

echo "[*] Wiping /dev/sda and creating partitions..."
sgdisk --zap-all /dev/sda
sgdisk -n 1:0:0 -t 1:8300 /dev/sda
mkfs.ext4 -F -L rootfs /dev/sda1

echo "[*] Mounting root partition..."
mount /dev/sda1 /mnt

echo "[*] Creating swapfile..."
dd if=/dev/zero of=/mnt/swapfile bs=1M count=2048 status=progress
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile

echo "[*] Installing base system..."
pacstrap -K /mnt base linux linux-firmware sudo vim openssh

echo "[*] Generating fstab..."
mkdir -p /mnt/etc
genfstab -U /mnt >> /mnt/etc/fstab


echo "[*] Downloading Phase 2 setup script..."
curl -sL https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/phase2.sh -o /mnt/phase2.sh
chmod +x /mnt/phase2.sh

echo "[*] Setting auto-run of Phase 2 on first login..."
echo "bash /mnt/phase2.sh" >> /mnt/root/.bash_profile

echo "[!] Rebooting to apply partition table. After reboot, run manually if needed:"
echo "    bash /mnt/phase2.sh"
reboot
