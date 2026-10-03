extends Node3D
## Game root. Loads or creates an island and builds the world, player, camera and UI.
##
## Command-line options (after `--`):
##   --new              ignore the save and start a fresh island
##   --seed=N           start a fresh island from seed N
##   --gen=N            ...made with an older generator version (see IslandGenerator.VERSION)
##   --hour=H           time travel to hour H today
##   --screenshot=PATH  render a few frames, save a PNG and quit
##   --view=overview    frame the whole island (for screenshots)
##   --frames=N         frames to wait before the screenshot (default 45)
##   --grass=F          grass density multiplier (0 disables)
##   --at=X,Z           start the player at a world position
##   --demo             pitch the tent, place furniture and chop a tree before the screenshot
##   --demo=decor       same, but stay by the furniture instead of chopping
##   --demo=sit         same, and sit on the chair
##   --demo=home        pitch the tent, go inside and furnish it (--room=wallpaper,flooring)
##   --demo=door        pitch the tent and stand outside its door
##   --house            with --demo: the tent has already become a house
##   --series=ID        with --demo=home: furnish it from one furniture series (--variant=ID)
##   --ui=pockets|pause|map|creator|crafting|customise|placing|intro|ask|lucy|sleep|shop|sell  (--tab=N picks a creator tab, --try=key:id,... dresses up, --closet=TEXT opens the wardrobe with clothes whose ids contain TEXT)  open a menu or mode (for screenshots)

const AUTOSAVE_SECONDS := 60.0

var world: World
var player: Player
var camera_rig: CameraRig
var day_night: DayNight
var hud: Hud
var placement: Placement
var _seed := 0
var _gen_version := IslandGenerator.VERSION
var _welcome_pending := false
## The room the player is in, or null outdoors.
var room: World
var _home_uid := -1
## Saved rooms by home uid (as a string, for JSON).
var _rooms: Dictionary = {}
var _going_through_door := false
var ambient: AmbientEffects


func _ready() -> void:
	var fresh := Game.args.has("new") or Game.args.has("seed") or Game.args.has("screenshot")
	var saved := {} if fresh else SaveGame.read()
	_seed = int(Game.args.get("seed", saved.get("seed", randi() % 1000000)))
	# Islands keep the generator version they were made with (saves before versions are 1).
	_gen_version = int(saved.get("gen", 1)) if saved.has("seed") else int(Game.args.get("gen", IslandGenerator.VERSION))
	var island := IslandGenerator.generate(_seed, IslandGenerator.WIDTH, IslandGenerator.HEIGHT, _gen_version)

	GameClock.offset_seconds = int(saved.get("clock_offset", 0))
	if Game.args.has("hour"):
		GameClock.set_hour(float(Game.args["hour"]))

	world = World.new()
	world.name = "World"
	add_child(world)
	world.setup(island, saved.get("world", {}))
	Game.world = world
	Game.island = world
	IslandMap.terrain_texture(island) # starts painting the map in the background
	_rooms = saved.get("rooms", {})

	if saved.has("inventory"):
		Inventory.from_save(saved["inventory"])
	else:
		_new_game_pockets()
	Recipes.from_save(saved.get("recipes", []))
	Story.from_save(saved.get("story", {}))
	if not saved.is_empty() and not saved.has("story"):
		# Saved before the story began: they've already got going.
		Story.flags["intro_done"] = true
		Story.flags["got_tent"] = true

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
	Game.camera = camera_rig
	ambient = AmbientEffects.new()
	ambient.camera = camera_rig
	add_child(ambient)
	_spawn_npcs()

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
	Events.home_entered.connect(_enter_home)
	Events.home_left.connect(_leave_home)
	Events.sleep_requested.connect(_sleep)
	Events.day_changed.connect(func(_key): if room == null: _check_house())
	_check_house()
	# Back inside if that's where we saved.
	var inside := int(saved.get("inside", -1))
	if inside >= 0 and not world.get_object(inside).is_empty():
		await _enter_home(inside, true)
		player.position = Vector3(saved["player"]["x"], room.ground_height(saved["player"]["x"], saved["player"]["z"]), saved["player"]["z"])
		camera_rig.snap()

	if Game.args.has("demo"):
		await _run_demo()
	match Game.args.get("ui", ""):
		"pockets":
			for id in ["wood", "stone", "clay", "iron_nugget", "tree_branch", "wooden_chair", "campfire", "apple", "tulip_red"]:
				Inventory.add_item(id, 3)
			hud._pockets.open()
		"pause":
			hud.phone.open()
		"map":
			hud.open_map()
		"shop", "sell":
			Inventory.add_currency(2500)
			for id in ["wood", "stone", "apple", "clay", "wooden_chair"]:
				Inventory.add_item(id, 4)
			hud.shop.open("buy" if Game.args["ui"] == "shop" else "sell")
		"sleep":
			# The bed question, in the tent (use with --demo=home).
			for obj in world_now().objects():
				if obj.get("item", "") == "sleeping_bag":
					player._bed(obj)
		"intro", "ask", "lucy":
			# Poppy's welcome (or Lucy's first chat) part-way through, for screenshots.
			Game.player_name = "Sam"
			Game.island_name = "Driftwood"
			if Game.args["ui"] == "lucy":
				player.position = Vector3(world.data.plaza.position.x + 6.6, player.position.y, world.data.plaza.position.y + 5.4)
				player.facing = Vector3(1, 0, -0.6).normalized()
				Story.talk_to(Story.npc("lucy"))
			else:
				Story.intro()
			if Game.args["ui"] == "ask":
				for i in 24:
					await get_tree().create_timer(0.16).timeout
					var ev := InputEventAction.new()
					ev.action = "ui_accept"
					ev.pressed = true
					Input.parse_input_event(ev)
		"creator":
			var trying := Appearance.DEFAULT.duplicate()
			for pair in Game.args.get("try", "").split(",", false):
				trying[pair.get_slice(":", 0)] = pair.get_slice(":", 1)
			if Game.args.has("closet"):
				# A wardrobe full of clothes, for screenshots.
				for id in ItemDB.items:
					if ItemDB.is_clothing(id) and Game.args["closet"] in id:
						Inventory.closet.append(id)
			hud.creator.open(trying, not Game.args.has("closet"))
			if Game.args.has("tab"):
				hud.creator._select_tab(int(Game.args["tab"]))
		"crafting":
			Inventory.add_item("wood", 12)
			Inventory.add_item("stone", 5)
			hud.crafting.open()
		"customise":
			for id: String in ["meadow_armchair_cream", "lodge_sofa_honey", "raincoat_yellow", "driftwood_lamp_bleached"]:
				Inventory.add_item(id)
			Inventory.add_item("customisation_kit", 3)
			hud.crafting.open("customise")
			hud.crafting.cycle(hud.crafting._rows[0], 1)
		"placing":
			Inventory.add_item("wooden_table")
			placement.begin(Inventory.slots.find_custom(func(s): return s.get("id", "") == "wooden_table"))
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
		elif not saved.has("player_name"):
			# A save from before characters existed: make one now.
			_welcome_pending = true
			hud.creator.open(player.model.look, true)


