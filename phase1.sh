#!/bin/bash

set -euo pipefail

# === CONFIG ===
HOSTNAME="arch"
USERNAME="archadmin"
PASSWORD="SuperSecurePassword123!"
TIMEZONE="America/Los_Angeles"
LOCALE="en_US.UTF-8"
KEYMAP="us"
SWAP_SIZE="2G"  # Set to "0" or empty to disable swap

# === Detect disk ===
echo "[*] Detecting primary disk..."
DISK=$(lsblk -ndo NAME,TYPE | awk '$2=="disk" {print "/dev/"$1; exit}')
echo "[+] Using disk: $DISK"

# === Ask for SSH Key ===
echo -n "Paste your SSH public key (or leave blank to skip): "
read -r SSH_KEY

# === WIPE & PARTITION ===
echo "[*] Wiping $DISK and creating partitions..."
sgdisk --zap-all $DISK
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System" $DISK
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux filesystem" $DISK

EFI_PART="${DISK}1"
ROOT_PART="${DISK}2"

mkfs.vfat -F32 $EFI_PART
mkfs.ext4 -L rootfs $ROOT_PART

# === MOUNT ===
echo "[*] Mounting root partition..."
mount $ROOT_PART /mnt
mkdir -p /mnt/boot/efi
mount $EFI_PART /mnt/boot/efi

# === OPTIONAL SWAP ===
if [[ -n "$SWAP_SIZE" && "$SWAP_SIZE" != "0" ]]; then
  echo "[*] Creating swapfile..."
  fallocate -l $SWAP_SIZE /mnt/swapfile
  chmod 600 /mnt/swapfile
  mkswap /mnt/swapfile
  swapon /mnt/swapfile
fi

# === BASE INSTALL ===
echo "[*] Installing base system..."
pacstrap /mnt base linux linux-firmware sudo vim openssh

# === FSTAB ===
echo "[*] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# === Download Phase 2 ===
echo "[*] Downloading Phase 2 setup script..."
curl -sL https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/phase2.sh -o /mnt/phase2.sh
chmod +x /mnt/phase2.sh

# === Auto-run Phase 2 after chroot ===
echo "[*] Setting auto-run of Phase 2 on first login..."
echo 'bash /phase2.sh && rm /phase2.sh' >> /mnt/root/.bash_profile

# === Store SSH key if provided ===
if [[ -n "$SSH_KEY" ]]; then
  echo "$SSH_KEY" > /mnt/root/.sshkey.tmp
fi

# === DONE ===
echo "[!] Rebooting to apply partition table. After reboot, run manually if needed:"
echo "    bash /mnt/phase2.sh"
