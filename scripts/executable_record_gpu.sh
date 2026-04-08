#!/usr/bin/env bash

OUT="$HOME/gpu_metrics.csv"

# Write header if file doesn't exist
if [ ! -f "$OUT" ]; then
    echo "gpu_clock_mhz,vram_clock_mhz,gpu_voltage_mv,temp_vrsoc_c,temp_mem_c,temp_junction_c,temp_vrgfx_c,temp_vrmem_c,temp_edge_c,vram_used_mb,vram_total_mb,fan_percent,fan_rpm" >> "$OUT"
fi

while true; do
    stats=$(lact cli -g 1 stats)

    # Extract values
    gpu_clock=$(echo "$stats" | grep "GPU Clockspeed" | awk '{print $3}')
    vram_clock=$(echo "$stats" | grep "VRAM Clockspeed" | awk '{print $3}')
    gpu_volt=$(echo "$stats" | grep "GPU Voltage" | awk '{print $3}')

    # Temps (order varies, so we normalize)
    temp_vrsoc=$(echo "$stats" | grep -o "vrsoc: [0-9]*" | awk '{print $2}')
    temp_mem=$(echo "$stats" | grep -o "mem: [0-9]*" | awk '{print $2}')
    temp_junction=$(echo "$stats" | grep -o "junction: [0-9]*" | awk '{print $2}')
    temp_vrgfx=$(echo "$stats" | grep -o "vrgfx: [0-9]*" | awk '{print $2}')
    temp_vrmem=$(echo "$stats" | grep -o "vrmem: [0-9]*" | awk '{print $2}')
    temp_edge=$(echo "$stats" | grep -o "edge: [0-9]*" | awk '{print $2}')

    # VRAM usage
    vram_used=$(echo "$stats" | grep "VRAM Usage" | awk '{print $3}' | cut -d'/' -f1)
    vram_total=$(echo "$stats" | grep "VRAM Usage" | awk '{print $3}' | cut -d'/' -f2)

    # Fan
    fan_percent=$(echo "$stats" | grep "Fan Speed" | awk '{print $3}' | tr -d '%')
    fan_rpm=$(echo "$stats" | grep "Fan Speed" | awk -F'[()]' '{print $2}' | awk '{print $1}')

    # Append CSV row
    echo "${gpu_clock},${vram_clock},${gpu_volt},${temp_vrsoc},${temp_mem},${temp_junction},${temp_vrgfx},${temp_vrmem},${temp_edge},${vram_used},${vram_total},${fan_percent},${fan_rpm}" >> "$OUT"

    sleep 1
done

