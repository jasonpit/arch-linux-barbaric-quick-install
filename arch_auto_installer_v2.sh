#!/bin/bash

set -euo pipefail

# === USER CONFIG ===
USERNAME="${USERNAME:-archuser}"
PASSWORD="${PASSWORD:-SuperSecurePassword123!}"
HOSTNAME="${HOSTNAME:-archlinux}"
TIMEZONE="America/Los_Angeles"
LOCALE="en_US.UTF-8"
KEYMAP="us"
SWAP_SIZE="2G"

log="/mnt/install.log"
exec > >(tee -a "$log") 2>&1

# === Detect disk ===
echo "[*] Detecting primary disk..."
DISK=$(lsblk -ndo NAME,TYPE | awk '$2=="disk" {print "/dev/"$1; exit}')
EFI_PART="${DISK}1"
ROOT_PART="${DISK}2"

echo "[+] Using disk: $DISK"

# === SSH Key (optional) ===
echo -n "Paste your SSH public key (or leave blank to skip): "
read -r SSH_KEY

# === Partition disk ===
echo "[*] Partitioning $DISK..."
sgdisk --zap-all "$DISK"
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System" "$DISK"
sgdisk -n 2:0:0     -t 2:8300 -c 2:"Linux Root" "$DISK"
partprobe "$DISK"
sleep 2

# === Format and mount ===
mkfs.vfat -F32 "$EFI_PART"
mkfs.ext4 "$ROOT_PART"

mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

# === Base install ===
echo "[*] Installing base system..."
pacstrap /mnt base linux linux-firmware sudo zsh networkmanager intel-ucode amd-ucode efibootmgr systemd-boot

# === FSTAB ===
genfstab -U /mnt >> /mnt/etc/fstab

# === Chroot setup ===
arch-chroot /mnt /bin/bash -e <<EOF
echo "[*] Setting system clock and locale..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

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

echo "[*] Creating user '$USERNAME'..."
useradd -m -G wheel -s /bin/zsh "$USERNAME" || echo "[!] User creation failed."
echo "$USERNAME:$PASSWORD" | chpasswd

echo "[*] Enabling sudo for wheel group..."
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel

if [ -n "$SSH_KEY" ]; then
  echo "[*] Setting SSH key for $USERNAME"
  mkdir -p /home/$USERNAME/.ssh
  echo "$SSH_KEY" > /home/$USERNAME/.ssh/authorized_keys
  chmod 700 /home/$USERNAME/.ssh
  chmod 600 /home/$USERNAME/.ssh/authorized_keys
  chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
fi

systemctl enable NetworkManager

echo "[*] Installing systemd-boot..."
bootctl --path=/boot install

UUID=$(blkid -s PARTUUID -o value $ROOT_PART)

cat > /boot/loader/entries/arch.conf <<EOL
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
options root=PARTUUID=$UUID rw
EOL

cat > /boot/loader/loader.conf <<EOL
default arch.conf
timeout 3
editor no
EOL

mkinitcpio -P

if [[ -n "$SWAP_SIZE" && "$SWAP_SIZE" != "0" ]]; then
  echo "[*] Creating swapfile..."
  dd if=/dev/zero of=/swapfile bs=1M count=$(echo $SWAP_SIZE | sed 's/G//')000 status=progress
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo "/swapfile none swap defaults 0 0" >> /etc/fstab
fi

efibootmgr --create --disk $DISK --part 1 --label "Arch Linux" --loader /EFI/systemd/systemd-bootx64.efi || echo "[!] efibootmgr failed but systemd-boot should still work"
EOF

echo "[✔] Arch install complete. Reboot when ready."
