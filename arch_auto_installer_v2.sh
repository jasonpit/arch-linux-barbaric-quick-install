#!/bin/bash
echo "[info] Running phase1.sh version 2025-05-19-01"

set -euo pipefail

PASSWORD="${PASSWORD:-SuperSecurePassword123!}"
HOSTNAME="${HOSTNAME:-archlinux}"

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

echo -n "Paste your SSH public key (or leave blank to skip): "
read -r SSH_KEY

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

if [[ "$DISK" == *"nvme"* ]]; then
  EFI_PART="${DISK}p1"
  ROOT_PART="${DISK}p2"
else
  EFI_PART="${DISK}1"
  ROOT_PART="${DISK}2"
fi

echo "[*] Formatting partitions..."
mkfs.fat -F32 "$EFI_PART"
mkfs.ext4 "$ROOT_PART"

echo "[*] Mounting partitions..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

echo "[*] Installing base system..."
pacstrap /mnt base linux linux-firmware sudo networkmanager openssh

if [[ -n "$SSH_KEY" ]]; then
  mkdir -p /mnt/root/.ssh
  echo "$SSH_KEY" >> /mnt/root/.ssh/authorized_keys
  chmod 600 /mnt/root/.ssh/authorized_keys
fi

echo "[*] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "[*] Copying phase2.sh to /mnt/root/phase2.sh..."
cat > /mnt/root/phase2.sh << 'EOF'
#!/bin/bash
set -euo pipefail

TIMEZONE="America/Los_Angeles"
LOCALE="en_US.UTF-8"
KEYMAP="us"
HOSTNAME="${HOSTNAME}"
USERNAME="${USERNAME}"
PASSWORD="${PASSWORD}"

echo "[*] Setting timezone..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
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

echo "[*] Creating user '$USERNAME'..."
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd

echo "[*] Setting root password..."
echo "root:$PASSWORD" | chpasswd

echo "[*] Enabling sudo for wheel group..."
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "[*] Enabling NetworkManager and SSH services..."
systemctl enable NetworkManager
systemctl enable sshd

echo "[*] Installing systemd-boot bootloader..."
bootctl --path=/boot install

echo "[*] Creating loader entry..."
cat > /boot/loader/loader.conf << EOF2
default arch
timeout 3
console-mode max
editor no
EOF2

cat > /boot/loader/entries/arch.conf << EOF2
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=$(blkid -s PARTUUID -o value $ROOT_PART) rw
EOF2

echo "[*] Phase 2 complete. Exiting chroot."
EOF

chmod +x /mnt/root/phase2.sh

echo "[*] Entering chroot and running phase2.sh..."
arch-chroot /mnt /root/phase2.sh

echo "[*] Installation phase 1 complete."

---

#!/bin/bash
echo "This installer has been split into two phases."
echo "Please run phase1.sh to start the installation process."
echo "Phase 2 will be executed automatically inside the chroot."
echo
echo "Usage:"
echo "  ./phase1.sh"
echo
echo "Make sure to set the following environment variables before running:"
echo "  USERNAME - your desired username"
echo "  PASSWORD - your desired password"
echo "  HOSTNAME - your desired hostname"
echo "  DISK     - target disk (e.g., sda)"
echo
echo "Example:"
echo "  export USERNAME=john"
echo "  export PASSWORD=MySecret123"
echo "  export HOSTNAME=myarch"
echo "  export DISK=sda"
echo "  ./phase1.sh"
