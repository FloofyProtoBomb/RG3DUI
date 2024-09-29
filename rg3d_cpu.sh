#!/bin/bash

# ANSI color codes for formatting
NC='\033[0m'     # No Color
R='\033[0;31m'   # Red
G='\033[1;32m'   # Light Green
Y='\033[1;33m'   # Yellow
LC='\033[1;36m'  # Light Cyan
LG='\033[1;32m'  # Light Green
LB='\033[1;34m'  # Light Blue
P='\033[0;35m'   # Purple
LP='\033[1;35m'  # Light Purple

# Fancy banner
echo -e "${LB} _____ _____ _____ ${NC}"
echo -e "${LB}|     |  _  |  |  |${NC}   ${LC}CCminer${NC}"
echo -e "${LB}|   --|   __|  |  |${NC}   ${LC}Hashrate${NC}"
echo -e "${LB}|_____|__|  |_____|${NC}   ${LC}CPU Check${NC}"
echo -e "${LB} ___| |_ ___ ___| |_ ${NC}"
echo -e "${LB}|  _|   | -_|  _| '_|${NC} by ${LP}@Ch3ckr${NC}"
echo -e "${LB}|___|_|_|___|___|_,_|${NC} ${LG}https://api.rg3d.eu:8443${NC}"
echo -e  # New line for spacing

