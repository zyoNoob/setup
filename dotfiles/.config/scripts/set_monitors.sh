#!/bin/bash

# Function to count connected displays
count_displays() {
    xrandr --query | grep " connected" | wc -l
}

# Get number of connected displays
DISPLAY_COUNT=$(count_displays)

# Configure displays based on count
if [ "$DISPLAY_COUNT" -gt 1 ]; then
    echo "Detected multiple displays, configuring dual monitor setup..."
    # DUAL MONITOR SETUP
    PRIMARY_MONITOR=${PRIMARY_MONITOR:-"DP-4"}
    SECONDARY_MONITOR=${SECONDARY_MONITOR:-"DP-2"}
    TERTIARY_MONITOR=${TERTIARY_MONITOR:-"HDMI-0"}
    
    xrandr --fb 6720x2160 \
        --output $SECONDARY_MONITOR --mode 1920x1080 --pos 0x270 --rate 144 --scale 1.5x1.5 \
        --output $PRIMARY_MONITOR --mode 3840x2160 --pos 2880x0 --primary --rate 144 \
        --output $TERTIARY_MONITOR --off
else
    echo "Detected single display, configuring single monitor setup..."
    # SINGLE MONITOR SETUP
    PRIMARY_MONITOR=$(xrandr --query | grep " connected" | cut -d" " -f1)
    xrandr --output $PRIMARY_MONITOR --mode 3840x2160 --pos 0x0 --primary --rate 144
fi