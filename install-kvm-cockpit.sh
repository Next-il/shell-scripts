#!/usr/bin/env bash
# install-kvm-cockpit.sh
#
# PURPOSE:
#   Installs KVM hypervisor, Libvirt, and the Cockpit Web GUI for managing VMs.
#   Automatically enables Nested Virtualization for AMD/Intel.
#
# COMPATIBILITY:
#   Ubuntu 24.04 (AMD64 / x86_64)

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] This script must be run as root." >&2
  exit 1
fi

info(){ printf "\e[1;34m[INFO]\e[0m %s\n" "$*"; }

info "Updating package lists..."
apt-get update -qq

# 1. Install KVM, Libvirt, and Bridge utilities
info "Installing KVM and Libvirt packages..."
apt-get install -y -qq qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst > /dev/null

# 2. Install Cockpit and the Machines plugin (for VM management)
info "Installing Cockpit Web GUI and Machines plugin..."
apt-get install -y -qq cockpit cockpit-machines > /dev/null

# 3. Enable Nested Virtualization (AMD & Intel)
info "Configuring Nested Virtualization..."
if grep -q "svm" /proc/cpuinfo; then
    info "AMD CPU detected. Enabling AMD Nested Virtualization."
    echo "options kvm_amd nested=1" > /etc/modprobe.d/kvm-amd.conf
    modprobe -r kvm_amd || true
    modprobe kvm_amd
elif grep -q "vmx" /proc/cpuinfo; then
    info "Intel CPU detected. Enabling Intel Nested Virtualization."
    echo "options kvm_intel nested=1" > /etc/modprobe.d/kvm-intel.conf
    modprobe -r kvm_intel || true
    modprobe kvm_intel
fi

# 4. Enable Services to start on boot
info "Enabling and starting Libvirt & Cockpit services..."
systemctl enable --now libvirtd
systemctl enable --now cockpit.socket

# 5. Start default Libvirt network
info "Configuring default KVM network..."
virsh net-autostart default >/dev/null 2>&1 || true
virsh net-start default >/dev/null 2>&1 || true

# 6. Add the user who ran sudo to the necessary groups
if [[ -n "${SUDO_USER:-}" ]]; then
    info "Adding user $SUDO_USER to libvirt and kvm groups..."
    usermod -aG libvirt,kvm "$SUDO_USER"
fi

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "\e[1;32m[SUCCESS] KVM and Cockpit have been successfully installed!\e[0m"
echo "-------------------------------------------------------------------"
echo "You can now manage your Virtual Machines via the Web GUI."
echo ""
echo "Access URL: https://${SERVER_IP}:9090"
echo "Login with your standard Ubuntu username and password."
echo ""
echo "Note: Your browser will show a security warning (Self-Signed SSL)."
echo "      Simply click 'Advanced' and 'Proceed' to access the panel."
echo "-------------------------------------------------------------------"