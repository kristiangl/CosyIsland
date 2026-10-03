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
	_test_shop_and_house()
	_test_clothes()
	_test_furniture_series()
	_test_customising()
	_test_rugs_and_curtains()
	_test_flowers()
	_test_journal()
	_test_lucy_shop()
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


func _test_shop_and_house() -> void:
	Inventory.reset()
	Story.reset()
	var today := Shop.stock(42, 100)
	check(today == Shop.stock(42, 100), "the shop's stock is the same all day")
	check(today != Shop.stock(42, 101), "and changes the next day")
	check(today.size() == Shop.STAPLES.size() + Shop.FURNITURE_PER_DAY + Shop.INTERIORS_PER_DAY + Shop.CLOTHES_PER_DAY, "the shop has a full stock")
	check(today.any(func(id): return ItemDB.is_clothing(id)), "the shop sells clothes")
	var thing: String = today[Shop.STAPLES.size()]
	check(Shop.buy(thing, 100) != "", "can't buy without acorns")
	Inventory.add_currency(Shop.buy_price(thing) * 2)
	check(Shop.buy(thing, 100) == "" and Inventory.count_of(thing) == 1, "buying puts it in the pockets")
	check(Inventory.currency == Shop.buy_price(thing), "and takes the acorns")
	check(Shop.is_sold_out(thing, 100) and Shop.buy(thing, 100) != "", "one of each a day")
	check(not Shop.is_sold_out(thing, 101), "new stock tomorrow")
	check(Shop.buy("flimsy_axe", 100) == "" and not Shop.is_sold_out("flimsy_axe", 100), "staples never sell out")
	Inventory.add_item("wood", 5)
	var before := Inventory.currency
	var slot := Inventory.slots.find_custom(func(sl): return sl.get("id", "") == "wood")
	check(Shop.sell(slot, 2) == 2 * Shop.sell_price("wood") and Inventory.count_of("wood") == 3, "selling some of a stack")
	check(Shop.sell(slot, 99) == 3 * Shop.sell_price("wood") and Inventory.count_of("wood") == 0, "selling the rest")
	check(Inventory.currency == before + 5 * Shop.sell_price("wood"), "selling pays")
	check(not Shop.can_sell("tent_kit"), "some things can't be sold")

	var d := IslandGenerator.generate(42)
	var w := World.new()
	add_child(w)
	w.setup(d)
	Game.island = w
	var tent := w.place_item("tent_kit", Rect2i(_find_tent_spot(w, d), Vector2i(3, 3)), 0)
	check(not Story.can_offer_house(), "no house offer before Poppy's seen the tent")
	Story.flags["tent_gift"] = true
	check(Story.can_offer_house(), "Poppy offers a house once the tent is up")
	Story.flags["house_day"] = GameClock.day_key()
	check(not Story.finish_house(w) and tent["item"] == "tent_kit", "the house isn't ready the same day")
	Story.flags["house_day"] = GameClock.day_key() - 1
	check(Story.finish_house(w) and tent["item"] == "house", "the tent becomes a house overnight")
	check(not Story.can_offer_house() and not Story.finish_house(w), "and only once")
	check(not w.door_of(tent).is_empty() and ItemDB.placeable("house")["room"]["size"][0] > 6, "the house has a door and a bigger room")
	w.free()
	Game.island = null
	Story.reset()
	Inventory.reset()


