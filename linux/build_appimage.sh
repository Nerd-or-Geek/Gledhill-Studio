#!/bin/bash

set -euo pipefail

APP_ID="gledhill_metadata"
APP_DISPLAY_NAME="Gledhill Metadata"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [[ -d "$REPO_ROOT/gledhillmetadata" ]]; then
	FLUTTER_DIR="$REPO_ROOT/gledhillmetadata"
elif [[ -d "$REPO_ROOT/gledhillstudio" ]]; then
	FLUTTER_DIR="$REPO_ROOT/gledhillstudio"
else
	echo "Error: Could not find Flutter project folder (expected gledhillmetadata or gledhillstudio under $REPO_ROOT)." >&2
	exit 1
fi
BUILD_DIR="$FLUTTER_DIR/build/linux/x64/release/bundle"
APPDIR="$SCRIPT_DIR/AppDir"
ICON_SOURCE="$FLUTTER_DIR/assets/icons/app_logo.png"
ICON_BASENAME="AppLogo"

require_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Error: Required command '$1' is not installed or not in PATH." >&2
		exit 1
	fi
}

require_cmd flutter
require_cmd appimagetool

if [[ ! -d "$FLUTTER_DIR" ]]; then
	echo "Error: Flutter project directory not found at $FLUTTER_DIR" >&2
	exit 1
fi

if [[ ! -f "$ICON_SOURCE" ]]; then
	echo "Error: Icon not found at $ICON_SOURCE" >&2
	exit 1
fi

echo "Cleaning old builds..."
pushd "$FLUTTER_DIR" >/dev/null
flutter clean
flutter pub get

echo "Building Flutter Linux release..."
flutter build linux --release
popd >/dev/null

if [[ ! -x "$BUILD_DIR/$APP_ID" ]]; then
	echo "Error: Expected binary not found at $BUILD_DIR/$APP_ID" >&2
	exit 1
fi

echo "Creating AppDir..."
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"

echo "Copying Flutter bundle into AppDir..."
cp -a "$BUILD_DIR/." "$APPDIR/usr/bin/"

echo "Adding icon..."
cp "$ICON_SOURCE" "$APPDIR/$ICON_BASENAME.png"

echo "Creating desktop file..."
cat <<EOF > "$APPDIR/$APP_ID.desktop"
[Desktop Entry]
Name=$APP_DISPLAY_NAME
Exec=$APP_ID
Icon=$ICON_BASENAME
Type=Application
Categories=Utility;
Terminal=false
EOF

echo "Creating AppRun..."
cat <<'EOF' > "$APPDIR/AppRun"
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
exec "$HERE/usr/bin/gledhill_metadata" "$@"
EOF

chmod +x "$APPDIR/AppRun"

echo "Building AppImage..."
pushd "$SCRIPT_DIR" >/dev/null
ARCH="$(uname -m)"
appimagetool "$APPDIR"

APPIMAGE_OUT="AppDir-${ARCH}.AppImage"
if [[ -f "$APPIMAGE_OUT" ]]; then
	FINAL_NAME="${APP_ID}-${ARCH}.AppImage"
	mv -f "$APPIMAGE_OUT" "$FINAL_NAME"
	echo "Done: $FINAL_NAME"
else
	echo "Done: AppImage created (name determined by appimagetool output)."
fi

echo "Moving AppImage to downloads folder..."
mkdir -p "$REPO_ROOT/downloads"
shopt -s nullglob
APPIMAGES=("$SCRIPT_DIR"/*.AppImage)
if (( ${#APPIMAGES[@]} > 0 )); then
	mv -f "${APPIMAGES[@]}" "$REPO_ROOT/downloads/"
	echo "AppImage copied to $REPO_ROOT/downloads"
else
	echo "No AppImage file found to move."
fi
shopt -u nullglob

popd >/dev/null