#!/bin/bash
NB_DIR="/media/fat/linux/netbird"
STARTUP="/media/fat/linux/user-startup.sh"
UPDATE_SCRIPT="/media/fat/Scripts/netbird_update.sh"
START_SCRIPT="/media/fat/Scripts/netbird_start.sh"

if [ ! -x "$START_SCRIPT" ]; then
    echo "Error: Could not find netbird_start.sh next to this script ($START_SCRIPT)."
    exit 1
fi

# Install NetBird first if it isn't present yet
if [ ! -x "$NB_DIR/netbird" ]; then
    echo "NetBird binary not found. Installing now..."
    if [ -x "$UPDATE_SCRIPT" ]; then
        "$UPDATE_SCRIPT"
    else
        echo "Error: Could not find netbird_update.sh next to this script ($UPDATE_SCRIPT)."
        exit 1
    fi
fi

"$START_SCRIPT" "$@" || exit 1

echo "Updating boot configuration..."
if [ -f "$STARTUP" ]; then
    # Clean out any old NetBird lines
    sed -i -e '/# NetBird Autostart/d' -e '\|netbird_start.sh|d' "$STARTUP"
fi

# Only add a separating blank line if the file doesn't already end with one
if [ -s "$STARTUP" ] && [ -n "$(tail -n 1 "$STARTUP")" ]; then
    echo "" >> "$STARTUP"
fi
echo "# NetBird Autostart" >> "$STARTUP"
echo "$START_SCRIPT > /dev/null 2>&1 &" >> "$STARTUP"
echo "Added NetBird to startup process."

echo "Current NetBird IP:"
"$NB_DIR/netbird" status --ipv4
