#!/usr/bin/env bash
# arch_full_autoinstall Phase 1

set -e

echo "[*] Wiping /dev/sda and creating partitions..."
sgdisk --zap-all /dev/sda
parted /dev/sda --script mklabel gpt
parted /dev/sda --script mkpart primary ext4 1MiB 100%
mkfs.ext4 /dev/sda1 -F
mount /dev/sda1 /mnt

# Create swap file
echo "[*] Creating swapfile..."
dd if=/dev/zero of=/mnt/swapfile bs=1M count=2048 status=progress
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile

# Add fstab entry
echo "/swapfile none swap defaults 0 0" >> /mnt/etc/fstab

# Download phase2.sh
echo "[*] Downloading Phase 2 setup script..."
curl -sLo /mnt/phase2.sh https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/phase2.sh
chmod +x /mnt/phase2.sh

# Ensure phase2 runs on first boot
echo "bash /mnt/phase2.sh && rm -f /mnt/phase2.sh" >> /mnt/etc/profile

# Prompt for reboot
echo "[!] Rebooting to apply partition table. After reboot, system will auto-run Phase 2."
sleep 5
reboot
