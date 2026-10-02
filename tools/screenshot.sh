#!/usr/bin/env bash
# Renders the game headlessly under a virtual display and saves a PNG.
# Usage: tools/screenshot.sh out.png [--seed=N] [--hour=H] [--view=overview] ...
set -euo pipefail

GODOT="${GODOT:-/opt/godot/godot}"
OUT="$1"
shift
cd "$(dirname "$0")/.."
mkdir -p "$(dirname "$OUT")"
case "$OUT" in /*) ABS="$OUT" ;; *) ABS="$PWD/$OUT" ;; esac

# Make sure resources are imported before the first real run.
if [ ! -d .godot/imported ]; then
	"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fi

xvfb-run -a -s "-screen 0 1280x720x24" \
	"$GODOT" --path . --rendering-driver opengl3 --resolution 1280x720 \
	-- --screenshot="$ABS" "$@"
