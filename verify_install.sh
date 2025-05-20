#!/bin/bash

GUI=true
if [[ "${1:-}" == "--headless" ]]; then
    GUI=false
fi

# ... (other setup steps before GUI installation)

if $GUI; then
    GUI_PACKAGES="xorg-server openbox tint2 lxterminal lightdm lightdm-gtk-greeter"
    sudo pacman -Sy --noconfirm $GUI_PACKAGES

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
    xinput --map-to-output "$(xinput list --name-only | grep -i touch)" "$(xrandr | grep ' connected' | cut -f1 -d ' ')"
fi
carla-rack ~/carla-default.carxp &
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

    echo "[*] Enabling LightDM GUI login manager..."
    if systemctl enable lightdm.service; then
        echo "[+] LightDM enabled successfully."
    else
        echo "[!] Failed to enable LightDM."
    fi
fi

# ... (other setup steps after GUI installation)

if $GUI; then
    echo "[*] Setup completed with GUI enabled."
else
    echo "[*] Setup completed in headless mode."
fi
