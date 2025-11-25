#!/bin/bash

# Script to manage named scratchpads in i3
# Usage: scratchpad.sh <name> <command> [--gui]

NAME="$1"
shift

# Check if this is a GUI app (not terminal-based)
if [ "$1" = "--gui" ]; then
    GUI_MODE=true
    shift
else
    GUI_MODE=false
fi

COMMAND="$@"

# For GUI apps, check by class name; for terminal apps, check by instance
if [ "$GUI_MODE" = true ]; then
    SELECTOR="class"
    WINDOW_NAME="$NAME"
else
    SELECTOR="instance"
    WINDOW_NAME="scratchpad-$NAME"
fi

# Check if window with this instance/class already exists
if i3-msg -t get_tree | grep -q "\"$SELECTOR\":\"$WINDOW_NAME\""; then
    # Window exists, show it and move to focused output's center
    i3-msg "[$SELECTOR=\"$WINDOW_NAME\"] scratchpad show, move position center"
else
    # Launch the application
    if [ "$GUI_MODE" = true ]; then
        $COMMAND &
    else
        kitty --class "scratchpad-$NAME" $COMMAND &
    fi
fi
