#!/bin/bash
# Starts the Tailscale daemon (if it isn't already running) and connects to the tailnet.
# Used by tailscale_enable.sh, tailscale_update.sh and the boot sequence (user-startup.sh).
# Any arguments are passed through to `tailscale up` (e.g. --qr).
TS_DIR="/media/fat/linux/tailscale"

if [ ! -x "$TS_DIR/tailscale" ] || [ ! -x "$TS_DIR/tailscaled" ]; then
    echo "Error: Tailscale binaries not found at $TS_DIR. Run tailscale_update.sh to install."
    exit 1
fi

mkdir -p "$TS_DIR/.state"
ln -sf "$TS_DIR/tailscale" /usr/bin/tailscale
ln -sf "$TS_DIR/tailscaled" /usr/bin/tailscaled

if pidof tailscaled > /dev/null; then
    echo "Daemon is already running."
else
    # Dynamically check for TUN support
    modprobe tun 2>/dev/null
    if [ -c /dev/net/tun ]; then
        TUN_FLAG=""
        echo "Native TUN support detected. Starting natively..."
    else
        TUN_FLAG="--tun=userspace-networking"
        echo "No TUN support detected. Falling back to userspace mode..."
    fi

    "$TS_DIR/tailscaled" $TUN_FLAG --statedir="$TS_DIR/.state/" > /dev/null 2>&1 &
    sleep 2
fi

echo "Bringing network up..."
"$TS_DIR/tailscale" up --accept-dns=false "$@"
