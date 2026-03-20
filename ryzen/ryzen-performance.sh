#!/usr/bin/env bash
# ryzen-performance.sh
#
# PURPOSE: Force all CPU cores to 'performance' governor AND 'performance' EPP.
# COMPATIBILITY: AMD Ryzen with amd_pstate_epp driver (XanMod/Linux 6.x+)

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] This script must be run as root." >&2
  exit 1
fi

SYS_CPU_DIR="/sys/devices/system/cpu"

echo "[INFO] Applying 'performance' profile (Governor + EPP) to all AMD Ryzen cores..."

for cpu_dir in "$SYS_CPU_DIR"/cpu[0-9]*; do
  freq_dir="$cpu_dir/cpufreq"
  if [[ -d "$freq_dir" ]]; then
    # 1. Set the Scaling Governor
    if [[ -w "$freq_dir/scaling_governor" ]]; then
      echo "performance" > "$freq_dir/scaling_governor" 2>/dev/null || true
    fi

    # 2. Set the Energy Performance Preference (EPP) - CRITICAL FOR RYZEN
    if [[ -w "$freq_dir/energy_performance_preference" ]]; then
      echo "performance" > "$freq_dir/energy_performance_preference" 2>/dev/null || true
    fi
  fi
done

# Verification (Checking Core 0 as a representative)
echo ""
echo "[INFO] Verification (Core 0):"
echo "Governor: $(cat "$SYS_CPU_DIR/cpu0/cpufreq/scaling_governor" 2>/dev/null || echo "N/A")"
echo "EPP:      $(cat "$SYS_CPU_DIR/cpu0/cpufreq/energy_performance_preference" 2>/dev/null || echo "N/A")"
echo "[INFO] Done. CPUs are locked to maximum responsiveness."