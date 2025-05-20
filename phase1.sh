#!/bin/bash
# phase1.sh - Arch Linux base install and chroot trigger

set -euo pipefail

# Required vars
: "${USERNAME:?Missing USERNAME}"
: "${PASSWORD:?Missing PASSWORD}"
: "${HOSTNAME:?Missing HOSTNAME}"
: "${DISK:?Missing DISK}"

echo "[*] Partitioning /dev/$DISK..."
sgdisk --zap-all /dev/$DISK
sgdisk -n 1::+512M -t 1:ef00 -c 1:EFI /dev/$DISK
sgdisk -n 2::-0 -t 2:8300 -c 2:ROOT /dev/$DISK
mkfs.fat -F32 /dev/${DISK}p1
mkfs.ext4 /dev/${DISK}p2

echo "[*] Mounting filesystems..."
mount /dev/${DISK}p2 /mnt
mkdir -p /mnt/boot
mount /dev/${DISK}p1 /mnt/boot

echo "[*] Installing base system..."
pacstrap /mnt base linux linux-firmware networkmanager openssh sudo grub efibootmgr

echo "[*] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "[*] Copying phase2.sh..."
curl -L https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/main/phase2.sh -o /mnt/root/phase2.sh
chmod +x /mnt/root/phase2.sh

echo "[*] Preparing chroot..."
for dir in /dev /proc /sys /run; do
    mount --bind $dir /mnt$dir
done
mkdir -p /mnt/tmp && chmod 1777 /mnt/tmp

echo "[*] Entering chroot and running phase2.sh..."
arch-chroot /mnt /root/phase2.sh
