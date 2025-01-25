#!/bin/bash

# Source monitor configuration if it exists
MONITOR_CONF="$HOME/.config/monitors.conf"
if [ -f "$MONITOR_CONF" ]; then
    source "$MONITOR_CONF"
fi

# Function to count connected displays
count_displays() {
    xrandr --query | grep " connected" | wc -l
}

# Function to update monitor configuration
update_monitor_config() {
    local primary=$1
    local secondary=$2
    mkdir -p "$(dirname "$MONITOR_CONF")"
    echo "# Monitor configuration" > "$MONITOR_CONF"
    echo "PRIMARY_MONITOR=\"$primary\"" >> "$MONITOR_CONF"
    [ -n "$secondary" ] && echo "SECONDARY_MONITOR=\"$secondary\"" >> "$MONITOR_CONF"
}

# Get number of connected displays
DISPLAY_COUNT=$(count_displays)

# Configure displays based on count
if [ "$DISPLAY_COUNT" -gt 1 ]; then
    echo "Detected multiple displays, configuring dual monitor setup..."
    # DUAL MONITOR SETUP
    PRIMARY_MONITOR=${PRIMARY_MONITOR:-"DP-4"}
    SECONDARY_MONITOR=${SECONDARY_MONITOR:-"DP-2"}
    
    xrandr --fb 6720x2160 \
        --output $SECONDARY_MONITOR --mode 1920x1080 --pos 0x0 --rate 144 --scale 1.5x1.5 \
        --output $PRIMARY_MONITOR --mode 3840x2160 --pos 2880x0 --primary --rate 144
    
    # Update monitor configuration
    update_monitor_config "$PRIMARY_MONITOR" "$SECONDARY_MONITOR"
else
    echo "Detected single display, configuring single monitor setup..."
    # SINGLE MONITOR SETUP
    PRIMARY_MONITOR=$(xrandr --query | grep " connected" | cut -d" " -f1)
    xrandr --output $PRIMARY_MONITOR --mode 1920x1080 --pos 0x0 --rate 60 --scale 1x1
    
    # Update monitor configuration with only primary monitor
    update_monitor_config "$PRIMARY_MONITOR"
fi

# Load .Xresources for DPI scaling
xrdb -merge ~/.Xresources

# Export monitor variables for i3
export PRIMARY_MONITOR
export SECONDARY_MONITOR

# Restart i3 to apply changes
i3-msg restart
