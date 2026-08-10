#!/bin/bash

# Check if it's running and toggle accordingly
if pgrep -x wlsunset >/dev/null; then
    pkill wlsunset
else
    wlsunset -T 3501 -t 3500 &
fi

# Wait a tiny fraction of a second for the state to change
sleep 0.1

# Send a wake-up signal (we'll use signal number 12) to Waybar to refresh the icon
pkill -RTMIN+12 waybar
