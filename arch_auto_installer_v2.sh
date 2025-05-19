#bin/bash
# run like this 
# curl -LO https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/arch_auto_installer_v2.sh
# chmod +x arch_auto_installer_v2.sh
#
# export USERNAME=username
# export PASSWORD=password
# export HOSTNAME=arch

# This script automates the installation of Arch Linux with a focus on simplicity and speed.
# It is designed to be run from a live USB environment and will partition, format, and install the base system.

# Clean any existing mounts to avoid errors on rerun
umount -R /mnt 2>/dev/null || true

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

echo "[*] Available disks:"
lsblk -d -o NAME,SIZE,MODEL | grep -v loop

if [[ -n "${DISK:-}" ]]; then
  echo "[+] Using disk from environment: /dev/$DISK"
else
  echo -n "Enter the disk to install to (e.g., sda): "
  read -r DISK
fi

DISK="/dev/${DISK}"
echo "[+] Final disk selection: $DISK"

echo "[*] Installing reflector and updating mirrorlist..."
pacman -Sy --noconfirm reflector
reflector --country US --latest 10 --sort rate --protocol https --save /etc/pacman.d/mirrorlist

# === SSH Key (optional) ===
echo -n "Paste your SSH public key (or leave blank to skip): "
read -r SSH_KEY

# === Partition disk ===
echo "[*] Partitioning $DISK..."
echo "[*] Wiping existing filesystem signatures..."
wipefs -a "$DISK"
echo "[*] Zapping GPT and partition table..."
sgdisk --zap-all "$DISK"
dd if=/dev/zero of="$DISK" bs=1M count=100 status=progress
partprobe "$DISK"
sleep 2
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System" "$DISK"
sgdisk -n 2:0:0     -t 2:8300 -c 2:"Linux Root" "$DISK"
partprobe "$DISK"
sleep 2

# Assign partition variables after partitioning
if [[ "$DISK" == *"nvme"* ]]; then
  EFI_PART="${DISK}p1"
  ROOT_PART="${DISK}p2"
else
  EFI_PART="${DISK}1"
  ROOT_PART="${DISK}2"
fi

# === Format and mount ===
mkfs.vfat -F32 "$EFI_PART"
mkfs.ext4 "$ROOT_PART"

mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

# === Base install ===
echo "[*] Installing base system..."
pacstrap /mnt base linux linux-firmware sudo zsh networkmanager intel-ucode amd-ucode efibootmgr

# === FSTAB ===
genfstab -U /mnt >> /mnt/etc/fstab

cat << 'EOS' > /mnt/tmp/setup-bootloader.sh
#!/bin/bash

UUID=$(blkid -s PARTUUID -o value /dev/sda2)

echo "title   Arch Linux" > /boot/loader/entries/arch.conf
echo "linux   /vmlinuz-linux" >> /boot/loader/entries/arch.conf
echo "initrd  /intel-ucode.img" >> /boot/loader/entries/arch.conf
echo "initrd  /amd-ucode.img" >> /boot/loader/entries/arch.conf
echo "initrd  /initramfs-linux.img" >> /boot/loader/entries/arch.conf
echo "options root=PARTUUID=$UUID rw" >> /boot/loader/entries/arch.conf

echo "default arch.conf" > /boot/loader/loader.conf
echo "timeout 3" >> /boot/loader/loader.conf
echo "editor no" >> /boot/loader/loader.conf
EOS

chmod +x /mnt/tmp/setup-bootloader.sh

export USERNAME
export PASSWORD
export SSH_KEY

# === Chroot setup ===
echo "[debug] Entering chroot with USERNAME='$USERNAME'"
arch-chroot /mnt /usr/bin/env -i USERNAME="$USERNAME" PASSWORD="$PASSWORD" SSH_KEY="$SSH_KEY" bash -e <<'EOF'
export USERNAME="$USERNAME"
export PASSWORD="$PASSWORD"
export SSH_KEY="$SSH_KEY"
echo "[*] Setting system clock and locale..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
echo "FONT=ter-v16n" >> /etc/vconsole.conf

echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

echo "[*] Setting root password..."
echo "root:$PASSWORD" | chpasswd

echo "[*] Enabling sudo for wheel group..."
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel

echo "[*] Enabling NetworkManager..."
systemctl enable NetworkManager

echo "[*] Installing and enabling SSH..."
pacman -Sy --noconfirm openssh
systemctl enable sshd

if [[ "$USERNAME" == "root" || -z "$USERNAME" ]]; then
  echo "[!] Cannot use 'root' or empty string as a custom username. Please choose a different USERNAME."
  exit 1
fi

echo "[*] Creating user '$USERNAME'..."
useradd -m -G wheel -s /bin/zsh "$USERNAME" || echo "[!] User creation failed."
echo "$USERNAME:$PASSWORD" | chpasswd

if [ -n "$SSH_KEY" ]; then
  echo "[*] Setting SSH key for $USERNAME"
  mkdir -p /home/$USERNAME/.ssh
  echo "$SSH_KEY" > /home/$USERNAME/.ssh/authorized_keys
  chmod 700 /home/$USERNAME/.ssh
  chmod 600 /home/$USERNAME/.ssh/authorized_keys
  chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
fi

echo "[*] Installing systemd-boot..."
bootctl --path=/boot install
echo "[*] Copying fallback BOOTX64.EFI..."
mkdir -p /boot/EFI/BOOT
cp -f /boot/EFI/systemd/systemd-bootx64.efi /boot/EFI/BOOT/BOOTX64.EFI

mkinitcpio -P

if [[ -n "$SWAP_SIZE" && "$SWAP_SIZE" != "0" ]]; then
  echo "[*] Creating swapfile..."
  dd if=/dev/zero of=/swapfile bs=1M count=$(echo $SWAP_SIZE | sed 's/G//')000 status=progress
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo "/swapfile none swap defaults 0 0" >> /etc/fstab
fi

efibootmgr --create --disk /dev/sda --part 1 --label "Arch Linux" --loader /EFI/systemd/systemd-bootx64.efi || echo "[!] efibootmgr failed but systemd-boot should still work"
EOF

arch-chroot /mnt /tmp/setup-bootloader.sh
rm /mnt/tmp/setup-bootloader.sh

echo "[✔] Arch install complete. Reboot when ready."
