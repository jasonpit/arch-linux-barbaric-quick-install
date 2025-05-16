#!/bin/bash

set -euo pipefail

# === CONFIG ===
HOSTNAME="${HOSTNAME:-arch}"
USERNAME="${USERNAME:-archuser}"
PASSWORD="${PASSWORD:-SuperSecurePassword123!}"
TIMEZONE="America/Los_Angeles"
LOCALE="en_US.UTF-8"
KEYMAP="us"
SWAP_SIZE="2G"  # e.g., 0 disables swap

# === Detect disk ===
echo "[*] Detecting primary disk..."
DISK=$(lsblk -ndo NAME,TYPE | awk '$2=="disk" {print "/dev/"$1; exit}')
EFI_PART="${DISK}1"
ROOT_PART="${DISK}2"

echo "[+] Using disk: $DISK"

# === Ask for SSH Key ===
echo -n "Paste your SSH public key (or leave blank to skip): "
read -r SSH_KEY

# === Partition Disk ===
echo "[*] Wiping and partitioning $DISK..."
sgdisk --zap-all "$DISK"
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System" "$DISK"
sgdisk -n 2:0:0     -t 2:8300 -c 2:"Linux Root" "$DISK"
partprobe "$DISK"
sleep 2

# === Format and Mount ===
mkfs.vfat -F32 "$EFI_PART"
mkfs.ext4 "$ROOT_PART"

mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

# === Base Install ===
echo "[*] Installing base system..."
pacstrap /mnt base linux linux-firmware sudo zsh networkmanager intel-ucode amd-ucode grub efibootmgr

# === FSTAB ===
genfstab -U /mnt >> /mnt/etc/fstab

# === Chroot Setup ===
arch-chroot /mnt /bin/bash -e <<EOF
echo "[*] Setting timezone..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo "[*] Generating locales..."
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

echo "[*] Setting root password..."
echo "root:$PASSWORD" | chpasswd

echo "[*] Creating user $USERNAME..."
useradd -m -G wheel -s /bin/zsh "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel

if [ -n "$SSH_KEY" ]; then
  mkdir -p /home/$USERNAME/.ssh
  echo "$SSH_KEY" > /home/$USERNAME/.ssh/authorized_keys
  chmod 700 /home/$USERNAME/.ssh
  chmod 600 /home/$USERNAME/.ssh/authorized_keys
  chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
fi

echo "[*] Enabling services..."
systemctl enable NetworkManager

echo "[*] Installing bootloader..."
bootctl install

UUID=$(blkid -s PARTUUID -o value "$ROOT_PART")

mkdir -p /boot/loader/entries
cat > /boot/loader/entries/arch.conf <<ENTRY
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
options root=PARTUUID=$UUID rw
ENTRY

echo "default arch.conf" > /boot/loader/loader.conf
echo "timeout 3" >> /boot/loader/loader.conf
echo "editor no" >> /boot/loader/loader.conf

echo "[*] Generating initramfs..."
mkinitcpio -P

# === Swap Setup ===
if [[ -n "$SWAP_SIZE" && "$SWAP_SIZE" != "0" ]]; then
  echo "[*] Creating swapfile of size $SWAP_SIZE..."
  dd if=/dev/zero of=/swapfile bs=1M count=$(echo $SWAP_SIZE | sed 's/G//')000 status=progress
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo "/swapfile none swap defaults 0 0" >> /etc/fstab
fi

EOF

echo "[✔] Installation complete. You can now reboot into your new system."
