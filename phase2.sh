#!/bin/bash
set -euo pipefail

# === Mount root partition ===
mountpoint -q /mnt || mount $(lsblk -lnpo NAME,TYPE | grep part | awk '{print $1}' | head -n1) /mnt

arch-chroot /mnt /bin/bash <<'EOF'
set -euo pipefail

USERNAME="archadmin"
PASSWORD="SuperSecurePW123!"

# Create user with sudo
useradd -m -G wheel,audio -s /bin/bash $USERNAME || true
echo "$USERNAME:$PASSWORD" | chpasswd

# Enable sudo
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/99_wheel

# Enable services
systemctl enable sshd
loginctl enable-linger $USERNAME

# Install real-time audio dependencies
pacman -Sy --noconfirm pipewire pipewire-alsa pipewire-pulse wireplumber realtime-privileges
usermod -aG realtime $USERNAME

# Setup SSH key if present
if [[ -f /root/ssh_key.pub ]]; then
  mkdir -p /home/$USERNAME/.ssh
  cp /root/ssh_key.pub /home/$USERNAME/.ssh/authorized_keys
  chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
  chmod 600 /home/$USERNAME/.ssh/authorized_keys
  rm /root/ssh_key.pub
fi

EOF

echo "[✓] Phase 2 completed. You may now login as 'archadmin'"
