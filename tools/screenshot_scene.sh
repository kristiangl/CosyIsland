#!/usr/bin/env bash
# Renders any scene headlessly and saves a PNG after a few frames.
# Usage: tools/screenshot_scene.sh out.png res://path/scene.tscn [extra args]
set -euo pipefail

GODOT="${GODOT:-/opt/godot/godot}"
OUT="$1"
SCENE="$2"
shift 2
cd "$(dirname "$0")/.."
mkdir -p "$(dirname "$OUT")"
case "$OUT" in /*) ABS="$OUT" ;; *) ABS="$PWD/$OUT" ;; esac
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
xvfb-run -a -s "-screen 0 1280x720x24" \
	"$GODOT" --path . --rendering-driver opengl3 --resolution 1280x720 "$SCENE" \
	-- --screenshot="$ABS" "$@"
