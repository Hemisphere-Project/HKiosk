# HKiosk

Chromium / Chrome web kiosk for **Raspberry Pi** and **x86** machines
(e.g. Intel **N150**), bootstrapped with
[Pi-tools](https://github.com/Hemisphere-Project/Pi-tools).

It boots straight into X / Openbox and a single full-screen browser window,
with hardware video acceleration, screen rotation, and automatic recovery when
the target URL is offline.

## Install

```
git clone https://github.com/Hemisphere-Project/HKiosk.git
cd HKiosk
sudo ./install.sh
```

The installer detects the platform and does the right thing:

| | Raspberry Pi (ARM) | x86 / N150 (Ubuntu/Debian) |
|---|---|---|
| Browser | `chromium` (`.deb`) | **Google Chrome** (`.deb`) — Ubuntu's `chromium` is a snap whose confinement breaks kiosk mode, so Chrome is installed from Google's apt repo |
| Video decode | V4L2 | **Intel VAAPI** (`intel-media-va-driver`) |
| Boot config dir | `/boot/firmware` | `/boot` |

It also:
- installs X / Openbox and links `openbox-chromium` to `/etc/xdg/openbox/autostart`,
- sets `allowed_users=anybody` in `/etc/X11/Xwrapper.config` so X can start from the service,
- links the `kiosk` launcher to `/usr/local/bin` and `kiosk.service` to systemd,
- drops a default `kiosk.url` on the boot partition.

> If installed alongside **Pi-tools 2026**, HKiosk also ships a `module.ini`, so
> it can be picked up by the Pi-tools installer and registered (disabled) in
> `starter.txt`.

## Usage

```
kiosk
    -u, --url <url>          URL to load
    -r, --rotate <deg>       Rotate screen (0, 90, 180, 270)
    -m, --reflect <mode>     Reflect screen (n, x, y, xy)
    -s, --resolution <WxH>   Force resolution (e.g. 1920x1080), default auto
    -c, --nocursor           Hide cursor
    -d, --devtools           Show devtools (windowed)
    -e, --extra <args>       Extra chromium flags
    -h, --help               Show this help
```

The X / Openbox / browser startup lives in **openbox-chromium**, symlinked to
**/etc/xdg/openbox/autostart** at install. Browser flags are set there.
The browser binary is auto-detected (Chromium on Pi, Google Chrome on x86);
override with `KIOSK_BROWSER=/path/to/browser` if needed.

### Command line

```
kiosk -u https://wikipedia.org
```

### Service (start at boot)

1. Edit **`<boot>/kiosk.url`** to set the URL and options
   (`/boot/firmware/kiosk.url` on Pi, `/boot/kiosk.url` on x86).
2. Enable and start:
   ```
   systemctl enable --now kiosk
   ```

`kiosk.service` reads its arguments from `kiosk.url`, syncs the clock
(best-effort), and restarts automatically. The `<mac>` token in `kiosk.url`
is replaced with the device's Pi-tools drive id (`/data/var/drive-id`).

> Serving a **local** page with no internet? Comment out the
> `After=/Requires=network-online.target` lines in `kiosk.service` for a faster,
> offline-capable boot, then `systemctl daemon-reload`.

## Performance notes

- A **persistent profile/cache** is kept on `/data/var/chromium` (or `/tmp` when
  there is no data partition), so a heavy web app reloads warm after a reboot.
- Resolution defaults to the panel's **native mode** (`xrandr --auto`) instead of
  forcing 1080p — pass `--resolution` only when you need to override it.
- GPU rasterization, zero-copy and hardware video decode are enabled per platform
  (Intel VAAPI on x86, V4L2 on Pi). Check decode with `vainfo` on x86.

## Files

| File | Purpose |
|---|---|
| `install.sh` | Platform-aware installer |
| `kiosk` | Launcher — starts X via `startx` with the chosen options |
| `openbox-chromium` | Openbox autostart — configures display, launches the browser |
| `kiosk.service` | systemd unit to run the kiosk at boot |
| `kiosk.url` | Launch arguments (copied to the boot partition) |
| `loader.html` | Waits for the target URL to come online, then redirects |
| `module.ini` | Pi-tools 2026 module manifest |
