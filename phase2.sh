#!/bin/bash

set -e

# Phase 2 - Chrooted setup script

# Mount everything
mount /dev/sda1 /mnt
swapon /mnt/swapfile

# Set timezone and localization
arch-chroot /mnt ln -sf /usr/share/zoneinfo/UTC /etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
arch-chroot /mnt locale-gen
arch-chroot /mnt bash -c 'echo "LANG=en_US.UTF-8" > /etc/locale.conf'

# Set hostname
arch-chroot /mnt bash -c 'echo "arch" > /etc/hostname'

# Hosts file
arch-chroot /mnt bash -c 'cat <<EOF > /etc/hosts
127.0.0.1	localhost
::1		localhost
127.0.1.1	arch.localdomain	arch
EOF'

# Root password
arch-chroot /mnt bash -c "echo root:SuperSecurePW123! | chpasswd"

# Create user
arch-chroot /mnt useradd -m -G wheel,audio,video,optical,storage,realtime -s /bin/bash archadmin
arch-chroot /mnt bash -c "echo archadmin:SuperSecurePW123! | chpasswd"
arch-chroot /mnt sed -i '/%wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers

# Install essential packages
arch-chroot /mnt pacman --noconfirm -Sy \
  networkmanager \
  openssh \
  sudo \
  vim \
  git \
  base-devel \
  linux-headers \
  pipewire pipewire-alsa pipewire-pulse pipewire-jack \
  wireplumber \
  jack-example-tools

# Enable services
arch-chroot /mnt systemctl enable NetworkManager
arch-chroot /mnt systemctl enable sshd
arch-chroot /mnt systemctl enable pipewire-pulse --user
arch-chroot /mnt systemctl enable wireplumber --user

# Final clean up
umount -R /mnt
reboot
