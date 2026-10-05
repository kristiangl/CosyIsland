extends Node
## Shared game state: the current input mode and references to the live scene objects.

enum Mode { PLAY, MENU, PLACING }

const CURRENCY_NAME := "Acorns"

var mode: Mode = Mode.PLAY:
	set(value):
		mode = value
		Events.mode_changed.emit(value)

## The world the player is in: the island, or a room inside a home.
var world: World
## The island itself, even while indoors.
var island: World
## The island visited on a tour, while there.
var tour: World
var player: Player
var camera: CameraRig
var dialogue: DialogueBox
var shop: ShopMenu
## The characters standing about on the island.
var npcs: Array[Npc] = []
var player_name := ""
var island_name := ""

## The island the player is out on: home, or a tour island.
func outdoors() -> World:
	return tour if tour else island


## Command-line arguments passed after `--`, as {"key": "value"}. Flags map to "".
var args: Dictionary = {}


func _enter_tree() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else ""
	# --procedural: the hand-built animal heads instead of the generated ones.
	CharacterModel.use_model_heads = not args.has("procedural")
	InputSetup.register()


func _ready() -> void:
	_tool_screenshot.call_deferred()


## Tool scenes (not the main game) take their --screenshot here.
func _tool_screenshot() -> void:
	var scene := get_tree().current_scene
	if args.has("screenshot") and scene and scene.scene_file_path.begins_with("res://tools/"):
		screenshot(args["screenshot"], int(args.get("frames", "20")))


## Renders a few frames, saves the viewport as a PNG and quits.
func screenshot(path: String, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved screenshot to ", path)
	get_tree().quit()
