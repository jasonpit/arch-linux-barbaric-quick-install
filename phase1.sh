#!/bin/bash
# -----------------------------------------------------------------------------
# phase1.sh - Arch Linux base system installer and phase2 trigger
#
# This script automates the first phase of a two-phase Arch Linux installation.
# It partitions the target disk, formats file systems, installs essential base
# packages, generates fstab, and prepares the system to run phase2 from within
# chroot.
#
# Usage:
#   curl -LO https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/phase1.sh
#   chmod +x phase1.sh
#   export USERNAME=myuser
#   export PASSWORD=mypass
#   export HOSTNAME=myhost
#   export DISK=nvme0n1
#   ./phase1.sh
#
# Required environment variables:
#   USERNAME  - Username for the new user
#   PASSWORD  - Password for the new user
#   HOSTNAME  - Hostname of the new system
#   DISK      - Disk to install Arch on (e.g., nvme0n1)
#
# -----------------------------------------------------------------------------

set -euo pipefail

# Required vars
: "${USERNAME:?Missing USERNAME}"
: "${PASSWORD:?Missing PASSWORD}"
: "${HOSTNAME:?Missing HOSTNAME}"
: "${DISK:?Missing DISK}"

echo "[*] Partitioning /dev/$DISK..."
# Wipe and repartition the disk with EFI and root partitions
sgdisk --zap-all /dev/$DISK
sgdisk -n 1::+512M -t 1:ef00 -c 1:EFI /dev/$DISK
sgdisk -n 2::-0 -t 2:8300 -c 2:ROOT /dev/$DISK
# Format partitions: EFI (FAT32) and root (ext4)
mkfs.fat -F32 /dev/${DISK}p1
mkfs.ext4 /dev/${DISK}p2

echo "[*] Mounting filesystems..."
# Mount the root and boot partitions
mount /dev/${DISK}p2 /mnt
mkdir -p /mnt/boot
mount /dev/${DISK}p1 /mnt/boot

echo "[*] Installing base system..."
# Install the base Arch Linux system and essential packages
pacstrap /mnt base linux linux-firmware networkmanager openssh sudo grub efibootmgr

echo "[*] Generating fstab..."
# Generate /etc/fstab with UUIDs
genfstab -U /mnt >> /mnt/etc/fstab

echo "[*] Copying phase2.sh..."
# Download phase2.sh into the new system and make it executable
curl -L https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/main/phase2.sh -o /mnt/root/phase2.sh
chmod +x /mnt/root/phase2.sh

echo "[*] Preparing chroot..."
# Bind necessary filesystems for chroot environment
for dir in /dev /proc /sys /run; do
    mount --bind $dir /mnt$dir
done
# Create and secure /tmp in case it doesn't exist
mkdir -p /mnt/tmp && chmod 1777 /mnt/tmp

echo "[*] Entering chroot and running phase2.sh..."
# Enter the new system and run phase2.sh to complete setup
arch-chroot /mnt /root/phase2.sh
