#!/bin/bash
set -e

### CONFIG
DISK="/dev/sda"
HOSTNAME="arch"
USERNAME="archadmin"
PASSWORD="SuperSecurePassword123!"
TIMEZONE="America/Los_Angeles"
LOCALE="en_US.UTF-8"
KEYMAP="us"

echo "[*] Mounting root partition..."
mount "${DISK}1" /mnt

echo "[*] Installing base system..."
pacstrap /mnt base linux linux-firmware vim sudo openssh networkmanager pipewire pipewire-alsa pipewire-jack wireplumber jack-example-tools

echo "[*] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "[*] Setting up system config..."
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
echo "$HOSTNAME" > /etc/hostname

echo "[*] Creating user $USERNAME..."
useradd -m -G wheel,audio -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd

echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

systemctl enable sshd
systemctl enable NetworkManager
EOF

echo "[*] Installation complete! You can reboot now."
