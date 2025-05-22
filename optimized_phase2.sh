#!/usr/bin/env bash
set -euo pipefail

# Load .env file if present
if [[ -f /root/setup.env ]]; then
    echo "Loading configuration from /root/setup.env"
    source /root/setup.env
fi

# Defaults if env not set
GUI={${GUI:-false}}
DEV_MACHINE={${DEV_MACHINE:-false}}
INSTALL_AUR={${INSTALL_AUR:-false}}

echo "Enabling essential services..."
systemctl enable NetworkManager
systemctl enable sshd

# Install core packages
echo "Installing base development tools..."
pacman -S --noconfirm --needed git base-devel

if [[ "$GUI" == "true" ]]; then
    echo "Installing GUI environment packages..."
    pacman -Sy --noconfirm $GUI_PACKAGES
    pacman -Sy --noconfirm $THEMES_AND_FONTS $BROWSERS_AND_GUI_TOOLS

    echo "Enabling display manager..."
    systemctl enable sddm || systemctl enable lightdm || echo "No DM found"
fi

if [[ "$DEV_MACHINE" == "true" ]]; then
    echo "Installing developer tools..."
    pacman -Syu --noconfirm
    pacman -S --noconfirm --needed flatpak $DEV_PACKAGES $EXTRA_TOOLS
fi

if [[ "$INSTALL_AUR" == "true" ]]; then
    echo "Installing AUR packages using yay..."
    yay -S --noconfirm --needed $AUR_PACKAGES
fi

echo "System setup complete!"
