sleep 2
termux-wake-lock
screen -ls | grep Detached | cut -d. -f1 | awk '{print $1}' | xargs kill
sleep 2
screen -dmS Jobscheduler ./jobscheduler_loop.sh
screen -dmS Monitor ./monitor_loop.sh
screen -dmS CCminer ~/ccminer/ccminer -c ~/ccminer/config.json
termux-toast -s "Mining Started"