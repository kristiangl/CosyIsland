#!/usr/bin/env bash
# Installs Godot to /opt/godot/godot. Tries the official release first, then builds
# from source if download hosts are blocked.
set -euo pipefail

VERSION="${GODOT_VERSION:-4.7.2}"
DEST=/opt/godot
mkdir -p "$DEST"

if [ -x "$DEST/godot" ]; then
	echo "Godot already installed: $("$DEST/godot" --version)"
	exit 0
fi

URL="https://github.com/godotengine/godot/releases/download/${VERSION}-stable/Godot_v${VERSION}-stable_linux.x86_64.zip"
if curl -fsSL -o /tmp/godot.zip "$URL" 2>/dev/null; then
	unzip -o -q /tmp/godot.zip -d /tmp/godot_zip
	mv /tmp/godot_zip/Godot_v*_linux.x86_64 "$DEST/godot"
	chmod +x "$DEST/godot"
	echo "Installed official Godot $VERSION"
	exit 0
fi

echo "Official download unavailable; building Godot $VERSION from source."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq build-essential pkg-config \
	libx11-dev libxcursor-dev libxinerama-dev libgl1-mesa-dev libglu1-mesa-dev \
	libasound2-dev libpulse-dev libudev-dev libxi-dev libxrandr-dev libwayland-dev \
	libfontconfig-dev mesa-utils libgl1-mesa-dri xvfb
pip install -q scons
SRC=/opt/build/godot
if [ ! -d "$SRC" ]; then
	git clone -q --depth 1 --branch "${VERSION}-stable" https://github.com/godotengine/godot.git "$SRC"
fi
(cd "$SRC" && scons platform=linuxbsd target=editor -j"$(nproc)")
cp "$SRC"/bin/godot.linuxbsd.editor.x86_64 "$DEST/godot"
echo "Built Godot $VERSION from source"
