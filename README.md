# MiSTer FPGA Scripts

A collection of utility scripts designed to be executed directly from the [MiSTer FPGA](https://github.com/MiSTer-devel/Main_MiSTer/wiki) On-Screen Display (OSD) using a controller, or via the command line over SSH. 

## Included Scripts

### Tailscale Management (`tailscale_*.sh`)

This suite of scripts allows you to install, update, and manage a [Tailscale](https://tailscale.com/) node directly on your MiSTer, allowing secure remote access to your devices over your Tailnet.

*   `tailscale_update.sh`: Dynamically determines the latest stable ARM release. It checks your local installation and, if a newer version is found, downloads the update and gracefully restarts the daemon without requiring manual intervention.
*   `tailscale_enable.sh`: Initializes and brings up the Tailscale daemon in the background. Enables start on boot. Requires registering on first run.
*   `tailscale_disable.sh`: Safely halts the Tailscale daemon and terminates the connection. Disables start on boot.

> **⚠️ Important Note on TUN Support**
> The previous stable MiSTer kernel (`5.15.1-MiSTer`) lacks native TUN routing support, meaning Tailscale will default to operating in user-space mode, which dramatically limits its functionality. However, TUN support is now enabled by default in `6.18.38-MiSTer` and newer so Tailscale works well with full native routing.

* If this is a fresh install of Tailscale, run the `tailscale_enable.sh` script via SSH first so you can easily copy and paste the authentication URL into your browser. It will *also* generate a scannable QR code but that is less reliable.
* If you have multiple MiSTers you plan on using with Tailscale, give it a unique tailscale host name in the [Tailscale Console](https://console.tailscale.com/admin/machines)
* You may also want to consider disabling key expiration for this host in the [Tailscale Console](https://console.tailscale.com/admin/machines)

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
```

## Installation & Updates

> You do not need to clone this repository to use these scripts.

You can configure the MiSTer Downloader (used by the Update All script) to automatically fetch and keep these scripts up to date alongside your cores and arcade databases.

#### Drag and Drop Install

The easiest option is to drag and drop a file onto their SD card.

Download [`downloader_badamsz_MiSTer_Scripts.zip`](https://raw.githubusercontent.com/badamsz/MiSTer_Scripts/db/downloader_badamsz_MiSTer_Scripts.zip)

Then they only need to:

1. Extract `downloader_jose_game_wallpapers.ini` from the ZIP.
2. Copy it to the **root of the MiSTer SD card**, next to `downloader.ini`.

That's it. 

#### Manual INI editing (for Advanced Users)

If you prefer to do it manually instead, they may add the following lines to the bottom of `downloader.ini`:

```ini
[badamsz/MiSTer_Scripts]
db_url = https://raw.githubusercontent.com/badamsz/MiSTer_Scripts/db/db.json.zip
```

This needs to be done just once. After that, whenever you run *downloader* or *update_all* you will install any updated files.

## Usage

Once the scripts are placed in the /media/fat/Scripts/ directory, they are fully integrated into the MiSTer UI.

1. Open the main MiSTer OSD using your controller, keyboard, or the MiSTer physical button.
2. Scroll down and select Scripts.
3. Select the script you wish to run (e.g., tailscale_update or retrosmb_dns_helper) and press the action button.

An overlay window will appear showing the output of the script as it runs.