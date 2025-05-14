#!/bin/bash
set -e

# === CONFIG ===
HOSTNAME="arch"
USERNAME="archadmin"
PASSWORD="SuperSecurePassword123!"
TIMEZONE="America/Los_Angeles"
LOCALE="en_US.UTF-8"
KEYMAP="us"
SSH_KEY_FILE="/tmp/ssh_key.pub"

echo "[*] Setting timezone..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo "[*] Setting locale..."
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "[*] Setting hostname..."
echo "$HOSTNAME" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
EOF

echo "[*] Creating user $USERNAME..."
useradd -m -G wheel,audio -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd

echo "[*] Enabling sudo for wheel group..."
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# === Inject SSH key if provided ===
if [[ -f /root/.sshkey.tmp ]]; then
  mkdir -p /home/$USERNAME/.ssh
  mv /root/.sshkey.tmp /home/$USERNAME/.ssh/authorized_keys
  chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
  chmod 700 /home/$USERNAME/.ssh
  chmod 600 /home/$USERNAME/.ssh/authorized_keys
fi

echo "[*] Enabling SSH..."
systemctl enable sshd

# Optional: Setup SSH key if provided
if [[ -f "$SSH_KEY_FILE" ]]; then
  echo "[*] Setting up SSH public key..."
  mkdir -p /home/$USERNAME/.ssh
  cp "$SSH_KEY_FILE" /home/$USERNAME/.ssh/authorized_keys
  chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
  chmod 700 /home/$USERNAME/.ssh
  chmod 600 /home/$USERNAME/.ssh/authorized_keys
fi

# === Install Bootloader ===
echo "[*] Installing GRUB bootloader..."
boot_mode="bios"
if [ -d /sys/firmware/efi ]; then
  boot_mode="uefi"
  echo "[*] UEFI mode detected"
  pacman -Sy --noconfirm grub efibootmgr dosfstools os-prober mtools
  mkdir -p /boot/efi
  mount $(lsblk -rpno NAME,TYPE | grep part | head -n1) /boot/efi || true
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
else
  echo "[*] BIOS mode detected"
  pacman -Sy --noconfirm grub
  grub-install --target=i386-pc /dev/sda
fi

echo "[*] Generating GRUB config..."
grub-mkconfig -o /boot/grub/grub.cfg

echo "[*] Done. You can now reboot."
