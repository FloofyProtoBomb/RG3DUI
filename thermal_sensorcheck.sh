for VARIABLE in $(seq 1 80)
do
	cat /sys/devices/virtual/thermal/thermal_zone$VARIABLE/type
  cat /sys/devices/virtual/thermal/thermal_zone$VARIABLE/temp
done
