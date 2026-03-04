#!/usr/bin/env sh

# Get active monitors from xrandr (compatible with both bash/zsh)
monitors=($(xrandr --listactivemonitors | awk '/^ [0-9]+:/ { sub(/^[+*]*/, "", $NF); print $NF }'))

# Handle shell-specific array indexing without changing shell options
if [ -n "$ZSH_VERSION" ]; then
    primary_index=1  # Zsh uses 1-based indexing
    secondary_index=2
else
    primary_index=0  # Bash uses 0-based indexing
    secondary_index=1
fi

# Export primary monitor (first in list)
export PRIMARY_MONITOR="${monitors[$primary_index]}"

# Export secondary monitors if present
if [ ${#monitors[@]} -gt $primary_index ]; then
    export SECONDARY_MONITOR="${monitors[$secondary_index]}"
fi

# For systems with multiple secondary monitors:
# for i in $(seq $secondary_index $((${#monitors[@]} - 1))); do
#     export "SECONDARY_MONITOR_$((i - primary_index))"="${monitors[$i]}"
# done