#!/bin/bash

set -e

# === CONFIG ===
HOSTNAME="arch"
USERNAME="archadmin"
PASSWORD="SuperSecurePassword123!"  # You may want to hash or prompt for this in a real use
DISK="/dev/sda"
TIMEZONE="America/Los_Angeles"
LOCALE="en_US.UTF-8"
KEYMAP="us"
SWAP_SIZE="2G"  # Set to "0" or "" to disable swap

# === WIPE & PARTITION ===
echo "[*] Wiping $DISK and creating partitions..."
sgdisk --zap-all $DISK
parted $DISK --script mklabel gpt     mkpart primary 1MiB 100%     set 1 boot on

mkfs.ext4 ${DISK}1 -L rootfs
mount ${DISK}1 /mnt

# === OPTIONAL SWAP ===
if [[ -n "$SWAP_SIZE" && "$SWAP_SIZE" != "0" ]]; then
    echo "[*] Creating swapfile..."
    fallocate -l $SWAP_SIZE /mnt/swapfile
    chmod 600 /mnt/swapfile
    mkswap /mnt/swapfile
    swapon /mnt/swapfile
    echo "/swapfile none swap defaults 0 0" >> /mnt/etc/fstab
fi

# === BASE INSTALL ===
echo "[*] Installing base system..."
pacstrap -K /mnt base linux linux-firmware sudo vim networkmanager pipewire pipewire-jack wireplumber openssh git zsh htop neofetch

# === CONFIGURE SYSTEM ===
echo "[*] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<EOF
echo "$HOSTNAME" > /etc/hostname
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# === ADD USER ===
useradd -m -G wheel,audio,video,optical,storage -s /bin/zsh $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

# === ENABLE SERVICES ===
systemctl enable sshd
systemctl enable NetworkManager
EOF

echo "[+] Installation complete. Reboot and login as $USERNAME"
