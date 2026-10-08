#!/bin/bash

STARTUP_FILE="/media/fat/linux/user-startup.sh"
HELPER_SCRIPT="/media/fat/Scripts/retrosmb_dns_helper.sh"
CONFIG_FILE="/media/fat/Scripts/retrosmb_dns_helper.ini"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Warning: $CONFIG_FILE not found. The DNS helper will fail at boot until it is created."
    echo "    Copy and modify the example script '_retrosmb_dns_helper.ini' as needed"
fi

# Ensure the linux startup file exists
touch "$STARTUP_FILE"

# Check if the script is already in the startup file (ignoring commented-out lines)
if grep -v '^[[:space:]]*#' "$STARTUP_FILE" | grep -qF "$HELPER_SCRIPT"; then
    echo "DNS helper is already enabled on startup."
else
    # Remove any commented-out copy so we don't leave duplicates behind
    sed -i "\|${HELPER_SCRIPT}|d" "$STARTUP_FILE"

    # Make sure we start on a new line if the file doesn't end with a newline
    if [ -s "$STARTUP_FILE" ] && [ -n "$(tail -c 1 "$STARTUP_FILE")" ]; then
        echo "" >> "$STARTUP_FILE"
    fi

    # Append the script execution, pushed to the background (&) so it doesn't stall boot
    echo "$HELPER_SCRIPT &" >> "$STARTUP_FILE"
    echo "Success: DNS helper enabled on startup."
fi
