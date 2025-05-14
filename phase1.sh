#!/usr/bin/env bash

set -euo pipefail

# --- CONFIG ---
DEFAULT_HOSTNAME="arch"
SSH_KEY=""
ZRAM_ENABLE=true
LOG_FILE="/mnt/install.log"

# --- Detect Root Disk ---
get_root_disk() {
  for dev in nvme0n1 vda sda; do
    if [[ -b "/dev/$dev" ]]; then
      echo "/dev/$dev"
      return
    fi
  done
  echo "No suitable block device found." >&2
  exit 1
}

ROOT_DISK=$(get_root_disk)
echo "[+] Using disk: $ROOT_DISK"

# --- Prompt for SSH Key ---
echo "Paste your SSH public key (or leave blank to skip):"
read -r SSH_KEY

# --- Wipe Disk and Partition ---
echo "[*] Wiping $ROOT_DISK and creating partitions..."
sgdisk --zap-all "$ROOT_DISK"
sgdisk -n 1:0:100% -t 1:8300 "$ROOT_DISK"
mkfs.ext4 -F "${ROOT_DISK}p1" -L rootfs
mount "${ROOT_DISK}p1" /mnt

# --- Optional: ZRAM Setup ---
if $ZRAM_ENABLE; then
  echo "[*] Setting up ZRAM swap..."
  echo 'zram' > /mnt/etc/modules-load.d/zram.conf
  cat <<EOF > /mnt/etc/udev/rules.d/99-zram.rules
KERNEL=="zram0", ATTR{disksize}="2G", TAG+="systemd"
EOF
  mkdir -p /mnt/etc/systemd/system
  cat <<EOF > /mnt/etc/systemd/system/zram-swap.service
[Unit]
Description=ZRAM Swap
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'mkswap /dev/zram0 && swapon /dev/zram0'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
else
  echo "[*] Creating swapfile..."
  fallocate -l 2G /mnt/swapfile
  chmod 600 /mnt/swapfile
  mkswap /mnt/swapfile
  swapon /mnt/swapfile
fi

# --- Install Base System ---
pacstrap -K /mnt base linux linux-firmware openssh sudo vim &>> "$LOG_FILE"

# --- Generate fstab ---
genfstab -U /mnt >> /mnt/etc/fstab

# --- Configure Hostname ---
echo "$DEFAULT_HOSTNAME" > /mnt/etc/hostname

# --- Create Phase 2 Script ---
cat <<'EOF' > /mnt/phase2.sh
#!/bin/bash
set -e

# Set timezone and locale
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Enable SSH
systemctl enable sshd

# Create user
useradd -m -G wheel,audio realtime -s /bin/bash archadmin
echo "archadmin:changeme" | chpasswd

echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel

# Inject SSH key
mkdir -p /home/archadmin/.ssh
chmod 700 /home/archadmin/.ssh
echo "$SSH_KEY" > /home/archadmin/.ssh/authorized_keys
chmod 600 /home/archadmin/.ssh/authorized_keys
chown -R archadmin:archadmin /home/archadmin/.ssh

# Enable ZRAM swap if configured
if [ -f /etc/systemd/system/zram-swap.service ]; then
  systemctl enable zram-swap.service
fi

EOF
chmod +x /mnt/phase2.sh

# --- Run Phase 2 on Login ---
echo "bash /mnt/phase2.sh" >> /mnt/root/.bash_profile

# --- Done ---
echo "[!] Rebooting to apply changes... After reboot, run manually if needed: bash /mnt/phase2.sh"
reboot
