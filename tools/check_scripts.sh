#!/usr/bin/env bash
# Loads every script in the project (with autoloads) and prints any parse errors.
set -uo pipefail
GODOT="${GODOT:-/opt/godot/godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . res://tools/check_scripts.tscn 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error|at: GDScript|scripts loaded" | grep -v "^$"
