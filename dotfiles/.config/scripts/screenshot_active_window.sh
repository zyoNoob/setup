#!/usr/bin/env sh

maim --window "$(xdotool getactivewindow)" | tee "$HOME/Pictures/$(date +%Y-%m-%d_%H-%M-%S).png" | xclip -selection clipboard -t image/png
