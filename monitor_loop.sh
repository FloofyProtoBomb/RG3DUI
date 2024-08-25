#!/bin/bash

# Version number
VERSION="1.0t"

# Function to check if API URL is reachable with SSL
check_ssl_support() {
  local url="https://api.rg3d.eu:8443/api.php"
  if curl --output /dev/null --silent --head --fail --connect-timeout 5 --max-time 10 "$url"; then
    return 0  # SSL supported
  else
    return 1  # SSL not supported
  fi
}

# Function to send data to PHP script or echo if dryrun
send_data() {
  local url="https://api.rg3d.eu:8443/api.php"
  local data="hw_brand=$hw_brand&hw_model=$hw_model&ip=$mac&summary=$summary_json&pool=$pool_json&battery=$batt_temp_json&cpu_temp=$cpu_temp_json&cpu_max=$cpu_count&password=$rig_pw&monitor_version=$VERSION&scheduler_version=$scheduler_version"

  if [ -n "$miner_id" ]; then
    data+="&miner_id=$miner_id"
  fi

  if [ "$dryrun" == true ]; then
    echo "curl -s -X POST -d \"$data\" \"$url\""
  elif [ "$ssl_supported" == "true" ]; then
    response=$(curl -s -X POST -d "$data" "$url")
    echo "Response from server: $response"
  else
    response=$(curl -s -k -X POST -d "$data" "$url")
    echo "Response from server (insecure): $response"
  fi

  # Extracting miner_id from the response
  miner_id=$(echo "$response" | jq -r '.miner_id')

  # Check if miner_id is valid and update rig.conf
  if [[ "$miner_id" =~ ^[0-9]+$ ]]; then
    update_rig_conf "$miner_id"
  else
    echo "Invalid miner_id received: $miner_id"
  fi
}

# Function to update rig.conf with miner_id and ssl_supported
update_rig_conf() {
  local miner_id=$1
  local rig_conf_path=~/rig.conf

  if [ -f "$rig_conf_path" ]; then
    if grep -q "miner_id=" "$rig_conf_path"; then
      sed -i "s/miner_id=.*/miner_id=$(printf '%q' "$miner_id")/" "$rig_conf_path"
    else
      echo "miner_id=$miner_id" >> "$rig_conf_path"
    fi

    if grep -q "ssl_supported=" "$rig_conf_path"; then
      sed -i "s/ssl_supported=.*/ssl_supported=$(printf '%q' "$ssl_supported")/" "$rig_conf_path"
    else
      echo "ssl_supported=$ssl_supported" >> "$rig_conf_path"
    fi
  else
    echo "rig.conf file not found. Creating a new one."
    echo "miner_id=$miner_id" > "$rig_conf_path"
    echo "ssl_supported=$ssl_supported" >> "$rig_conf_path"
  fi
}

# Function to measure time of an action
measure_time() {
  local label=$1
  local start_time=$2
  local end_time=$(date +%s%N)
  local elapsed=$((end_time - start_time))
  echo "$label took $(echo "scale=3; $elapsed / 1000000000" | bc) seconds"
}

