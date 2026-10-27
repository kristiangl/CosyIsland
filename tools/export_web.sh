#!/usr/bin/env bash
# Builds the web version (index.html, index.wasm, index.pck...) into build/web, or the
# folder given, ready for any static web host. GitHub Pages builds it on every push
# (.github/workflows/web.yml). Needs Godot's web templates: tools/fetch_web_templates.py.
#
# It exports a copy of the project with the music squeezed smaller for the web (the
# originals aren't touched), using the "Web" preset in export_presets.cfg: single
# threaded, so any host works without special headers.
set -euo pipefail

GODOT="${GODOT:-/opt/godot/godot}"
cd "$(dirname "$0")/.."
OUT="${1:-build/web}"
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/project"
tar --exclude=./build --exclude=./.git --exclude=./shots --exclude=./screenshots -cf - . | tar -xf - -C "$WORK/project"

if command -v ffmpeg >/dev/null; then
	for song in "$WORK"/project/assets/music/*.mp3; do
		ffmpeg -loglevel error -y -i "$song" -b:a 80k "${song%.mp3}.small.mp3"
		mv "${song%.mp3}.small.mp3" "$song"
	done
else
	echo "No ffmpeg: the music goes in at full size."
fi

"$GODOT" --headless --path "$WORK/project" --import >/dev/null 2>&1 || true
rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path "$WORK/project" --export-release "Web" "$OUT/index.html" 2>&1 | grep -E "ERROR|DONE" || true
test -f "$OUT/index.pck" || { echo "Export failed"; exit 1; }
ls -la "$OUT"
