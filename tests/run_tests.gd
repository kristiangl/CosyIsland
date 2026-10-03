extends Node
## Headless test runner (a scene, so autoloads are available):
##   godot --headless --path . res://tests/test_runner.tscn
## Exits with code 1 if any check fails.

var _failures := 0
var _checks := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_items()
	_test_inventory()
	_test_generation()
	_test_world_rules()
	_test_appearance()
	_test_crafting()
	_test_rooms()
	_test_story()
	_test_phone_and_sleep()
	print("\n%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", what)


func _test_items() -> void:
	for f in IslandGenerator.FRUITS:
		check(ItemDB.has_item(f), "fruit item exists: " + f)
	for f in IslandGenerator.FLOWERS:
		for c in ["red", "white", "yellow"]:
			check(ItemDB.has_item("%s_%s" % [f, c]), "flower item exists: %s_%s" % [f, c])


func _test_inventory() -> void:
	Inventory.reset()
	check(Inventory.add_item("wood", 45) == 0, "45 wood fits")
	check(Inventory.count_of("wood") == 45, "wood counted across stacks")
	check(Inventory.slots[0]["count"] == 30 and Inventory.slots[1]["count"] == 15, "wood stacks at 30")
	Inventory.add_item("flimsy_axe")
	check(Inventory.slots[2]["durability"] == 40, "tools get durability")
	Inventory.cycle_tool(1)
	check(Inventory.equipped_id() == "flimsy_axe", "cycling equips the axe")
	Inventory.reset()


func _test_generation() -> void:
	var a := IslandGenerator.generate(1234)
	var b := IslandGenerator.generate(1234)
	check(a.tiles == b.tiles and a.corners == b.corners and a.objects.size() == b.objects.size(), "generation is deterministic")
	var t0 := Time.get_ticks_msec()
	for s in range(1, 21):
		var d := IslandGenerator.generate(s * 7919)
		var counts := {}
		for o in d.objects:
			counts[o["kind"]] = counts.get(o["kind"], 0) + 1
		check(counts.get("rock", 0) == IslandGenerator.ROCK_COUNT, "seed %d has %d rocks (got %d)" % [s, IslandGenerator.ROCK_COUNT, counts.get("rock", 0)])
		check(counts.get("fruit_tree", 0) == IslandGenerator.FRUIT_TREE_COUNT, "seed %d has fruit trees" % s)
		check(counts.get("tree", 0) >= 60, "seed %d has a decent forest (%d trees)" % [s, counts.get("tree", 0)])
		check(counts.get("flower", 0) >= 10, "seed %d has flowers" % s)
		check(d.tile(d.spawn.x, d.spawn.y) == IslandData.Tile.GRASS, "seed %d spawn is on grass" % s)
		check(counts.get("bridge", 0) >= 1, "seed %d has a river with a bridge" % s)
		check(d.tiles.count(IslandData.Tile.WATER) >= 50, "seed %d has rivers and ponds" % s)
		var reach := _reachable_fraction(d)
		check(reach > 0.9, "seed %d: %.0f%% of land reachable from spawn" % [s, reach * 100.0])
	print("Generated 20 islands in %d ms" % (Time.get_ticks_msec() - t0))
	# Older islands keep their shape, but river water never sits on the beach any more.
	for s in [10, 37]:
		var old := IslandGenerator.generate(s, IslandGenerator.WIDTH, IslandGenerator.HEIGHT, 1)
		var beach_water := 0
		for i in old.tiles.size():
			if old.tiles[i] == IslandData.Tile.WATER and old.tiers[i] == 0:
				beach_water += 1
		check(beach_water == 0, "seed %d (version 1) has no river water on the beach" % s)


