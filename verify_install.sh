#!/bin/bash
## This script verifies the installation of Arch Linux and checks for common issues.
## It is designed to be run after the installation script to ensure everything is set up correctly. 
## curl -LO https://raw.githubusercontent.com/jasonpit/arch-linux-barbaric-quick-install/master/verify_install.sh && chmod +x verify_install.sh && ./verify_install.sh


set -euo pipefail

print_header() {
  echo -e "\n==== $1 ===="
}

check_cmd() {
  if "$@" > /dev/null 2>&1; then
    echo "[PASS] $*"
  else
    echo "[FAIL] $*"
  fi
}

print_header "Network Connectivity"
check_cmd ping -c 1 archlinux.org

print_header "Disk Space Check"
df -h /

print_header "Filesystem Mounts"
findmnt | grep -E '/$|/boot|/home'

print_header "systemd-boot Installed"
check_cmd bootctl is-installed

print_header "/etc/fstab Check"
check_cmd test -s /etc/fstab && cat /etc/fstab

print_header "Hostname"
hostnamectl

print_header "User archadmin Exists"
check_cmd id archadmin

print_header "archadmin Sudo Permissions"
check_cmd sudo -l -U archadmin

print_header "SSHD Service Status"
check_cmd systemctl is-active sshd

print_header "Systemd Boot Target"
check_cmd systemctl get-default

print_header "Essential Packages"
for pkg in vim sudo openssh base; do
  check_cmd pacman -Q $pkg
done

print_header "All checks complete"
echo "✅ System baseline looks clean. Ready to move on to setup."
