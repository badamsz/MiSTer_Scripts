#!/bin/bash
TS_DIR="/media/fat/linux/tailscale"
STARTUP="/media/fat/linux/user-startup.sh"
UPDATE_SCRIPT="/media/fat/Scripts/tailscale_update.sh"
START_SCRIPT="/media/fat/Scripts/tailscale_start.sh"

if [ ! -x "$START_SCRIPT" ]; then
    echo "Error: Could not find tailscale_start.sh next to this script ($START_SCRIPT)."
    exit 1
fi

# Install Tailscale first if it isn't present yet
if [ ! -x "$TS_DIR/tailscale" ] || [ ! -x "$TS_DIR/tailscaled" ]; then
    echo "Tailscale binaries not found. Installing now..."
    if [ -x "$UPDATE_SCRIPT" ]; then
        "$UPDATE_SCRIPT"
    else
        echo "Error: Could not find tailscale_update.sh next to this script ($UPDATE_SCRIPT)."
        exit 1
    fi
fi

"$START_SCRIPT" --qr || exit 1

echo "Updating boot configuration..."
if [ -f "$STARTUP" ]; then
    # Clean out any old Tailscale lines (including ones from older versions of these scripts)
    sed -i -e '/# Tailscale Autostart/d' -e '\|'"$TS_DIR"'/|d' -e '\|tailscale_start.sh|d' "$STARTUP"
fi

# Only add a separating blank line if the file doesn't already end with one
if [ -s "$STARTUP" ] && [ -n "$(tail -n 1 "$STARTUP")" ]; then
    echo "" >> "$STARTUP"
fi
echo "# Tailscale Autostart" >> "$STARTUP"
echo "$START_SCRIPT > /dev/null 2>&1 &" >> "$STARTUP"
echo "Added Tailscale to startup process."

echo "Current Tailscale IP:"
"$TS_DIR/tailscale" ip