## Fraction of walkable land the player can reach from the spawn point on foot.
func _reachable_fraction(d: IslandData) -> float:
	var w := World.new()
	add_child(w)
	w.setup(d)
	var land := 0
	for z in d.height:
		for x in d.width:
			if w.is_walkable(x + 0.5, z + 0.5):
				land += 1
	var seen := {d.idx(d.spawn.x, d.spawn.y): true}
	var stack: Array[Vector2i] = [d.spawn]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		for dir in IslandGenerator.DIRS:
			var n: Vector2i = p + dir
			if seen.has(d.idx(n.x, n.y)) or not d.in_bounds(n.x, n.y) or not w.is_walkable(n.x + 0.5, n.y + 0.5):
				continue
			# Compare heights on either side of the shared edge.
			var edge := Vector2(p) + Vector2(0.5, 0.5) + Vector2(dir) * 0.5
			var ha := w.ground_height(edge.x - dir.x * 0.01, edge.y - dir.y * 0.01)
			var hb := w.ground_height(edge.x + dir.x * 0.01, edge.y + dir.y * 0.01)
			if absf(ha - hb) <= IslandData.MAX_STEP:
				seen[d.idx(n.x, n.y)] = true
				stack.append(n)
	w.free()
	return float(seen.size()) / maxf(land, 1.0)


func _test_world_rules() -> void:
	Inventory.reset()
	var d := IslandGenerator.generate(42)
	var w := World.new()
	add_child(w)
	w.setup(d)
	var tree: Dictionary = w.objects().filter(func(o): return o["kind"] == "tree")[0]
	var here := Vector3(tree["x"] + 0.5, 0, tree["z"] + 1.5)
	for i in 4:
		w.chop(tree, here)
	var wood := w.objects().filter(func(o): return o["kind"] == "drop" and o["item"] == "wood")
	check(wood.size() == 3, "a tree gives 3 wood a day (got %d)" % wood.size())
	check(w.pick_up(wood[0]["x"], wood[0]["z"]), "can pick up wood")
	check(Inventory.count_of("wood") == 1, "wood went into the pockets")

	var gift_trees: Array = w.objects().filter(func(o): return o.has("gift"))
	check(gift_trees.size() == World.GIFT_TREES, "two trees hide furniture each day")
	var shaken: Dictionary = w.objects().filter(func(o): return o["kind"] == "tree" and not o.has("gift"))[0]
	for i in 12:
		w.shake(shaken, Vector3(shaken["x"] + 0.5, 0, shaken["z"] + 1.5))
	check(shaken.get("branches", 0) == World.BRANCHES_PER_TREE, "shaking a tree gives up to two branches a day")
	var gift_id: String = gift_trees[0]["gift"]
	w.shake(gift_trees[0], Vector3(gift_trees[0]["x"] + 0.5, 0, gift_trees[0]["z"] + 1.5))
	check(w.objects().any(func(o): return o["kind"] == "drop" and o["item"] == gift_id), "shaking a gift tree drops furniture")
	var rock: Dictionary = w.objects().filter(func(o): return o["kind"] == "rock")[0]
	var hits := 0
	while w.strike_rock(rock, Vector3(rock["x"] + 0.5, 0, rock["z"] + 1.5)):
		hits += 1
	check(hits == World.ROCK_HITS, "a rock can be hit %d times (got %d)" % [World.ROCK_HITS, hits])

	var spot := _find_tent_spot(w, d)
	check(spot.x >= 0, "found somewhere flat for a tent")
	if spot.x >= 0:
		var rect := Rect2i(spot, Vector2i(3, 3))
		w.place_item("tent_kit", rect, 0)
		check(not w.is_walkable(spot.x + 1.5, spot.y + 1.5), "tent blocks walking")
		check(not w.can_place(rect, Vector3(-10, 0, -10)), "can't place on top of the tent")

	var saved: Dictionary = JSON.parse_string(JSON.stringify(w.to_save()))
	var w2 := World.new()
	add_child(w2)
	w2.setup(IslandGenerator.generate(42), saved)
	check(w2.objects().size() == w.objects().size(), "objects survive a save round trip")
	check(w2.objects().filter(func(o): return o["kind"] == "placed" and o["item"] == "tent_kit").size() == 1, "tent survives a save round trip")
	var started := Time.get_ticks_msec()
	var map := IslandMap.paint(d)
	print("Painted the island map in %d ms" % (Time.get_ticks_msec() - started))
	check(map.get_width() == d.width * IslandMap.PX and map.get_height() == d.height * IslandMap.PX, "the map covers the whole island")
	w.free()
	w2.free()
	Inventory.reset()


