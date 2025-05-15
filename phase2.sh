#!/bin/bash

set -euo pipefail

log="/mnt/install.log"
exec > >(tee -a "$log") 2>&1

# Ensure there is enough free space before proceeding
required_space_blocks=160000
available_blocks=$(df --output=avail /mnt | tail -n1)

if [ "$available_blocks" -lt "$required_space_blocks" ]; then
  echo "[\u2717] Not enough disk space on /mnt ($available_blocks < $required_space_blocks blocks)."
  echo "    Resize disk or increase partition size in Phase 1."
  exit 1
fi

# Detect root partition
root_disk=$(lsblk -dn -o NAME,TYPE | awk '$2 == "disk" {print $1}' | head -n1)
root_dev="/dev/$root_disk"
root_part="${root_dev}2"
boot_part="${root_dev}1"

if [ ! -b "$root_part" ] || [ ! -b "$boot_part" ]; then
  echo "Root or boot partition not found. Make sure Phase 1 completed successfully."
  exit 1
fi

# Mount root and boot partitions if not already mounted
if ! mountpoint -q /mnt; then
  mount "$root_part" /mnt
fi

if [ ! -d /mnt/boot ]; then
  mkdir -p /mnt/boot
fi
mount "$boot_part" /mnt/boot

if [ -f /mnt/swapfile ]; then
  if ! grep -q "/mnt/swapfile" /proc/swaps; then
    swapon /mnt/swapfile
  else
    echo "[*] Swap already active, skipping swapon."
  fi
else
  echo "No swapfile found; skipping swap."
fi

# Ensure /mnt/tmp exists before mounting pseudo-filesystems
if [ ! -d /mnt/tmp ]; then
  mkdir -p /mnt/tmp
fi

# Mount system pseudo-filesystems
for fs in dev proc sys run; do
  target="/mnt/$fs"
  if [ ! -d "$target" ]; then
    mkdir -p "$target"
  fi
  if ! mountpoint -q "$target"; then
    mount --bind "/$fs" "$target"
  fi
done

# Ensure required binaries are available in the chroot
if [ ! -x /mnt/usr/bin/ln ]; then
  echo "[!] Required binaries missing from chroot. Attempting to re-run pacstrap..."
  echo "[*] Re-running pacstrap... this may take a moment."
  pacstrap -K /mnt base linux linux-firmware sudo vim --needed || {
    echo "[\u2717] pacstrap failed. Check disk space or network issues."
    exit 1
  }
  if [ ! -x /mnt/usr/bin/ln ]; then
    echo "[\u2717] Recovery attempt failed. Manual intervention required."
    exit 1
  else
    echo "[\u2713] Recovery successful. Continuing..."
  fi
fi

# Set timezone and localization
arch-chroot /mnt ln -sf /usr/share/zoneinfo/UTC /etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
arch-chroot /mnt locale-gen
arch-chroot /mnt bash -c 'echo "LANG=en_US.UTF-8" > /etc/locale.conf'

# Generate dynamic hostname from MAC or fallback to "arch"
MAC=$(cat /sys/class/net/*/address | grep -v 00:00:00 | head -n1)
HOSTNAME=${MAC//:/}
HOSTNAME="arch-${HOSTNAME:0:6}"
arch-chroot /mnt bash -c "echo \"$HOSTNAME\" > /etc/hostname"

# Configure hosts
arch-chroot /mnt bash -c "cat <<EOF > /etc/hosts
127.0.0.1\tlocalhost
::1\t\tlocalhost
127.0.1.1\t$HOSTNAME.localdomain\t$HOSTNAME
EOF"

# Set root password
arch-chroot /mnt bash -c "echo root:SuperSecurePW123! | chpasswd"

# Create default user with realtime + sudo
group_exists=$(arch-chroot /mnt getent group realtime || true)
if [[ -z "$group_exists" ]]; then
  arch-chroot /mnt groupadd realtime
fi
arch-chroot /mnt useradd -m -G wheel,audio,video,optical,storage,realtime -s /bin/bash archadmin
arch-chroot /mnt bash -c "echo archadmin:SuperSecurePW123! | chpasswd"
arch-chroot /mnt sed -i '/%wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers

# Optionally inject SSH key
echo "[*] If you want to add your SSH public key, paste it now. Leave blank to skip:"
read -rp "Enter SSH public key: " SSH_KEY
if [[ -n "$SSH_KEY" ]]; then
    arch-chroot /mnt bash -c "mkdir -p /home/archadmin/.ssh && echo '$SSH_KEY' >> /home/archadmin/.ssh/authorized_keys && chown -R archadmin:archadmin /home/archadmin/.ssh"
fi

# Install packages
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
  jack-example-tools \
  zram-generator || true

# Enable services
arch-chroot /mnt systemctl enable NetworkManager
arch-chroot /mnt systemctl enable sshd

# User services - create persistent overrides to auto-enable if needed
arch-chroot /mnt bash -c "loginctl enable-linger archadmin"
arch-chroot /mnt -u archadmin systemctl --user enable pipewire-pulse
arch-chroot /mnt -u archadmin systemctl --user enable wireplumber

# Optionally setup ZRAM if swapfile not desired
echo "[*] Would you like to enable ZRAM instead of disk swap? (y/N)"
read -rn 1 ENABLE_ZRAM
echo
if [[ "$ENABLE_ZRAM" =~ [Yy] ]]; then
  arch-chroot /mnt bash -c 'cat <<EOF > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram / 2
EOF'
  arch-chroot /mnt rm -f /swapfile
fi

# Disable and remove phase2 systemd service
arch-chroot /mnt systemctl disable phase2-install.service || true
arch-chroot /mnt rm -f /etc/systemd/system/phase2-install.service

echo "[\u2713] Phase 2 complete. Cleaning up..."
umount -R /mnt || true
reboot