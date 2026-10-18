#!/bin/bash
# Enables the retrosmb DNS helper on boot. If retrosmb_dns_helper.ini doesn't exist yet
# (or still has the placeholder remote_ip), it is created from _retrosmb_dns_helper.ini
# after asking for target_host and remote_ip. The prompts use dialog menus so they can
# be driven with a controller from the OSD (D-pad to move, A/Enter to select, B/Esc to go back).

STARTUP_FILE="/media/fat/linux/user-startup.sh"
HELPER_SCRIPT="/media/fat/Scripts/retrosmb_dns_helper.sh"
CONFIG_FILE="/media/fat/Scripts/retrosmb_dns_helper.ini"
TEMPLATE_FILE="/media/fat/Scripts/_retrosmb_dns_helper.ini"
TS_BIN="/media/fat/linux/tailscale/tailscale"
NB_BIN="/media/fat/linux/netbird/netbird"
DEFAULT_TARGET_HOST="retrosmb"

TITLE="RetroSMB DNS Helper Setup"
DIALOG_OUT="/tmp/retrosmb_dialog.$$"
trap 'rm -f "$DIALOG_OUT" "$CONFIG_FILE.tmp.$$"' EXIT

if command -v dialog > /dev/null 2>&1; then
    HAS_DIALOG=1
else
    HAS_DIALOG=0
fi

# ==========================================
# INI Helpers
# ==========================================
# Same parsing rules as retrosmb_dns_helper.sh
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
        }' "$2"
}

