#!/bin/bash

# Script to manage named scratchpads in i3
# Usage: scratchpad.sh <name> <command>

NAME="$1"
shift
COMMAND="$@"

# Check if window with this instance already exists
if i3-msg -t get_tree | grep -q "\"instance\":\"scratchpad-$NAME\""; then
    # Window exists, just show it
    i3-msg "[instance=\"scratchpad-$NAME\"] scratchpad show"
else
    # Launch the application
    kitty --class "scratchpad-$NAME" $COMMAND &
fi
