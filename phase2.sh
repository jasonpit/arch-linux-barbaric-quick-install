#!/bin/bash
set -e

echo "[*] Running Phase 2 config..."

# Set up hostname, timezone, locales
echo "arch" > /etc/hostname
ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Create user
useradd -m -G wheel,audio,video -s /bin/bash archadmin
echo "archadmin:SuperSecurePassword123!" | chpasswd
echo "root:SuperSecurePassword123!" | chpasswd

# Allow wheel group sudo
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

# Install essentials
pacman -Sy --noconfirm openssh vim git base-devel pipewire pipewire-pulse wireplumber sudo

# Enable SSH
systemctl enable sshd

# Enable pipewire services (optional)
systemctl enable --user pipewire
systemctl enable --user wireplumber

# Cleanup
rm /root/.bash_profile  # prevent script from re-running
echo "[*] Phase 2 complete. Reboot recommended."
