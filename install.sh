#!/bin/bash

BASEPATH="$(dirname "$(readlink -f "$0")")"
DISTRO=''

echo "$BASEPATH"
cd "$BASEPATH"

## xBIAN (DEBIAN / RASPBIAN / UBUNTU)
if [[ $(command -v apt) ]]; then
    DISTRO='xbian'
    echo "Distribution: $DISTRO"

    apt install xserver-xorg x11-xserver-utils xinit openbox xdotool python3-xdg

    if grep -qw neon /proc/cpuinfo; then
       echo "NEON is supported"
       apt install chromium
    else
       echo "NEON is not supported"
       wget https://archive.raspberrypi.org/debian/pool/main/c/chromium-browser/chromium-codecs-ffmpeg-extra_104.0.5112.105-rpt2_armhf.deb
       wget https://archive.raspberrypi.org/debian/pool/main/c/chromium-browser/chromium-browser_104.0.5112.105-rpt2_armhf.deb
       apt install ./chromium-codecs-ffmpeg-extra_104.0.5112.105-rpt2_armhf.deb
       apt install ./chromium-browser_104.0.5112.105-rpt2_armhf.deb
       ln -s /usr/bin/chromium-browser /usr/bin/chromium
    fi

    # RPi / RP64
    if [[ $(uname -m) = aarch64* || $(uname -m) = armv* ]]; then
        echo "ARM platform"
    fi

## ARCH Linux
elif [[ $(command -v pacman) ]]; then
    DISTRO='arch'
    echo "Distribution: $DISTRO"

    pacman -S xorg-server xorg-apps xorg-xinit openbox --noconfirm --needed
    pacman -S chromium --noconfirm --needed

    # RPi / RP64
    if [[ $(uname -m) = armv* ]]; then
      echo "ARM platform"
    fi

## Plateform not detected ...
else
    echo "Distribution not detected:"
    echo "this script needs APT or PACMAN to run."
    echo ""
    echo "Please install manually."
    exit 1
fi


echo "exec openbox-session" > ~/.xinitrc

rm /etc/xdg/openbox/autostart
ln -sf "$BASEPATH/openbox-chromium" /etc/xdg/openbox/autostart

rm -Rf ~/.config/chromium
mkdir -p /data/var/chromium && ln -sf /data/var/chromium ~/.config/chromium

rm /root/.Xauthority
ln -sf /tmp/.Xauthority /root/.Xauthority

ln -sf "$BASEPATH/kiosk" /usr/local/bin/
ln -sf "$BASEPATH/kiosk.service" /etc/systemd/system/
systemctl daemon-reload

cp "$BASEPATH/kiosk.url" /boot/

FILE=/boot/starter.txt
if test -f "$FILE"; then
echo "## [hkiosk] Chromium kiosk
# kiosk
" >> /boot/starter.txt
fi

echo "Kiosk INSTALLED"
echo