func _test_clothes() -> void:
	Inventory.reset()
	var clothes: Array = ItemDB.items.keys().filter(func(id): return ItemDB.is_clothing(id))
	check(clothes.size() >= 60, "there are plenty of clothes (%d)" % clothes.size())
	for id: String in clothes:
		var wear: Dictionary = ItemDB.get_item(id)["wear"]
		var look := Appearance.sanitise(wear)
		var ok := true
		for k in wear:
			ok = ok and look[k] == wear[k]
		check(ok, "%s uses real styles and colours" % id)
		check(Models.get_mesh("clothing:" + id).get_surface_count() > 0, "%s has a model" % id)
	check(not Appearance.random(RandomNumberGenerator.new()).values().any(func(v): return v is String and Appearance.options("top").any(func(o): return o["id"] == v and o.get("designed", false))), "random looks don't use designed clothes")
	Inventory.add_item("raincoat_yellow")
	var slot := Inventory.slots.find_custom(func(sl): return sl.get("id", "") == "raincoat_yellow")
	var worn := Inventory.wear_from_slot(slot, Appearance.DEFAULT.duplicate())
	check(worn["top"] == "raincoat" and worn["top_color"] == "yellow", "wearing a raincoat changes your top")
	check(Inventory.count_of("raincoat_yellow") == 0 and "raincoat_yellow" in Inventory.closet, "it moves from the pockets to the wardrobe")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(Inventory.to_save()))
	Inventory.reset()
	Inventory.from_save(saved)
	check("raincoat_yellow" in Inventory.closet, "the wardrobe is saved")
	var creator := CharacterCreator.new()
	add_child(creator)
	creator.open(worn, false)
	creator._select_tab(7)
	check(creator._content.find_children("*", "", true, false).any(func(n): return n is Label and n.text == "Your clothes"), "the wardrobe lists your clothes")
	creator.free()
	Game.mode = Game.Mode.PLAY
	Inventory.reset()


func _test_furniture_series() -> void:
	check(ItemDB.series.size() >= 6, "there are furniture series (%d)" % ItemDB.series.size())
	var pieces: Array = ItemDB.items.keys().filter(func(id): return ItemDB.get_item(id).has("series"))
	check(pieces.size() >= 100, "series pieces come in variants (%d items)" % pieces.size())
	for id: String in pieces:
		var def := ItemDB.get_item(id)
		var mesh := Models.get_mesh(def["placeable"]["model"] if def.has("placeable") else "series:" + id)
		var tris := 0
		for s in mesh.get_surface_count():
			tris += mesh.surface_get_array_index_len(s) / 3
		check(tris > 0 and tris < 1500, "%s has a model within budget (%d triangles)" % [id, tris])
		if def["build"]["kind"] in ["rug", "curtains", "sofa", "bed", "armchair"]:
			check(mesh.has_meta("fabric"), "%s knows its fabric" % id)
	check(ItemDB.placeable("meadow_chair_sage").get("seat", 0.0) > 0.0, "series chairs can be sat on")
	check(ItemDB.placeable("lodge_table_walnut").get("surface", 0.0) > 0.0, "series tables hold things")
	check(ItemDB.placeable("driftwood_bed_grey").get("bed", false), "series beds can be slept in")
	check(ItemDB.display_name("meadow_sofa_rose") == "Meadow Sofa (Rose)", "series pieces are named with their variant")
	var mi := MeshInstance3D.new()
	mi.mesh = Models.get_mesh("series:meadow_sofa_sage")
	Models.dress(mi, Models.material())
	var fabric := mi.get_surface_override_material(1) as ShaderMaterial
	check(mi.material_override == null and fabric != null and fabric.get_shader_parameter("pattern") == Appearance.options("top_pattern").map(func(o): return o["id"]).find("gingham"), "sofa cushions are gingham")
	mi.mesh = Models.get_mesh("furniture:wooden_chair")
	Models.dress(mi, Models.material())
	check(mi.material_override == Models.material(), "plain models keep the one material")
	mi.free()
	check(Recipes.recipes.has("meadow_chair_cream") and not Recipes.is_known("meadow_chair_cream"), "series recipes can be learned")
	Inventory.reset()
	Inventory.add_item("wood", 5)
	check(Recipes.craft("meadow_chair_cream") and Inventory.count_of("meadow_chair_cream") == 1, "crafting a series chair works")
	Inventory.reset()
	var sold := false
	for day in 20:
		sold = sold or Shop.stock(7, day).any(func(id): return ItemDB.get_item(id).has("series"))
	check(sold, "Lucy sells series furniture")
	check(ItemDB.get_item("curtains_cherry").get("category", "") == "interior", "curtains are put up like wallpaper")
	for id: String in ["toadstool_lamp_coral", "starlight_bed_midnight", "star_chair_dusk", "glowcap_cluster_teal"]:
		var glowing := Models.get_mesh("series:" + id)
		check(glowing.has_meta("glow_surface"), "%s has parts that glow" % id)
		var shown := MeshInstance3D.new()
		shown.mesh = glowing
		Models.dress(shown, Models.material())
		check(shown.get_surface_override_material(glowing.get_meta("glow_surface")) == Models.glow_material(), "%s glows in the world" % id)
		shown.free()
	check(DayNight.glow_at(12.0) == 0.0 and DayNight.glow_at(23.0) == 1.0 and DayNight.glow_at(3.0) == 1.0, "things glow at night, not by day")


