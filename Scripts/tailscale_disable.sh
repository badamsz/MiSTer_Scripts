#!/bin/bash
TS_DIR="/media/fat/linux/tailscale"
STARTUP="/media/fat/linux/user-startup.sh"

echo "Stopping Tailscale..."
killall tailscaled 2>/dev/null

echo "Removing from boot sequence..."
if [ -f "$STARTUP" ]; then
    sed -i '/# Tailscale Autostart/d' "$STARTUP"
    sed -i '/ln -sf $TS_DIR/tailscale /usr/bin/tailscale/d' "$STARTUP"
    sed -i '/ln -sf $TS_DIR/tailscaled /usr/bin/tailscaled/d' "$STARTUP"
    sed -i '\|'$TS_DIR'/tailscaled|d' "$STARTUP"
    sed -i '\|'$TS_DIR'/tailscale up|d' "$STARTUP"
fi

echo "Tailscale disabled."
