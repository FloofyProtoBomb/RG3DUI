  for cpuseq in $(seq 1 60)
  do
    v3=$(cat /sys/devices/virtual/thermal/thermal_zone$cpuseq/type 2>/dev/null)
    v4="soc"
    if [[ "$v3" == "$v4" ]]; then
      cpu_temp_raw=$(cat /sys/devices/virtual/thermal/thermal_zone$cpuseq/temp 2>/dev/null)
      cpu_temp=$((cpu_temp_raw / 1000))
      break
    fi
  done


    for cpuseq in $(seq 1 60)
  do
    v3=$(cat /sys/devices/virtual/thermal/thermal_zone$cpuseq/type 2>/dev/null)
    v4="soc"
    if [[ "$v3" == "$v4" ]]; then
      cpu_temp_raw=$(cat /sys/devices/virtual/thermal/thermal_zone$cpuseq/temp 2>/dev/null)
      cpu_temp=$((cpu_temp_raw / 1000))
      break
    fi
  done