is_valid_ip() {
    local IFS=.
    local -a octets
    read -r -a octets <<< "$1"
    [[ "$1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || return 1
    for o in "${octets[@]}"; do
        [ "$((10#$o))" -le 255 ] || return 1
    done
}

is_valid_hostname() {
    [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]
}

# Writes the INI from the template (or built-in defaults), setting target_host and remote_ip
write_config() {
    local target_host="$1" remote_ip="$2" src="$TEMPLATE_FILE"
    local tmp="$CONFIG_FILE.tmp.$$"

    if [ ! -f "$src" ]; then
        src=/dev/null
    fi

    awk -v th="$target_host" -v ip="$remote_ip" '
        BEGIN { have_section = 0 }
        { sub(/\r$/, "") }
        /^[[:space:]]*\[/ { have_section = 1 }
        /^[[:space:]]*target_host[[:space:]]*=/ { print "target_host=" th; set_th = 1; next }
        /^[[:space:]]*remote_ip[[:space:]]*=/   { print "remote_ip=" ip;   set_ip = 1; next }
        { print }
        END {
            if (!have_section) {
                print "[Network]"
                print "local_domain=retronas"
                print "network_timeout=60"
                print "cifs_ini_file=/media/fat/Scripts/cifs_mount.ini"
                print "run_cifs_mount=false"
            }
            if (!set_th) print "target_host=" th
            if (!set_ip) print "remote_ip=" ip
        }' "$src" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
}

# ==========================================
# UI Helpers (dialog, with plain-text fallback for SSH sessions without it)
# ==========================================
# Runs dialog, storing the selection in $REPLY. Returns non-zero on cancel/back.
run_dialog() {
    dialog --backtitle "$TITLE" "$@" 2> "$DIALOG_OUT"
    local rc=$?
    REPLY=$(cat "$DIALOG_OUT")
    return $rc
}

msg() {
    if [ "$HAS_DIALOG" -eq 1 ]; then
        dialog --backtitle "$TITLE" --msgbox "$1" 10 60
    else
        echo -e "$1"
    fi
}

# Controller-friendly text entry: pick one character at a time from a menu.
# $1 = prompt, $2 = allowed characters, $3 = initial value. Result in $REPLY.
keypad_entry() {
    local prompt="$1" chars="$2" value="$3" last="DONE"
    local -a items
    local i c

    while true; do
        items=(DONE "Done - use this value" DEL "<- Delete last character")
        for ((i = 0; i < ${#chars}; i++)); do
            c="${chars:i:1}"
            items+=("$c" "Add '$c'")
        done

        run_dialog --default-item "$last" --menu \
            "$prompt\n\nCurrent value: ${value:-<empty>}" 22 60 13 "${items[@]}" || return 1

        last="$REPLY"
        case "$REPLY" in
            DONE) REPLY="$value"; return 0 ;;
            DEL)  value="${value%?}" ;;
            *)    value="$value$REPLY" ;;
        esac
    done
}

# Plain keyboard entry. $1 = prompt, $2 = initial value. Result in $REPLY.
keyboard_entry() {
    if [ "$HAS_DIALOG" -eq 1 ]; then
        run_dialog --inputbox "$1" 10 60 "$2"
    else
        read -r -p "$1 [$2]: " REPLY
        REPLY="${REPLY:-$2}"
    fi
}

# ==========================================
# VPN Peer Discovery
# ==========================================
# Each prints "IP NAME STATUS" lines

list_tailscale_peers() {
    local bin="$TS_BIN"
    [ -x "$bin" ] || bin=$(command -v tailscale) || return 1
    # Skip health warnings (#) and the first entry, which is this MiSTer
    "$bin" status 2> /dev/null | awk '
        /^#/ || NF < 2 { next }
        !seen_self++ { next }
        $1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {
            status = $5
            for (i = 6; i <= NF; i++) status = status " " $i
            sub(/;.*/, "", status)
            if (status == "" || status == "-") status = "online"
            print $1, $2, status
        }'
}

list_netbird_peers() {
    local bin="$NB_BIN"
    [ -x "$bin" ] || bin=$(command -v netbird) || return 1
    # Peers are listed as " name:" headers followed by indented detail lines
    "$bin" status -d 2> /dev/null | awk '
        /^Peers detail:/ { in_peers = 1; next }
        /^[^ ]/ { in_peers = 0 }
        !in_peers { next }
        /^ [^ ].*:$/ { name = $1; sub(/:$/, "", name); ip = ""; next }
        /^  NetBird IP:/ { ip = $3; sub(/\/.*/, "", ip); next }
        /^  Status:/ && name != "" && ip != "" { print ip, name, $2; name = "" }'
}

# Shows a picker for the given VPN. $1 = tailscale|netbird. Selected IP in $REPLY.
pick_vpn_peer() {
    local vpn="$1" label peers
    local -a items
    if [ "$vpn" = "tailscale" ]; then
        label="Tailscale"
        peers=$(list_tailscale_peers)
    else
        label="NetBird"
        peers=$(list_netbird_peers)
    fi

    if [ -z "$peers" ]; then
        msg "No $label peers found.\n\nMake sure $label is running and connected (run ${vpn}_enable.sh), then try again."
        return 1
    fi

    while read -r ip name status; do
        items+=("$ip" "$name [$status]")
    done <<< "$peers"

    run_dialog --menu "Select the $label host running RetroNAS:" 20 70 12 "${items[@]}"
}

# ==========================================
# Setup Prompts
# ==========================================
prompt_target_host() {
    local value="$DEFAULT_TARGET_HOST"
    while true; do
        run_dialog --default-item DEFAULT --menu \
            "Hostname the MiSTer will use for your RetroNAS share (target_host).\n\nThis is written to /etc/hosts, so use the same name as SERVER in cifs_mount.ini." \
            16 70 4 \
            DEFAULT "Use \"$DEFAULT_TARGET_HOST\" (recommended)" \
            KEYPAD  "Enter with controller (on-screen keypad)" \
            KEYBOARD "Type with keyboard" || return 1

        case "$REPLY" in
            DEFAULT)  REPLY="$DEFAULT_TARGET_HOST" ;;
            KEYPAD)   keypad_entry "Enter target_host" "abcdefghijklmnopqrstuvwxyz0123456789-." "$value" || continue ;;
            KEYBOARD) keyboard_entry "Enter target_host:" "$value" || continue ;;
        esac

        if is_valid_hostname "$REPLY"; then
            return 0
        fi
        msg "\"$REPLY\" is not a valid hostname.\n\nUse letters, numbers, '-' and '.' only."
    done
}

