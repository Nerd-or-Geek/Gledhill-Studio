#!/bin/bash

set -euo pipefail

APP_NAME="Gledhill Metadata"
APP_ID="gledhill_metadata"
ARCH="$(uname -m)"
ARCH_ALT="$ARCH"
if [[ "$ARCH" == "amd64" ]]; then
	ARCH_ALT="x86_64"
fi
DOWNLOAD_BASE="${DOWNLOAD_BASE:-https://nerd-or-geek.github.io/Gledhill-Metadata/downloads}"
RAW_BASE="${RAW_BASE:-https://raw.githubusercontent.com/Nerd-or-Geek/Gledhill-Metadata/main}"

INSTALL_DIR="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons"
DESKTOP_DIR="$HOME/.local/share/applications"
APPIMAGE_DEST="$INSTALL_DIR/${APP_ID}.AppImage"
ICON_DEST="$ICON_DIR/${APP_ID}.png"
DESKTOP_FILE="$DESKTOP_DIR/${APP_ID}.desktop"

download_file() {
	local url="$1"
	local dest="$2"

	if command -v curl >/dev/null 2>&1; then
		curl -fsSL "$url" -o "$dest"
		return
	fi

	if command -v wget >/dev/null 2>&1; then
		wget -qO "$dest" "$url"
		return
	fi

	echo "Error: curl or wget is required to download files." >&2
	exit 1
}

echo "Installing $APP_NAME..."

mkdir -p "$INSTALL_DIR"
mkdir -p "$ICON_DIR"
mkdir -p "$DESKTOP_DIR"

TMP_APPIMAGE="$(mktemp)"
trap 'rm -f "$TMP_APPIMAGE"' EXIT

echo "Downloading AppImage..."
APPIMAGE_URLS=(
	"$DOWNLOAD_BASE/Gledhill_Metadata-${ARCH}.AppImage"
	"$DOWNLOAD_BASE/Gledhill_Metadata-${ARCH_ALT}.AppImage"
	"$DOWNLOAD_BASE/${APP_ID}-${ARCH}.AppImage"
	"$DOWNLOAD_BASE/${APP_ID}-${ARCH_ALT}.AppImage"
	"$DOWNLOAD_BASE/Gledhill-Metadata-${ARCH}.AppImage"
	"$DOWNLOAD_BASE/Gledhill-Metadata-${ARCH_ALT}.AppImage"
)

DOWNLOAD_OK="false"
for url in "${APPIMAGE_URLS[@]}"; do
	if download_file "$url" "$TMP_APPIMAGE"; then
		DOWNLOAD_OK="true"
		break
	fi
done

if [[ "$DOWNLOAD_OK" != "true" ]]; then
	echo "Error: Could not download an AppImage for architecture '${ARCH}'." >&2
	echo "Tried URLs:" >&2
	printf '  - %s\n' "${APPIMAGE_URLS[@]}" >&2
	exit 1
fi

install -m 755 "$TMP_APPIMAGE" "$APPIMAGE_DEST"

echo "Installing icon..."
download_file "$RAW_BASE/gledhillmetadata/assets/icons/app_logo.png" "$ICON_DEST"

echo "Creating desktop entry..."
cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Name=Gledhill Metadata
Exec=$APPIMAGE_DEST
Icon=$APP_ID
Type=Application
Categories=Utility;
Terminal=false
EOF

if command -v update-desktop-database >/dev/null 2>&1; then
	echo "Updating desktop database..."
	update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

echo "Installation complete."
echo "AppImage installed to: $APPIMAGE_DEST"