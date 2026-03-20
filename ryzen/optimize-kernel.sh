#!/usr/bin/env bash
# optimize-kernel.sh
#
# PURPOSE:
#   Advanced System Tuning for Bare-Metal Ryzen Servers (128GB RAM).
#   - Disables Network Interrupt Coalescing for minimum latency.
#   - Optimizes Virtual Memory (Swappiness).
#
# COMPATIBILITY: Ubuntu 24.04 / XanMod Kernel 6.6+ (EEVDF)

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] This script must be run as root." >&2
  exit 1
fi

info(){ printf "\e[1;34m[INFO]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[WARN]\e[0m %s\n" "$*"; }

# ==========================================
# 1. Network Interface Tuning (ethtool)
# ==========================================
info "Installing ethtool..."
apt-get update -qq && apt-get install -y -qq ethtool >/dev/null

PRIMARY_IFACE=$(ip route | grep default | sed -e "s/^.*dev \([^ ]*\).*$/\1/" | head -n 1 || true)

if [[ -n "$PRIMARY_IFACE" ]]; then
  info "Found primary network interface: $PRIMARY_IFACE"
  info "Disabling Interrupt Coalescing (rx-usecs 0) on $PRIMARY_IFACE..."
  ethtool -C "$PRIMARY_IFACE" rx-usecs 0 2>/dev/null || warn "Interface $PRIMARY_IFACE doesn't support rx-usecs."
else
  warn "Could not explicitly detect primary network interface."
fi

# ==========================================
# 2. System Performance & Memory (sysctl)
# ==========================================
SYSCTL_CONF="/etc/sysctl.d/99-kernel-optimization.conf"
info "Writing memory optimizations to $SYSCTL_CONF..."

cat <<EOF > "$SYSCTL_CONF"
# --- (System Memory Optimization) ---
# Reduce Swappiness for 128GB RAM 
vm.swappiness = 10
vm.vfs_cache_pressure = 50

# Increase max open files
fs.file-max = 2097152

# Note: Old CFS Scheduler tuning keys removed for compatibility with Linux 6.6+ (EEVDF)
EOF

info "Applying sysctl changes..."
# Using || true ensures the script doesn't crash if an obscure sysctl key fails on a specific distro
sysctl -p "$SYSCTL_CONF" || warn "Some sysctl keys could not be applied."

# ==========================================
# 3. CPU Preempt Mode
# ==========================================
PREEMPT_FILE="/sys/kernel/debug/sched/preempt"
if [[ -w "$PREEMPT_FILE" ]]; then
  info "Forcing Kernel Preempt to 'full'..."
  echo "full" > "$PREEMPT_FILE" 2>/dev/null || warn "Could not write to $PREEMPT_FILE."
fi

info "Kernel optimization complete!"