#!/bin/bash
NB_DIR="/media/fat/linux/netbird"
STARTUP="/media/fat/linux/user-startup.sh"

echo "Stopping NetBird..."
"$NB_DIR/netbird" down > /dev/null 2>&1
killall netbird 2>/dev/null

echo "Removing from boot sequence..."
if [ -f "$STARTUP" ]; then
    sed -i -e '/# NetBird Autostart/d' -e '\|netbird_start.sh|d' "$STARTUP"
fi

echo "NetBird disabled."
