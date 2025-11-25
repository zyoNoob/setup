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

    # Determine max refresh rate for PRIMARY_MONITOR at 3840x2160
    echo "Determining max rate for $PRIMARY_MONITOR (3840x2160)..."
    RATE_PRIMARY=$(xrandr --query | grep -A5 "^${PRIMARY_MONITOR} connected" | grep "3840x2160" | head -n1 | awk '{$1=""; print $0}' | tr -d '*+' | xargs -n1 | sort -nr | head -n1)
    # Fallback if rate not found or mode not available for monitor
    RATE_PRIMARY=${RATE_PRIMARY:-60} 
    echo "$PRIMARY_MONITOR (3840x2160) selected rate: $RATE_PRIMARY Hz"

    # Determine max refresh rate for SECONDARY_MONITOR at 1920x1080
    echo "Determining max rate for $SECONDARY_MONITOR (1920x1080)..."
    RATE_SECONDARY=$(xrandr --query | grep -A5 "^${SECONDARY_MONITOR} connected" | grep "1920x1080" | head -n1 | awk '{$1=""; print $0}' | tr -d '*+' | xargs -n1 | sort -nr | head -n1)
    # Fallback if rate not found or mode not available for monitor
    RATE_SECONDARY=${RATE_SECONDARY:-60}
    echo "$SECONDARY_MONITOR (1920x1080) selected rate: $RATE_SECONDARY Hz"
    
    echo "Applying dual monitor settings..."
    xrandr --fb 6720x2160 \
        --output $SECONDARY_MONITOR --mode 1920x1080 --pos 0x270 --rate $RATE_SECONDARY --scale 1.5x1.5 \
        --output $PRIMARY_MONITOR --mode 3840x2160 --pos 2880x0 --primary --rate $RATE_PRIMARY \
        --output $TERTIARY_MONITOR --off
else
    echo "Detected single display, configuring single monitor setup..."
    # SINGLE MONITOR SETUP
    PRIMARY_MONITOR=$(xrandr --query | grep " connected" | head -n1 | cut -d" " -f1)
    
    # Detect the preferred resolution for the monitor (highest available)
    PREFERRED_MODE=$(xrandr --query | grep -A1 "^${PRIMARY_MONITOR} connected" | grep -E "^\s+[0-9]+x[0-9]+" | head -n1 | awk '{print $1}')
    
    # Get the max refresh rate for the preferred mode
    RATE_PRIMARY=$(xrandr --query | grep -A1 "^${PRIMARY_MONITOR} connected" | grep "$PREFERRED_MODE" | head -n1 | awk '{$1=""; print $0}' | tr -d '*+' | xargs -n1 | sort -nr | head -n1)
    RATE_PRIMARY=${RATE_PRIMARY:-60}
    
    echo "$PRIMARY_MONITOR ($PREFERRED_MODE) applying rate: $RATE_PRIMARY Hz"

    echo "Applying single monitor settings..."
    xrandr --output $PRIMARY_MONITOR --mode $PREFERRED_MODE --pos 0x0 --primary --rate $RATE_PRIMARY
fi
