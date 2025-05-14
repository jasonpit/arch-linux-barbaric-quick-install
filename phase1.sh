#!/bin/bash
set -euo pipefail

# === Config ===
HOSTNAME="arch-$(cat /sys/class/net/*/address | head -n1 | tr -d ':')"
USERNAME="archadmin"
PASSWORD="SuperSecurePW123!"
SSH_KEY_TEMP="/tmp/arch_ssh_key.pub"

# === Disk Detection ===
DISK=$(lsblk -dpno NAME | grep -E '/dev/(nvme0n1|vda|sda)' | head -n1)

echo "[*] Using disk: $DISK"

# === Disk Partitioning ===
echo "[*] Wiping $DISK and creating partitions..."
sgdisk --zap-all "$DISK"
parted "$DISK" mklabel gpt
parted "$DISK" mkpart primary ext4 1MiB 100%
mkfs.ext4 "${DISK}p1"

mount "${DISK}p1" /mnt

# === Swap Setup ===
echo "[*] Creating swapfile..."
fallocate -l 2G /mnt/swapfile
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile

# === Base Install ===
echo "[*] Installing base system..."
pacstrap -K /mnt base linux linux-firmware openssh sudo vim

# === Generate fstab ===
genfstab -U /mnt >> /mnt/etc/fstab

# === Hostname ===
echo "$HOSTNAME" > /mnt/etc/hostname

# === SSH Key Prompt ===
read -p "Paste your SSH public key (or leave blank to skip): " USER_SSH_KEY
if [[ -n "$USER_SSH_KEY" ]]; then
    echo "$USER_SSH_KEY" > /mnt/root/ssh_key.pub
fi

# === Download Phase 2 ===
echo "[*] Downloading Phase 2 setup script..."
curl -sL https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/phase2.sh -o /mnt/phase2.sh
chmod +x /mnt/phase2.sh

# === Autostart Phase 2 on login ===
echo "bash /mnt/phase2.sh" >> /mnt/root/.bash_profile

echo "[!] Reboot and run phase2 if not automatic: bash /mnt/phase2.sh"
