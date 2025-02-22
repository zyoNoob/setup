#!/bin/bash
# set_mouse.sh: Set flat acceleration profile and sensitivity for all pointer devices

for id in $(xinput list --short | grep -i "pointer" | grep -o "id=[0-9]*" | sed "s/id=//"); do
    xinput set-prop "$id" "libinput Accel Profile Enabled" 0 1 0
    xinput set-prop "$id" "libinput Accel Speed" 0.5
done