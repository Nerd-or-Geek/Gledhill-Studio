#!/bin/bash

set -euo pipefail

echo "Updating system..."
sudo apt update

echo "Installing Flutter Linux build dependencies..."
sudo apt install -y \
  cmake \
  ninja-build \
  clang \
  pkg-config \
  libgtk-3-dev \
  libfuse2 \
  desktop-file-utils \
  curl \
  wget \
  git

echo "Installing AppImage tool..."
wget -O appimagetool.AppImage https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool.AppImage

echo "Making tool globally usable..."
sudo mv appimagetool.AppImage /usr/local/bin/appimagetool

echo "Setup complete"
echo "Run: flutter doctor"