func _new_game_pockets() -> void:
	Inventory.reset()
	Inventory.add_item("flimsy_axe")
	Inventory.add_item("flimsy_shovel")
	Inventory.equip(0)


func _on_creator_finished(look: Dictionary, player_name: String, island_name: String) -> void:
	player.model.set_look(look)
	if _welcome_pending:
		_welcome_pending = false
		Game.player_name = player_name
		Game.island_name = island_name
		if not Story.flags.get("intro_done", false):
			save_game()
			await Story.intro()
	save_game()


func save_game() -> void:
	if Game.args.has("screenshot"):
		return
	if room:
		_rooms[str(_home_uid)] = room.to_save()
	SaveGame.write({
		"seed": _seed,
		"gen": _gen_version,
		"clock_offset": GameClock.offset_seconds,
		"world": world.to_save(),
		"rooms": _rooms,
		"inside": _home_uid if room else -1,
		"inventory": Inventory.to_save(),
		"player": player.to_save(),
		"recipes": Recipes.to_save(),
		"story": Story.to_save(),
		"player_name": Game.player_name,
		"island_name": Game.island_name,
	})


func _exit_tree() -> void:
	IslandMap.finish()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and world != null:
		save_game()


func world_now() -> World:
	return room if room else world


# --- Characters ---------------------------------------------------------------------

## Where the island's characters stand, in plaza tiles, and which way they face.
const NPC_SPOTS := {
	"poppy": [Vector2(3.5, 3.55), Vector3(0.2, 0, 1)],
	"lucy": [Vector2(7.55, 4.5), Vector3(-0.6, 0, 1)],
}


func _spawn_npcs() -> void:
	Game.npcs.clear()
	var plaza := world.data.plaza
	for id: String in NPC_SPOTS:
		var spot: Vector2 = NPC_SPOTS[id][0] + Vector2(plaza.position)
		var npc := Npc.new()
		world.add_child(npc)
		npc.setup(id, world, Vector3(spot.x, 0, spot.y), NPC_SPOTS[id][1].normalized())
		world.reserve(Vector2i(floori(spot.x), floori(spot.y)))
		Game.npcs.append(npc)


## The house Poppy promised goes up once a night has passed (not while you're inside).
func _check_house() -> void:
	if Story.finish_house(world):
		Events.toast.emit("Your house is ready! Go and have a look inside.")


