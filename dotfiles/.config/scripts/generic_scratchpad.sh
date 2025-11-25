#!/bin/bash

# Script to show only generic scratchpad windows (not named ones)
# Generic scratchpads are windows manually moved with mod+Shift+minus

# List of named scratchpad instances and classes to exclude
NAMED_INSTANCES="scratchpad-terminal|scratchpad-music|scratchpad-monitor|scratchpad-files"
NAMED_CLASSES="gnome-calculator|discord|obsidian"

# Get all scratchpad windows
SCRATCHPAD_WINDOWS=$(i3-msg -t get_tree | jq -r '
  .. | 
  select(.type? == "con" and .name? != null) | 
  select(.floating? == "user_on" or .floating? == "auto_on") |
  select(any(.nodes[]?; .scratchpad_state? == "fresh" or .scratchpad_state? == "changed") or .scratchpad_state? == "fresh" or .scratchpad_state? == "changed") |
  select(
    (.window_properties.instance? | test("^('"$NAMED_INSTANCES"')$") | not) and
    (.window_properties.class? | test("^('"$NAMED_CLASSES"')$"; "i") | not)
  ) |
  .id
' | head -1)

if [ -n "$SCRATCHPAD_WINDOWS" ]; then
    i3-msg "[con_id=$SCRATCHPAD_WINDOWS] scratchpad show, move position center"
else
    # If no generic scratchpad found, just call the normal scratchpad show
    # This will work if windows are in scratchpad but jq query didn't catch them
    i3-msg "scratchpad show"
fi
