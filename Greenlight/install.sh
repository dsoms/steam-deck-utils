#!/bin/bash
# ---------------------------------------------------------------------
# Script for installing Greenlight on Steam Deck.
# ---------------------------------------------------------------------

## Variable definitions
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DECK_USER=$(grep "^User=" /etc/sddm.conf.d/steamos.conf | cut -d"=" -f2)
DESKTOP_DIR="/home/${DECK_USER}/Desktop/Greenlight"
GREENLIGHT_REPO="unknownskl/greenlight"
APPIMAGELAUNCHER_DIR="/home/$DECK_USER/.local/lib/appimagelauncher-lite"
APPIMAGES_DIR="/home/$DECK_USER/Applications"

## Functions
function initialize_pacman_keys() {
  if [ ! -e "/etc/pacman.d/gnupg/trustdb.gpg" ]; then
      echo "Initalizing pacman keys"
      pacman-key --init
      pacman-key --populate archlinux
  fi
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

## Create desktop folder
echo "Creating Greenlight desktop folder"

if [ -d "$DESKTOP_DIR" ]; then
  rm -r "$DESKTOP_DIR"
  mkdir -p "$DESKTOP_DIR"

  # Move to the created folder
  cd "$DESKTOP_DIR" || exit
fi

## Disable readonly filesystem
echo -e "\nDisabling readonly filesystem"
sudo steamos-readonly disable

## Install appimagelauncher
echo -e "\nInstalling package AppImageLauncher"

if command -v "$APPIMAGELAUNCHER_DIR/appimagelauncher-lite.AppImage" > /dev/null; then
  echo "AppImageLauncher is already installed on the system."
else
  URL=$(curl --silent "https://api.github.com/repos/TheAssassin/AppImageLauncher/releases/latest" | grep -Po '"browser_download_url": "\K.*x86_64.AppImage(?=")')
  curl -L -o "AppImageLauncher_latest.AppImage" "$URL"
  chmod +x "AppImageLauncher_latest.AppImage"
  ./AppImageLauncher_latest.AppImage install
  rm "AppImageLauncher_latest.AppImage"
fi

## Initialize pacman keys
initialize_pacman_keys

## Install jq
install_packages jq

## Enable readonly filesystem
echo -e "\nRe-enabling readonly filesystem"
sudo steamos-readonly enable

## Remove installed Greenlight
echo -e "\nRemoving installed Greenlight"
"$APPIMAGELAUNCHER_DIR"/appimagelauncher-lite.AppImage cli unintegrate "$APPIMAGES_DIR/Greenlight.AppImage"
if [ -f "$APPIMAGES_DIR/Greenlight.AppImage" ]; then rm "$APPIMAGES_DIR/Greenlight.AppImage"; fi

## Download Greenlight
echo -e "\nDownloading Greenlight"

#Prompt the user for the version tag or latest
echo -e "\nChoose an option:"
echo "1) Download latest release (default)"
echo "2) Download specific version"
read -p "Enter your choice: " CHOICE < /dev/tty

if [ -z "$CHOICE" ] || [ "$CHOICE" == "1" ]; then
    # Get the latest release tag
    TAG=$(curl -sL "https://api.github.com/repos/$GREENLIGHT_REPO/releases/latest" | jq -r '.tag_name')
elif [ "$CHOICE" == "2" ]; then
    # Get the last 5 releases tags
    TAGS=$(curl -sL "https://api.github.com/repos/$GREENLIGHT_REPO/releases?per_page=5" | jq -r '.[].name')

    # Display the tags as a numbered list
    echo -e "\nVersions:"
    i=1
    for t in $TAGS; do
        echo "$i) $t"
        i=$((i+1))
    done

    # Prompt the user to choose a tag
    echo
    read -p "Enter the number of the version to download: " CHOICE < /dev/tty
    while ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt 5 ]; do
        echo "Invalid choice. Please enter a number between 1 and 5"
        read -p "Enter the number of the version to download: " CHOICE < /dev/tty
    done
    TAG=$(echo "$TAGS" | sed -n "${CHOICE}p")
else
    echo "Invalid choice: $CHOICE"
    exit 1
fi

echo -e "Selected version: $TAG\n"

# Get the release ID for the specified tag
RELEASE_ID=$(curl -sL "https://api.github.com/repos/$GREENLIGHT_REPO/releases/tags/$TAG" | jq -r '.id')

# Get the download URL for the release asset
DOWNLOAD_URL=$(curl -sL "https://api.github.com/repos/$GREENLIGHT_REPO/releases/$RELEASE_ID" | jq -r '.assets[] | select(.name | endswith(".AppImage")) | .browser_download_url')

# Download the file
curl -L -o "$APPIMAGES_DIR/Greenlight.AppImage" "$DOWNLOAD_URL"
echo -e "\nGreenlight $TAG installed"

echo -e "\nCreating desktop entry"

LAUNCHER_TEXT="[Desktop Entry]
Name=Update Greenlight
Exec=curl -sSL https://raw.githubusercontent.com/dsoms/steam-deck-utils/main/Greenlight/install.sh | bash -s --
Icon=/usr/share/app-info/icons/archlinux-arch-community/64x64/onionshare_org.onionshare.OnionShare.png
Terminal=true
Type=Application
StartupNotify=false"

echo "$LAUNCHER_TEXT" > "/home/${DECK_USER}/Desktop/Greenlight/Update Greenlight.desktop"

chown "${DECK_USER}" "/home/${DECK_USER}/Desktop/Greenlight/Update Greenlight.desktop"
chmod +x "/home/${DECK_USER}/Desktop/Greenlight/Update Greenlight.desktop"

echo -e "\nDone!"

read -s -n 1 -p "Press any key to continue . . ."

# Remove shell script file
rm "$SCRIPT_DIR/$SCRIPT_NAME"

echo ""
