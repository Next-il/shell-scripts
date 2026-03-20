#!/usr/bin/env bash
# ryzen-network-tuning.sh
#
# PURPOSE:
#   Apply or revert high-performance network sysctl settings optimized for 
#   Game Servers (UDP) and Real-Time APIs / WebSockets (TCP/BBR).
#   Tailored for bare-metal servers with large RAM (e.g., 128GB).

set -euo pipefail

CONFIG_FILE="/etc/sysctl.d/99-game-network.conf"

SYSCTL_KEYS=(
  "net.core.somaxconn"
  "net.core.netdev_max_backlog"
  "net.core.rmem_max"
  "net.core.wmem_max"
  "net.ipv4.udp_rmem_min"
  "net.ipv4.udp_wmem_min"
  "net.ipv4.tcp_rmem"
  "net.ipv4.tcp_wmem"
  "net.ipv4.tcp_max_syn_backlog"
  "net.ipv4.tcp_synack_retries"
  "net.ipv4.tcp_fin_timeout"
  "net.core.default_qdisc"
  "net.ipv4.tcp_congestion_control"
)

usage() {
  cat <<EOF
Usage: $0 {apply|revert|status}

  apply   - Write $CONFIG_FILE with optimized values and apply via sysctl.
  revert  - Backup $CONFIG_FILE and revert to system defaults.
  status  - Show current runtime values for tuned keys.
EOF
}

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] This script must be run as root." >&2
  exit 1
fi

ACTION="${1:-}"

if [[ -z "$ACTION" ]]; then
  usage
  exit 1
fi

backup_existing_file() {
  if [[ -f "$CONFIG_FILE" ]]; then
    local ts backup
    ts="$(date +%Y%m%d-%H%M%S)"
    backup="${CONFIG_FILE}.bak.${ts}"
    cp "$CONFIG_FILE" "$backup"
    echo "[INFO] Existing config backed up to $backup"
  fi
}

write_config() {
  cat > "$CONFIG_FILE" <<'EOF'
# 99-game-network.conf
# Optimized for bare-metal game servers and WebSocket backends.

# Max sockets waiting to be accepted (Crucial for Node.js/Bun APIs under load)
net.core.somaxconn = 8192

# Maximum packets queued on the network interface
net.core.netdev_max_backlog = 16384

# Max socket buffer sizes (128MB - safe for 128GB RAM servers)
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728

# Minimum UDP buffer sizes (Critical for smooth CS2/Game server ticks)
net.ipv4.udp_rmem_min = 131072
net.ipv4.udp_wmem_min = 131072

# TCP memory (min, default, max)
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# Backlog for half-open connections (Mitigates SYN floods)
net.ipv4.tcp_max_syn_backlog = 8192

# Faster SYN/ACK retries & FIN timeout to free up connections quickly
net.ipv4.tcp_synack_retries = 3
net.ipv4.tcp_fin_timeout = 15

# Modern qdisc & congestion control (BBR is built into XanMod - ensures lowest latency)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
}

show_status() {
  echo "[INFO] Runtime values:"
  for key in "${SYSCTL_KEYS[@]}"; do
    if sysctl "$key" >/dev/null 2>&1; then
      sysctl "$key"
    else
      echo "$key = (unavailable on this kernel)"
    fi
  done
}

case "$ACTION" in
  apply)
    echo "[INFO] Applying high-performance network tuning..."
    backup_existing_file
    write_config
    sysctl -p "$CONFIG_FILE" || echo "[WARN] Check $CONFIG_FILE for syntax errors."
    echo "[INFO] Apply complete. Current values:"
    show_status
    ;;
  revert)
    if [[ -f "$CONFIG_FILE" ]]; then
      ts="$(date +%Y%m%d-%H%M%S)"
      backup="${CONFIG_FILE}.reverted.${ts}"
      mv "$CONFIG_FILE" "$backup"
      echo "[INFO] Reverted configuration. Backup saved to $backup"
    else
      echo "[INFO] No configuration found; nothing to revert."
    fi
    sysctl --system || echo "[WARN] Check other *.conf files for syntax errors."
    echo "[INFO] Revert complete. Current values:"
    show_status
    ;;
  status)
    show_status
    ;;
  *)
    usage
    exit 1
    ;;
esac