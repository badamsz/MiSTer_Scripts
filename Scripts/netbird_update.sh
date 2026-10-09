#!/bin/bash
NB_DIR="/media/fat/linux/netbird"
START_SCRIPT="/media/fat/Scripts/netbird_start.sh"

echo "Checking local NetBird version..."
if [ -f "$NB_DIR/netbird" ]; then
    LOCAL_VERSION=$("$NB_DIR/netbird" version | head -n1 | tr -d '\r\n')
    echo "Installed version: $LOCAL_VERSION"
else
    LOCAL_VERSION="none"
    echo "NetBird is not currently installed."
fi

echo "Checking latest stable release..."

# -k ignores cert errors
# -sI fetches headers only; the "latest" release page redirects to .../tag/vX.Y.Z
# tr forcibly strips any hidden newline or carriage return characters
LATEST_VERSION=$(curl -ksI https://github.com/netbirdio/netbird/releases/latest | grep -i '^location:' | grep -o 'tag/v[0-9]*\.[0-9]*\.[0-9]*' | head -n 1 | cut -d'v' -f2 | tr -d '\r\n')

if [ -z "$LATEST_VERSION" ]; then
    echo "Error: Could not determine the latest version from GitHub."
    exit 1
fi

echo "Latest version:    $LATEST_VERSION"

if [ "$LOCAL_VERSION" == "$LATEST_VERSION" ]; then
    echo "NetBird is already up to date. Exiting."
    exit 0
fi

echo "Update available! Preparing to update..."

WAS_RUNNING=0
if pidof netbird > /dev/null; then
    WAS_RUNNING=1
    echo "NetBird daemon is currently running. Stopping it..."
    killall netbird 2>/dev/null
    sleep 2
fi

echo "Downloading NetBird v$LATEST_VERSION..."
cd /tmp
# The armv6 build runs on the MiSTer's ARMv7 CPU
ARCHIVE="netbird_${LATEST_VERSION}_linux_armv6.tar.gz"
DOWNLOAD_URL="https://github.com/netbirdio/netbird/releases/download/v${LATEST_VERSION}/${ARCHIVE}"

if ! curl -k -f -O -L "$DOWNLOAD_URL"; then
    echo "Error: Download failed."
    rm -f "$ARCHIVE"
    exit 1
fi

echo "Extracting..."
mkdir -p netbird_extract
tar xzf "$ARCHIVE" -C netbird_extract netbird

echo "Installing binary..."
mkdir -p "$NB_DIR"
cp netbird_extract/netbird "$NB_DIR/"
chmod +x "$NB_DIR/netbird"

echo "Cleaning up temp files..."
rm -rf netbird_extract "$ARCHIVE"

echo "Update complete (v$LATEST_VERSION installed)."

# Restart the daemon if it was running before we started the update
if [ $WAS_RUNNING -eq 1 ]; then
    echo "Restarting NetBird..."
    if "$START_SCRIPT"; then
        echo "NetBird is back online."
        sleep 1
        "$NB_DIR/netbird" status --ipv4
    fi
else
    echo "Update finished. Run the Enable script to start NetBird."
fi
