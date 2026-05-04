#!/bin/bash

set -euo pipefail

APP_NAME="Gledhill Metadata"
APP_ID="gledhill_metadata"

INSTALL_DIR="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons"
DESKTOP_DIR="$HOME/.local/share/applications"

echo "Removing $APP_NAME..."

rm -f "$INSTALL_DIR/${APP_ID}.AppImage"
rm -f "$ICON_DIR/${APP_ID}.png"
rm -f "$DESKTOP_DIR/${APP_ID}.desktop"

# Remove legacy install artifacts from older script versions.
rm -f "$INSTALL_DIR/GledhillMetadata.AppImage"
rm -f "$INSTALL_DIR/Gledhill_Metadata-x86_64.AppImage"
rm -f "$ICON_DIR/GledhillMetadata.png"
rm -f "$DESKTOP_DIR/GledhillMetadata.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
	update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

echo "Removed successfully"