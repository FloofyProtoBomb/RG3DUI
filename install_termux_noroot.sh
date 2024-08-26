#!/bin/bash

# Clearing screen
clear


# Installer version
VERSION="1.0t"

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

# Log file location
LOG_FILE="termux_setup.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - v$VERSION - $@" | tee -a $LOG_FILE
}

# Function to run commands and log their output
run_command() {
    log "Running command: $@"
    "$@" >> $LOG_FILE 2>&1
    local status=$?
    if [ $status -ne 0 ]; then
        log "Command failed with status $status"
    fi
    return $status
}

# Function to check if curl works properly with SSL
check_curl_ssl() {
    log "Checking if curl works with SSL..."
    curl -sI https://www.google.com > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "curl is working properly with SSL."
        CURL_CMD="curl -sSL"
    else
        log "curl is not working properly with SSL, switching to --insecure mode."
        CURL_CMD="curl -sSL --insecure"
    fi
}

# Function to download a file and make it executable, overwrite if exists
download_and_make_executable() {
    local url=$1
    local filename=$2
    local target_dir=$3

    if [ ! -z "$target_dir" ]; then
        cd $target_dir
    fi

    log "Downloading $url to $filename"
    $CURL_CMD $url -o $filename
    if [ $? -eq 0 ]; then
        chmod +x $filename
        log "Downloaded and made executable: $filename"
    else
        log "Failed to download $url"
    fi
}

# Function to prompt for password with verification
function prompt_for_password {
    while true; do
        echo -e "${R}->${NC} ${Y}Enter RIG Password:${NC}"
        read -s pw1
        echo
        echo -e "${R}->${NC} ${Y}Confirm RIG Password:${NC}"
        read -s pw2
        echo

        if [[ "$pw1" == "$pw2" ]]; then
            echo "rig_pw=$pw1" > ~/rig.conf
            log "Password set successfully."
            break
        else
            log "Passwords do not match."
            echo -e "${R}->${NC} ${R}Passwords do not match. Please try again.${NC}"
        fi
    done
}

# Function to delete ~/ccminer folder if it exists
function delete_ccminer_folder {
    if [ -d ~/ccminer ]; then
        log "Deleting existing ~/ccminer folder and its contents"
        rm -rf ~/ccminer
    fi
    if [ -d ~/ccminer_build ]; then
        log "Deleting existing ~/ccminer_build folder and its contents"
        rm -rf ~/ccminer_build
    fi
}




# Fancy Banner with RG3D VERUS Logo
echo -e "${LC}#########################################################${NC}"
echo -e "${LC}#${NC} ${LB}     __________   ________ ________  ________         ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}     \______   \ /  _____/ \_____  \ \______ \        ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}      |       _//   \  ___   _(__  <  |    |  \       ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}      |    |   \\    \_\  \ /       \ |     |   \      ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}      |____|_  / \______  //______  //_______  /      ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}             \/         \/        \/         \/       ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}____   _________________________  ____ ___  _________ ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}\   \ /   /\_   _____/\______   \|    |   \/   _____/ ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB} \   Y   /  |    __)_  |       _/|    |   /\_____  \  ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}  \     /   |        \ |    |   \|    |  / /        \ ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}   \___/   /_______  / |____|_  /|______/ /_______  / ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}                   \/         \/                  \/  ${LC}#${NC}"
echo -e "${LC}#########################################################${NC}"
echo -e "${LC}#          ${LP}->${NC} ${LG}VERUS Miner SETUP${NC} by Ch3ckr ${P}<-${NC}            ${LC}#${NC}"
echo -e "${LC}#########################################################${NC}"
echo -e "${LC}#${NC}              ${LG}https://api.rg3d.eu:8443${NC}                 ${LC}#${NC}"
echo -e "${LC}#########################################################${NC}"
echo  # New line for spacing
echo -e "${R}->${NC} ${LC}This process may take a while...${NC}"
echo  # New line for spacing

check_curl_ssl

delete_ccminer_folder



if command -v termux-info > /dev/null 2>&1; then
	log "Running on Termux :)"
	echo -e "${R}->${NC} Please enter your RIG password.${NC}"
	prompt_for_password
	# Ensure rig.conf is created and contains the password
	if [ -f ~/rig.conf ]; then
		echo -e "${LG}->${NC} Created rig.conf.${NC}"
	else
		echo -e "${R}->${NC} Failed to create rig.conf.${NC}"
	fi
	# Update and upgrade packages
	log "Updating and upgrading packages"
	run_command pkg update -y
	run_command pkg upgrade -y

	# Install required packages
	log "Installing required packages"
	run_command pkg install -y termux-auth termux-api libjansson wget nano git screen openssh libjansson netcat-openbsd jq iproute2 tsu android-tools

	# Create ~/ccminer folder if not exists
	log "Creating ~/ccminer folder"
	run_command mkdir -p ~/ccminer

	# Download ccminer and make it executable, overwrite if exists
	log "Downloading ccminer"
	run_command wget -q https://raw.githubusercontent.com/Darktron/pre-compiled/generic/ccminer -O ~/ccminer/ccminer
	run_command chmod +x ~/ccminer/ccminer

	# Run jobscheduler.sh, monitor.sh and vcgencmd, overwrite if exists
	log "Downloading and setting up jobscheduler.sh, monitor.sh, and vcgencmd"
	download_and_make_executable https://raw.githubusercontent.com/FloofyProtoBomb/RG3DUI/Termux/jobscheduler_loop.sh jobscheduler_loop.sh
	download_and_make_executable https://raw.githubusercontent.com/FloofyProtoBomb/RG3DUI/Termux/monitor_loop.sh monitor_loop.sh
	download_and_make_executable https://raw.githubusercontent.com/FloofyProtoBomb/RG3DUI/Termux/bashrc .bashrc
	# Install default config for DONATION
	log "Downloading default config"
	run_command wget -q -O ~/ccminer/config.json https://raw.githubusercontent.com/dismaster/RG3DUI/main/config.json
	# Add jobscheduler.sh and monitor.sh to crontab
	log "Adding jobscheduler.sh and monitor.sh to startup"
	#log "Running CCMiner for 3 minutes to fix thread count."
	run_command screen -ls | grep Detached | cut -d. -f1 | awk '{print $1}' | xargs kill
	sleep 2
	#run_command screen -dmS Jobscheduler ./jobscheduler_loop.sh
	#run_command screen -dmS Monitor ./monitor_loop.sh
	#run_command screen -dmS CCminer ~/ccminer/ccminer -c ~/ccminer/config.json
	#sleep 180
	#log "Clearing screens and restarting."
	#run_command screen -ls | grep Detached | cut -d. -f1 | awk '{print $1}' | xargs kill
	#sleep 2
	#run_command screen -dmS Jobscheduler ./jobscheduler_loop.sh
	#run_command screen -dmS Monitor ./monitor_loop.sh
	#run_command screen -dmS CCminer ~/ccminer/ccminer -c ~/ccminer/config.json
 	run_command termux-toast "Please Relaunch Termux"
	exit 0
else
	log "Termux not detected, exiting"
	echo -e "${R}->${NC} Termux not detected. Please run this script in a Termux environment.${NC}"
	exit 1
fi
