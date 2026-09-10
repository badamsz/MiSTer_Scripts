#!/bin/bash
TS_DIR="/media/fat/linux/tailscale"

echo "Checking local Tailscale version..."
if [ -f "$TS_DIR/tailscale" ]; then
    LOCAL_VERSION=$($TS_DIR/tailscale version | head -n1)
    echo "Installed version: $LOCAL_VERSION"
else
    LOCAL_VERSION="none"
    echo "Tailscale is not currently installed."
fi

echo "Checking latest stable release..."

# -k ignores cert errors
# -sL runs silently and follows redirects
# head -n 1 forces ONLY the first match to be kept, avoiding double-matches
# tr forcibly strips any hidden newline or carriage return characters
LATEST_VERSION=$(curl -ksL https://pkgs.tailscale.com/stable/ | grep -o 'tailscale_[0-9]*\.[0-9]*\.[0-9]*_arm\.tgz' | head -n 1 | cut -d'_' -f2 | tr -d '\r\n')

if [ -z "$LATEST_VERSION" ]; then
    echo "Error: Could not determine the latest version from Tailscale servers."
    exit 1
fi

echo "Latest version:    $LATEST_VERSION"

if [ "$LOCAL_VERSION" == "$LATEST_VERSION" ]; then
    echo "Tailscale is already up to date. Exiting."
    exit 0
fi

echo "Update available! Preparing to update..."

WAS_RUNNING=0
if pidof tailscaled > /dev/null; then
    WAS_RUNNING=1
    echo "Tailscale daemon is currently running. Stopping it..."
    killall tailscaled 2>/dev/null
    sleep 2
fi

echo "Downloading Tailscale v$LATEST_VERSION..."
cd /tmp
DOWNLOAD_URL="https://pkgs.tailscale.com/stable/tailscale_${LATEST_VERSION}_arm.tgz"

curl -k -O -L "$DOWNLOAD_URL"

echo "Extracting..."
tar xzf "tailscale_${LATEST_VERSION}_arm.tgz"

echo "Installing binaries..."
mkdir -p $TS_DIR
cp "tailscale_${LATEST_VERSION}_arm/tailscale" $TS_DIR/
cp "tailscale_${LATEST_VERSION}_arm/tailscaled" $TS_DIR/
chmod +x $TS_DIR/tailscale
chmod +x $TS_DIR/tailscaled

echo "Cleaning up temp files..."
rm -rf tailscale_*_arm*

echo "Update complete (v$LATEST_VERSION installed)."

# Restart the daemon if it was running before we started the update
if [ $WAS_RUNNING -eq 1 ]; then
    echo "Restarting Tailscale daemon..."
    
    modprobe tun 2>/dev/null
    if [ -c /dev/net/tun ]; then
        TUN_FLAG=""
    else
        TUN_FLAG="--tun=userspace-networking"
    fi
    
    $TS_DIR/tailscaled $TUN_FLAG --statedir=$TS_DIR/.state/ > /dev/null 2>&1 &
    sleep 2
    
    echo "Reconnecting to the tailnet..."
    $TS_DIR/tailscale up --accept-dns=false > /dev/null 2>&1 &
    
    echo "Tailscale is back online."
    $TS_DIR/tailscale ip
else
    echo "Update finished. Run the Enable script to start Tailscale."
fi