func _test_rugs_and_curtains() -> void:
	var w := World.new()
	w.interior = true
	add_child(w)
	w.setup(IslandData.room(8, 7))
	check(w.can_place_rug(Rect2i(1, 1, 3, 2)), "a rug fits on the floor")
	var rug := w.place_item("large_rug_cherry", Rect2i(1, 1, 3, 2), 0)
	check(w.rug_at(2, 2) == rug and w.object_at(2, 2).is_empty(), "rugs lie on the floor layer")
	check(w.is_walkable(2.5, 2.5), "you can walk on rugs")
	check(not w.can_place_rug(Rect2i(2, 1, 2, 2)), "rugs don't overlap")
	check(w.can_place(Rect2i(1, 1, 2, 1), Vector3(6.5, 0, 6.5)), "furniture can stand on a rug")
	var table := w.place_item("lodge_table_honey", Rect2i(1, 1, 2, 1), 0)
	check(w.object_at(1, 1) == table and w.rug_at(1, 1) == rug, "the table stands on the rug")
	check(w.can_place_rug(Rect2i(4, 3, 2, 2)), "a rug can go under furniture that's already there")
	Inventory.reset()
	check(w.pack_up(rug) and Inventory.count_of("large_rug_cherry") == 1, "rugs pack up")
	check(not w.get_object(table["uid"]).is_empty(), "and the table stays put")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(w.to_save()))
	check(w.set_room_look("curtains_cherry") == "", "curtains go up")
	check(w.get_node("Room").get_node_or_null("Curtains") != null, "the windows get curtains")
	check(w.set_room_look("curtains_starry") == "curtains_cherry", "new curtains replace the old ones")
	w.free()
	var w2 := World.new()
	w2.interior = true
	add_child(w2)
	saved["look"] = {"window": "curtains_fern"}
	w2.setup(IslandData.room(8, 7), saved)
	check(w2.get_node("Room").get_node_or_null("Curtains") != null, "curtains are saved with the room")
	w2.free()
	Inventory.reset()


