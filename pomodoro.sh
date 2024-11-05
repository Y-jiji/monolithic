# count of cycles
count=1
while true
do
    sleep $((40*60))
    notify "Rest" "Time for a Rest! ($count)" -a "Pomodoro 🍅"
    sleep $((20*60))
    notify "Work" "Time for Work! ($count)" -a "Pomodoro 🍅"
    count=$($count+1)
done
