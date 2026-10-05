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
##   --demo=shop        Lucy's shop has been built; stand in front of it (--demo=museum: Bramble's,
##                      --built for the finished museum, --visit to go in)
##   --demo=dock        Marlow's ferry dock (--demo=tour: off on a tour, --camper with someone camping there,
##                     --island=orchard|meadow|quarry|buggy|fishy for a rare island)
##   --demo=orchard     a row of planted fruit trees, one at each stage of growing
##   --demo=site        Lucy's shop kit staked out, waiting to be built
##   --demo=neighbours  two neighbours have just moved in (--visit: go inside one's home, --who=id,id: who)
##   --demo=visitor     someone met on a tour is visiting by the plaza (--who=id)
##   --demo=fishing     fishing off the beach with fish about (--demo=bugs: bugs nearby)
##   --demo=flowers     stand by some flowers, one picked, with a flower in your hair
##   --house            with --demo: the tent has already become a house
##   --series=ID        with --demo or --demo=home: furniture from one series (--variant=ID)
##   --ui=pockets|pause|map|creator|crafting|customise|journal|exchange|critters|friends|neighbour|placing (--place=ID)|intro|ask|lucy|sleep|asleep|shop|sell  (--tab=N picks a creator tab, --try=key:id,... dresses up, --closet=TEXT opens the wardrobe with clothes whose ids contain TEXT)  open a menu or mode (for screenshots)

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
## The island visited on a tour, while there.
var tour: World
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
	Journal.from_save(saved.get("journal", {}))
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
	Effects.warm_up(player.position)

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
	Events.day_changed.connect(func(_key): if room == null and tour == null: _check_house())
	Events.tour_requested.connect(func(): _start_tour.call_deferred())
	Events.tour_ended.connect(func(): _end_tour.call_deferred())
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
			for id in ["wood", "stone", "clay", "iron_nugget", "tree_branch", "wooden_chair", "campfire", "apple", "tulip_red", "tour_ticket", "shop_kit"]:
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
		"tailors":
			Inventory.add_currency(9000)
			hud.shop.open("buy", "tailors")
		"sleep", "asleep":
			# The bed question, or tucked up in bed, in the tent (use with --demo=home).
			var beds := world_now().objects().filter(func(o): return o.get("item", "") == "sleeping_bag" or ItemDB.placeable(o.get("item", "")).get("bed", false))
			beds.sort_custom(func(a, b): return a["item"] != "sleeping_bag" and b["item"] == "sleeping_bag")
			for obj in beds:
					if Game.args["ui"] == "asleep":
						player._lie_in(obj)
						camera_rig.snap()
					else:
						player._bed(obj)
					break
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
		"critters":
			for id: String in ["sea_bass", "koi", "anchovy", "white_butterfly", "ladybug", "cicada", "frog"]:
				Journal.catch(id)
			for id: String in ["sea_bass", "white_butterfly", "ladybug"]:
				Journal.donate(id)
			hud.journal.open("critters")
		"neighbour":
			# Chatting with a neighbour who's asked for a favour.
			Story.flags["met_neighbours"] = ["biscuit"]
			var rect := Rect2i(world.data.spawn + Vector2i(-6, 6), Vector2i(3, 3))
			var house := world.place_item("plot_kit", rect, 0)
			house["item"] = "neighbour_house"
			house["resident"] = "biscuit"
			_spawn_neighbour(house)
			var npc := Story.npc("biscuit")
			npc.wanders = false
			npc.position = player.position + Vector3(1.0, 0, 0.2)
			player.facing = Vector3(1, 0, 0)
			Story.talk_to(npc)
		"friends":
			Story.flags["met_neighbours"] = ["biscuit", "maple"]
			Story.flags["friendship"] = {"biscuit": 16, "maple": 4}
			for i in 2:
				var rect := Rect2i(world.data.spawn + Vector2i(-6 + i * 10, 6), Vector2i(3, 3))
				var obj := world.place_item("plot_kit", rect, 0)
				obj["item"] = "neighbour_house"
				obj["resident"] = ["biscuit", "maple"][i]
			hud.journal.open("neighbours")
		"journal", "exchange":
			Journal.add("wood", 12)
			Journal.add("crafted", 2)
			Journal.add("sold", 6)
			hud.journal.open("today" if Game.args["ui"] == "journal" else "exchange")
		"customise":
			for id: String in ["meadow_armchair_cream", "lodge_sofa_honey", "raincoat_yellow", "driftwood_lamp_bleached"]:
				Inventory.add_item(id)
			Inventory.add_item("customisation_kit", 3)
			hud.crafting.open("customise")
			hud.crafting.cycle(hud.crafting._rows[0], 1)
		"placing":
			var item: String = Game.args.get("place", "wooden_table")
			Inventory.add_item(item)
			placement.begin(Inventory.slots.find_custom(func(s): return s.get("id", "") == item))
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
	Inventory.add_item("flimsy_pickaxe")
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
	if room and not ItemDB.placeable(world.get_object(_home_uid).get("item", "")).get("museum", false):
		_rooms[str(_home_uid)] = room.to_save()
	var me := player.to_save()
	if tour:
		# Tour islands aren't kept: a game saved on one carries on back at the dock.
		var back: Vector3 = world.dock_spots(world.building("dock"))["arrive"]
		me["x"] = back.x
		me["z"] = back.z
	SaveGame.write({
		"seed": _seed,
		"gen": _gen_version,
		"clock_offset": GameClock.offset_seconds,
		"world": world.to_save(),
		"rooms": _rooms,
		"inside": _home_uid if room else -1,
		"inventory": Inventory.to_save(),
		"player": me,
		"recipes": Recipes.to_save(),
		"story": Story.to_save(),
		"journal": Journal.to_save(),
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
	_place_lucy()
	_place_bramble()
	_place_tailors()
	_place_marlow(world)
	for obj in world.objects():
		if obj.has("resident"):
			_spawn_neighbour(obj)
	_check_visitor()


## Nothing on this tile or near it (so a visitor isn't hidden in the trees).
func _open_around(x: int, z: int) -> bool:
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			if not world.object_at(x + dx, z + dz).is_empty():
				return false
	return true


## The house Poppy promised goes up once a night has passed (not while you're inside).
func _check_house() -> void:
	if Story.finish_house(world):
		Events.toast.emit("Your house is ready! Go and have a look inside.")
	if Story.finish_shop(world):
		Events.toast.emit("Lucy's shop is open! Go and say hello.")
		_place_lucy()
	if Story.finish_tailors(world):
		Events.toast.emit("Daisy and Morris's clothes shop is open!")
		_place_tailors()
	if Story.finish_museum(world):
		Events.toast.emit("Bramble has put up his museum tent! Go and say hello.")
		_place_bramble()
	if Story.finish_museum_building(world):
		Events.toast.emit("The museum is finished! Go and look inside.")
	if Story.finish_dock(world):
		Events.toast.emit("A ferry has tied up at the beach! Go and say hello.")
		_place_marlow(world)
	for who in Story.move_in(world):
		Events.toast.emit("%s has moved in! Go and say hello." % NpcData.display_name(who))
		_spawn_neighbour(world.building_of(who))
	_check_visitor()


## Someone you met on a tour drops in for the day, round the plaza; yesterday's goes home.
func _check_visitor() -> void:
	var who := Story.visitor_today()
	for n in Game.npcs.duplicate():
		if n.visiting and n.id != who:
			Game.npcs.erase(n)
			n.queue_free()
	if who == "" or Story.npc(who) != null:
		return
	# Somewhere open just outside the plaza.
	var plaza := world.data.plaza
	var centre := Vector2(plaza.get_center())
	var spot := Vector3.ZERO
	var best := INF
	for z in range(plaza.position.y - 4, plaza.end.y + 4):
		for x in range(plaza.position.x - 4, plaza.end.x + 4):
			var c := Vector2(x + 0.5, z + 0.5)
			var d := c.distance_to(centre + Vector2(0, plaza.size.y * 0.5 + 2.0))
			if not plaza.grow(1).has_point(Vector2i(x, z)) and world.data.tile(x, z) == IslandData.Tile.GRASS \
					and world.is_walkable(c.x, c.y) and _open_around(x, z) and d < best:
				best = d
				spot = Vector3(c.x, 0, c.y)
	if best == INF:
		return
	var npc := Npc.new()
	world.add_child(npc)
	npc.setup(who, world, spot, Vector3(0, 0, 1))
	npc.wanders = true
	npc.visiting = true
	npc.home = npc.position
	Game.npcs.append(npc)


## A neighbour, out and about near their house.
func _spawn_neighbour(house: Dictionary) -> void:
	if house.is_empty() or Story.npc(house["resident"]) != null:
		return
	var at := world.outside_door(house)
	var npc := Npc.new()
	world.add_child(npc)
	npc.setup(house["resident"], world, at["position"], at["facing"])
	npc.wanders = true
	npc.home = at["position"]
	Game.npcs.append(npc)


## Bramble comes to the island with his museum and stands at its door.
func _place_bramble() -> void:
	var museum := world.building("museum_tent")
	if museum.is_empty():
		museum = world.building("museum")
	if museum.is_empty():
		return
	var bramble := Story.npc("bramble")
	if bramble == null:
		bramble = Npc.new()
		world.add_child(bramble)
		var spot := world.outside_door(museum)
		bramble.setup("bramble", world, spot["position"], spot["facing"])
		Game.npcs.append(bramble)
	var at := world.outside_door(museum)
	bramble.position = at["position"] + Vector3(0.9, 0, -0.2)
	bramble.position.y = world.ground_height(bramble.position.x, bramble.position.z)
	bramble.rest_facing = at["facing"]
	world.reserve(Vector2i(floori(bramble.position.x), floori(bramble.position.z)))


## Marlow stands by his dock, on the island or a tour island.
func _place_marlow(w: World) -> Npc:
	var dock := w.building("dock")
	if dock.is_empty():
		return null
	for n in Game.npcs:
		if n.id == "marlow" and n.world == w:
			return n
	var spots := w.dock_spots(dock)
	var marlow := Npc.new()
	w.add_child(marlow)
	marlow.setup("marlow", w, spots["skipper"], spots["facing"])
	w.reserve(Vector2i(floori(spots["skipper"].x), floori(spots["skipper"].z)))
	Game.npcs.append(marlow)
	marlow.tree_exiting.connect(func(): Game.npcs.erase(marlow))
	return marlow


## Daisy and Morris stand either side of their shop door.
func _place_tailors() -> void:
	var shop := world.building("tailor_shop")
	if shop.is_empty():
		return
	var at := world.outside_door(shop)
	var side := Vector3(at["facing"].z, 0, -at["facing"].x)
	for pair: Array in [["daisy", -0.7], ["morris", 0.7]]:
		var npc := Story.npc(pair[0])
		if npc == null:
			npc = Npc.new()
			world.add_child(npc)
			npc.setup(pair[0], world, at["position"], at["facing"])
			Game.npcs.append(npc)
		npc.position = at["position"] + side * float(pair[1])
		npc.position.y = world.ground_height(npc.position.x, npc.position.z)
		npc.rest_facing = at["facing"]
		world.reserve(Vector2i(floori(npc.position.x), floori(npc.position.z)))


## Lucy stands in front of her shop once it's built.
func _place_lucy() -> void:
	var lucy := Story.npc("lucy")
	var shop := world.shop()
	if lucy == null or shop.is_empty():
		return
	var spot := world.outside_door(shop)
	lucy.position = spot["position"]
	lucy.rest_facing = spot["facing"]
	world.reserve(Vector2i(floori(spot["position"].x), floori(spot["position"].z)))


## Fades out, moves the clock on, and wakes up again.
func _sleep(hour: float) -> void:
	Game.mode = Game.Mode.MENU
	await hud.fade_out()
	var hours := GameClock.sleep_until(hour)
	Journal.add("slept")
	await get_tree().create_timer(0.6).timeout
	player.get_up()
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
	var resident: String = home.get("resident", "")
	var museum: bool = def.get("museum", false)
	if resident != "" and Npc.out_at(GameClock.hour_float()):
		Events.toast.emit("Nobody's home. %s is out and about until six." % NpcData.display_name(resident))
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
	room.visitor = resident != "" or museum
	room.setup(IslandData.room(size[0], size[1]), {} if museum else _rooms.get(str(uid), {}))
	if museum:
		fill_museum(room)
	elif first_visit and resident != "":
		_furnish_for(room, resident)
	elif first_visit:
		# Every new home comes with somewhere to sleep, against the back wall.
		room.place_item("sleeping_bag", Rect2i(0, 0, 1, 2), 0)
	if resident != "":
		# They're home: standing by their table.
		var host := Npc.new()
		room.add_child(host)
		# The free floor tile nearest the middle of the room, off the path to the door.
		var spot := Vector3(size[0] * 0.5, 0, size[1] * 0.5)
		var best := INF
		var door := room.data.room_door()
		for z in size[1]:
			for x in size[0]:
				var c := Vector3(x + 0.5, 0, z + 0.5)
				if x != door.x and room.object_at(x, z).is_empty() and room.rug_at(x, z).is_empty() \
						and room.is_walkable(c.x, c.z) and c.distance_to(Vector3(size[0] * 0.6, 0, size[1] * 0.45)) < best:
					best = c.distance_to(Vector3(size[0] * 0.6, 0, size[1] * 0.45))
					spot = c
		host.setup(resident, room, spot, Vector3(-0.5, 0, 1).normalized())
		room.reserve(Vector2i(floori(spot.x), floori(spot.z)))
		Game.npcs.append(host)
		room.tree_exiting.connect(func(): Game.npcs.erase(host))
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
	if not ItemDB.placeable(world.get_object(_home_uid).get("item", "")).get("museum", false):
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


# --- Island tours --------------------------------------------------------------------

## Sails to a new little island: generated fresh each trip, never saved.
func _start_tour() -> void:
	if tour != null or room != null:
		return
	Game.mode = Game.Mode.MENU
	await hud.fade_out()
	var trips := int(Story.flags.get("tours", 0)) + 1
	Story.flags["tours"] = trips
	# Now and then Marlow finds somewhere special.
	var luck := RandomNumberGenerator.new()
	luck.seed = hash([_seed, GameClock.day_key(), trips, "kind"])
	var kind: String = Game.args.get("island", TourKinds.pick(trips, luck.randf(), luck.randf()))
	var dock := {}
	for attempt in 6:
		var data := IslandGenerator.generate_tour(absi(hash([_seed, GameClock.day_key(), trips, attempt])) % 1000000,
			world.data.native_fruit, world.data.native_flower, kind)
		tour = World.new()
		tour.name = "Tour"
		tour.tour = true
		add_child(tour)
		tour.setup(data)
		dock = tour.add_dock(Vector2i(data.width / 2, data.height / 2))
		if not dock.is_empty():
			break
		tour.free()
		tour = null
	if tour == null:
		Events.toast.emit("Marlow couldn't find anywhere to land today. Sorry!")
		Game.mode = Game.Mode.PLAY
		await hud.fade_in()
		return
	_place_marlow(tour)
	_add_camper(tour)
	Game.tour = tour
	_switch_world(tour)
	var spots := tour.dock_spots(dock)
	player.position = spots["arrive"]
	player.facing = spots["facing"]
	camera_rig.island_size = Vector2(tour.data.width, tour.data.height)
	camera_rig.snap()
	Events.placed_changed.emit()
	Game.mode = Game.Mode.PLAY
	await hud.fade_in()
	Events.toast.emit(TourKinds.get_kind(kind).get("arrive", TourKinds.get_kind("plain")["arrive"]))


## Someone's camping on each tour island who'd like a new home: one of the neighbours
## who doesn't live on your island and isn't already on their way.
func _add_camper(t: World) -> Npc:
	var here: Array = Story.invited().duplicate()
	for obj in world.objects():
		if obj.has("resident"):
			here.append(obj["resident"])
	var free: Array = NpcData.neighbours().keys().filter(func(id): return not id in here)
	if free.is_empty():
		return null
	free.sort()
	var who: String = free[t.data.seed_value % free.size()]
	# Somewhere open near the middle of the island.
	var centre := Vector2(t.data.width, t.data.height) * 0.5
	var spot := Vector3.ZERO
	var best := INF
	for z in t.data.height:
		for x in t.data.width:
			var c := Vector2(x + 0.5, z + 0.5)
			if t.data.tile(x, z) == IslandData.Tile.GRASS and t.is_walkable(c.x, c.y) and t.object_at(x, z).is_empty() \
					and c.distance_to(centre) < best:
				best = c.distance_to(centre)
				spot = Vector3(c.x, 0, c.y)
	var camper := Npc.new()
	t.add_child(camper)
	camper.setup(who, t, spot, Vector3(0, 0, 1))
	camper.wanders = true
	camper.always_out = true
	camper.home = camper.position
	Game.npcs.append(camper)
	camper.tree_exiting.connect(func(): Game.npcs.erase(camper))
	return camper


## Sails home to the dock, leaving the tour island behind.
func _end_tour() -> void:
	if tour == null:
		return
	Game.mode = Game.Mode.MENU
	await hud.fade_out()
	Game.tour = null
	tour.queue_free()
	tour = null
	_switch_world(world)
	_check_house()
	var spots := world.dock_spots(world.building("dock"))
	player.position = spots["arrive"]
	player.facing = spots["facing"]
	camera_rig.island_size = Vector2(world.data.width, world.data.height)
	camera_rig.snap()
	Events.placed_changed.emit()
	Game.mode = Game.Mode.PLAY
	await hud.fade_in()
	save_game()


## Points the player, placement and UI at the island or a room, and swaps the
## outdoor-only bits (curvature, wind, sky) on or off.
func _switch_world(to: World) -> void:
	var outside := not to.interior
	world.visible = to == world
	world.process_mode = Node.PROCESS_MODE_INHERIT if to == world else Node.PROCESS_MODE_DISABLED
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
	if Game.args["demo"] == "visitor":
		var who: String = Game.args.get("who", "kiwi")
		Story.flags["met"] = {who: GameClock.day_key() - 1}
		Story.force_visitor = who
		_check_visitor()
		var visitor := Story.npc(who)
		if visitor:
			visitor.wanders = false
			player.position = visitor.position + Vector3(1.3, 0, 0.6)
			player.facing = Vector3(-1, 0, -0.4).normalized()
			camera_rig.snap()
		return
	if Game.args["demo"] == "neighbours":
		# Two plots staked out yesterday, so two neighbours have just moved in.
		var placed := 0
		for r in range(3, 16):
			for dx: int in [-6, 4]:
				var rect := Rect2i(spawn + Vector2i(dx, r), Vector2i(3, 3))
				if placed < 2 and world.can_place(rect, player.position) and world.door_clear("plot_kit", rect, 0):
					var plot := world.place_item("plot_kit", rect, 0)
					plot["plot_day"] = world.day_key - 1
					# --who=id,id picks who moves in.
					var who: PackedStringArray = Game.args.get("who", "").split(",", false)
					if placed < who.size():
						plot["item"] = "neighbour_house"
						plot["resident"] = who[placed]
						plot.erase("plot_day")
						world.refresh_node(plot)
						_spawn_neighbour(plot)
					placed += 1
		_check_house()
		var homes := world.objects().filter(func(o): return o.has("resident"))
		if not homes.is_empty():
			var at := world.outside_door(homes[0])
			player.position = at["position"] + Vector3(0.6, 0, 1.8)
			player.facing = Vector3(0, 0, -1)
			camera_rig.snap()
			if Game.args.has("visit"):
				await _enter_home(homes[0]["uid"], true)
		return
	if Game.args["demo"] == "museum":
		# As if Bramble arrived last night with the first specimens.
		Story.flags["museum_gifts"] = ["sea_bass", "koi", "white_butterfly", "ladybug", "cicada"]
		Story.flags["museum_day"] = GameClock.day_key() - 1
		_check_house()
		if Game.args.has("built"):
			# --built: the real museum, with half the collection donated.
			var all: Array = ItemDB.fish.keys() + ItemDB.bugs.keys()
			for i in all.size():
				if i % 2 == 0:
					Journal.donate(all[i])
			Story.flags["museum_build_day"] = GameClock.day_key() - 1
			_check_house()
		var museum := world.building("museum" if Game.args.has("built") else "museum_tent")
		if not museum.is_empty():
			player.position = world.outside_door(museum)["position"] + Vector3(-1.2, 0, 2.0)
			player.facing = Vector3(0.3, 0, -1).normalized()
			camera_rig.snap()
			if Game.args.has("visit"):
				await _enter_home(museum["uid"], true)
		return
	if Game.args["demo"] == "shop":
		# As if Lucy built her shop last night: stand in front of it.
		Story.flags["shop_day"] = GameClock.day_key() - 1
		_check_house()
		var shop := world.shop()
		if not shop.is_empty():
			player.position = world.outside_door(shop)["position"] + Vector3(1.4, 0, 2.2)
			player.facing = Vector3(-0.3, 0, -1).normalized()
			camera_rig.snap()
		return
	if Game.args["demo"] in ["dock", "tour"]:
		# Marlow's dock (tied up yesterday), or straight off on a tour (--camper: stand by the camper).
		Story.flags["intro_done"] = true
		Story.flags["dock_from"] = GameClock.day_key() - 1
		_check_house()
		var dock := world.building("dock")
		if dock.is_empty():
			return
		var spots := world.dock_spots(dock)
		player.position = spots["arrive"] - spots["facing"] * 0.2 + Vector3(-spots["facing"].z, 0, spots["facing"].x) * 1.6
		player.facing = -spots["facing"]
		camera_rig.snap()
		if Game.args["demo"] == "tour":
			await _start_tour()
			if Game.args.has("camper"):
				for n in Game.npcs:
					if n.world == tour and n.id != "marlow":
						player.position = n.position + Vector3(0.8, 0, 1.6)
						player.facing = Vector3(-0.4, 0, -1).normalized()
						camera_rig.snap()
		return
	if Game.args["demo"] == "orchard":
		# Fruit planted over the last few days, one tree at each stage of growing.
		var fruit: String = IslandGenerator.FRUITS.filter(func(f): return f != world.data.native_fruit)[0]
		var row := 0
		for z in range(spawn.y + 4, world.data.height):
			for x in range(spawn.x - 8, spawn.x + 8):
				var ok := true
				for i in World.GROW_DAYS + 1:
					ok = ok and world.can_plant_tree(Vector2i(x + i * 2, z))
				if ok and row == 0:
					for i in World.GROW_DAYS + 1:
						var tree := world.plant_fruit(fruit, Vector2i(x + i * 2, z))
						tree["planted"] = world.day_key - i
						if i == World.GROW_DAYS:
							tree.erase("planted")
							tree["fruit_count"] = 3
						world.refresh_node(tree)
					player.position = Vector3(x + World.GROW_DAYS + 0.5, 0, z + 3.5)
					player.facing = Vector3(0, 0, -1)
					camera_rig.snap()
					row = 1
		return
	if Game.args["demo"] == "site":
		# Lucy's shop kit staked out by the plaza, to be built tonight.
		var site := world.add_building("lucy_shop")
		if not site.is_empty():
			site["item"] = "shop_kit"
			site["plot_day"] = world.day_key
			site.erase("fixed")
			world.refresh_node(site)
			player.position = world.outside_door(site)["position"] + Vector3(1.4, 0, 2.2)
			player.facing = Vector3(-0.3, 0, -1).normalized()
			camera_rig.snap()
		return
	if Game.args["demo"] == "tailors":
		# Lucy's shop and, the night after her news, Daisy and Morris's.
		Story.flags["shop_day"] = GameClock.day_key() - 1
		_check_house()
		Story.flags["shop_thanks"] = true
		Story.flags["tailors_day"] = GameClock.day_key() - 1
		_check_house()
		var tailors := world.building("tailor_shop")
		if not tailors.is_empty():
			player.position = world.outside_door(tailors)["position"] + Vector3(0.6, 0, 2.4)
			player.facing = Vector3(-0.2, 0, -1).normalized()
			camera_rig.snap()
		return
	if Game.args["demo"] in ["fishing", "bugs"]:
		var tool := "flimsy_rod" if Game.args["demo"] == "fishing" else "flimsy_net"
		Inventory.add_item(tool)
		Inventory.equip(Inventory.slots.find_custom(func(s): return s.get("id", "") == tool))
		if Game.args["demo"] == "fishing":
			# The nearest sand by the sea, facing out over the water, with a bite coming.
			var best := Vector2i(-1, -1)
			for z in world.data.height:
				for x in world.data.width:
					if world.data.tile(x, z) == IslandData.Tile.SAND and world.critters.water_kind(x, z + 2) == "sea" \
							and world.data.tile(x, z + 1) != IslandData.Tile.GRASS and world.object_at(x, z).is_empty():
						if best.x < 0 or Vector2(x, z).distance_to(Vector2(spawn)) < Vector2(best).distance_to(Vector2(spawn)):
							best = Vector2i(x, z)
			player.position = Vector3(best.x + 0.5, world.ground_height(best.x + 0.5, best.y + 0.5), best.y + 0.5)
			player.facing = Vector3(0, 0, 1)
			camera_rig.snap()
			await get_tree().process_frame
			player._cast()
			await get_tree().create_timer(0.5).timeout
			var at: Vector3 = world.critters.bobber.position
			world.critters.add_fish("sea_bass", at + Vector3(0.9, 0.03, 0.5))
			world.critters.add_fish("horse_mackerel", at + Vector3(-1.6, 0.03, 1.2))
		else:
			player.facing = Vector3(0, 0, 1)
			var p := player.position
			world.critters.add_bug("white_butterfly", p + Vector3(-1.2, 0.9, 1.4), "air")
			world.critters.add_bug("red_dragonfly", p + Vector3(1.5, 1.0, 1.0), "air")
			world.critters.add_bug("ladybug", p + Vector3(0.6, 0.05, 1.8), "grass")
			world.critters.add_bug("grasshopper", p + Vector3(-0.5, 0.05, 2.4), "grass")
			world.critters.add_bug("honeybee", p + Vector3(0.2, 0.7, 2.6), "air")
		return
	if Game.args["demo"] == "flowers":
		# Stand by the nearest flowers, pick one for your hair and leave it picked.
		var flowers := world.objects().filter(func(o): return o["kind"] == "flower")
		flowers.sort_custom(func(a, b): return Vector2(a["x"], a["z"]).distance_to(Vector2(spawn)) < Vector2(b["x"], b["z"]).distance_to(Vector2(spawn)))
		if not flowers.is_empty():
			var f: Dictionary = flowers[0]
			world.pick_up(f["x"], f["z"])
			var look: Dictionary = player.model.look.duplicate()
			look["hair_flower"] = "%s_%s" % [f["species"], f["color"]]
			player.model.set_look(look)
			player.position = Vector3(f["x"] + 1.5, 0, f["z"] + 1.6)
			player.position.y = world.ground_height(player.position.x, player.position.z)
			player.facing = Vector3(-0.3, 0, 1).normalized()
			camera_rig.snap()
		return
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
	if Game.args.has("series"):
		decor.clear()
		for entry: Array in _series_layout(Game.args["series"], Game.args.get("variant", "")):
			if not ItemDB.placeable(entry[0]).get("rug", false):
				decor.append(entry[0])
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


## The museum's hall: a fish tank for every fish round the walls and a glass case for
## every bug down the middle, each empty until that creature is donated.
static func fill_museum(r: World) -> void:
	var w := r.data.width
	var d := r.data.height - 1
	var door := r.data.room_door()
	var walls: Array[Vector2i] = []
	for x in w:
		walls.append(Vector2i(x, 0))
	for z in range(1, d - 1):
		walls.append(Vector2i(0, z))
		walls.append(Vector2i(w - 1, z))
	var middle: Array[Vector2i] = []
	for z in range(2, d - 1, 2):
		for x in range(2, w - 2):
			if absi(x - door.x) > 0:
				middle.append(Vector2i(x, z))
	var fish: Array = ItemDB.fish.keys()
	var bugs: Array = ItemDB.bugs.keys()
	for i in mini(fish.size(), walls.size()):
		var t: Vector2i = walls[i]
		var rot := 0 if t.y == 0 else (1 if t.x == 0 else 3)
		var obj := r.place_item("exhibit_tank", Rect2i(t, Vector2i.ONE), rot)
		obj["exhibit"] = fish[i] if fish[i] in Journal.donated else ""
		r.refresh_node(obj)
	for i in mini(bugs.size(), middle.size()):
		var obj := r.place_item("exhibit_case", Rect2i(middle[i], Vector2i.ONE), 0)
		obj["exhibit"] = bugs[i] if bugs[i] in Journal.donated else ""
		r.refresh_node(obj)


## A neighbour's room the first time anyone visits: their wallpaper and flooring and a
## room's worth of their favourite series.
func _furnish_for(r: World, who: String) -> void:
	var inside: Dictionary = NpcData.get_character(who).get("inside", {})
	for part in ["wall", "floor"]:
		if inside.has(part):
			r.set_room_look(inside[part])
	for entry in _series_layout(inside.get("series", "meadow"), inside.get("variant", "")):
		var size: Array = ItemDB.placeable(entry[0])["footprint"]
		var dims := Vector2i(size[0], size[1]) if entry[2] % 2 == 0 else Vector2i(size[1], size[0])
		var rect := Rect2i(entry[1], dims)
		var fits := r.can_place_rug(rect) if ItemDB.placeable(entry[0]).get("rug", false) else r.can_place(rect, Vector3(-10, 0, -10))
		if fits:
			r.place_item(entry[0], rect, entry[2])


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
			["side_table", Vector2i(5, 2), 0], ["dresser", Vector2i(1, 5), 0], ["crate", Vector2i(5, 0), 0],
			["fridge", Vector2i(0, 0), 0], ["counter", Vector2i(1, 0), 0], ["stove", Vector2i(2, 0), 0], ["sink", Vector2i(3, 0), 0],
			["oven", Vector2i(4, 0), 0], ["cupboard", Vector2i(5, 0), 0], ["round_table", Vector2i(2, 3), 0], ["tree", Vector2i(4, 0), 0]]:
		if by_kind.has(entry[0]):
			var at: Vector2i = entry[1]
			# Seats go in front of the table, however deep it is.
			if entry[0] in ["chair", "stool"] and by_kind.has("table"):
				at.y = 2 + int(ItemDB.placeable(by_kind["table"])["footprint"][1])
			out.append([by_kind[entry[0]], at, entry[2]])
	return out