func _test_customising() -> void:
	Inventory.reset()
	check(ItemDB.variants_of("meadow_chair_cream").size() == 4, "a series piece has its four colourways")
	check("raincoat_red" in ItemDB.variants_of("raincoat_yellow"), "clothes have colourways too")
	check(ItemDB.variants_of("wooden_chair").size() == 5 and "wooden_chair_walnut" in ItemDB.variants_of("wooden_chair"), "the original wooden furniture comes painted too")
	check(ItemDB.variants_of("stone_lantern").is_empty(), "one-off furniture has none")
	check(Models.get_mesh("furniture:wooden_chair:walnut") != Models.get_mesh("furniture:wooden_chair"), "painted pieces have their own model")
	check(ItemDB.variant_name("lodge_sofa_walnut") == "Walnut", "variant names come from the item name")
	Inventory.add_item("meadow_chair_cream")
	var slot := Inventory.slots.find_custom(func(sl): return sl.get("id", "") == "meadow_chair_cream")
	check(Recipes.customise(slot, "meadow_chair_sage") != "", "customising needs a kit")
	Inventory.add_item(Recipes.KIT, 2)
	check(Recipes.customise(slot, "lodge_chair_honey") != "", "it can't become a different piece")
	check(Recipes.customise(slot, "meadow_chair_sage") == "", "customising with a kit works")
	check(Inventory.slots[slot].get("id", "") == "meadow_chair_sage" and Inventory.count_of(Recipes.KIT) == 1, "the piece changes in place and uses one kit")
	check(Recipes.KIT in Shop.stock(1, 1), "Lucy always sells kits")
	var menu := CraftingMenu.new()
	add_child(menu)
	menu.open("customise")
	check(menu._rows.size() == 1 and menu._rows[0].item_id == "meadow_chair_sage", "the workbench lists things that can be customised")
	menu.cycle(menu._rows[0], 1)
	check(menu._rows[0].choice == "meadow_chair_butter", "left and right look through the colourways")
	menu._set_mode("make")
	check(not menu.is_customising(), "the tabs switch back to making")
	menu.close()
	menu.free()
	Inventory.reset()


func _test_flowers() -> void:
	Inventory.reset()
	var d := IslandGenerator.generate(7)
	var w := World.new()
	add_child(w)
	w.setup(d)
	var flower: Dictionary = w.objects().filter(func(o): return o["kind"] == "flower")[0]
	var id := "%s_%s" % [flower["species"], flower["color"]]
	check(w.pick_up(flower["x"], flower["z"]) and Inventory.count_of(id) == 1, "picking a flower gives a bloom")
	check(w.object_at(flower["x"], flower["z"]) == flower and flower.get("picked", false), "and leaves the plant behind")
	check(not w.pick_up(flower["x"], flower["z"]), "a picked plant has nothing more to pick")
	w._on_day_changed(w.day_key + 1)
	check(not flower.get("picked", false), "it blooms again the next day")
	check(w.dig_up(flower) and Inventory.count_of(id + "_plant") == 1, "a shovel digs up the whole plant")
	check(w.object_at(flower["x"], flower["z"]).is_empty(), "leaving the ground clear")
	var spot := Vector2i(flower["x"], flower["z"])
	check(w.can_plant(spot), "it can be planted again")
	var planted := w.plant_flower(id + "_plant", spot)
	check(planted["species"] == flower["species"] and w.object_at(spot.x, spot.y) == planted, "planting puts the flower back in the ground")
	for key: String in ["flower:%s:%s:picked" % [flower["species"], flower["color"]], "vase:" + id, "hairflower:" + id, "drop:" + id + "_plant"]:
		check(Models.get_mesh(key).get_surface_count() > 0, "%s has a model" % key)
	check(ItemDB.placeable(id).get("small", false), "picked flowers stand in a vase on tables")
	var look := Appearance.sanitise({"hair_flower": id})
	check(look["hair_flower"] == id, "a flower can be worn in your hair")
	check(Appearance.sanitise({"hair_flower": "wood"})["hair_flower"] == "", "but not just anything")
	var model := CharacterModel.new(look)
	add_child(model)
	check(model.find_children("*", "MeshInstance3D", true, false).any(func(m): return m.mesh == Models.get_mesh("hairflower:" + id)), "the hair flower shows on the character")
	model.free()
	w.free()
	var room := World.new()
	room.interior = true
	add_child(room)
	room.setup(IslandData.room(6, 6))
	check(not room.can_plant(Vector2i(2, 2)), "flowers aren't planted indoors")
	room.free()
	Inventory.reset()


