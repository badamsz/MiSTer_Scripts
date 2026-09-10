#!/bin/bash
TS_DIR="/media/fat/linux/tailscale"
STARTUP="/media/fat/linux/user-startup.sh"

mkdir -p $TS_DIR/.state

# Dynamically check for TUN support
modprobe tun 2>/dev/null
if [ -c /dev/net/tun ]; then
    TUN_FLAG=""
    echo "Native TUN support detected. Starting natively..."
else
    TUN_FLAG="--tun=userspace-networking"
    echo "No TUN support detected. Falling back to userspace mode..."
fi

if ! pidof tailscaled > /dev/null; then
    $TS_DIR/tailscaled $TUN_FLAG --statedir=$TS_DIR/.state/ > /dev/null 2>&1 &
    sleep 2
else
    echo "Daemon is already running."
fi

echo "Bringing network up..."
$TS_DIR/tailscale up --qr --accept-dns=false

echo "Updating boot configuration..."
if [ -f "$STARTUP" ]; then
    # Clean out any old Tailscale lines to prevent conflicting flags
    sed -i '/# Tailscale Autostart/d' "$STARTUP"
    sed -i '/ln -sf $TS_DIR/tailscale /usr/bin/tailscale/d' "$STARTUP"
    sed -i '/ln -sf $TS_DIR/tailscaled /usr/bin/tailscaled/d' "$STARTUP"
    sed -i '\|'$TS_DIR'/tailscaled|d' "$STARTUP"
    sed -i '\|'$TS_DIR'/tailscale up|d' "$STARTUP"
fi

echo "" >> "$STARTUP"
echo "# Tailscale Autostart" >> "$STARTUP"
echo "ln -sf $TS_DIR/tailscale /usr/bin/tailscale" >> "$STARTUP"
echo "ln -sf $TS_DIR/tailscaled /usr/bin/tailscaled" >> "$STARTUP"
echo "$TS_DIR/tailscaled $TUN_FLAG --statedir=$TS_DIR/.state/ > /dev/null 2>&1 &" >> "$STARTUP"
echo "$TS_DIR/tailscale up --accept-dns=false > /dev/null 2>&1 &" >> "$STARTUP"
echo "Added detected Tailscale configuration to startup process."

sleep 2
echo "Current Tailscale IP:"
$TS_DIR/tailscale ip
