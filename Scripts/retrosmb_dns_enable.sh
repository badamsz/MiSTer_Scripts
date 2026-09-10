#!/bin/bash

STARTUP_FILE="/media/fat/linux/user-startup.sh"
HELPER_SCRIPT="/media/fat/Scripts/retrosmb_dns_helper.sh"

# Ensure the linux startup file exists
touch "$STARTUP_FILE"

# Check if the script is already in the startup file
if grep -q "$HELPER_SCRIPT" "$STARTUP_FILE"; then
    echo "DNS helper is already enabled on startup."
else
    # Append the script execution, pushed to the background (&) so it doesn't stall boot
    echo "$HELPER_SCRIPT &" >> "$STARTUP_FILE"
    echo "Success: DNS helper enabled on startup."
fi
