

# Arch Auto Installer (Barbaric Edition)

This script fully automates the installation of Arch Linux with:

- Disk partitioning (GPT, UEFI)
- Swap file creation
- Arch keyring refresh to avoid PGP signature errors
- Mirrorlist updates using reflector
- System locale, timezone, and hostname configuration
- Root password setup
- Automatic user creation (if `USERNAME` is not root)
- Enables SSH and NetworkManager services via systemd
- Installs systemd-boot with proper loader entry
- Handles possible firmware warnings gracefully
- Secure random seed warning notification

---

## Usage

Run this script inside an Arch ISO shell or over SSH:

```bash
curl -LO https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/phase1.sh
chmod +x phase1.sh
export USERNAME=archuser
export PASSWORD=SuperSecurePassword123!
export HOSTNAME=archlinux
export DISK=nvme0n1
./phase1.sh
```

**IMPORTANT:** Do not use `USERNAME=root`. The script will abort to prevent login issues.

---

## Recovery + Confirmation (after install)

If you run into a keyring or package integrity issue, try:
pacman -Sy archlinux-keyring --noconfirm

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

You should now boot into a fully configured Arch system with SSH access and `node` as your user.

⚠️ Note: If you receive random seed or font warnings, they are non-blocking and can be addressed post-install.

---

## Features

- Auto-detects primary disk
- Sets up fast mirrors using `reflector`
- Installs base Arch with Zsh
- Enables `NetworkManager` via systemd
- Includes optional SSH key input during install
- Configures systemd-boot and fallback bootloader path
- Installs `openssh` and enables the SSH service
- Uses systemd-boot as the bootloader
- Includes fallback initramfs generation
- Automatically mounts partitions and generates fstab
- Optionally copies in your public SSH key during setup