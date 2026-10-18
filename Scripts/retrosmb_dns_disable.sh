#!/bin/bash

STARTUP_FILE="/media/fat/linux/user-startup.sh"
HELPER_SCRIPT="/media/fat/Scripts/retrosmb_dns_helper.sh"

if [ -f "$STARTUP_FILE" ]; then
    # Safely delete the autostart comment and the line containing the helper script path
    sed -i -e '/# RetroSMB DNS Helper Autostart/d' -e "\|${HELPER_SCRIPT}|d" "$STARTUP_FILE"
    echo "Success: DNS helper disabled on startup."
else
    echo "Startup file not found. Nothing to disable."
fi
