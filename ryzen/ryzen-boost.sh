#!/usr/bin/env bash
# ryzen-boost.sh
# 
# PURPOSE: Enable or disable AMD Precision Boost via sysfs.
# COMPATIBILITY: AMD Ryzen (5950X) on Linux 6.x+ (amd_pstate driver)

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root." >&2
  exit 1
fi

ACTION="${1:-}"

if [[ -z "$ACTION" || ( "$ACTION" != "enable" && "$ACTION" != "disable" ) ]]; then
  echo "Usage: $(basename "$0") [enable|disable]" >&2
  exit 1
fi

# Path for AMD P-State Boost control (XanMod/Modern Kernels)
BOOST_PATH="/sys/devices/system/cpu/cpufreq/boost"

if [[ ! -f "$BOOST_PATH" ]]; then
    # Fallback for older drivers if needed
    BOOST_PATH="/sys/devices/system/cpu/amd_pstate/boost_enabled"
fi

if [[ ! -f "$BOOST_PATH" ]]; then
    echo "Error: AMD Boost control not found. Is amd_pstate driver loaded?" >&2
    exit 1
fi

if [[ "$ACTION" == "enable" ]]; then
    echo 1 > "$BOOST_PATH"
    echo "AMD Precision Boost: ENABLED"
else
    echo 0 > "$BOOST_PATH"
    echo "AMD Precision Boost: DISABLED"
fi

# Verify the state
current=$(cat "$BOOST_PATH")
echo "Current CPU Boost State: $current (1=Enabled, 0=Disabled)"