#!/bin/bash

killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done
polybar -l info makc &

if type "xrandr"; then
    for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
        echo "$m"
        MONITOR=$m polybar -l info --reload makc &
    done
else
    polybar --reload makc &
fi
