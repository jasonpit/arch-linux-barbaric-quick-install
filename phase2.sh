#!/bin/bash
# phase2.sh - Arch Linux post-install configuration script (to be run inside chroot)
#
# This script performs post-installation setup tasks for a freshly installed Arch Linux system.
# It is intended to be executed from within a chroot environment after the base system has been
# installed and mounted at /mnt. The script:
#   - Sets timezone, locale, and keymap
#   - Configures hostname and networking
#   - Sets root and user credentials
#   - Enables essential services (NetworkManager, SSH)
#   - Installs and configures the system bootloader using systemd-boot

##### do this in chroot
# mount --bind /dev /mnt/dev
# mount --bind /proc /mnt/proc
# mount --bind /sys /mnt/sys
# mount --bind /run /mnt/run
# arch-chroot /mnt
# Now inside chroot:
# # curl -LO https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/phase2.sh chmod +x phase2.sh

# export USERNAME=node
# export PASSWORD=meat
# export HOSTNAME=nodeos
# export DISK=nvme0n1
# ./phase2.sh


# Exit immediately on error, undefined variable usage, or failed pipeline command
set -euo pipefail

# --- System Localization Settings ---
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

# --- Hostname and Networking Configuration ---
echo "[*] Setting hostname..."
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# --- User and Password Setup ---
echo "[*] Setting root password..."
echo "root:$PASSWORD" | chpasswd

echo "[*] Creating user '$USERNAME'..."
id "$USERNAME" &>/dev/null || useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# --- Enable Essential Services ---
echo "[*] Enabling services..."
systemctl enable NetworkManager || echo "⚠️  NetworkManager not found"
systemctl enable sshd || echo "⚠️  sshd not found"

# --- Install and Configure systemd-boot Bootloader ---
echo "[*] Installing bootloader..."
bootctl --path=/boot install

echo "[*] Writing bootloader config..."
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

# --- Finalization ---
echo "[*] Phase 2 complete. You may now reboot."
