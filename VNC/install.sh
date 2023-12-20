#!/bin/bash
# ---------------------------------------------------------------------
# Script for installing x11vnc on Steam Deck.
#
# This will modify root filesystem so it will probably get
# overwrite on system updates but is totally ok executing
# it several times, so if something stops working just
# launch it again.
#
# If you like seeing the terminal window, change
# "Terminal=false" to "Terminal=true" for the desktop entries below.
#
# Based on:
#
# Àngel "mussol" Bosch (muzzol@gmail.com)
# https://gist.github.com/muzzol/f01fa6a3134d2ec90d3eb3e241bf541b
#
# ZW Cai "x43x61x69"
# https://gist.github.com/x43x61x69/9a5a231a25426e8a2cc0f7c24cfdaed9
#
# ---------------------------------------------------------------------

## Variable definitions
DECK_USER=$(grep "^User=" /etc/sddm.conf.d/steamos.conf | cut -d"=" -f2)
DESKTOP_VNC_DIR="/home/${DECK_USER}/Desktop/VNC"

## Functions
function initialize_pacman_keys() {
    echo -e "\nInitalizing pacman keys\n"
    sudo pacman-key --init
    sudo pacman-key --populate archlinux
    sudo pacman-key --populate holo
}

function is_package_installed() {
    pacman -Qi "$1" >/dev/null 2>&1
}

function install_packages() {
    local packages=("$@") # Get the list of packages as an array
    local missing_packages=() # Initialize an empty array to store missing packages

    # Check each package in the list
    for package in "${packages[@]}"; do
        if ! is_package_installed "$package"; then
            missing_packages+=("$package") # Add missing package to the array
        fi
    done

    # Install missing packages, if any
    if [ -n "$missing_packages" ]; then
        echo "Installing package: ${missing_packages[*]}"
        sudo pacman -Sy --needed --noconfirm "${missing_packages[@]}"
    fi
}

## Disable readonly filesystem
echo -e "\nDisabling readonly filesystem"
sudo steamos-readonly disable

## Initialize pacman keys
initialize_pacman_keys

## Install jq
install_packages x11vnc

## Enable readonly filesystem
echo -e "\nRe-enabling readonly filesystem"
sudo steamos-readonly enable

## Create desktop folder
echo "Creating VNC desktop folder"

if [ -d "$DESKTOP_VNC_DIR" ]; then
  rm -r "$DESKTOP_VNC_DIR"
fi

mkdir -p "$DESKTOP_VNC_DIR"

# Move to the created folder
cd "$DESKTOP_VNC_DIR" || exit

## Create desktop entries
echo -e "\nCreating desktop entries"

LAUNCHER_TEXT="[Desktop Entry]
Name=Start VNC
Exec=x11vnc -noxdamage -usepw -display :0 -no6 -forever -bg
Icon=/usr/share/app-info/icons/archlinux-arch-community/64x64/x11vnc_computer.png
Terminal=false
Type=Application
StartupNotify=false"

echo "$LAUNCHER_TEXT" > "${DESKTOP_VNC_DIR}/Start VNC.desktop"
chown "${DECK_USER}" "${DESKTOP_VNC_DIR}/Start VNC.desktop"
chmod +x "${DESKTOP_VNC_DIR}/Start VNC.desktop"

LAUNCHER_TEXT="[Desktop Entry]
Name=Stop VNC
Exec=killall x11vnc
Icon=/usr/share/app-info/icons/archlinux-arch-community/64x64/x11vnc_computer.png
Terminal=false
Type=Application
StartupNotify=false"

echo "$LAUNCHER_TEXT" > "${DESKTOP_VNC_DIR}/Stop VNC.desktop"
chown "${DECK_USER}" "${DESKTOP_VNC_DIR}/Stop VNC.desktop"
chmod +x "${DESKTOP_VNC_DIR}/Stop VNC.desktop"

LAUNCHER_TEXT="[Desktop Entry]
Name=Set VNC Password
Exec=sudo x11vnc -storepasswd; read -s -n 1 -p 'Press any key to continue . . .'
Icon=/usr/share/app-info/icons/archlinux-arch-community/64x64/x11vnc_computer.png
Terminal=true
Type=Application
StartupNotify=false"

echo "$LAUNCHER_TEXT" > "${DESKTOP_VNC_DIR}/Set VNC Password.desktop"
chown "${DECK_USER}" "${DESKTOP_VNC_DIR}/Set VNC Password.desktop"
chmod +x "${DESKTOP_VNC_DIR}/Set VNC Password.desktop"

LAUNCHER_TEXT="[Desktop Entry]
Name=Reinstall VNC
Exec=curl -sSL https://raw.githubusercontent.com/dsoms/steam-deck-utils/main/VNC/install.sh | bash -s --
Icon=/usr/share/app-info/icons/archlinux-arch-community/64x64/x11vnc_computer.png
Terminal=true
Type=Application
StartupNotify=false"

echo "$LAUNCHER_TEXT" > "${DESKTOP_VNC_DIR}/Reinstall VNC.desktop"
chown "${DECK_USER}" "${DESKTOP_VNC_DIR}/Reinstall VNC.desktop"
chmod +x "${DESKTOP_VNC_DIR}/Reinstall VNC.desktop"

## Create autostart scripts
echo -e "\nCreating autostart scripts"

SCRIPT_TEXT="#!/bin/bash
x11vnc -noxdamage -usepw -display :0 -no6 -forever -bg"

echo "$SCRIPT_TEXT" > "${DESKTOP_VNC_DIR}/vnc_startup.sh"
chown "${DECK_USER}" "${DESKTOP_VNC_DIR}/vnc_startup.sh"
chmod +x "${DESKTOP_VNC_DIR}/vnc_startup.sh"

LAUNCHER_TEXT="[Desktop Entry]
Exec=/home/deck/Desktop/VNC/vnc_startup.sh
Icon=dialog-scripts
Name=vnc_startup.sh
Path=
Type=Application
X-KDE-AutostartScript=true"

echo "$SCRIPT_TEXT" > "/home/${DECK_USER}/.config/autostart/vnc_startup.sh.desktop"
chown "${DECK_USER}" "/home/${DECK_USER}/.config/autostart/vnc_startup.sh.desktop"
chmod +x "/home/${DECK_USER}/.config/autostart/vnc_startup.sh.desktop"

## Check VNC password
if [ ! -f "/home/${DECK_USER}/.vnc/passwd" ]; then
    echo "Creating VNC password"
    sudo -H -u "${DECK_USER}" bash -c "x11vnc -storepasswd"
fi

echo -e "\nDone!"

read -s -n 1 -p "Press any key to continue . . ."

echo ""
