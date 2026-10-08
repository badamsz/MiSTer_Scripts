#!/bin/bash
TS_DIR="/media/fat/linux/tailscale"
STARTUP="/media/fat/linux/user-startup.sh"

echo "Stopping Tailscale..."
killall tailscaled 2>/dev/null

echo "Removing from boot sequence..."
if [ -f "$STARTUP" ]; then
    # Also removes lines left by older versions of tailscale_enable.sh
    sed -i -e '/# Tailscale Autostart/d' -e '\|'"$TS_DIR"'/|d' -e '\|tailscale_start.sh|d' "$STARTUP"
fi

echo "Tailscale disabled."
