#!/bin/bash

# Script to show only generic scratchpad windows (not named ones)
# Generic scratchpads are windows manually moved with mod+Shift+minus

# List of named scratchpad instances and classes to exclude
NAMED_INSTANCES="scratchpad-terminal|scratchpad-music|scratchpad-monitor|scratchpad-files"
NAMED_CLASSES="gnome-calculator|discord|obsidian"

# Get the first generic scratchpad window (not in our named list)
WINDOW_ID=$(i3-msg -t get_tree | jq -r '
  [.. | select(.scratchpad_state? == "fresh" or .scratchpad_state? == "changed") | 
   .. | 
   select(.window?) | 
   select(
     (.window_properties.instance? | test("^('"$NAMED_INSTANCES"')$") | not) and
     (.window_properties.class? | test("^('"$NAMED_CLASSES"')$"; "i") | not)
   ) | 
   .window
  ] | first // empty
')

if [ -n "$WINDOW_ID" ]; then
    i3-msg "[id=$WINDOW_ID] scratchpad show, move position center"
fi
