extends Node
## Shared game state: the current input mode and references to the live scene objects.

enum Mode { PLAY, MENU, PLACING }

const CURRENCY_NAME := "Acorns"

var mode: Mode = Mode.PLAY:
	set(value):
		mode = value
		Events.mode_changed.emit(value)

var world: World
var player: Player

## Command-line arguments passed after `--`, as {"key": "value"}. Flags map to "".
var args: Dictionary = {}


func _enter_tree() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else ""
	InputSetup.register()
