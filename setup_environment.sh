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
    # Define the list of GUI packages to install: Xorg server, Openbox window manager, tint2 panel,
    # terminal emulator (lxterminal), and LightDM display manager with GTK greeter
    GUI_PACKAGES="xorg-server openbox tint2 lxterminal lightdm lightdm-gtk-greeter"
    if ! sudo pacman -Sy --noconfirm $GUI_PACKAGES; then
        echo "[!] Failed to install GUI packages. Exiting."
        exit 1
    fi

    # Paths for Openbox autostart script and .xinitrc file to launch Openbox session
    AUTOSTART_PATH="$HOME/.config/openbox/autostart"
    XINITRC_PATH="$HOME/.xinitrc"

    if [ ! -f "$AUTOSTART_PATH" ]; then
        mkdir -p "$(dirname "$AUTOSTART_PATH")"
        cat > "$AUTOSTART_PATH" <<'EOF'
#!/bin/bash
# Set the root window background color to grey
xsetroot -solid grey
# Launch terminal emulator
lxterminal &
# Launch tint2 panel
tint2 &
# If xinput is available, map the first detected touch device to the connected display output
if command -v xinput &>/dev/null; then
    TOUCH_DEVICE=$(xinput list --name-only | grep -i touch | head -n1)
    DISPLAY_OUTPUT=$(xrandr | grep ' connected' | cut -f1 -d ' ' | head -n1)
    if [[ -n "$TOUCH_DEVICE" && -n "$DISPLAY_OUTPUT" ]]; then
        xinput --map-to-output "$TOUCH_DEVICE" "$DISPLAY_OUTPUT"
    fi
fi
# Launch Carla project if the default project file exists
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
        # Write command to start Openbox session when X starts
        echo "exec openbox-session" > "$XINITRC_PATH"
    else
        echo "[!] Skipping .xinitrc setup, file already exists."
    fi

    # Enable LightDM to manage graphical logins on system startup
    echo "[*] Enabling LightDM GUI login manager..."
    if systemctl enable lightdm.service; then
        echo "[+] LightDM enabled successfully."
    else
        echo "[!] Failed to enable LightDM."
    fi
fi

# Summary messages indicating completion status based on GUI or headless mode
if $GUI; then
    echo "[+] GUI setup complete. Reboot to launch LightDM and Openbox environment."
else
    echo "[*] Setup completed in headless mode."
fi
