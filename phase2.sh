#!/bin/bash
set -euo pipefail

echo "[*] Configuring Arch system..."

arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "arch" > /etc/hostname

# Setup hosts
cat <<HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   arch.localdomain arch
HOSTS

# Create user
useradd -m -G wheel,audio -s /bin/bash archadmin
echo "archadmin:supersecure" | chpasswd
echo "root:supersecure" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Enable services
systemctl enable sshd
EOF

echo "[+] Phase 2 complete. Please reboot."