func _find_tent_spot(w: World, d: IslandData) -> Vector2i:
	for z in range(d.plaza.end.y + 2, d.height - 3):
		for x in range(d.plaza.position.x - 10, d.plaza.end.x + 10):
			if w.can_place(Rect2i(x, z, 3, 3), Vector3(-10, 0, -10)):
				return Vector2i(x, z)
	return Vector2i(-1, -1)


func _test_appearance() -> void:
	var look := Appearance.sanitise({"hair": "bob", "skin": "nonsense"})
	check(look["hair"] == "bob" and look["skin"] == Appearance.DEFAULT["skin"], "appearance keeps valid values and drops unknown ones")
	Appearance.step(look, "hair", -1)
	check(look["hair"] == "spiky", "stepping an option moves through the catalogue")
	for key in Appearance.SOURCES:
		check(Appearance.options(key).size() > 1, "appearance has options for " + key)
	var tuned := Appearance.sanitise({"eye_size": 99, "mouth_y": "-2", "hat": "cap", "hat_pos": 5})
	check(tuned["eye_size"] == 4 and tuned["mouth_y"] == -2, "face adjustments are kept within range")
	check(tuned["hat_pos"] == Appearance.hat_positions(tuned).size() - 1, "a hat position past the end is pulled back")
	var bow := Appearance.sanitise({"hat": "bow"})
	for i in 10:
		Appearance.adjust(bow, "hat_pos", 1)
	check(bow["hat_pos"] == Appearance.hat_positions(bow).size() - 1, "bows can be worn in each position and no further")
	var creator := CharacterCreator.new()
	add_child(creator)
	creator.open(Appearance.DEFAULT, true)
	for i in CharacterCreator.TABS.size():
		creator._select_tab(i)
	check(creator._content.get_child_count() > 0, "every creator tab builds")
	creator.choose("nose", "button")
	check(creator.look["nose"] == "button" and creator._preview.look["nose"] == "button", "trying on an option updates the preview")
	creator.free()
	Game.mode = Game.Mode.PLAY
	# Every part option should build a mesh without errors.
	for key in ["hair", "top", "bottom", "shoes", "hat", "glasses", "nose"]:
		for opt in Appearance.options(key):
			var test_look := Appearance.DEFAULT.duplicate()
			test_look[key] = opt["id"]
			var model := CharacterModel.new(test_look)
			add_child(model)
			check(model.get_child_count() > 0, "character builds with %s = %s" % [key, opt["id"]])
			model.free()


