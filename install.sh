#!/bin/bash
#
# HKiosk installer.
# Supports Raspberry Pi (ARM) and x86 (e.g. Intel N150) bootstrapped with
# Pi-tools. Run as root:  sudo ./install.sh
#

BASEPATH="$(dirname "$(readlink -f "$0")")"
cd "$BASEPATH"
echo "$BASEPATH"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: must run as root (use sudo)."
    exit 1
fi

# ── Platform / boot partition ──
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|i686|i386) PLATFORM="x86" ;;
    aarch64|arm*)     PLATFORM="arm" ;;
    *)                PLATFORM="other" ;;
esac
echo "Architecture: $ARCH ($PLATFORM)"

# Pi OS (bookworm+) and Pi-tools 2026 mount the FAT boot config at
# /boot/firmware; classic layouts and x86 use /boot.
if [ -d /boot/firmware ]; then BOOT=/boot/firmware; else BOOT=/boot; fi
echo "Boot partition: $BOOT"


# ── Install Google Chrome (real .deb) on x86 ──
# On Ubuntu `apt install chromium` only provides a snap, whose confinement
# breaks --user-data-dir and the kiosk profile. Google Chrome ships a proper
# .deb and is the same Chromium engine.
install_google_chrome() {
    if command -v google-chrome-stable >/dev/null 2>&1 || command -v google-chrome >/dev/null 2>&1; then
        echo "Google Chrome already installed."
        return 0
    fi
    echo "Installing Google Chrome (.deb) ..."
    install -d -m 0755 /etc/apt/keyrings
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
        | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
        > /etc/apt/sources.list.d/google-chrome.list
    apt update
    apt install -y google-chrome-stable
}


## xBIAN (DEBIAN / RASPBIAN / UBUNTU)
if [[ $(command -v apt) ]]; then
    DISTRO='xbian'
    echo "Distribution: $DISTRO"

    apt update
    apt install -y xserver-xorg xinit x11-xserver-utils openbox xdotool python3-xdg unclutter ca-certificates curl wget gnupg

    if [ "$PLATFORM" = "arm" ]; then
        # ── Raspberry Pi: chromium ships as a real .deb ──
        if grep -qw neon /proc/cpuinfo; then
            echo "NEON is supported"
            apt install -y chromium || apt install -y chromium-browser
        else
            echo "NEON is not supported — installing pinned armhf build"
            wget -q https://archive.raspberrypi.org/debian/pool/main/c/chromium-browser/chromium-codecs-ffmpeg-extra_104.0.5112.105-rpt2_armhf.deb
            wget -q https://archive.raspberrypi.org/debian/pool/main/c/chromium-browser/chromium-browser_104.0.5112.105-rpt2_armhf.deb
            apt install -y ./chromium-codecs-ffmpeg-extra_104.0.5112.105-rpt2_armhf.deb
            apt install -y ./chromium-browser_104.0.5112.105-rpt2_armhf.deb
            ln -sf /usr/bin/chromium-browser /usr/bin/chromium
        fi
    else
        # ── x86 (Intel N150 etc.): Google Chrome + Intel VAAPI drivers ──
        install_google_chrome
        echo "Installing Intel VAAPI video drivers ..."
        apt install -y intel-media-va-driver va-driver-all vainfo mesa-va-drivers || \
            echo "WARN: VAAPI drivers not fully installed — video may fall back to software."
    fi

## ARCH Linux
elif [[ $(command -v pacman) ]]; then
    DISTRO='arch'
    echo "Distribution: $DISTRO"

    pacman -S xorg-server xorg-apps xorg-xinit openbox xdotool unclutter --noconfirm --needed
    pacman -S chromium --noconfirm --needed

## Plateform not detected ...
else
    echo "Distribution not detected:"
    echo "this script needs APT or PACMAN to run."
    echo ""
    echo "Please install manually."
    exit 1
fi


# ── Allow X to start from the service (no console / non-login) ──
# Debian/Ubuntu default `allowed_users=console` blocks startx from systemd.
if [ -f /etc/X11/Xwrapper.config ]; then
    sed -i 's/^allowed_users=.*/allowed_users=anybody/' /etc/X11/Xwrapper.config
    if grep -q '^needs_root_rights=' /etc/X11/Xwrapper.config; then
        sed -i 's/^needs_root_rights=.*/needs_root_rights=yes/' /etc/X11/Xwrapper.config
    else
        echo 'needs_root_rights=yes' >> /etc/X11/Xwrapper.config
    fi
else
    printf 'allowed_users=anybody\nneeds_root_rights=yes\n' > /etc/X11/Xwrapper.config
fi


# ── X / Openbox session ──
echo "exec openbox-session" > /root/.xinitrc
mkdir -p /etc/xdg/openbox
chmod +x "$BASEPATH/openbox-chromium"
ln -sf "$BASEPATH/openbox-chromium" /etc/xdg/openbox/autostart

# Chromium profile / cache dir (persistent on /data when present)
if [ -d /data ]; then
    mkdir -p /data/var/chromium
fi

# X authority cookie lives in /tmp
rm -f /root/.Xauthority
ln -sf /tmp/.Xauthority /root/.Xauthority


# ── Install launcher + service ──
chmod +x "$BASEPATH/kiosk"
ln -sf "$BASEPATH/kiosk" /usr/local/bin/
ln -sf "$BASEPATH/kiosk.service" /etc/systemd/system/
systemctl daemon-reload

# Default config on the boot partition (don't clobber an existing one)
[ -f "$BOOT/kiosk.url" ] || cp "$BASEPATH/kiosk.url" "$BOOT/"

# Register (disabled) in Pi-tools starter.txt if present
if [ -f "$BOOT/starter.txt" ] && ! grep -q '^#\?[[:space:]]*kiosk[[:space:]]*$' "$BOOT/starter.txt"; then
    printf '\n## [hkiosk] Chromium kiosk\n# kiosk\n' >> "$BOOT/starter.txt"
fi

echo
echo "Kiosk INSTALLED"
echo "  - Edit $BOOT/kiosk.url to set the URL and options"
echo "  - Run on demand:   kiosk -u https://example.org"
echo "  - Enable at boot:  systemctl enable --now kiosk"
echo
