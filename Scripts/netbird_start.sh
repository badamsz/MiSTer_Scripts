#!/bin/bash
# Starts the NetBird daemon (if it isn't already running) and connects to the network.
# Used by netbird_enable.sh, netbird_update.sh and the boot sequence (user-startup.sh).
# Any arguments are passed through to `netbird up` (e.g. --management-url for self-hosted).
NB_DIR="/media/fat/linux/netbird"
SETUP_KEY_FILE="$NB_DIR/setup_key"

if [ ! -x "$NB_DIR/netbird" ]; then
    echo "Error: NetBird binary not found at $NB_DIR. Run netbird_update.sh to install."
    exit 1
fi

# Keep config/state on the SD card instead of the Linux image
export NB_STATE_DIR="$NB_DIR/.state"
mkdir -p "$NB_STATE_DIR"
ln -sf "$NB_DIR/netbird" /usr/bin/netbird

if pidof netbird > /dev/null; then
    echo "Daemon is already running."
else
    # Dynamically check for TUN support
    modprobe tun 2>/dev/null
    if [ -c /dev/net/tun ]; then
        unset NB_USE_NETSTACK_MODE
        echo "Native TUN support detected. Starting natively..."
    else
        export NB_USE_NETSTACK_MODE=true
        echo "No TUN support detected. Falling back to userspace (netstack) mode..."
    fi

    "$NB_DIR/netbird" service run --log-file console > /dev/null 2>&1 &

    # Wait for the daemon socket to come up
    for i in $(seq 1 10); do
        [ -S /var/run/netbird.sock ] && break
        sleep 1
    done
fi

# Use a setup key for registration if one has been provided, otherwise fall back to SSO login
SETUP_KEY_ARGS=()
if [ -s "$SETUP_KEY_FILE" ]; then
    SETUP_KEY_ARGS=(--setup-key-file "$SETUP_KEY_FILE")
fi

echo "Bringing network up..."
"$NB_DIR/netbird" up --disable-dns --no-browser "${SETUP_KEY_ARGS[@]}" "$@"