func _test_crafting() -> void:
	Inventory.reset()
	Recipes.reset()
	for id in Recipes.recipes:
		check(ItemDB.has_item(id), "recipe result is an item: " + id)
		for mat in Recipes.materials(id):
			check(ItemDB.has_item(mat), "recipe material is an item: %s for %s" % [mat, id])
		var def := ItemDB.get_item(id)
		if def.get("category", "") == "furniture":
			check(Models.get_mesh(def["placeable"]["model"]).get_surface_count() > 0, "furniture has a model: " + id)
	check(not Recipes.can_craft("wooden_stool"), "can't craft without materials")
	Inventory.add_item("wood", 5)
	check(Recipes.craft("wooden_stool"), "crafting a stool works")
	check(Inventory.count_of("wood") == 1 and Inventory.count_of("wooden_stool") == 1, "crafting uses materials and gives the item")
	Inventory.add_item("wood", 1)
	check(Recipes.craft("wooden_fence") and Inventory.count_of("wooden_fence") == 4, "fences come in fours")

	var d := IslandGenerator.generate(42)
	var w := World.new()
	add_child(w)
	w.setup(d)
	var bench: Array = w.objects().filter(func(o): return o["kind"] == "placed" and o["item"] == "workbench")
	check(bench.size() == 1, "the plaza has a workbench")
	check(not w.pack_up(bench[0]), "the plaza workbench can't be packed up")
	var bottles: Array = w.objects().filter(func(o): return o["kind"] == "drop" and o["item"] == "message_bottle")
	check(bottles.size() == 1, "a message bottle washes up on a new island")
	var known_before := Recipes.known.size()
	if not bottles.is_empty():
		w.pick_up(bottles[0]["x"], bottles[0]["z"])
	check(Recipes.known.size() == known_before + 1, "message bottles teach a recipe")
	var spot := _find_tent_spot(w, d)
	var stool := w.place_item("wooden_stool", Rect2i(spot, Vector2i.ONE), 1)
	Inventory.remove_item("wooden_stool", 1)
	check(w.pack_up(stool) and Inventory.count_of("wooden_stool") == 1, "furniture packs back into the pockets")

	# Small things go on tables, and the table can't be packed until they're off.
	var table := w.place_item("wooden_table", Rect2i(spot, Vector2i(2, 1)), 0)
	check(w.surface_height(spot.x, spot.y) > 0.5, "a table has a top to put things on")
	check(w.can_place_on_surface(spot), "can put something on an empty table")
	var pot := w.place_on_surface("teapot", spot, 0)
	check(w.surface_item_at(spot.x, spot.y) == pot, "the teapot sits on the table")
	check(not w.can_place_on_surface(spot), "one small thing per table tile")
	check(w.can_place_on_surface(spot + Vector2i(1, 0)), "the other half of the table is still free")
	check(w.object_at(spot.x, spot.y) == table, "the table still owns the tile")
	check(not w.pack_up(table), "can't pack a table with things on it")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(w.to_save()))
	var w2 := World.new()
	add_child(w2)
	w2.setup(IslandGenerator.generate(42), saved)
	check(w2.surface_item_at(spot.x, spot.y).get("item", "") == "teapot", "things on tables survive a save round trip")
	w2.free()
	check(w.pack_up(pot) and Inventory.count_of("teapot") == 1, "things on tables pack up")
	check(w.pack_up(table), "an empty table packs up")

	var bench_seat := w.place_item("log_bench", Rect2i(spot, Vector2i(2, 1)), 0)
	var spots := w.seats(bench_seat)
	check(spots.size() == 2, "a two-tile bench seats two (got %d)" % spots.size())
	if spots.size() == 2:
		check(spots[0]["position"].distance_to(spots[1]["position"]) > 0.9, "bench seats are side by side")
		check(spots[0]["facing"].is_equal_approx(Vector3(0, 0, 1)), "an unrotated bench faces south")
	check(w.seats(w.place_item("wooden_box", Rect2i(spot + Vector2i(0, 2), Vector2i.ONE), 0)).is_empty(), "boxes aren't seats")
	w.free()

	# Islands saved before the DIY update get a workbench added on load.
	var old := IslandGenerator.generate(42)
	var old_objects: Array = old.objects.filter(func(o): return o["kind"] != "placed")
	var w3 := World.new()
	add_child(w3)
	w3.setup(IslandGenerator.generate(42), JSON.parse_string(JSON.stringify({"objects": old_objects, "next_uid": old.next_uid, "day_key": 0})))
	check(w3.objects().filter(func(o): return o["kind"] == "placed" and o["item"] == "workbench").size() == 1, "old saves get a plaza workbench")
	w3.free()

	# Saves from before the office had the workbench where the office now goes.
	var before := IslandGenerator.generate(42)
	var before_objects: Array = before.objects.filter(func(o): return o["item"] != "island_office" if o.has("item") else true)
	for o in before_objects:
		if o.get("item", "") == "workbench":
			o["x"] = before.plaza.position.x + 3
			o["z"] = before.plaza.position.y + 2
	var w4 := World.new()
	add_child(w4)
	w4.setup(IslandGenerator.generate(42), JSON.parse_string(JSON.stringify({"objects": before_objects, "next_uid": before.next_uid, "day_key": 0})))
	var placed := w4.objects().filter(func(o): return o["kind"] == "placed")
	check(placed.filter(func(o): return o["item"] == "island_office").size() == 1, "old saves get the island office")
	check(placed.filter(func(o): return o["item"] == "workbench").size() == 1, "and keep one workbench")
	w4.free()
	Inventory.reset()
	Recipes.reset()