# Start the monitoring loop
while true; do
  # Start the overall timer
  overall_start_time=$(date +%s%N)

  # Determine SSL support and update rig.conf only if not already set
  ssl_supported="false"
  if [ -f ~/rig.conf ]; then
    ssl_supported=$(grep -E "^ssl_supported=" ~/rig.conf | cut -d '=' -f 2)
  fi

  if [ -z "$ssl_supported" ]; then
    ssl_start_time=$(date +%s%N)
    if check_ssl_support; then
      ssl_supported="true"
    else
      ssl_supported="false"
    fi
    # Update rig.conf with the SSL support status
    update_rig_conf "$miner_id"
    measure_time "SSL check" $ssl_start_time
  fi

  # Get the number of CPUs
  cpu_start_time=$(date +%s%N)
  cpu_count=$(lscpu | grep -E '^CPU\(s\):' | awk '{print $2}')
  measure_time "CPU count retrieval" $cpu_start_time

  # Parse arguments
  dryrun=false
  if [ "$1" == "--dryrun" ]; then
    dryrun=true
  fi

  # 1. Check if ~/rig.conf exists and rig_pw is set
  config_check_start_time=$(date +%s%N)
  if [ -f ~/rig.conf ]; then
    rig_pw=$(grep -E "^rig_pw=" ~/rig.conf | cut -d '=' -f 2)
    if [ -z "$rig_pw" ]; then
      echo "rig_pw not set in ~/rig.conf. Exiting."
      exit 1
    fi
    miner_id=$(grep -E "^miner_id=" ~/rig.conf | cut -d '=' -f 2)
  else
    echo "~/rig.conf file not found. Exiting."
    exit 1
  fi
  measure_time "Config file check" $config_check_start_time

  # 2. Check hardware brand and format to uppercase
  hw_start_time=$(date +%s%N)
  if [ -n "$(uname -o | grep Android)" ]; then
    hw_brand=$(getprop ro.product.brand | tr '[:lower:]' '[:upper:]')
  else
    hw_brand="ERR"
  fi
  measure_time "Hardware brand check" $hw_start_time

  # 3. Check hardware model and format to uppercase
  model_start_time=$(date +%s%N)
  if [ -n "$(uname -o | grep Android)" ]; then
    hw_model=$(getprop ro.product.model)
  else
    hw_model=$(uname -m)
  fi
  hw_model=$(echo "$hw_model" | tr '[:lower:]' '[:upper:]')
  measure_time "Hardware model check" $model_start_time

  # 4. Get MAC address
  mac_start_time=$(date +%s%N)
  if [ -n "$(uname -o | grep Android)" ]; then
    # For Android
    mac=$(getprop persist.sys.wifi_mac | sed s/:/./g) 
    if [ -z "$mac" ]; then
      # If no MAC address was found, set to null
      mac="null"
    fi
  fi

  measure_time "MAC address retrieval" $mac_start_time

  # 5. Check if ccminer is running, exit if not
  miner_check_start_time=$(date +%s%N)
  if ! screen -list | grep -q "\.CCminer"; then
    echo "ccminer not running. Exiting."
    exit 1
  fi
  measure_time "Miner check" $miner_check_start_time

  # 6. Get summary output of ccminer API socket (default port)
  summary_start_time=$(date +%s%N)
  summary_raw=$(echo 'summary' | nc 127.0.0.1 4068 | tr -d '\0')
  summary_raw=${summary_raw%|}  # Remove trailing '|'
  summary_json=$(echo "$summary_raw" | jq -R 'split(";") | map(split("=")) | map({(.[0]): .[1]}) | add')
  measure_time "Summary retrieval" $summary_start_time

  # 7. Get pool output of ccminer API socket (default port)
  pool_start_time=$(date +%s%N)
  pool_raw=$(echo 'pool' | nc 127.0.0.1 4068 | tr -d '\0')
  pool_raw=${pool_raw%|}  # Remove trailing '|'
  pool_json=$(echo "$pool_raw" | jq -R 'split(";") | map(split("=")) | map({(.[0]): .[1]}) | add')
  measure_time "Pool retrieval" $pool_start_time

  # 8. Check battery status if OS is Termux
  battery_start_time=$(date +%s%N)
    for battseq in $(seq 1 60); do
    v1=$(cat /sys/devices/virtual/thermal/thermal_zone$battseq/type 2>/dev/null)
    v2="battery"
    if [[ "$v1" == "$v2" ]]; then
      batt_temp_raw=$(cat /sys/devices/virtual/thermal/thermal_zone$battseq/temp 2>/dev/null)
      batt_temp=$((batt_temp_raw / 1000))
      break
    fi
  done
  measure_time "Battery status check" $battery_start_time

# 9. Check CPU temperature

  for cpuseq in $(seq 1 60); do
    v3=$(cat /sys/devices/virtual/thermal/thermal_zone$cpuseq/type 2>/dev/null)
    v4="soc"
    if [[ "$v3" == "v4" ]]; then
      cpu_temp_raw=$(cat /sys/devices/virtual/thermal/thermal_zone$cpuseq/temp 2>/dev/null)
      cpu_temp=$((cpu_temp_raw / 1000))
      break
    fi
  done

# Format cpu_temp as JSON
cpu_temp_json="{\"temp\":\"$cpu_temp\"}"
batt_temp_json="{\"temperature\":\"$batt_temp\"}"

  # Get the scheduler version from the jobscheduler.sh file
  scheduler_version_start_time=$(date +%s%N)
  scheduler_version=$(grep -E "^VERSION=" ~/jobscheduler_loop.sh | cut -d '=' -f 2 | tr -d '"')
  measure_time "Scheduler version check" $scheduler_version_start_time

  # Send data to PHP script or echo if dryrun
  send_data_start_time=$(date +%s%N)
  send_data
  measure_time "Data sending" $send_data_start_time

  # Calculate and display overall execution time
  measure_time "Overall execution" $overall_start_time

  # Sleep for a specified interval before running again
  sleep 60  # Set the interval in seconds (e.g., 60 seconds for a 1-minute loop)
done
