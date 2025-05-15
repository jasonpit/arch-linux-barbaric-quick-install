# Arch Linux Automated Installation (2-Phase Setup)

This repository contains a fully automated 2-phase installer for Arch Linux. It is designed for quick provisioning of a minimal yet powerful Arch system, optimized for DSP and networked audio environments.

---

## 🚀 Overview

This installation is broken into two distinct phases:

- **Phase 1: `phase1.sh`**
  - Automatically detects root disk (`nvme0n1`, `vda`, or `sda`)
  - Wipes and formats disk
  - Optionally configures ZRAM or swapfile
  - Installs base Arch system with essential packages
  - Prompts for SSH key injection
  - Prepares and installs the `phase2.sh` script
  - Reboots into new system

- **Phase 2: `phase2.sh`**
  - Finalizes system configuration via `arch-chroot`
  - Sets timezone, locale, hostname (MAC-based)
  - Creates default user `archadmin` with sudo and realtime permissions
  - Installs network, audio, and development packages
  - Optionally enables ZRAM via `zram-generator`
  - Enables user linger + systemd audio services
  - Reboots into final system

---

## 🔧 Usage

### 1. Boot into Arch ISO

Start an Arch ISO via UTM, USB, or PXE boot.

Login as `root`.

Ensure you have network connectivity.

### 2. Run Phase 1 Script

```bash
curl -LO https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/phase1.sh
chmod +x phase1.sh
./phase1.sh
```


* Phase 1 prompts for your **SSH public key** (optional), installs base packages, sets up auto-run for Phase 2, and reboots.

### 3. After Reboot: run Phase 2 if it did not automatically run.

```bash
curl -LO https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/phase2.sh
chmod +x phase2.sh
./phase2.sh
```

* Final configurations apply automatically.
* You’ll be prompted to paste your SSH key and then the system will reboot automatically.

You can also rerun it manually (e.g., from chroot):

```bash
arch-chroot /mnt /phase2.sh
```

---

## 🧠 Features

* Dynamic disk detection (`nvme0n1`, `vda`, `sda`)
* ZRAM or disk swap
* MAC-based hostname generation
* Secure user creation (`archadmin`)
* Audio stack: PipeWire + JACK + Realtime
* Network-ready: `NetworkManager`, `openssh`
* Persistent user service enabling
* Logs saved to `/mnt/install.log` (Phase 1 only)

---

## 🔐 Default Credentials

* **User:** `archadmin`
* **Password:** `SuperSecurePW123!` (change this!)

---

## ✅ Future Enhancements

* Phase 2 auto-pull from GitHub if not preloaded
* Support for custom usernames/passwords via CLI args
* Optional graphical stack

---

## 📁 Files

* `phase1.sh` — Initial installer
* `phase2.sh` — Final provisioning (auto-executed)

---

Built for rapid bootstrapping of minimal, headless Arch Linux environments.
