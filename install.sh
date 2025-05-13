#!/bin/bash
# nodeos-auto-install.sh - Minimal, robust Arch Linux base installer (headless)

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# === Prompt for Configuration ===
echo "[*] Starting NodeOS Arch install script"
HOSTNAME="${HOSTNAME:-archaudio}"
USERNAME="${USERNAME:-audioadmin}"
PASSWORD="${PASSWORD:-supersecure}"
echo "[*] Using HOSTNAME=$HOSTNAME, USERNAME=$USERNAME"

# === Disk Detection ===
DISK="/dev/$(lsblk -dno NAME | grep -E '^sd|^vd|^nvme' | head -n 1)"
echo -e "\n[*] Target disk: $DISK"

# === Cleanup any mounted leftovers ===
umount -R /mnt || true
swapoff -a || true

# === Partition Disk ===
echo "[*] Partitioning disk..."
sgdisk -Z "$DISK"
sgdisk -n 1::+512M -t 1:ef00 -c 1:ESP "$DISK"
sgdisk -n 2:: -t 2:8300 -c 2:ROOT "$DISK"

mkfs.fat -F32 "${DISK}1"
mkfs.ext4 -F "${DISK}2"

# === Mount Partitions ===
mount "${DISK}2" /mnt
mkdir -p /mnt/boot/efi
mount "${DISK}1" /mnt/boot/efi

# === Install Base System ===
echo "[*] Installing base system..."
pacstrap /mnt base linux linux-firmware \
  networkmanager openssh sudo git zsh vim \
  pipewire pipewire-jack wireplumber grub efibootmgr

# === FSTAB ===
genfstab -U /mnt >> /mnt/etc/fstab

# === System Configuration ===
echo "[*] Configuring system..."
arch-chroot /mnt /bin/bash <<EOF

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "$HOSTNAME" > /etc/hostname
cat <<EOT > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOT

echo "root:$PASSWORD" | chpasswd

useradd -m -G wheel -s /bin/zsh $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

systemctl enable NetworkManager
systemctl enable sshd
systemctl start sshd

# === Install GRUB Bootloader ===
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

EOF

# === Done ===
echo "[*] Install complete. You can now reboot into your new system."
echo "SSH will be available at the same IP as the installer."
echo "Login: $USERNAME (password: $PASSWORD)"
echo "You can override defaults using environment variables: HOSTNAME, USERNAME, PASSWORD"