## Fades out, moves the clock on, and wakes up again.
func _sleep(hour: float) -> void:
	Game.mode = Game.Mode.MENU
	await hud.fade_out()
	var hours := GameClock.sleep_until(hour)
	await get_tree().create_timer(0.6).timeout
	await hud.fade_in()
	Game.mode = Game.Mode.PLAY
	player.model.play("cheer")
	var greeting := "Good morning!" if hour >= 5.0 and hour < 12.0 else ("Good afternoon!" if hour >= 12.0 and hour < 17.0 else ("Good evening!" if hour >= 17.0 else "It's the middle of the night."))
	Events.toast.emit("You slept for %d hours. %s" % [roundi(hours), greeting])
	save_game()


# --- Homes --------------------------------------------------------------------------

func _enter_home(uid: int, instant := false) -> void:
	var home := world.get_object(uid)
	var def := ItemDB.placeable(home.get("item", ""))
	if _going_through_door or room != null or not def.has("room"):
		return
	_going_through_door = true
	Game.mode = Game.Mode.MENU
	if not instant:
		await hud.fade_out()
	var size: Array = def["room"]["size"]
	room = World.new()
	room.name = "Room"
	room.interior = true
	room.room_style = def["room"]["style"]
	add_child(room)
	var first_visit := not _rooms.has(str(uid))
	room.setup(IslandData.room(size[0], size[1]), _rooms.get(str(uid), {}))
	if first_visit:
		# Every new home comes with somewhere to sleep, against the back wall.
		room.place_item("sleeping_bag", Rect2i(0, 0, 1, 2), 0)
	_home_uid = uid
	_switch_world(room)
	var spawn := room.data.spawn
	player.position = Vector3(spawn.x + 0.5, room.ground_height(spawn.x + 0.5, spawn.y + 0.5), spawn.y + 0.5)
	player.facing = Vector3(0, 0, -1)
	camera_rig.room = Rect2(0, 0, size[0], size[1])
	camera_rig.snap()
	Game.mode = Game.Mode.PLAY
	if not instant:
		await hud.fade_in()
	_going_through_door = false


func _leave_home() -> void:
	if _going_through_door or room == null:
		return
	_going_through_door = true
	Game.mode = Game.Mode.MENU
	await hud.fade_out()
	_rooms[str(_home_uid)] = room.to_save()
	room.queue_free()
	room = null
	_switch_world(world)
	_check_house()
	var out := world.outside_door(world.get_object(_home_uid))
	player.position = out["position"]
	player.facing = out["facing"]
	camera_rig.room = Rect2()
	camera_rig.snap()
	Game.mode = Game.Mode.PLAY
	await hud.fade_in()
	_going_through_door = false


## Points the player, placement and UI at the island or a room, and swaps the
## outdoor-only bits (curvature, wind, sky) on or off.
func _switch_world(to: World) -> void:
	var outside := to == world
	world.visible = outside
	world.process_mode = Node.PROCESS_MODE_INHERIT if outside else Node.PROCESS_MODE_DISABLED
	Game.world = to
	player.world = to
	placement.world = to
	day_night.indoors = not outside
	hud.indoors = not outside
	ambient.indoors = not outside
	RenderingServer.global_shader_parameter_set("curve_amount", ProjectSettings.get_setting("shader_globals/curve_amount")["value"] if outside else 0.0)
	RenderingServer.global_shader_parameter_set("wind_strength", ProjectSettings.get_setting("shader_globals/wind_strength")["value"] if outside else 0.0)


