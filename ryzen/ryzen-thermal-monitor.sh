#!/usr/bin/env bash
# ryzen-thermal-monitor.sh
#
# PURPOSE: Monitor Ryzen CPU temperature, frequency, and thermal status.
# Optimized for 5950X on XanMod.

set -euo pipefail

# Check for required tools and install if missing
if ! command -v sensors >/dev/null 2>&1; then
    echo "[INFO] 'lm-sensors' not found. Installing..."
    sudo apt-get update -qq && sudo apt-get install -y -qq lm-sensors > /dev/null
fi

# Function to handle cleanup on exit
cleanup() {
    clear
    echo "Monitoring stopped."
    exit 0
}
trap cleanup SIGINT SIGTERM

echo "--- Ryzen Status Monitor (Press Ctrl+C to stop) ---"

while true; do
    # Clear screen and move cursor to top
    clear
    
    echo "Timestamp: $(date '+%H:%M:%S')"
    echo "-------------------------------------------"
    
    # 1. Get Temperature (Handling multiple outputs from sensors)
    TEMP_STR=$(sensors | grep -E 'Tctl|Tdie' | awk '{print $2}' | head -n 1)
    echo "Current Temp: ${TEMP_STR:-N/A}"
    
    # 2. Get Avg Frequency across all cores
    AVG_FREQ=$(grep "cpu MHz" /proc/cpuinfo | awk '{sum+=$4} END{if(NR>0) printf "%.0f", sum/NR; else print "N/A"}')
    echo "Avg Frequency: ${AVG_FREQ} MHz"
    
    # 3. Check for Throttling (Using bash-native comparison to avoid 'bc' dependency)
    # Remove +, °C and everything after decimal to get integer for comparison
    TEMP_INT=$(echo "$TEMP_STR" | sed 's/+//;s/°C//;s/\..*//')
    
    if [[ -z "$TEMP_INT" ]]; then
        echo -e "\e[1;33m[STATUS] Temperature unavailable (run: sudo sensors-detect)\e[0m"
    elif [ "$TEMP_INT" -gt 89 ]; then
        echo -e "\e[1;31m[STATUS] !!! THERMAL THROTTLING LIKELY ACTIVE !!!\e[0m"
    elif [ "$TEMP_INT" -gt 80 ]; then
        echo -e "\e[1;33m[STATUS] WARNING: HIGH TEMPERATURE\e[0m"
    else
        echo -e "\e[1;32m[STATUS] OPERATING WITHIN THERMAL LIMITS\e[0m"
    fi
    
    echo "-------------------------------------------"
    echo "Core breakdown (Current MHz):"
    # Pretty print core frequencies in a grid-like format
    grep "cpu MHz" /proc/cpuinfo | awk '{printf "%4.0f ", $4} NR%8==0 {print ""}'
    
    sleep 2
done