prompt_remote_ip() {
    local value=""
    local -a items
    while true; do
        items=()
        if [ -x "$TS_BIN" ] || command -v tailscale > /dev/null 2>&1; then
            items+=(TAILSCALE "Pick a host from Tailscale")
        fi
        if [ -x "$NB_BIN" ] || command -v netbird > /dev/null 2>&1; then
            items+=(NETBIRD "Pick a host from NetBird")
        fi
        items+=(KEYPAD "Enter with controller (on-screen keypad)" KEYBOARD "Type with keyboard")

        run_dialog --menu \
            "Remote IP of your RetroNAS (remote_ip).\n\nUsed when the local domain can't be resolved, e.g. your Tailscale or NetBird address." \
            16 70 4 "${items[@]}" || return 1

        case "$REPLY" in
            TAILSCALE) pick_vpn_peer tailscale || continue ;;
            NETBIRD)   pick_vpn_peer netbird || continue ;;
            KEYPAD)    keypad_entry "Enter remote_ip" "0123456789." "$value" || continue ;;
            KEYBOARD)  keyboard_entry "Enter remote_ip:" "$value" || continue ;;
        esac

        value="$REPLY"
        if is_valid_ip "$REPLY"; then
            return 0
        fi
        msg "\"$REPLY\" is not a valid IPv4 address (e.g. 100.64.0.10)."
    done
}

# Plain-text setup for terminals without dialog (e.g. a minimal SSH session)
prompt_plain() {
    local peers
    peers=$( { list_tailscale_peers; list_netbird_peers; } 2> /dev/null)

    while true; do
        keyboard_entry "Enter target_host" "$DEFAULT_TARGET_HOST"
        is_valid_hostname "$REPLY" && break
        echo "Invalid hostname. Use letters, numbers, '-' and '.' only."
    done
    TARGET_HOST="$REPLY"

    if [ -n "$peers" ]; then
        echo "Available VPN hosts:"
        echo "$peers" | awk '{ printf "  %s  %s [%s]\n", $1, $2, $3 }'
    fi
    while true; do
        keyboard_entry "Enter remote_ip" ""
        is_valid_ip "$REPLY" && break
        echo "Invalid IPv4 address."
    done
    REMOTE_IP="$REPLY"
}

run_setup() {
    if [ "$HAS_DIALOG" -eq 1 ]; then
        prompt_target_host || return 1
        TARGET_HOST="$REPLY"
        prompt_remote_ip || return 1
        REMOTE_IP="$REPLY"

        run_dialog --yesno \
            "Save these settings to\n$CONFIG_FILE?\n\ntarget_host=$TARGET_HOST\nremote_ip=$REMOTE_IP" \
            12 60 || return 1
        clear
    else
        prompt_plain
    fi

    write_config "$TARGET_HOST" "$REMOTE_IP" || return 1
    echo "Created $CONFIG_FILE (target_host=$TARGET_HOST, remote_ip=$REMOTE_IP)."
}

# ==========================================
# Configuration Check
# ==========================================
NEEDS_SETUP=0
if [ ! -f "$CONFIG_FILE" ]; then
    NEEDS_SETUP=1
elif ! is_valid_ip "$(get_ini_value remote_ip "$CONFIG_FILE")" \
    || ! is_valid_hostname "$(get_ini_value target_host "$CONFIG_FILE")"; then
    if [ "$HAS_DIALOG" -eq 1 ]; then
        run_dialog --yesno \
            "$CONFIG_FILE has a missing or invalid target_host/remote_ip.\n\nSet them up now?" 10 60 \
            && NEEDS_SETUP=1
        clear
    else
        echo "Warning: $CONFIG_FILE has a missing or invalid target_host/remote_ip."
        read -r -p "Set them up now? [Y/n]: " ans
        case "$ans" in [Nn]*) ;; *) NEEDS_SETUP=1 ;; esac
    fi
fi

if [ "$NEEDS_SETUP" -eq 1 ]; then
    if ! run_setup; then
        clear
        echo "Setup cancelled. DNS helper was not enabled."
        exit 1
    fi
fi

# ==========================================
# Enable on Boot
# ==========================================
echo "Updating boot configuration..."
if [ -f "$STARTUP_FILE" ]; then
    # Clean out any old DNS helper lines (including commented-out copies)
    sed -i -e '/# RetroSMB DNS Helper Autostart/d' -e "\|${HELPER_SCRIPT}|d" "$STARTUP_FILE"
fi

# Only add a separating blank line if the file doesn't already end with one
if [ -s "$STARTUP_FILE" ] && [ -n "$(tail -n 1 "$STARTUP_FILE")" ]; then
    echo "" >> "$STARTUP_FILE"
fi
echo "# RetroSMB DNS Helper Autostart" >> "$STARTUP_FILE"
# Pushed to the background (&) so it doesn't stall boot
echo "$HELPER_SCRIPT &" >> "$STARTUP_FILE"
echo "Success: DNS helper enabled on startup."
