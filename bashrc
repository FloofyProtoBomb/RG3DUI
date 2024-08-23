screen -ls | grep Detached | cut -d. -f1 | awk '{print $1}' | xargs kill
sleep 2
screen -dmS Jobscheduler ./jobscheduler.sh
screen -dmS Monitor ./monitor.sh
screen -dmS CCminer ~/ccminer/ccminer -c ~/ccminer/config.json
