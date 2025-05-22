#!/bin/bash
# # curl -LO https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/setup-dev-machine.sh chmod +x setup-dev-machine.sh

echo "📦 Installing daily driver packages..."

# Ensure yay is available for AUR installs
if ! command -v yay &> /dev/null; then
  echo "Installing yay..."
  sudo pacman -S --needed git base-devel
  git clone https://aur.archlinux.org/yay.git
  cd yay && makepkg -si && cd .. && rm -rf yay
fi

# Enable flatpak if not already
if ! command -v flatpak &> /dev/null; then
  echo "Installing flatpak..."
  sudo pacman -S flatpak
  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

# Native packages

# Audio and dev packages
AUDIO_PACKAGES=(
  jack2 qjackctl carla a2jmidid rtkit helvum easyeffects
)

# DAWs
DAW_PACKAGES=(
  ardour lmms audacity reaper-bin
)

# Audio plugins
PLUGIN_PACKAGES=(
  calf lsp-plugins dragonfly-reverb zam-plugins
)

DEV_PACKAGES=(
  #docker docker-compose kubectl 
  azure-cli aws-cli terraform
  openjdk gradle nodejs npm python python-pip go jq httpie
)

EXTRA_TOOLS=(
  tmux vim neovim rsync lsof lshw net-tools inetutils nmap
  reflector pkgfile
)

THEMES_AND_FONTS=(
  materia-gtk-theme arc-gtk-theme ttf-jetbrains-mono
  ttf-fira-code ttf-nerd-fonts-symbols
)

sudo pacman -Syu --needed \
  "${AUDIO_PACKAGES[@]}" \
  "${DAW_PACKAGES[@]}" \
  "${PLUGIN_PACKAGES[@]}" \
  "${DEV_PACKAGES[@]}" \
  "${EXTRA_TOOLS[@]}" \
  "${THEMES_AND_FONTS[@]}" \
  firefox \
  thunderbird \
  filezilla \
  libreoffice-fresh \
  git \
  base-devel \
  gnome-keyring \
  gparted \
  vlc \
  krita \
  htop \
  zsh \
  neofetch \
  unzip \
  wget \
  curl \
  gnome-disk-utility \
  papirus-icon-theme \
  noto-fonts noto-fonts-cjk noto-fonts-emoji

# AUR packages via yay
yay -S --needed \
  google-chrome \
  microsoft-edge-stable-bin \
  visual-studio-code-bin \
  teams-for-linux \
  chromium-widevine \
  private-internet-access

echo "🎹 DAWs and plugin suites installed for audio production."
echo "🎧 Audio stack, dev tools, and extra CLI utilities installed!"

# Optional: Flatpak versions (if you prefer)
# flatpak install flathub org.mozilla.firefox -y
# flatpak install flathub com.microsoft.Edge -y
# flatpak install flathub com.visualstudio.code -y
# flatpak install flathub org.kde.krita -y
# flatpak install flathub org.libreoffice.LibreOffice -y
# flatpak install flathub com.github.IsmaelMartinez.teams_for_linux -y

echo "✅ All done! Reboot or log out/in if needed for all apps to show up."