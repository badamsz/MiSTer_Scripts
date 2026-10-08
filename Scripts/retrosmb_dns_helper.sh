#!/bin/bash

# ==========================================
# Configuration Setup & INI Parsing
# ==========================================
CONFIG_FILE="/media/fat/Scripts/retrosmb_dns_helper.ini"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE"
    echo "    Copy and modify the example script '_retrosmb_dns_helper.ini' as needed"
    exit 1
fi

# Lightweight function to parse INI values in BusyBox
# Tolerates spaces around "=", skips comments and keeps any "=" inside the value
get_ini_value() {
    awk -v key="$1" '
        { sub(/\r$/, "") }
        /^[[:space:]]*[#;]/ { next }
        {
            i = index($0, "=")
            if (i == 0) next
            k = substr($0, 1, i - 1)
            v = substr($0, i + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
            if (k == key) { print v; exit }
        }' "$CONFIG_FILE"
}

# Fetch optional file paths from INI
INI_LOG_FILE=$(get_ini_value "log_file")

# Apply defaults if not specified in the INI file
LOG_FILE="${INI_LOG_FILE:-/var/log/retrosmb_dns_helper.log}"

# ==========================================
# Logging Function
# ==========================================
# Function to log to both console and the configured log file
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting retrosmb DNS helper script..."
log "Using Log file: $LOG_FILE"

# ==========================================
# Fetch Remaining Network Configurations
# ==========================================
TARGET_HOST=$(get_ini_value "target_host")
LOCAL_DOMAIN=$(get_ini_value "local_domain")
REMOTE_IP=$(get_ini_value "remote_ip")
NETWORK_TIMEOUT=$(get_ini_value "network_timeout")
CIFS_INI_FILE=$(get_ini_value "cifs_ini_file")
RUN_CIFS_MOUNT=$(get_ini_value "run_cifs_mount")

# Apply default timeout of 60 seconds if not specified in INI
NETWORK_TIMEOUT="${NETWORK_TIMEOUT:-60}"

# Failsafe check for critical variables
if [ -z "$TARGET_HOST" ] || [ -z "$LOCAL_DOMAIN" ] || [ -z "$REMOTE_IP" ]; then
    log "Error: Missing critical configuration values (target_host, local_domain, remote_ip) in $CONFIG_FILE."
    exit 1
fi

# ==========================================
# Network Connectivity Check
# ==========================================
log "Waiting up to $NETWORK_TIMEOUT seconds for network connectivity..."
elapsed=0
network_up=0

while [ $elapsed -lt $NETWORK_TIMEOUT ]; do
    if ip route | grep -q default; then
        network_up=1
        break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

if [ $network_up -eq 0 ]; then
    log "Error: Network connectivity not established within $NETWORK_TIMEOUT seconds. Exiting."
    exit 1
fi

log "Network connected. Proceeding..."

# ==========================================
# DNS Resolution Logic
# ==========================================
log "Checking for local resolution of $LOCAL_DOMAIN..."

LOCAL_IP=$(ping -c 1 -W 2 "$LOCAL_DOMAIN" 2>/dev/null | awk -F'[()]' '/PING/{print $2}')

if [ -n "$LOCAL_IP" ]; then
    SELECTED_IP=$LOCAL_IP
    log "Success: Local IP found -> $SELECTED_IP"
else
    SELECTED_IP=$REMOTE_IP
    log "Failed: Falling back to Remote IP -> $SELECTED_IP"
fi

# ==========================================
# Patch cifs_mount.ini
# ==========================================
if [ -z "$CIFS_INI_FILE" ]; then
    log "No cifs_ini_file configured. Skipping cifs_mount.ini update."
elif [ -w "$CIFS_INI_FILE" ]; then
    log "Patching $CIFS_INI_FILE with resolved IP..."
    # Replace any active SERVER= line; if there isn't one, uncomment only the first #SERVER= line
    HAS_ACTIVE_SERVER=$(grep -c '^SERVER=' "$CIFS_INI_FILE")
    TMP_INI="/tmp/retrosmb_cifs_ini.$$"
    awk -v ip="$SELECTED_IP" -v has_active="$HAS_ACTIVE_SERVER" '
        /^SERVER=/ { print "SERVER=\"" ip "\""; next }
        has_active == 0 && !done && /^#+SERVER=/ { print "SERVER=\"" ip "\""; done = 1; next }
        { print }' "$CIFS_INI_FILE" > "$TMP_INI" && cat "$TMP_INI" > "$CIFS_INI_FILE"
    rm -f "$TMP_INI"

    # Verify the write was successful
    if grep -qxF "SERVER=\"$SELECTED_IP\"" "$CIFS_INI_FILE"; then
        log "Success: Updated SERVER in $CIFS_INI_FILE to $SELECTED_IP"
    else
        log "Error: Failed to verify SERVER update in $CIFS_INI_FILE"
    fi
else
    log "Error: $CIFS_INI_FILE is not writable or does not exist."
fi

# ==========================================
# Update /etc/hosts
# ==========================================
if [ -w "/etc/hosts" ]; then
    # Drop only lines where TARGET_HOST is an exact hostname field (ignoring trailing comments)
    TMP_HOSTS="/tmp/retrosmb_hosts.$$"
    awk -v host="$TARGET_HOST" '
        {
            for (i = 2; i <= NF; i++) {
                if ($i ~ /^#/) break
                if ($i == host) next
            }
            print
        }' /etc/hosts > "$TMP_HOSTS" && cat "$TMP_HOSTS" > /etc/hosts
    rm -f "$TMP_HOSTS"

    echo "$SELECTED_IP $TARGET_HOST" >> /etc/hosts
    if grep -qxF "$SELECTED_IP $TARGET_HOST" /etc/hosts; then
        log "Success: Hosts file verified and updated $TARGET_HOST correctly."
    else
        log "Error: Failed to verify the new $TARGET_HOST entry in /etc/hosts."
    fi
else
    log "Warning: /etc/hosts is not writable. Skipping hosts update."
fi

# ==========================================
# Mount CIFS shares (optional)
# ==========================================
# Running the mount from here guarantees it happens after SERVER has been patched,
# instead of racing cifs_mount.sh's own MOUNT_AT_BOOT entry in user-startup.sh
if [ "$RUN_CIFS_MOUNT" = "true" ]; then
    CIFS_MOUNT_SCRIPT="${CIFS_INI_FILE%.*}.sh"
    if [ -n "$CIFS_INI_FILE" ] && [ -x "$CIFS_MOUNT_SCRIPT" ]; then
        log "Running $CIFS_MOUNT_SCRIPT..."
        if "$CIFS_MOUNT_SCRIPT" >> "$LOG_FILE" 2>&1; then
            log "Success: CIFS shares mounted."
        else
            log "Error: $CIFS_MOUNT_SCRIPT failed. See output above."
        fi
    else
        log "Error: run_cifs_mount is enabled but no executable cifs_mount script was found next to cifs_ini_file."
    fi
fi
