# MiSTer FPGA Scripts

A collection of utility scripts designed to be executed directly from the [MiSTer FPGA](https://github.com/MiSTer-devel/Main_MiSTer/wiki) On-Screen Display (OSD) using a controller, or via the command line over SSH. 

## Included Scripts

### Tailscale Management (`tailscale_*.sh`)

This suite of scripts allows you to install, update, and manage a [Tailscale](https://tailscale.com/) node directly on your MiSTer, allowing secure remote access to your devices over your Tailnet.

*   `tailscale_update.sh`: Dynamically determines the latest stable ARM release. It checks your local installation and, if a newer version is found, downloads the update and gracefully restarts the daemon without requiring manual intervention.
*   `tailscale_enable.sh`: Initializes and brings up the Tailscale daemon in the background. Enables start on boot. Requires registering on first run.
*   `tailscale_start.sh`: Starts the Tailscale daemon (auto-detecting TUN support) and connects to your Tailnet for the current session only. Used by the other scripts and at boot.
*   `tailscale_disable.sh`: Safely halts the Tailscale daemon and terminates the connection. Disables start on boot.

> **⚠️ Important Note on TUN Support**
> The previous stable MiSTer kernel (`5.15.1-MiSTer`) lacks native TUN routing support, meaning Tailscale will default to operating in user-space mode, which dramatically limits its functionality. However, TUN support is now enabled by default in `6.18.38-MiSTer` and newer so Tailscale works well with full native routing.

* If this is a fresh install of Tailscale, run the `tailscale_enable.sh` script via SSH first so you can easily copy and paste the authentication URL into your browser. It will *also* generate a scannable QR code but that is less reliable.
* If you have multiple MiSTers you plan on using with Tailscale, give it a unique tailscale host name in the [Tailscale Console](https://console.tailscale.com/admin/machines)
* You may also want to consider disabling key expiration for this host in the [Tailscale Console](https://console.tailscale.com/admin/machines)

### NetBird Management (`netbird_*.sh`)

These scripts mirror the Tailscale ones for [NetBird](https://netbird.io/), an open source WireGuard-based alternative that can also be self-hosted.

*   `netbird_update.sh`: Looks up the latest NetBird release on GitHub. It checks your local installation and, if a newer version is found, downloads the `linux_armv6` build (which runs on the MiSTer's ARMv7 CPU) and restarts the daemon if it was running.
*   `netbird_enable.sh`: Installs NetBird if needed, starts the daemon in the background and connects. Enables start on boot. Requires registering on first run.
*   `netbird_start.sh`: Starts the NetBird daemon (auto-detecting TUN support, falling back to userspace netstack mode) and connects to your network for the current session only. Used by the other scripts and at boot.
*   `netbird_disable.sh`: Disconnects and stops the NetBird daemon. Disables start on boot.

NetBird's binaries and state are kept in `/media/fat/linux/netbird/`. NetBird DNS management is turned off (`--disable-dns`) so it doesn't overwrite the MiSTer's `/etc/resolv.conf`.

* **SSO login:** If this is a fresh install, run `netbird_enable.sh` via SSH first. It prints a login URL that you open in your browser to register the MiSTer.
* **Setup key (no SSH needed):** Alternatively, create a setup key in the [NetBird Dashboard](https://app.netbird.io/setup-keys) and save it as the only contents of `/media/fat/linux/netbird/setup_key`. The scripts will use it to register automatically, so `netbird_enable.sh` can be run straight from the OSD.
* **Self-hosted:** Pass your management server when running the enable or start script over SSH, e.g. `netbird_start.sh --management-url https://netbird.example.com`. NetBird remembers it for later boots.
* As with Tailscale, the TUN note above applies: on older kernels without TUN support, NetBird runs in userspace mode with limited functionality.

### RetroSMB (`retrosmb_*.sh`)

These scripts automate and manage the process of configuring CIFS network mounts to prefer local connections over VPN when connecting to a RetroNAS setup. By mapping these remote shares based selectively your MiSTer can seamlessly load games, BIOS files, and save states directly over local *or* remote networks rather than relying entirely on local SD card storage.

*   `retrosmb_dns_helper.sh`: Checks to see if `local_domain` server is resoveable and if not fails to `remote_ip`. Sets a local hosts entry with the resovled address. Optionally can update `cifs_mount.ini` file if defined as the MiSTer `cifs_mount.sh` script doesn't currently support hosts resolution.
*   `retrosmb_dns_enable.sh`: Enables DNS helper start on boot via `user-startup.sh`
*   `retrosmb_dns_disable.sh`: Disables DNS helper start on boot via `user-startup.sh`

Copy or rename the template `_retrosmb_dns_helper.ini` in the `/media/fat/Scripts/` folder and configure as needed.

```ini
[Network]
target_host=retrosmb
local_domain=retronas
remote_ip=100.x.x.x
network_timeout=60
cifs_ini_file=/media/fat/Scripts/cifs_mount.ini
run_cifs_mount=false
```

*   `cifs_ini_file` (optional): The `cifs_mount.ini` whose `SERVER` value is updated with the resolved address.
*   `run_cifs_mount` (optional): Set to `true` to have the helper run `cifs_mount.sh` (found next to `cifs_ini_file`) after patching `SERVER`. This guarantees the shares mount with the updated address. If you use this, set `MOUNT_AT_BOOT="false"` in `cifs_mount.ini` so the shares aren't also mounted separately (and possibly earlier, with the old address).

## Installation & Updates

> You do not need to clone this repository to use these scripts.

You can configure the MiSTer Downloader (used by the Update All script) to automatically fetch and keep these scripts up to date alongside your cores and arcade databases.

#### Drag and Drop Install

The easiest option is to drag and drop a file onto your SD card.

Download [`downloader_badamsz_MiSTer_Scripts.zip`](https://raw.githubusercontent.com/badamsz/MiSTer_Scripts/db/downloader_badamsz_MiSTer_Scripts.zip)

Then you only need to:

1. Extract `downloader_badamsz_MiSTer_Scripts.ini` from the ZIP.
2. Copy it to the **root of the MiSTer SD card**, next to `downloader.ini`.

That's it. 

#### Manual INI editing (for Advanced Users)

If you prefer to do it manually instead, you may add the following lines to the bottom of `downloader.ini`:

```ini
[badamsz/MiSTer_Scripts]
db_url = https://raw.githubusercontent.com/badamsz/MiSTer_Scripts/db/db.json.zip
```

This needs to be done just once. After that, whenever you run *downloader* or *update_all* you will install any updated files.