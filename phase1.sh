#!/bin/bash
set -euo pipefail

DISK="/dev/sda"
LOG="/mnt/install.log"

echo "[*] Detecting primary disk..."
for candidate in /dev/nvme0n1 /dev/vda /dev/sda; do
  if [ -b "$candidate" ]; then
    DISK="$candidate"
    break
  fi
done

echo "[+] Using disk: $DISK"
echo "[*] Wiping $DISK and creating partitions..."

# Wipe disk
sgdisk --zap-all "$DISK"
sgdisk -o "$DISK"

# Create single root partition
sgdisk -n 1:0:0 -t 1:8300 "$DISK"

# Reload partition table
partprobe "$DISK"
sleep 2

ROOT="${DISK}1"
mkfs.ext4 "$ROOT" -L rootfs
mount "$ROOT" /mnt

echo "[*] Creating swapfile..."
fallocate -l 2G /mnt/swapfile
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile

# Write fstab
mkdir -p /mnt/etc
genfstab -U /mnt >> /mnt/etc/fstab

echo "[*] Installing base system..."
pacstrap -K /mnt base linux linux-firmware openssh sudo vim > "$LOG" 2>&1

echo "[*] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "[*] Downloading Phase 2 setup script..."
curl -sL https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/phase2.sh -o /mnt/phase2.sh
chmod +x /mnt/phase2.sh

echo "[*] Setting auto-run of Phase 2 on first login..."
mkdir -p /mnt/root
echo 'bash /phase2.sh' >> /mnt/root/.bash_profile

read -rp "Paste your SSH public key (or leave blank to skip): " SSHKEY
if [[ -n "$SSHKEY" ]]; then
  mkdir -p /mnt/root/.ssh
  echo "$SSHKEY" > /mnt/root/.ssh/authorized_keys
  chmod 700 /mnt/root/.ssh
  chmod 600 /mnt/root/.ssh/authorized_keys
fi

echo "[!] Rebooting to apply partition table. After reboot, run manually if needed:"
echo "    bash /mnt/phase2.sh"
