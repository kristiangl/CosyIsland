extends Node3D
## Game root. Loads or creates an island and builds the world, player, camera and UI.
##
## Command-line options (after `--`):
##   --new              ignore the save and start a fresh island
##   --seed=N           start a fresh island from seed N
##   --hour=H           time travel to hour H today
##   --screenshot=PATH  render a few frames, save a PNG and quit
##   --view=overview    frame the whole island (for screenshots)
##   --frames=N         frames to wait before the screenshot (default 45)
##   --grass=F          grass density multiplier (0 disables)
##   --at=X,Z           start the player at a world position
##   --demo             pitch the tent and chop a tree before the screenshot
##   --ui=pockets|pause|creator   open a menu (for screenshots)

const AUTOSAVE_SECONDS := 60.0

var world: World
var player: Player
var camera_rig: CameraRig
var day_night: DayNight
var hud: Hud
var placement: Placement
var _seed := 0
var _welcome_pending := false


func _ready() -> void:
	var fresh := Game.args.has("new") or Game.args.has("seed") or Game.args.has("screenshot")
	var saved := {} if fresh else SaveGame.read()
	_seed = int(Game.args.get("seed", saved.get("seed", randi() % 1000000)))
	var island := IslandGenerator.generate(_seed)

	GameClock.offset_seconds = int(saved.get("clock_offset", 0))
	if Game.args.has("hour"):
		GameClock.set_hour(float(Game.args["hour"]))

	world = World.new()
	world.name = "World"
	add_child(world)
	world.setup(island, saved.get("world", {}))
	Game.world = world

	if saved.has("inventory"):
		Inventory.from_save(saved["inventory"])
	else:
		_new_game_pockets()

	player = Player.new()
	player.name = "Player"
	add_child(player)
	var start := Vector3(island.spawn.x + 0.5, 0, island.spawn.y + 0.5)
	if Game.args.has("at"):
		var at: PackedStringArray = Game.args["at"].split(",")
		start = Vector3(float(at[0]), 0, float(at[1]))
	elif saved.has("player"):
		start = Vector3(saved["player"]["x"], 0, saved["player"]["z"])
		player.facing = Vector3(saved["player"].get("fx", 0.0), 0, saved["player"].get("fz", 1.0))
	var look: Dictionary = saved.get("player", {}).get("look", Appearance.DEFAULT)
	player.setup(world, start, look)
	Game.player = player

	camera_rig = CameraRig.new()
	camera_rig.target = player
	camera_rig.island_size = Vector2(island.width, island.height)
	camera_rig.overview = Game.args.get("view", "") == "overview"
	add_child(camera_rig)

	day_night = DayNight.new()
	add_child(day_night)

	placement = Placement.new()
	placement.player = player
	placement.world = world
	add_child(placement)

	hud = Hud.new()
	hud.place_requested.connect(placement.begin)
	hud.save_requested.connect(save_game)
	hud.quit_requested.connect(func():
		save_game()
		get_tree().quit())
	hud.wardrobe_requested.connect(func(): hud.creator.open(player.model.look, false))
	add_child(hud)
	hud.creator.finished.connect(_on_creator_finished)
	Game.player_name = saved.get("player_name", "")
	Game.island_name = saved.get("island_name", "")

	if Game.args.has("demo"):
		await _run_demo()
	match Game.args.get("ui", ""):
		"pockets":
			hud._pockets.open()
		"pause":
			hud._open_pause()
		"creator":
			hud.creator.open(Appearance.DEFAULT, true)
	if Game.args.has("screenshot"):
		_take_screenshot(Game.args["screenshot"], int(Game.args.get("frames", "45")))
	else:
		var timer := Timer.new()
		timer.wait_time = AUTOSAVE_SECONDS
		timer.autostart = true
		timer.timeout.connect(save_game)
		add_child(timer)
		if saved.is_empty():
			_welcome_pending = true
			hud.creator.open(Appearance.DEFAULT, true)


func _new_game_pockets() -> void:
	Inventory.reset()
	Inventory.add_item("flimsy_axe")
	Inventory.add_item("flimsy_shovel")
	Inventory.add_item("tent_kit")
	Inventory.equip(0)


func _on_creator_finished(look: Dictionary, player_name: String, island_name: String) -> void:
	player.model.set_look(look)
	if _welcome_pending:
		_welcome_pending = false
		Game.player_name = player_name
		Game.island_name = island_name
		var island := world.data
		Events.toast.emit("Welcome to %s Island, %s!" % [island_name, player_name])
		Events.toast.emit("This island's fruit is the %s, and %ss grow wild here." % [island.native_fruit, island.native_flower])
		Events.toast.emit("Open your pockets (X) to pitch your tent.")
	save_game()


func save_game() -> void:
	if Game.args.has("screenshot"):
		return
	SaveGame.write({
		"seed": _seed,
		"clock_offset": GameClock.offset_seconds,
		"world": world.to_save(),
		"inventory": Inventory.to_save(),
		"player": player.to_save(),
		"player_name": Game.player_name,
		"island_name": Game.island_name,
	})


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and world != null:
		save_game()


## Scripted actions for checking gameplay visuals in screenshots: pitch the tent near
## the spawn, then chop the nearest tree.
func _run_demo() -> void:
	for i in 5:
		await get_tree().process_frame
	var spawn := world.data.spawn
	for r in range(2, 12):
		var rect := Rect2i(spawn + Vector2i(-1, -r - 2), Vector2i(3, 3))
		if world.can_place(rect, player.position):
			world.place_item("tent_kit", rect, 0)
			Inventory.remove_from_slot(2)
			break
	var trees := world.objects().filter(func(o): return o["kind"] == "tree")
	trees.sort_custom(func(a, b): return Vector2(a["x"], a["z"]).distance_to(Vector2(spawn)) < Vector2(b["x"], b["z"]).distance_to(Vector2(spawn)))
	var tree: Dictionary = trees[0]
	player.position = Vector3(tree["x"] + 0.5, 0, tree["z"] + 1.6)
	player.position.y = world.ground_height(player.position.x, player.position.z)
	player.facing = Vector3(0, 0, -1)
	camera_rig.focus = player.position
	for i in 3:
		player._use()
		await get_tree().create_timer(0.5).timeout
	player._use()
	await get_tree().create_timer(0.2).timeout


func _take_screenshot(path: String, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	print("Saved screenshot to ", path)
	get_tree().quit()
