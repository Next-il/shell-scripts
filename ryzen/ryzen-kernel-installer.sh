#!/usr/bin/env bash
# ryzen-kernel-installer.sh
#
# PURPOSE:
#   Installs the optimized XanMod Kernel (x64v3 - perfect for Ryzen Zen 3/4)
#   AND applies Ryzen-specific GRUB tuning parameters automatically.
#
# USAGE:
#   curl -sSL https://raw.githubusercontent.com/Next-il/shell-scripts/main/ryzen/ryzen-kernel-installer.sh | sudo bash

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] This script must be run as root." >&2
  exit 1
fi

# =====================
# ===== SETTINGS ======
# =====================
# We use the MAIN branch for production server stability (instead of EDGE)
PKG_NAME="linux-xanmod-x64v3"
AUTO_REBOOT=1

# Ryzen specific GRUB parameters (Optimized for Backend & Game Servers)
# NOTE: mitigations=off was intentionally removed — it disables Spectre/Meltdown/Retbleed
# protections and puts any networked server at risk of cross-process memory leaks.
RYZEN_GRUB_ARGS="quiet transparent_hugepage=never processor.max_cstate=1 nmi_watchdog=0 audit=0"

# =====================
# ===== CONSTANTS =====
# =====================
REPO_FILE="/etc/apt/sources.list.d/xanmod-release.list"
KEYRING="/etc/apt/keyrings/xanmod-archive-keyring.gpg"
XANMOD_DEB_URL="http://deb.xanmod.org"
GPG_URL="https://dl.xanmod.org/archive.key"

info(){ printf "\e[1;34m[INFO]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[WARN]\e[0m %s\n" "$*"; }

# 1) Prepare system
info "Updating APT and installing prerequisites..."
apt-get update -y -qq
apt-get install -y -qq --no-install-recommends wget curl ca-certificates gnupg lsb-release

install -m 0755 -d /etc/apt/keyrings

# 2) Import GPG key
info "Importing XanMod GPG key..."
wget -qO - "$GPG_URL" | gpg --dearmor -o "$KEYRING" --yes
chmod 644 "$KEYRING"

# 3) Add repository
DISTRO=$(lsb_release -cs || echo "stable")
info "Detected distribution codename: $DISTRO"
echo "deb [signed-by=$KEYRING] $XANMOD_DEB_URL releases main" > "$REPO_FILE"
chmod 644 "$REPO_FILE"

# 4) Install the Kernel
info "Refreshing repositories and installing $PKG_NAME..."
apt-get update -y -qq
apt-get install -y "$PKG_NAME"

# 5) Apply Ryzen GRUB Tuning
info "Applying Ryzen-specific GRUB parameters..."
if [[ -f /etc/default/grub ]]; then
  # Backup original GRUB config
  cp /etc/default/grub /etc/default/grub.bak.$(date +%F_%H-%M-%S)
  
  # Replace the default cmdline with our optimized Ryzen arguments
  sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"$RYZEN_GRUB_ARGS\"/" /etc/default/grub
  info "GRUB parameters updated successfully."
else
  warn "/etc/default/grub not found. Skipping GRUB tuning."
fi

# 6) Update initramfs and GRUB
info "Updating initramfs..."
update-initramfs -u -k all || true

if command -v update-grub >/dev/null 2>&1; then
  info "Updating GRUB..."
  update-grub || warn "update-grub returned non-zero"
fi

# 7) Display info
info "Kernel installation and GRUB tuning complete."

# 8) Auto reboot
if [ "$AUTO_REBOOT" -eq 1 ]; then
  info "Auto-reboot enabled. Rebooting in 5 seconds to apply the new kernel..."
  sleep 5
  sync
  reboot
fi