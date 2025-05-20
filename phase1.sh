#!/bin/bash
# phase2.sh - Arch Linux Post-Install Configuration

set -euo pipefail

TIMEZONE="America/Los_Angeles"
LOCALE="en_US.UTF-8"
KEYMAP="us"

echo "[*] Setting timezone..."
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

echo "[*] Configuring locale..."
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

echo "[*] Setting hostname..."
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

echo "[*] Setting root password..."
echo "root:$PASSWORD" | chpasswd

echo "[*] Creating user '$USERNAME'..."
id "$USERNAME" &>/dev/null || useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd

sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

systemctl enable NetworkManager
systemctl enable sshd

bootctl --path=/boot install

echo "[*] Creating bootloader config..."
cat > /boot/loader/loader.conf << EOF
default arch
timeout 3
console-mode max
editor no
EOF

cat > /boot/loader/entries/arch.conf << EOF
  title   Arch Linux
  linux   /vmlinuz-linux
  initrd  /initramfs-linux.img
  options root=PARTUUID=$(blkid -s PARTUUID -o value /dev/${DISK}p2) rw
EOF

echo "[*] Phase 2 complete. You may now reboot."
