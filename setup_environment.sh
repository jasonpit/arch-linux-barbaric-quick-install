#!/bin/bash

# setup_environment.sh - Configures system environment, optionally installs GUI (Openbox + LightDM), or runs headless mode.
# # curl -LO https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/setup_environment.sh chmod +x setup_environment.sh
# Determine whether to install GUI components based on the --headless flag
GUI=true
if [[ "${1:-}" == "--headless" ]]; then
    GUI=false
fi

# ... (other setup steps before GUI installation)

if $GUI; then
    # Choose environment type: "openbox" or "kde"
    ENVIRONMENT="kde"

    if [[ "$ENVIRONMENT" == "kde" ]]; then
        GUI_PACKAGES="xorg-server plasma-meta konsole sddm"
        AUDIO_PACKAGES="jack2 qjackctl carla a2jmidid pulseaudio pulseaudio-alsa rtkit pipewire pipewire-alsa pipewire-pulse wireplumber helvum easyeffects"
        DEV_PACKAGES="git base-devel zsh tmux vim neovim docker docker-compose kubectl azure-cli aws-cli terraform openjdk gradle nodejs npm python python-pip go jq httpie"

        EXTRA_TOOLS="neofetch htop btop unzip wget curl rsync lsof lshw net-tools inetutils nmap reflector pkgfile"

        THEMES_AND_FONTS="papirus-icon-theme materia-gtk-theme arc-gtk-theme ttf-jetbrains-mono ttf-fira-code ttf-nerd-fonts-symbols noto-fonts noto-fonts-cjk noto-fonts-emoji"

        BROWSERS_AND_GUI_TOOLS="firefox thunderbird filezilla libreoffice-fresh krita"

        AUR_PACKAGES="google-chrome microsoft-edge-stable-bin visual-studio-code-bin teams-for-linux private-internet-access"
    elif [[ "$ENVIRONMENT" == "openbox" ]]; then
        GUI_PACKAGES="xorg-server openbox tint2 lxterminal lightdm lightdm-gtk-greeter"
    else
        echo "[!] Unknown GUI environment: $ENVIRONMENT. Exiting."
        exit 1
    fi

    if ! sudo pacman -Sy --noconfirm $GUI_PACKAGES; then
        echo "[!] Failed to install GUI packages. Exiting."
        exit 1
    fi

    if [[ "$ENVIRONMENT" == "kde" ]]; then
        if ! sudo pacman -Sy --noconfirm $AUDIO_PACKAGES $DEV_PACKAGES $EXTRA_TOOLS $THEMES_AND_FONTS $BROWSERS_AND_GUI_TOOLS; then
            echo "[!] Failed to install one or more core packages. Exiting."
            exit 1
        fi

        if ! command -v yay &> /dev/null; then
            echo "[*] Installing yay AUR helper..."
            sudo pacman -S --noconfirm --needed git base-devel
            git clone https://aur.archlinux.org/yay.git
            cd yay && makepkg -si --noconfirm && cd .. && rm -rf yay
        fi

        echo "[*] Installing AUR packages with yay..."
        yay -S --noconfirm --needed $AUR_PACKAGES
    fi

    if [[ "$ENVIRONMENT" == "openbox" ]]; then
        AUTOSTART_PATH="$HOME/.config/openbox/autostart"
        XINITRC_PATH="$HOME/.xinitrc"

        if [ ! -f "$AUTOSTART_PATH" ]; then
            mkdir -p "$(dirname "$AUTOSTART_PATH")"
            cat > "$AUTOSTART_PATH" <<'EOF'
#!/bin/bash
xsetroot -solid grey
lxterminal &
tint2 &
if command -v xinput &>/dev/null; then
    TOUCH_DEVICE=$(xinput list --name-only | grep -i touch | head -n1)
    DISPLAY_OUTPUT=$(xrandr | grep ' connected' | cut -f1 -d ' ' | head -n1)
    if [[ -n "$TOUCH_DEVICE" && -n "$DISPLAY_OUTPUT" ]]; then
        xinput --map-to-output "$TOUCH_DEVICE" "$DISPLAY_OUTPUT"
    fi
fi
if [ -f "$HOME/carla-default.carxp" ]; then
    carla-rack "$HOME/carla-default.carxp" &
else
    echo "[!] Carla project not found at ~/carla-default.carxp, skipping auto-launch."
fi
EOF
            chmod +x "$AUTOSTART_PATH"
        else
            echo "[!] Skipping autostart setup, file already exists."
        fi

        if [ ! -f "$XINITRC_PATH" ]; then
            echo "exec openbox-session" > "$XINITRC_PATH"
        else
            echo "[!] Skipping .xinitrc setup, file already exists."
        fi
    fi

    if [[ "$ENVIRONMENT" == "kde" ]]; then
        echo "[*] Enabling SDDM login manager..."
        systemctl enable sddm.service
    else
        echo "[*] Enabling LightDM GUI login manager..."
        systemctl enable lightdm.service
    fi
fi

# Summary messages indicating completion status based on GUI or headless mode
if $GUI; then
    echo "[+] GUI setup complete. Reboot to launch LightDM and Openbox environment."
    echo "[+] Audio, dev, and AUR packages installed. You're ready to build, route, and shred!"
else
    echo "[*] Setup completed in headless mode."
fi
