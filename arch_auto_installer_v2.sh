Verify Install
1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
26
27
28
29
30
31
32
33
34
35
36
37
38
39
40
41
42
43
44
45
46
47
48
49
50
51
52
53
54
55
56
57
58
59
60
61
62
63
64
65
66
67
68
69
70
71
72
73
74
75
76
77
78
79
#!/bin/bash
# run like this 
# curl -LO https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/arch_auto_installer_v2.sh
# chmod +x arch_auto_installer_v2.sh
#
# export USERNAME=username
# export PASSWORD=password
# export HOSTNAME=arch

# This script automates the installation of Arch Linux with a focus on simplicity and speed.
# It is designed to be run from a live USB environment and will partition, format, and install the base system.

# Clean any existing mounts to avoid errors on rerun
umount -R /mnt 2>/dev/null || true

set -euo pipefail

# Validate that USERNAME is set and not "root"
if [[ -z "${USERNAME:-}" || "${USERNAME}" == "root" ]]; then
  echo "[!] USERNAME is either empty or explicitly set to 'root' — this is not allowed."
  exit 1
fi

echo "[debug] Raw \$USERNAME='$USERNAME'"

# === USER CONFIG ===
PASSWORD="${PASSWORD:-SuperSecurePassword123!}"
HOSTNAME="${HOSTNAME:-archlinux}"
TIMEZONE="America/Los_Angeles"
LOCALE="en_US.UTF-8"
KEYMAP="us"
SWAP_SIZE="32G"

echo "[debug] Detected effective USERNAME='$USERNAME'"

log="/mnt/install.log"
exec > >(tee -a "$log") 2>&1

# === Disk selection ===
echo "[*] Available disks:"
lsblk -d -o NAME,SIZE,MODEL | grep -v loop

if [[ -n "${DISK:-}" ]]; then
  echo "[+] Using disk from environment: /dev/$DISK"
else
  echo -n "Enter the disk to install to (e.g., sda): "
  read -r DISK
fi

DISK="/dev/${DISK}"
echo "[+] Final disk selection: $DISK"

# === Mirrorlist update ===
echo "[*] Installing reflector and updating mirrorlist..."
pacman -Sy --noconfirm reflector
reflector --country US --latest 10 --sort rate --protocol https --save /etc/pacman.d/mirrorlist

# === SSH Key (optional) ===
echo -n "Paste your SSH public key (or leave blank to skip): "
read -r SSH_KEY

# === Partition disk ===
echo "[*] Partitioning $DISK..."
echo "[*] Wiping existing filesystem signatures..."
wipefs -a "$DISK"
echo "[*] Zapping GPT and partition table..."
sgdisk --zap-all "$DISK"
dd if=/dev/zero of="$DISK" bs=1M count=100 status=progress
partprobe "$DISK"
sleep 2
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System" "$DISK"
sgdisk -n 2:0:0     -t 2:8300 -c 2:"Linux Root" "$DISK"
partprobe "$DISK"
sleep 2

# Assign partition variables after partitioning
if [[ "$DISK" == *"nvme"* ]]; then
  EFI_PART="${DISK}p1"
  ROOT_PART="${DISK}p2"
