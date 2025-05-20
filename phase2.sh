#!/bin/bash
# Phase 2 Arch install script (run inside chroot)
# JasonPit 2025
set -euo pipefail

# Set essential variables
TIMEZONE="America/Los_Angeles"
LOCALE="en_US.UTF-8"
KEYMAP="us"

# You must export these into the environment when entering chroot or encode them directly in the script
: "${USERNAME:?USERNAME not set}"
: "${PASSWORD:?PASSWORD not set}"
: "${HOSTNAME:?HOSTNAME not set}"

echo "[*] Setting timezone to $TIMEZONE..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo "[*] Configuring locale..."
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "[*] Setting hostname to $HOSTNAME..."
echo "$HOSTNAME" > /etc/hostname
cat >> /etc/hosts <<EOF
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
EOF

echo "[*] Setting root password..."
echo "root:$PASSWORD" | chpasswd

echo "[*] Creating user $USERNAME..."
useradd -m -G wheel,audio,video -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd

echo "[*] Enabling sudo for wheel group..."
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "[*] Enabling NetworkManager and SSH services..."
systemctl enable NetworkManager
systemctl enable sshd

echo "[*] Installing systemd-boot..."
bootctl --path=/boot install

echo "[*] Creating boot loader entry..."
ROOT_UUID=$(blkid -s PARTUUID -o value $(findmnt / -o SOURCE -n))
cat > /boot/loader/loader.conf <<EOF
default arch
timeout 3
console-mode max
editor no
EOF

cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=$ROOT_UUID rw
EOF

echo "[*] Phase 2 complete. You can now exit and reboot."
