#!/bin/bash

# Create scripts directory if it doesn't exist
mkdir -p "$HOME/.config/i3/scripts"

# Function to take screenshots
take_screenshot() {
    FILENAME="$HOME/Pictures/$(date +%Y-%m-%d_%H-%M-%S-%3N).png"
    
    case "$1" in
        full)
            maim | tee "$FILENAME" | xclip -selection clipboard -t image/png
            notify-send -a "SS-UTILITY" -i "$FILENAME" "Screenshot" "Full screen captured"
            ;;
        select)
            maim --select | tee "$FILENAME" | xclip -selection clipboard -t image/png
            notify-send -a "SS-UTILITY" -i "$FILENAME" "Screenshot" "Selection captured"
            ;;
        window)
            maim --window "$(xdotool getactivewindow)" | tee "$FILENAME" | xclip -selection clipboard -t image/png
            notify-send -a "SS-UTILITY" -i "$FILENAME" "Screenshot" "Active window captured"
            ;;
        *)
            echo "Unknown screenshot type"
            exit 1
            ;;
    esac
}

# Make sure Pictures directory exists
mkdir -p "$HOME/Pictures"

# Take screenshot based on argument
take_screenshot "$1"
