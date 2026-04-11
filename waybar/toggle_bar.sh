#!/bin/bash

# Check if Waybar is currently running with the float config
if pgrep -f "config_float.jsonc" > /dev/null; then
    # It is floating. Kill it and launch pinned.
    killall waybar
    waybar -c ~/.config/waybar/config_pinned.jsonc &
else
    # It is pinned (or not running). Kill it and launch floating.
    killall waybar
    waybar -c ~/.config/waybar/config_float.jsonc &
fi
