

# Arch Auto Installer (Barbaric Edition)

This script fully automates the installation of Arch Linux with:

- Disk partitioning (GPT, UEFI)
- Swap file creation
- Systemd-boot installation and fallback bootloader setup
- SSH configuration (enabled on first boot)
- NetworkManager setup
- User creation (non-root)

---

## 🔧 Usage

Run this script inside an Arch ISO shell or over SSH:

```bash
curl -LO https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/arch_auto_installer_v2.sh
chmod +x arch_auto_installer_v2.sh
USERNAME=node PASSWORD=meat HOSTNAME=nodeos ./arch_auto_installer_v2.sh
```

🛑 **IMPORTANT:** Do not use `USERNAME=root`. The script will abort to prevent login issues.

---

## 🛠 Recovery + Confirmation (after install)

If you reboot and land in the UEFI shell or cannot log in, follow these steps:

### Step 1: Mount and enter chroot
Boot back into the ISO and run:

```bash
mount /dev/sda2 /mnt
mount /dev/sda1 /mnt/boot
arch-chroot /mnt
```

### Step 2: Set root password & create user

```bash
passwd root

useradd -m -G wheel -s /bin/zsh node
passwd node
```

Enable SSH key login if needed:

```bash
mkdir -p /home/node/.ssh
echo "your-public-ssh-key" > /home/node/.ssh/authorized_keys
chmod 700 /home/node/.ssh
chmod 600 /home/node/.ssh/authorized_keys
chown -R node:node /home/node/.ssh
```

### Step 3: Reboot

```bash
exit
umount -R /mnt
reboot
```

✅ You should now boot into a fully configured Arch system with SSH access and `node` as your user.

---

## 🧠 Features

- Auto-detects primary disk
- Sets up fast mirrors using `reflector`
- Installs base Arch with Zsh
- Enables systemd-networkd with `NetworkManager`
- Includes optional SSH key input during install
- Configures systemd-boot and fallback bootloader path