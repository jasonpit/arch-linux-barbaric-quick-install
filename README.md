# Arch Linux Audio Workstation Auto-Installer

This script automates the installation of a clean, headless Arch Linux system, specifically tuned as a base for professional audio development and engineering environments. It is designed for fast deployment on virtual machines, laptops, or desktops, assuming the system will be fully dedicated to Linux audio workflows.

---

##  Features

* Fully automated disk partitioning (wipes primary drive)
* Installs Arch Linux with:

  * PipeWire with JACK support
  * NetworkManager for wired/wireless switching
  * SSH server and sudo preconfigured
  * Git, Vim, Zsh, and base tools
* Prompts for custom hostname, user, and password
* Installs GRUB bootloader with UEFI support
* Works on both virtual machines and real hardware (desktop/laptop)

---

## Usage

You can run this script directly from an Arch Linux live ISO environment (e.g. via SSH into a live Arch session or on the local console).
Once you are at the archiso prompt you can run passwd to set a password and then ip a to get IP addres. then SSH into the installer from another system on your network to make things easier.

### Download and run the script (from Arch ISO):

```bash
curl -LO https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/arch_full_autoinstall.sh
```
> **WARNING:** This script will erase the entire primary disk on the system without confirmation unless modified. Use on dedicated systems or test environments only.

---

## When the sctip it done, reboot, remove install media. - All set 

## What It Installs

* **Base system:** Arch Linux, Linux kernel, firmware
* **Audio stack:** PipeWire, pipewire-jack, WirePlumber
* **Networking:** NetworkManager with automatic wired/wireless support
* **Developer tools:** git, zsh, vim
* **System services:** openssh, sudo, GRUB (EFI bootloader)

---

##  Interactive Prompts

During execution, you’ll be prompted for:

* Hostname
* Username
* Password (used for both root and user account)

---

##  Recommended Use Cases

* Building an audio-focused Linux workstation
* VM-based plugin testing environments
* Rapid setup for live performance rigs or headless synth systems

---

##  License

MIT License — use, adapt, and destroy your drives responsibly.

---

##  Credits

Inspired by the needs of real-time, headless audio engineers who want to avoid the noise and get straight to the signal.