# Function to calculate average KHS
calculate_avg_khs() {
    local khs_values=("$@")
    local khs_sum=0
    local count=0

    for value in "${khs_values[@]}"; do
        if [[ $value =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            khs_sum=$(echo "$khs_sum + $value" | bc)
            count=$((count + 1))
        fi
    done

    if [ $count -gt 0 ]; then
        avg=$(echo "scale=2; $khs_sum / $count" | bc)
        echo "$avg"
    else
        echo "0.00"
    fi
}

# Ensure bc and netcat are installed
check_and_install_packages() {
    if ! command -v bc &> /dev/null; then
        if [ -d /data/data/com.termux/files/home ]; then
            pkg install bc -y
        else
            sudo apt-get install bc -y
        fi
        bc_status="installed."
    else
        bc_status="already installed."
    fi
}

# Ensure netcat (nc) is installed
check_and_install_nc() {
    if ! command -v nc &> /dev/null; then
        if [ -d /data/data/com.termux/files/home ]; then
            pkg install netcat -y
        else
            sudo apt-get install netcat-traditional -y
        fi
        nc_status="installed."
    else
        nc_status="already installed."
    fi
}

# Function to add crontab entry
add_crontab() {
    if crontab -l | grep -q "rg3d_cpu.sh"; then
        echo -e "${LP}->${NC} Crontab:\033[32m already exists.\033[0m"
    else
        (crontab -l 2>/dev/null; echo "*/5 * * * * $PWD/rg3d_cpu.sh") | crontab -
        echo -e "${LP}->${NC} Crontab:\033[32m added.\033[0m"
    fi
}

# Extract hardware information
extract_hardware() {
    ./cpu_check | grep 'Hardware:' | head -n 1 | sed 's/.*Hardware: //'
}

# Extract architecture information
extract_architecture() {
    ./cpu_check | grep 'Architecture:' | sed 's/.*Architecture: //'
}

# Extract CPU information from the file and parse model and frequency
extract_cpu_info() {
    ./cpu_check | grep 'Processor' | awk -F': ' '{print $2}'
}

# Extract KHS values based on environment
extract_khs_values() {
    echo 'threads' | nc 127.0.0.1 4068 | tr -d '\0' | grep -o "KHS=[0-9]*\.[0-9]*" | awk -F= '{print $2}'
}

# Function to check the number of shares from ccminer
check_shares() {
    shares=$(echo 'summary' | nc 127.0.0.1 4068 | tr -d '\0' | grep -oP '(?<=ACC=)[0-9]+')
    if [ -z "$shares" ]; then
        shares_status="\033[31mError (no share data).\033[0m"
        exit 1
    elif [ "$shares" -lt 150 ]; then
        shares_status="\033[31m$shares (Bad - Below 150).\033[0m"
        exit 0
    else
        shares_status="\033[32m$shares (Good).\033[0m"
    fi
}

# Check if ccminer is running in a screen session or independently
check_ccminer_running() {
    if screen -list | grep -q "CCminer"; then
        ccminer_status="Screen session: 'CCminer'."
    elif pgrep -x "ccminer" > /dev/null; then
        ccminer_status="running."
    else
        ccminer_status="not running. Exiting."
        echo -e "\033[31m$ccminer_status\033[0m"
        exit 1
    fi
}

# Main script execution
detect_and_fetch_cpu_check() {
    if [ -f "./cpu_check" ] && [ -x "./cpu_check" ]; then
        cpu_check_status="exists and is executable."
    else
        if [ -d /data/data/com.termux/files/home ]; then
            wget -4 -O cpu_check https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_arm
        elif uname -a | grep -qi "raspberry\|pine\|odroid\|arm"; then
            wget -4 -O cpu_check https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_sbc
        elif uname -a | grep -qi "android" && [ -f /etc/os-release ] && grep -qi "Ubuntu" /etc/os-release; then
            wget -4 -O cpu_check https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_sbc
        elif uname -a | grep -qi "linux"; then
            wget -4 -O cpu_check https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_sbc
        else
            echo -e "\033[31mUnsupported OS. Exiting.\033[0m"
            exit 1
        fi
        chmod +x cpu_check
        cpu_check_status="downloaded and set as executable."
    fi
}

check_ccminer_config() {
    ccminer_pid=$(pgrep -x "ccminer" | head -n 1)
    
    if [ -n "$ccminer_pid" ]; then
        ccminer_cmd=$(tr '\0' ' ' < /proc/"$ccminer_pid"/cmdline | grep -oP '(?<=-c )[^ ]+')
        config_file="$ccminer_cmd"

        if [ -f "$config_file" ]; then
            if grep -q '"api-allow": "0/0"' "$config_file" && grep -q '"api-bind": "0.0.0.0:4068"' "$config_file"; then
                config_status="\033[32mConfig is properly set.\033[0m"
            else
                config_status="\033[31mMissing required API settings in config.json.\033[0m"
                echo -e "${LP}->${NC} Config check:\033[31m Missing required API settings in $config_file. Exiting.\033[0m"
                exit 1
            fi
        else
            config_status="\033[31mConfig file not found.\033[0m"
            echo -e "${LP}->${NC} Config check:\033[31m Config file not found at $config_file. Exiting.\033[0m"
            exit 1
        fi
    else
        config_status="\033[31mNo ccminer process found.\033[0m"
        echo -e "${LP}->${NC} Config check:\033[31m No ccminer process found. Exiting.\033[0m"
        exit 1
    fi
}

# Check crontab at the start
if [[ "$1" == "-crontab" ]]; then
    add_crontab
fi

# Proceed with main execution
detect_and_fetch_cpu_check
check_and_install_packages
check_and_install_nc
check_ccminer_running
check_ccminer_config
check_shares

hardware=$(extract_hardware)
architecture=$(extract_architecture)
cpu_info_raw=$(extract_cpu_info)
khs_values_raw=$(extract_khs_values)

# Convert CPU info and KHS values to arrays
IFS=$'\n' read -r -d '' -a cpu_info_lines <<<"$cpu_info_raw"
IFS=$'\n' read -r -d '' -a khs_values <<<"$khs_values_raw"

# Check lengths
cpu_count=${#cpu_info_lines[@]}
khs_count=${#khs_values[@]}

if [ "$cpu_count" -ne "$khs_count" ]; then
    echo -e "\033[31mERROR: The number of CPUs does not match the number of KHS values.\033[0m"
    exit 1
fi

declare -A cpu_khs_map

# Populate the map with KHS values grouped by CPU info
for i in "${!cpu_info_lines[@]}"; do
    cpu_info=${cpu_info_lines[$i]}
    khs=${khs_values[$i]}

    if [ -n "${cpu_khs_map[$cpu_info]}" ]; then
        cpu_khs_map[$cpu_info]+=" $khs"
    else
        cpu_khs_map[$cpu_info]=$khs
    fi
done

# Prepare JSON payload
json_payload="{\"hardware\":\"$hardware\", \"architecture\":\"$architecture\", \"cpus\":["

cpu_first=true
for cpu_info in "${!cpu_khs_map[@]}"; do
    if [ "$cpu_first" = true ]; then
        cpu_first=false
    else
        json_payload+=","
    fi

    khs_values=(${cpu_khs_map[$cpu_info]})
    avg_khs=$(calculate_avg_khs "${khs_values[@]}")
    cpu_model=$(echo "$cpu_info" | awk -F' @ ' '{print $1}')
    cpu_freq=$(echo "$cpu_info" | awk -F' @ ' '{print $2}' | sed 's/ MHz//')

    json_payload+="{\"cpu\":\"$cpu_model\", \"frequency\":\"$cpu_freq\", \"avg_khs\":\"$avg_khs\"}"
done
json_payload+="]}"

# Send JSON payload to the PHP API script
api_url="https://api.rg3d.eu:8443/cpu_api.php"
response=$(curl -s -X POST -H "Content-Type: application/json" -d "$json_payload" "$api_url")

if [[ $response == *"success"* ]]; then
    data_status="Success."
else
    data_status="Failed."
fi

# Final user-friendly output
echo -e "${LP}->${NC} Software:\033[32m $cpu_check_status\033[0m"
echo -e "${LP}->${NC} Package (bc):\033[32m $bc_status\033[0m"
echo -e "${LP}->${NC} Package (netcat):\033[32m $nc_status\033[0m"
echo -e "${LP}->${NC} CCminer:\033[32m $ccminer_status\033[0m"
echo -e "${LP}->${NC} Config check:\033[32m $config_status\033[0m"
echo -e "${LP}->${NC} Shares:\033[32m $shares_status\033[0m"
echo -e "${LP}->${NC} Transmission:\033[32m $data_status\033[0m\n"

# Fancy overview of what has been sent
echo -e "${LP}->${NC} Hardware:${LP} $hardware${NC}"
echo -e "${LP}->${NC} Architecture:${LP} $architecture${NC}"

for cpu_info in "${!cpu_khs_map[@]}"; do
    khs_values=(${cpu_khs_map[$cpu_info]})
    avg_khs=$(calculate_avg_khs "${khs_values[@]}")
    cpu_model=$(echo "$cpu_info" | awk -F' @ ' '{print $1}')
    cpu_freq=$(echo "$cpu_info" | awk -F' @ ' '{print $2}')

    echo -e "${LP}->${NC} CPU:${LC} $cpu_model${NC}"
    echo -e "${LP}->${NC} Frequency:${LC} $cpu_freq${NC}"
    echo -e "${LP}->${NC} AVG KHS:${LC} $avg_khs${NC}"
done