## Scripted actions for checking gameplay visuals in screenshots: pitch the tent near
## the spawn, then chop the nearest tree.
func _run_demo() -> void:
	for i in 5:
		await get_tree().process_frame
	var spawn := world.data.spawn
	var tent := {}
	for r in range(2, 12):
		var rect := Rect2i(spawn + Vector2i(-1, -r - 2), Vector2i(3, 3))
		if world.can_place(rect, player.position) and world.door_clear("tent_kit", rect, 0):
			tent = world.place_item("tent_kit", rect, 0)
			break
	if Game.args.has("house") and not tent.is_empty():
		# As if Poppy built the house last night.
		Story.flags["tent_gift"] = true
		Story.flags["house_day"] = GameClock.day_key() - 1
		_check_house()
	if Game.args["demo"] == "door" and not tent.is_empty():
		var out := world.outside_door(tent)
		player.position = out["position"] + Vector3(0.8, 0, 1.6)
		player.facing = Vector3(0, 0, -1)
		camera_rig.snap()
		return
	if Game.args["demo"] == "home" and not tent.is_empty():
		await _enter_home(tent["uid"], true)
		var furniture := [["simple_bed", Vector2i(1, 0), 0], ["wooden_table", Vector2i(3, 1), 0], ["wooden_chair", Vector2i(3, 2), 2],
				["stone_lantern", Vector2i(5, 0), 0], ["potted_plant", Vector2i(5, 5), 0], ["barrel", Vector2i(5, 3), 0], ["log_bench", Vector2i(0, 3), 1]]
		if Game.args.has("series"):
			furniture = _series_layout(Game.args["series"], Game.args.get("variant", ""))
		for entry in furniture:
			var size: Array = ItemDB.placeable(entry[0])["footprint"]
			var dims := Vector2i(size[0], size[1]) if entry[2] % 2 == 0 else Vector2i(size[1], size[0])
			var fits := room.can_place_rug(Rect2i(entry[1], dims)) if ItemDB.placeable(entry[0]).get("rug", false) \
				else room.can_place(Rect2i(entry[1], dims), player.position)
			if fits:
				room.place_item(entry[0], Rect2i(entry[1], dims), entry[2])
		for item in Game.args.get("room", "").split(",", false):
			room.set_room_look(item)
		if Game.args.has("series"):
			room.place_on_surface("teapot", Vector2i(3, 2), 0)
			room.place_on_surface("fruit_bowl", Vector2i(4, 2), 0)
			var lamp: Array = ItemDB.items.keys().filter(func(id): return ItemDB.get_item(id).get("series", "") == Game.args["series"] \
					and ItemDB.get_item(id)["build"]["kind"] == "table_lamp")
			room.place_on_surface(lamp[0] if not lamp.is_empty() else "candle_set", Vector2i(5, 2), 0)
		else:
			room.place_on_surface("teapot", Vector2i(3, 1), 0)
			room.place_on_surface("fruit_bowl", Vector2i(4, 1), 0)
			room.place_on_surface("candle_set", Vector2i(5, 3), 0)
		player.position.x += 0.6
		player.facing = Vector3(0, 0, 1)
		camera_rig.snap()
		return
	# Some furniture around the spawn.
	var decor := ["campfire", "log_bench", "stone_lantern", "wooden_table", "wooden_chair", "barrel", "flower_pot", "garden_lantern", "birdhouse"]
	var spot := 0
	for dz in range(-1, 6):
		for dx in range(-6, 7):
			if spot >= decor.size():
				break
			var size: Array = ItemDB.placeable(decor[spot])["footprint"]
			var rect := Rect2i(spawn + Vector2i(dx * 2, dz * 2), Vector2i(size[0], size[1]))
			if world.can_place(rect, player.position):
				world.place_item(decor[spot], rect, 0)
				spot += 1
	# Small things on the tables.
	var small := ["teapot", "fruit_bowl", "potted_plant", "candle_set", "book_stack"]
	for obj in world.objects():
		if obj["kind"] != "placed" or obj.has("on") or small.is_empty():
			continue
		for t in world.footprint(obj):
			if not small.is_empty() and world.can_place_on_surface(t):
				world.place_on_surface(small.pop_front(), t, 0)
	if Game.args["demo"] == "sit":
		var seats := world.objects().filter(func(o): return o["kind"] == "placed" and o["item"] == "wooden_chair")
		if not seats.is_empty():
			player._sit_on(seats[0])
			camera_rig.focus = player.position
		return
	if Game.args["demo"] == "decor":
		player.position = Vector3(spawn.x + 0.5, world.ground_height(spawn.x + 0.5, spawn.y + 4.5), spawn.y + 4.5)
		camera_rig.focus = player.position
		return
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


## A room's worth of one furniture series for --demo=home: [item, tile, rotation] by kind.
func _series_layout(series_id: String, variant: String) -> Array:
	var data: Dictionary = ItemDB.series.get(series_id, {})
	if data.is_empty():
		return []
	if variant == "":
		variant = data["variants"][0]["id"]
	var by_kind := {}
	for piece: Dictionary in data["pieces"]:
		if not by_kind.has(piece["kind"]):
			by_kind[piece["kind"]] = "%s_%s" % [piece["id"], variant]
	var out := []
	for entry: Array in [["rug", Vector2i(2, 2), 0], ["bed", Vector2i(1, 0), 0], ["bookcase", Vector2i(3, 0), 0], ["table", Vector2i(3, 2), 0],
			["chair", Vector2i(3, 3), 2], ["stool", Vector2i(4, 3), 2], ["floor_lamp", Vector2i(5, 0), 0],
			["sofa", Vector2i(0, 3), 1], ["bench", Vector2i(0, 3), 1], ["armchair", Vector2i(5, 4), 3],
			["side_table", Vector2i(5, 2), 0], ["dresser", Vector2i(1, 5), 0], ["crate", Vector2i(5, 0), 0]]:
		if by_kind.has(entry[0]):
			out.append([by_kind[entry[0]], entry[1], entry[2]])
	return out
