#!/bin/bash

# Clearing screen
clear 

# Installer version
VERSION="1.0.7"

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
LOG_FILE="gui_setup.log"

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

# Parse command-line arguments for -pw <password>
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -pw|--password) PASSWORD="$2"; shift ;;
        *) echo -e "${R}->${NC} Invalid argument: $1"; exit 1 ;;
    esac
    shift
done

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
echo -e "${LC}#${NC}                   \/         \/                  \/  ${LC}#${NC}"
echo -e "${LC}#########################################################${NC}"
echo -e "${LC}#          ${LP}->${NC} ${LG}VERUS Miner SETUP${NC} by Ch3ckr ${P}<-${NC}            ${LC}#${NC}"
echo -e "${LC}#########################################################${NC}"
echo -e "${LC}#${NC}              ${LG}https://api.rg3d.eu:8443${NC}                 ${LC}#${NC}"
echo -e "${LC}#########################################################${NC}"
echo  # New line for spacing
echo -e "${R}->${NC} ${LC}This process may take a while...${NC}"
echo  # New line for spacing

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

# Run the curl check
check_curl_ssl

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


# Function to prompt for password with verification, or use provided password
function prompt_for_password {
    if [ -n "$PASSWORD" ]; then
        log "Using provided password."
        echo "rig_pw=$PASSWORD" > ~/rig.conf
    else
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
    fi
}

# Function to delete ~/ccminer folder if it exists
function delete_ccminer_folder {
    if [ -d ~/ccminer ]; then
        log "Deleting existing ~/ccminer folder and its contents"
        rm -rf ~/ccminer
    fi
}

# Function to add scripts to crontab
function add_to_crontab {
    local script=$1
    # Remove existing entry from crontab if present
    (crontab -l | grep -v "$script" ; echo "* * * * * ~/$script") | crontab - >/dev/null 2>&1
    log "Added $script to crontab."

    # Start the script immediately after adding to crontab
    log "Starting $script."
    run_command ~/$script
}

# Function to add scripts to crontab
function start_miner_at_reboot {
    # Remove existing entry from crontab if present
    (crontab -l | grep -v "@reboot /usr/bin/screen -dmS CCminer /home/$USER/ccminer/ccminer -c /home/$USER/ccminer/config.json" ; echo "@reboot /usr/bin/screen -dmS CCminer /home/$USER/ccminer/ccminer -c /home/$USER/ccminer/config.json") | crontab - >/dev/null 2>&1
    log "Added automated start of miner at boot."
}

# Delete existing ~/ccminer folder including files in it, if it exists
delete_ccminer_folder

# Request RIG Password from user and store in ~/rig.conf with verification
echo -e "${R}->${NC} Please enter your RIG password.${NC}"
prompt_for_password

# Ensure rig.conf is created and contains the password
if [ -f ~/rig.conf ]; then
    echo -e "${LG}->${NC} Created rig.conf.${NC}"
else
    echo -e "${R}->${NC} Failed to create rig.conf.${NC}"
fi

# Detect OS with debugging
if [[ $(uname -o) == "GNU/Linux" ]]; then
    log "Detected OS: $(uname -o)"
    echo -e "${R}->${NC} Detected OS: $(uname -o)${NC}"
    echo -e "${R}->${NC} ${LC}You might get asked for SUDO password - required for Updates${NC}"
    log "Detected general Linux device"
    echo -e "${R}->${NC} Detected general Linux device${NC}"

    # Update and install necessary packages
    run_command sudo apt-get update
    run_command sudo apt-get install -y openssl git libcurl4-openssl-dev libssl-dev screen wget lm-sensors
    mkdir ~/ccminer
    run_command wget -q -O ~/ccminer/config.json https://raw.githubusercontent.com/dismaster/RG3DUI/main/config.json
    run_command wget -q -O ~/ccminer/ccminer https://raw.githubusercontent.com/FloofyProtoBomb/RG3DUI/refs/heads/x86/ccminer
    # Run jobscheduler.sh and monitor.sh, overwrite if exists
    download_and_make_executable https://raw.githubusercontent.com/FloofyProtoBomb/RG3DUI/refs/heads/x86/jobscheduler.sh jobscheduler.sh
    download_and_make_executable https://raw.githubusercontent.com/FloofyProtoBomb/RG3DUI/refs/heads/x86/monitor.sh monitor.sh

    # Add jobscheduler.sh and monitor.sh to crontab
    add_to_crontab jobscheduler.sh
    add_to_crontab monitor.sh

    # Add ccminer to start on boot
    start_miner_at_reboot
fi

# Remove installation script
run_command rm install.sh

# Start mining instance
run_command screen -dmS CCminer ~/ccminer/ccminer -c ~/ccminer/config.json
run_command ./monitor.sh
run_command ./jobscheduler.sh

# Success message
echo -e "${LG}->${NC} Installation completed and mining started.${NC}"
log "Installation completed and mining started."