func _test_rooms() -> void:
	Inventory.reset()
	var d := IslandGenerator.generate(42)
	var w := World.new()
	add_child(w)
	w.setup(d)
	var spot := _find_tent_spot(w, d)
	var tent := w.place_item("tent_kit", Rect2i(spot, Vector2i(3, 3)), 0)
	var door := w.door_of(tent)
	check(door.get("tile", Vector2i.ZERO) == spot + Vector2i(1, 2) and door.get("out", Vector2i.ZERO) == Vector2i(0, 1), "the tent door is front and centre")
	var outside := Vector3(spot.x + 1.5, 0, spot.y + 3.3)
	check(w.home_entrance(outside, Vector3(0, 0, -1)) == tent, "walking north into the tent door goes inside")
	check(w.home_entrance(outside, Vector3(0, 0, 1)).is_empty(), "walking away from the door doesn't")
	check(w.home_entrance(Vector3(spot.x - 0.4, 0, spot.y + 1.5), Vector3(1, 0, 0)).is_empty(), "walking into the side of the tent doesn't")
	var out := w.outside_door(tent)
	check(w.is_walkable(out["position"].x, out["position"].z), "you come out onto open ground")
	check(not w.can_place(Rect2i(spot + Vector2i(1, 3), Vector2i.ONE), Vector3(-10, 0, -10)), "nothing can go right in front of a door")
	w.free()

	var r := World.new()
	r.interior = true
	add_child(r)
	r.setup(IslandData.room(6, 6))
	var mat := r.data.room_door()
	check(mat == Vector2i(3, 6), "the doormat is in the middle of the front")
	check(r.is_walkable(mat.x + 0.5, mat.y + 0.5), "you can step onto the doormat")
	check(not r.is_walkable(0.5, 6.5), "the front edge beside the doormat isn't floor")
	check(not r.can_place(Rect2i(3, 5, 1, 1), Vector3(-10, 0, -10)), "the way out stays clear")
	check(r.can_place(Rect2i(0, 0, 2, 2), Vector3(-10, 0, -10)), "furniture fits in a room")
	var bed := r.place_item("simple_bed", Rect2i(0, 0, 2, 2), 0)
	var table := r.place_item("wooden_table", Rect2i(3, 1, 2, 1), 0)
	r.place_on_surface("teapot", Vector2i(3, 1), 0)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(r.to_save()))
	var r2 := World.new()
	r2.interior = true
	add_child(r2)
	r2.setup(IslandData.room(6, 6), saved)
	check(r2.objects().size() == 3, "rooms survive a save round trip")
	check(r2.surface_item_at(3, 1).get("item", "") == "teapot", "things on tables indoors survive a save")
	check(not bed.is_empty() and not table.is_empty(), "furniture placed indoors")
	check(r2.set_room_look("striped_wallpaper") == "" and r2.set_room_look("mint_dot_wallpaper") == "striped_wallpaper", "new wallpaper hands back the old roll")
	r2.set_room_look("wooden_flooring")
	var redone: Dictionary = JSON.parse_string(JSON.stringify(r2.to_save()))
	check(redone.get("look", {}) == {"wall": "mint_dot_wallpaper", "floor": "wooden_flooring"}, "wallpaper and flooring are saved with the room")
	check(r2.get_node_or_null("Room") != null and r2.get_children().filter(func(c): return c.name.begins_with("Room")).size() == 1, "the room is rebuilt, not doubled up")
	r.free()
	r2.free()
	Inventory.reset()


