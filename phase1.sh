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
sgdisk --zap-all "$DISK" || { echo "Failed to zap $DISK"; exit 1; }
sgdisk --clear "$DISK"

sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System" "$DISK" || { echo "Failed to create EFI partition"; exit 1; }
sgdisk -n 2:0:0     -t 2:8300 -c 2:"Linux filesystem" "$DISK" || { echo "Failed to create root partition"; exit 1; }

partprobe "$DISK"
sleep 2

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
pacstrap /mnt base linux linux-firmware sudo vim openssh dosfstools

# === FSTAB ===
echo "[*] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# === Download Phase 2 ===
echo "[*] Downloading Phase 2 setup script..."
curl -sL https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/phase2.sh -o /mnt/phase2.sh
chmod +x /mnt/phase2.sh

# === Create systemd service for Phase 2 ===
cat <<EOF > /mnt/etc/systemd/system/phase2-install.service
[Unit]
Description=Run Phase 2 install script once
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/phase2.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
arch-chroot /mnt systemctl enable phase2-install.service


# === Store SSH key if provided ===
if [[ -n "$SSH_KEY" ]]; then
  mkdir -p /mnt/home/$USERNAME/.ssh
  echo "$SSH_KEY" > /mnt/home/$USERNAME/.ssh/authorized_keys
  chmod 700 /mnt/home/$USERNAME/.ssh
  chmod 600 /mnt/home/$USERNAME/.ssh/authorized_keys
fi

cat <<EOF > /mnt/etc/systemd/system/run-phase2.service
[Unit]
Description=Run Phase 2 Install Script
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /phase2.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

arch-chroot /mnt systemctl enable run-phase2.service

# === DONE ===
echo "[!] Rebooting to apply partition table. After reboot, run manually if needed:"
echo "    bash /mnt/phase2.sh"

