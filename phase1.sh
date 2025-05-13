#!/bin/bash
set -e

### CONFIG
DISK="/dev/sda"
HOSTNAME="arch"
USERNAME="archadmin"
PASSWORD="SuperSecurePassword123!"
SWAP_SIZE="2G"  # Set to "0" or "" to disable

echo "[*] Wiping $DISK and creating partitions..."
sgdisk --zap-all "$DISK"
parted "$DISK" --script mklabel gpt mkpart primary 1MiB 100% set 1 boot on
sleep 2
partprobe "$DISK"

mkfs.ext4 "${DISK}1" -L rootfs
mount "${DISK}1" /mnt

if [[ "$SWAP_SIZE" != "0" && "$SWAP_SIZE" != "" ]]; then
    echo "[*] Creating swapfile..."
    fallocate -l "$SWAP_SIZE" /mnt/swapfile
    chmod 600 /mnt/swapfile
    mkswap /mnt/swapfile
    swapon /mnt/swapfile
fi

echo "[*] Downloading Phase 2 setup script..."
curl -L https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/main/phase2.sh -o /mnt/phase2.sh
chmod +x /mnt/phase2.sh

echo "[!] Rebooting to apply partition table. After reboot, run:"
echo "    bash /mnt/phase2.sh"

# Copy phase 2 installer script into new system
curl -Lo /mnt/phase2.sh https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/main/phase2.sh
chmod +x /mnt/phase2.sh

# Auto-run phase2 after reboot
echo "bash /mnt/phase2.sh" >> /mnt/root/.bash_profile

# Done — prompt reboot
echo "[*] Phase 1 complete. Rebooting into installed system..."
reboot