func _test_story() -> void:
	Inventory.reset()
	Story.reset()
	var d := IslandGenerator.generate(42)
	var w := World.new()
	add_child(w)
	w.setup(d)
	Game.island = w
	Game.player_name = "Sam"
	Game.island_name = "Driftwood"
	check(Story.fill("{player} of {island}") == "Sam of Driftwood", "story lines fill in names")
	check(Story.fill("the {fruit}") == "the " + d.native_fruit, "story lines fill in the native fruit")
	var offices := w.objects().filter(func(o): return o["kind"] == "placed" and o["item"] == "island_office")
	check(offices.size() == 1, "the plaza has the island office")
	if offices.size() == 1:
		check(not w.pack_up(offices[0]), "the office can't be packed up")
		var door := w.door_of(offices[0])
		check(not w.can_place(Rect2i(door["tile"] + door["out"], Vector2i.ONE), Vector3(-10, 0, -10)), "the office door stays clear")
	check(not Story._has_home(), "no home before the tent goes up")
	w.place_item("tent_kit", Rect2i(_find_tent_spot(w, d), Vector2i(3, 3)), 0)
	check(Story._has_home(), "the tent counts as a home")
	var first := Story._small_talk("lucy", ["a", "b", "c"])
	check(Story._small_talk("lucy", ["a", "b", "c"]) != first, "small talk moves on each chat")

	for id in ["poppy", "lucy"]:
		var m := NpcData.model(id)
		add_child(m)
		check(m.species.has("kind") and m.find_child("Tail", true, false) != null, "%s builds with fur and a tail" % id)
		m.free()

	var box := DialogueBox.new()
	add_child(box)
	var done := [false]
	box.finished.connect(func(): done[0] = true)
	box.say("poppy", ["One.", "Two."])
	box._opened_at = -1000
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	for i in 3:
		box._unhandled_input(accept)
	check(box.visible and not done[0], "dialogue waits for the last line to be read")
	box._unhandled_input(accept)
	check(done[0] and not box.visible, "dialogue finishes after the last line")
	var picked := [-1]
	box.picked.connect(func(i): picked[0] = i)
	box.ask("poppy", "Yes?", ["Yes", "No"])
	box._text.visible_characters = -1
	box._typing = false
	box._process(0.0)
	check(box._choices.get_child_count() == 2, "questions show their options")
	box._choose(1)
	check(picked[0] == 1, "picking an option reports it")
	box.free()
	w.free()
	Game.island = null
	Story.reset()
	Inventory.reset()


func _test_phone_and_sleep() -> void:
	var saved_offset := GameClock.offset_seconds
	GameClock.set_hour(21.0)
	var hours := GameClock.sleep_until(7.0)
	check(is_equal_approx(roundf(hours), 10.0), "sleeping at 9pm until morning is 10 hours (got %.2f)" % hours)
	check(absf(GameClock.hour_float() - 7.0) < 0.05, "and it's 7am when you wake")
	check(GameClock.sleep_until(7.0) > 23.0, "sleeping until the hour it already is takes a whole day")
	GameClock.offset_seconds = saved_offset

	var phone := IslandPhone.new()
	add_child(phone)
	phone.open()
	check(phone.visible and Game.mode == Game.Mode.MENU, "the phone opens")
	phone._open_app("time")
	check(phone._page == "time", "apps open a page on the phone")
	phone.back()
	check(phone._page == "home" and phone.visible, "back returns to the home screen")
	var chosen := [""]
	phone.app_chosen.connect(func(app): chosen[0] = app)
	phone._open_app("map")
	check(chosen[0] == "map" and not phone.visible and Game.mode == Game.Mode.PLAY, "the map app leaves the phone for the map")
	phone.free()
	check(ItemDB.placeable("sleeping_bag").get("bed", false), "sleeping bags are beds")
