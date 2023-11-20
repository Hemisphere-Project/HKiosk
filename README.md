# HKiosk
Chromium web kiosk

Usage:

```
kiosk
    -u, --url <url>        URL to load
    -r, --rotate <deg>     Rotate screen (0, 90, 180, 270)
    -m, --reflect <mode>   Reflect screen (n, x, y, xy)
    -c, --nocursor         Hide cursor
    -d, --devtools         Show devtools
    -h, --help             Show this help
```


Starting script for X / Openbox / Chromium is implemented in the **openbox-chromium** file
which is symlinked to **/etc/xdg/openbox/autostart** at install. 
This is where chromium flags are set too.

### Command line
You can start kiosk via command line, i.e.:  
```kiosk -u https://wikipedia.org ```

### Service
Or you can run Kiosk as a service at boot:
- First edit **kiosk.service** to tweak launch arguments (symlinked to **/etc/systemd/system/kiosk.service** at install)
- Run ```systemctl daemon-reload```
- Enable with ```systemctl enable kiosk```
- Restart

### Using with HPlayer3
Note: HPlayer3 use HKiosk as a player.  
In that case, HPlayer3 does starts HKiosk, so no need to enable the service launcher.  
This allows HPlayer3 to fully control HKiosk start/stop status.
