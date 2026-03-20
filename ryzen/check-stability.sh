#!/usr/bin/env bash
# check-stability.sh
# Runs a 10-minute stress test on Ryzen CPUs and monitors temperatures.

if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root." >&2
  exit 1
fi

echo "Installing required tools..."
apt-get update -qq
apt-get install -y -qq stress-ng lm-sensors > /dev/null

CPU_COUNT=$(nproc)
VM_GB=$(awk '/MemTotal/{printf "%d", $2*0.8/1024/1024}' /proc/meminfo)

echo "Starting 10-minute Stress Test ($CPU_COUNT Cores, ~${VM_GB}GB RAM)..."
echo "Press Ctrl+C to stop early."
echo ""

# הפעלת הסטרס ברקע
stress-ng --cpu "$CPU_COUNT" --vm 4 --vm-bytes "${VM_GB}G" --timeout 10m --metrics-brief &
STRESS_PID=$!

# לופ ניטור שמדפיס נתונים כל 2 שניות כל עוד הסטרס רץ
while kill -0 $STRESS_PID 2>/dev/null; do
    clear
    echo "=== RYZEN STRESS TEST IN PROGRESS ==="
    echo "-------------------------------------"
    sensors | grep -E "Tctl|Tdie"
    echo "-------------------------------------"
    grep "cpu MHz" /proc/cpuinfo | head -n 4
    sleep 2
done

echo "Stress test finished!"