func _test_journal() -> void:
	Journal.reset()
	Inventory.reset()
	Recipes.reset()
	Journal.add("wood", 9)
	check(Journal.tiers.get("woodcutter", 0) == 0, "no milestone before its goal")
	Journal.add("wood")
	check(Journal.stamps >= 100 and Journal.tiers.get("woodcutter", 0) == 1, "ten wood earns the first Woodcutter stamps")
	var before := Journal.stamps
	Journal.add("wood", 40)
	check(Journal.tiers["woodcutter"] == 2 and Journal.stamps > before, "the next goal pays too")
	check(Recipes.is_known("stone_axe"), "and teaches the stone axe recipe")
	var tasks := Journal.tasks_today()
	check(tasks.size() == Journal.DAILY_COUNT, "five tasks a day")
	var task: Dictionary = tasks.filter(func(t): return t["stat"] != "wood")[0]
	before = Journal.stamps
	Journal.add(task["stat"], int(task["n"]))
	check(task["id"] in Journal.today_done and Journal.stamps >= before + int(task["stamps"]), "finishing a daily task pays stamps")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(Journal.to_save()))
	var stamps := Journal.stamps
	Journal.from_save(saved)
	check(Journal.stamps == stamps and Journal.tiers["woodcutter"] == 2 and task["id"] in Journal.today_done, "the journal is saved")
	var pockets: Dictionary = Journal.exchange.filter(func(o): return o["id"] == "pockets_30")[0]
	Journal.stamps = 0
	check(Journal.can_buy(pockets) != "", "offers cost stamps")
	Journal.stamps = 5000
	var rng := RandomNumberGenerator.new()
	check(Journal.buy(pockets, rng) != "" and Inventory.slots.size() == 30 and Journal.stamps == 3500, "bigger pockets can be bought")
	check(Journal.can_buy(pockets) != "", "but only once")
	Inventory.add_item("wood", 1)
	var inv: Dictionary = JSON.parse_string(JSON.stringify(Inventory.to_save()))
	Inventory.from_save(inv)
	check(Inventory.slots.size() == 30, "bigger pockets are saved")
	var surprise: Dictionary = Journal.exchange.filter(func(o): return o["id"] == "furniture_box")[0]
	var got := Journal.buy(surprise, rng)
	check(got != "" and Inventory.slots.any(func(sl): return ItemDB.get_item(sl.get("id", "")).get("category", "") == "furniture"), "surprise furniture arrives in the pockets")
	Inventory.add_item("wood", 4)
	before = Journal.stats.get("crafted", 0)
	Recipes.craft("wooden_stool")
	check(Journal.stats.get("crafted", 0) == before + 1, "crafting is counted")
	var menu := JournalMenu.new()
	add_child(menu)
	menu.open("milestones")
	check(menu._rows.size() == Journal.milestones.size(), "the journal lists every milestone")
	menu.close()
	menu.free()
	Journal.reset()
	Inventory.reset()
	Recipes.reset()


func _test_lucy_shop() -> void:
	var saved_flags := Story.flags.duplicate(true)
	Story.flags.clear()
	var small := Shop.stock(7, 3, "tulip")
	check(not small.any(func(id): return ItemDB.get_item(id).get("category", "") == "flower_plant"), "the counter sells no plants")
	var d := IslandGenerator.generate(7)
	var w := World.new()
	add_child(w)
	w.setup(d)
	Story.flags["shop_day"] = GameClock.day_key() - 1
	check(Story.finish_shop(w), "Lucy builds her shop overnight")
	var shop := w.shop()
	check(not shop.is_empty() and shop.get("fixed", false), "it stands on the island and can't be packed away")
	check(not w.pack_up(shop), "really can't")
	check(not Story.finish_shop(w), "and only once")
	var big := Shop.stock(7, 3, d.native_flower)
	check(big.size() > small.size(), "the shop stocks more than the counter (%d vs %d)" % [big.size(), small.size()])
	var plants := big.filter(func(id): return ItemDB.get_item(id).get("category", "") == "flower_plant")
	check(plants.size() == Shop.PLANTS_PER_DAY and plants.all(func(id): return ItemDB.get_item(id)["species"] != d.native_flower), "and flower plants from other islands")
	check(Story._list_needs({"wood": 3, "stone": 2}) == "3 wood and 2 stone", "Lucy lists what she needs")
	w.free()
	Story.flags = saved_flags
