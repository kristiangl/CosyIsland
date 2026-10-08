extends Node
## Headless test runner (a scene, so autoloads are available):
##   godot --headless --path . res://tests/test_runner.tscn
## Exits with code 1 if any check fails.

var _failures := 0
var _checks := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# The real day's weather mustn't decide whether butterflies are about.
	Weather.force = "clear"
	Weather.update(12.0)
	# `-- --only=name` runs just _test_<name>.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			call("_test_" + arg.substr(7))
			print("\n%d checks, %d failures" % [_checks, _failures])
			IslandMap.finish()
			get_tree().quit(1 if _failures > 0 else 0)
			return
	_test_items()
	_test_inventory()
	_test_generation()
	_test_world_rules()
	_test_appearance()
	_test_animation()
	_test_crafting()
	_test_rooms()
	_test_story()
	_test_phone_and_sleep()
	_test_shop_and_house()
	_test_tailors()
	_test_clothes()
	_test_furniture_series()
	_test_customising()
	_test_rugs_and_curtains()
	_test_flowers()
	_test_journal()
	_test_lucy_shop()
	_test_critters()
	_test_museum()
	_test_museum_building()
	_test_neighbours()
	_test_friendship()
	_test_tours()
	_test_rare_islands()
	_test_tour_visitors()
	_test_fruit_planting()
	_test_save_slots()
	_test_music()
	_test_ramps_and_sos()
	_test_built_crossings()
	_test_landscaping()
	_test_paths_and_stairs()
	_test_trees_and_rocks()
	_test_outdoor_decorations()
	_test_storage()
	_test_weather()
	_test_sounds()
	_test_tour_crossings_and_pole()
	print("\n%d checks, %d failures" % [_checks, _failures])
	IslandMap.finish()
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
		check(counts.get("bush", 0) >= 10, "seed %d has bushes by the woods" % s)
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
	var before_bushes := IslandGenerator.generate(10, IslandGenerator.WIDTH, IslandGenerator.HEIGHT, 2)
	check(not before_bushes.objects.any(func(o): return o["kind"] == "bush"), "islands from before bushes don't sprout any")


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
	for i in CharacterCreator.TABS.size():
		if CharacterCreator.TABS[i].has("colours"):
			creator._select_tab(i)
			break
	var tile: CharacterCreator.OptionTile = null
	for t in creator._content.find_children("*", "", true, false):
		if t is CharacterCreator.OptionTile and t.swatch and not t.is_selected():
			tile = t
			break
	var before := creator.look.duplicate()
	tile.grab_focus()
	check(creator.look == before, "moving onto a colour doesn't put it on")
	tile.pressed.emit()
	check(creator.look[tile.key] == tile.id, "pressing it does")
	check(creator.thumb_base[tile.key] == before[tile.key], "and the pictures stay as they were until the tab changes")
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


func _test_animation() -> void:
	check(RigPose.ready(), "KayKit's animations load")
	for action: String in CharacterModel.ACTIONS:
		var spec: Array = CharacterModel.ACTIONS[action]
		check(RigPose.length(spec[0]) >= float(spec[2]) - 0.02, "%s plays a stretch of %s that exists" % [action, spec[0]])
	for clip: String in ["Idle_A", "Sit_Chair_Idle", "Lie_Idle", "Fishing_Idle"]:
		check(RigPose.length(clip) > 0.0, "the %s clip is there" % clip)
	var m := CharacterModel.new(Appearance.DEFAULT)
	add_child(m)
	var arm: Node3D = m.find_child("ArmL", true, false)
	for i in 30:
		m.animate(0.01, 0.0)
	var resting := arm.global_transform.basis.y
	m.play("chop")
	for i in 20:
		m.animate(0.01, 0.0)
	check(arm.global_transform.basis.y.dot(resting) < 0.5, "chopping swings the tool arm up")
	for i in 60:
		m.animate(0.01, 0.0)
	check(m._action == "", "and the action ends")
	# Generated heads: cats wear one on the procedural body; people keep theirs.
	check(not m._model_head, "people keep the procedural head")
	check(CharacterModel.has_model_head("cat") and CharacterModel.model_head("cat").get_surface_count() == 1, "there's a generated cat head")
	var aabb := CharacterModel.model_head("cat").get_aabb()
	check(aabb.get_center().distance_to(Vector3.ZERO) < 0.25 and aabb.size.x > 0.5 and aabb.size.x < 1.2, "sized and centred like the procedural head")
	check(CharacterModel.head_model_for({"kind": "cat", "short": true}) == "cat", "a variant without its own head wears its kind's")
	check(CharacterModel.head_model_for({"kind": "rabbit", "lop": true}) == "rabbit_lop", "lop rabbits wear the lop head")
	check(CharacterModel.head_model_for({"kind": "bird", "head": "bird_sea"}) == "bird_sea", "a species can name its head")
	var heads_ok := true
	for kind: String in ["cat", "dog", "dog_upright", "rabbit", "rabbit_lop", "ferret", "mouse", "bird", "bird_sea"]:
		var box := CharacterModel.model_head(kind).get_aabb() if CharacterModel.has_model_head(kind) else AABB()
		heads_ok = heads_ok and box.size.x > 0.5 and box.size.x < 1.3 and box.get_center().y > -0.4
	check(heads_ok, "every animal kind has a generated head of about the right size")
	var pip := NpcData.model("pip")
	add_child(pip)
	check(pip._model_head and CharacterModel.head_model_for(pip.species) == "dog_upright", "Pip wears the upright-eared dog head")
	pip.free()
	var cat := NpcData.model("maple")
	add_child(cat)
	check(cat._model_head and cat.find_child("Tail", true, false) != null and cat.find_child("LegL", true, false) != null,
		"a cat neighbour wears it, on the procedural body with its tail")
	CharacterModel.use_model_heads = false
	cat.rebuild()
	check(not cat._model_head, "the procedural head is still there to fall back on")
	CharacterModel.use_model_heads = true
	cat.free()
	for i in 60:
		m.animate(0.01, 3.4)
	var hips: Node3D = m.find_child("Hips", true, false)
	check(m._layer == 0.0 and hips.rotation.is_zero_approx(), "walking hands back to the hand-made walk, nothing left over")
	m.mode = "sleeping"
	for i in 40:
		m.animate(0.01, 0.0)
	check(absf(hips.global_transform.basis.y.y) < 0.5, "sleeping lies down")
	m.free()


func _test_crafting() -> void:
	for id: String in ["flimsy_axe", "flimsy_pickaxe", "flimsy_shovel", "flimsy_net", "flimsy_rod", "sturdy_pickaxe"]:
		check(ItemDB.is_tool(id) and Models.get_mesh("tool:" + id).get_surface_count() > 0, "%s is a tool with a model" % id)
	check(ItemDB.tool_type("flimsy_pickaxe") == "pickaxe" and Recipes.recipes.has("flimsy_pickaxe") and Recipes.recipes.has("sturdy_pickaxe"),
		"pickaxes can be made")
	check(RigPose.length(CharacterModel.ACTIONS["mine"][0]) > CharacterModel.ACTIONS["mine"][2], "the pickaxe swing has its clip")
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
	# Doors to other rooms: in the back, left and right walls, kept clear, and walked
	# through by pushing into the wall in front of them.
	var big := World.new()
	big.interior = true
	big.room_doors = World.doors_for(10, 8, ["back", "left", "right"])
	add_child(big)
	big.setup(IslandData.room(10, 8))
	check(big.room_doors.size() == 3 and big.room_doors[0]["tile"] == Vector2i(5, 0), "a back door in the middle of the back wall")
	check(not big.can_place(Rect2i(5, 0, 1, 1), Vector3(-10, 0, -10)) and not big.can_place(Rect2i(0, 4, 1, 1), Vector3(-10, 0, -10)),
		"nothing can block a door")
	check(big.room_door_ahead(Vector3(5.5, 0, 0.3), Vector3(0, 0, -1)) == 1, "walking into the back door goes through it")
	check(big.room_door_ahead(Vector3(5.5, 0, 0.3), Vector3(0, 0, 1)) == -1, "walking away from it doesn't")
	check(big.room_door_ahead(Vector3(0.3, 0, 4.5), Vector3(-1, 0, 0)) == 2 and big.room_door_ahead(Vector3(9.7, 0, 4.5), Vector3(1, 0, 0)) == 3,
		"and the side doors lead to the side rooms")
	check(big.room_door_ahead(Vector3(3.5, 0, 0.3), Vector3(0, 0, -1)) == -1, "the wall beside a door is just wall")
	big.free()
	# Sitting down and getting up again, from a chair against a wall facing into the
	# room and from one facing the wall.
	for case: Array in [[Vector2i(0, 2), 3], [Vector2i(0, 2), 1], [Vector2i(2, 0), 2]]:
		var seat_room := World.new()
		seat_room.interior = true
		add_child(seat_room)
		seat_room.setup(IslandData.room(6, 6))
		var seat := seat_room.place_item("wooden_chair", Rect2i(case[0], Vector2i.ONE), case[1])
		var sitter := Player.new()
		add_child(sitter)
		sitter.setup(seat_room, Vector3(case[0].x + 1.5, 0, case[0].y + 1.5), Appearance.DEFAULT)
		var was_mode := Game.mode
		Game.mode = Game.Mode.PLAY
		sitter._sit_on(seat)
		var sat := sitter.is_sitting()
		for action: String in ["move_down", "move_right", "move_up"]:
			Input.action_press(action)
			for i in 20:
				sitter._physics_process(0.05)
			Input.action_release(action)
			for i in 10:
				sitter._physics_process(0.05)
		var off := not seat_room.footprint(seat).has(sitter.tile())
		check(sat and not sitter.is_sitting() and off, "you can get up from a chair facing %s and walk away" % ["into the room", "the wall", "the back wall"][[3, 1, 2].find(case[1])])
		Game.mode = was_mode
		sitter.free()
		seat_room.free()
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
	var heights: Array[float] = []
	for i in 2:
		box.ask("", "Sleep?", ["a", "b", "c", "d", "e", "f"])
		box._typing = false
		box._process(0.0)
		heights.append(box._choices.size.y)
		box._choose(0)
	check(box._choices.get_child_count() == 6 and heights[1] == heights[0], "a menu asked again is the same height, not doubled")
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
	phone._open_app("options")
	check(phone._page == "options", "apps open a page on the phone")
	phone._show_page("time")
	phone.back()
	check(phone._page == "options", "time travel is in the options, and back returns there")
	phone.back()
	check(phone._page == "home" and phone.visible, "back returns to the home screen")
	check(not IslandPhone.APPS.any(func(a): return a[0] == "time"), "time travel isn't an app of its own any more")
	var chosen := [""]
	phone.app_chosen.connect(func(app): chosen[0] = app)
	phone._open_app("map")
	check(chosen[0] == "map" and not phone.visible and Game.mode == Game.Mode.PLAY, "the map app leaves the phone for the map")
	phone.free()
	check(ItemDB.placeable("sleeping_bag").get("bed", false), "sleeping bags are beds")


func _test_tailors() -> void:
	Inventory.reset()
	var saved_flags := Story.flags.duplicate(true)
	Story.flags.clear()
	var rails := Shop.stock(42, 100, "", "tailors")
	check(rails.size() == Shop.TAILOR_CLOTHES_PER_DAY and rails.all(func(id): return ItemDB.is_clothing(id)), "the tailors sell only clothes")
	check(rails != Shop.stock(42, 101, "", "tailors"), "new clothes every day")
	Inventory.add_currency(Shop.buy_price(rails[0]))
	check(Shop.buy(rails[0], 100, "tailors") == "" and Shop.is_sold_out(rails[0], 100, "tailors"), "buying from the tailors")
	check(not Shop.is_sold_out(rails[0], 100), "doesn't sell it out at Lucy's")
	for id: String in ["daisy", "morris"]:
		var m := NpcData.model(id)
		add_child(m)
		check(m.species.get("short", false) and m.find_child("Head", true, false) != null, "%s is a British Shorthair" % id)
		m.free()
	var d := IslandGenerator.generate(42)
	var w := World.new()
	add_child(w)
	w.setup(d)
	check(not Story.tailors_coming(), "no tailors before Lucy's shop")
	Story.flags["shop_thanks"] = true
	Story.flags["shop_open_day"] = GameClock.day_key() - 1
	check(Story.tailors_coming(), "a day after Lucy's shop opens, she has news")
	Story.flags["tailors_day"] = GameClock.day_key()
	check(not Story.finish_tailors(w), "the shop takes a night")
	Story.flags["tailors_day"] = GameClock.day_key() - 1
	check(Story.finish_tailors(w) and not w.building("tailor_shop").is_empty(), "then Daisy and Morris's shop opens")
	check(ItemDB.placeable("tailor_shop").get("inside", "") == "tailors" and not w.door_of(w.building("tailor_shop")).is_empty(), "and you can walk in")
	w.free()
	Inventory.reset()
	Story.flags = saved_flags


func _test_shop_and_house() -> void:
	Inventory.reset()
	Story.reset()
	var today := Shop.stock(42, 100)
	check(today == Shop.stock(42, 100), "the shop's stock is the same all day")
	check(today != Shop.stock(42, 101), "and changes the next day")
	check(today.size() == Shop.STAPLES.size() + 1 + Shop.FURNITURE_PER_DAY + Shop.OUTDOOR_PER_DAY + Shop.INTERIORS_PER_DAY + Shop.CLOTHES_PER_DAY,
		"the shop has a full stock (and an umbrella)")
	check(today.filter(func(id): return ItemDB.placeable(id).get("outdoor", false)).size() == Shop.OUTDOOR_PER_DAY, "including something for outdoors")
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
	check(not Story.can_offer_extension(), "no extension until Poppy's seen the house")
	Story.flags["house_thanks"] = true
	check(Story.can_offer_extension(), "then she offers a bigger house")
	Story.flags["extension_day"] = GameClock.day_key()
	check(not Story.finish_house(w) and tent["item"] == "house", "the extension isn't done the same day")
	Story.flags["extension_day"] = GameClock.day_key() - 1
	check(Story.finish_house(w) and tent["item"] == "big_house" and not Story.can_offer_extension(), "the house grows overnight")
	var defs := Main.room_defs(ItemDB.placeable("big_house"))
	check(defs.size() == 4 and defs[0]["size"][0] > ItemDB.placeable("house")["room"]["size"][0], "the big house has a bigger main room and three more")
	check(Main.room_key(5, 0) == "5" and Main.room_key(5, 2) == "5:2", "each room is saved on its own")
	tent["paint"] = {"wall": "cfe6f2", "roof": "3a5a8a", "door": "f2c14e"}
	check(Models.key_for(tent) == "big_house:cfe6f2:3a5a8a:f2c14e", "a painted house is drawn in its paint")
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
	var owned_tops := creator._content.find_children("*", "", true, false).filter(func(n): return n is CharacterCreator.OptionTile)
	check(not owned_tops.is_empty() and owned_tops.all(func(t): return t.key == "item"), "and in the wardrobe, only the clothes you own")
	creator.free()
	Game.mode = Game.Mode.PLAY

	# Everyday clothes: any plain style in any colour is an item, made when needed.
	var tee := ItemDB.basic_id("top", {"top": "tee", "top_color": "sky", "top_color2": "white", "top_pattern": "stripes"})
	check(tee == "basic.top.tee.sky.white.stripes" and ItemDB.is_clothing(tee) and ItemDB.has_item(tee), "a striped sky tee is an item")
	check(ItemDB.display_name(tee) == "Sky Tee (Stripes)" and ItemDB.get_item(tee)["wear"]["top_pattern"] == "stripes", "named after its colour, style and pattern")
	check(not ItemDB.has_item("basic.top.raincoat.sky.white.plain") and not ItemDB.has_item("basic.hat.none.red")
		and not ItemDB.has_item("basic.top.tee.tartan_blue.white.plain"), "only real everyday options")
	check(Shop.sell_price(tee) > 0 and Models.get_mesh("clothing:" + tee).get_surface_count() > 0, "they sell and have a model")
	var start := Appearance.DEFAULT.duplicate()
	start["hat"] = "beanie"
	Inventory.reset()
	Inventory.own_outfit(start)
	check(Inventory.closet.size() == 4 and "basic.hat.beanie.red" in Inventory.closet, "the outfit you start in is yours")
	var dressed := Appearance.DEFAULT.duplicate()
	dressed.merge(ItemDB.get_item("raincoat_yellow")["wear"], true)
	check(ItemDB.worn_item("top", dressed) == "raincoat_yellow", "a designed piece being worn is found as itself")
	# The fitting room: clothes bought there go straight into the wardrobe.
	Inventory.add_currency(5000)
	var rail := Shop.stock(7, 100, "", "tailors")
	check(Shop.buy(rail[0], 100, "tailors", true) == "" and rail[0] in Inventory.closet and Inventory.count_of(rail[0]) == 0
		and Shop.is_sold_out(rail[0], 100, "tailors"), "a piece bought in the fitting room goes into the wardrobe")
	var fitting := CharacterCreator.new()
	add_child(fitting)
	fitting.open_fitting(Appearance.DEFAULT.duplicate(), rail)
	fitting._select_tab(7)
	check(fitting._content.find_children("*", "", true, false).any(func(n): return n is Label and n.text.begins_with("On the rail")),
		"the fitting room shows the rail")
	var got := [{}]
	fitting.fitted.connect(func(l): got[0] = l)
	fitting._done()
	check(not got[0].is_empty(), "and hands back what you had on, without buying it")
	fitting.free()
	Game.mode = Game.Mode.PLAY
	check(ItemDB.placeable("fitting_mirror").get("mirror", false) and Models.get_mesh("fitting_mirror").get_surface_count() > 0,
		"there's a mirror to try things on at")
	var shop_def := ItemDB.placeable("tailor_shop")
	check(shop_def.has("room") and not Main._kept(shop_def), "the tailors have an inside, set out afresh each visit")
	var inside := World.new()
	inside.interior = true
	add_child(inside)
	inside.setup(IslandData.room(shop_def["room"]["size"][0], shop_def["room"]["size"][1]))
	Main.fill_inside(inside, "tailors")
	check(not inside.building("fitting_mirror").is_empty() and inside.objects().size() == Main.INSIDES["tailors"]["fittings"].size(),
		"rails, mannequins and the mirror all fit inside")
	inside.free()
	# Every set-out inside fits in its room, and leaves its people somewhere to stand.
	for building: String in ["tailor_shop", "island_office", "museum_tent"]:
		var def := ItemDB.placeable(building)
		var kind: String = def["inside"]
		var r2 := World.new()
		r2.interior = true
		add_child(r2)
		r2.setup(IslandData.room(def["room"]["size"][0], def["room"]["size"][1]))
		Main.fill_inside(r2, kind)
		var placed := 0
		for entry: Array in Main.INSIDES[kind]["fittings"]:
			placed += 1 if ItemDB.has_item(entry[0]) else 0
		check(r2.objects().size() == placed and placed == Main.INSIDES[kind]["fittings"].size(), "everything fits inside the %s" % kind)
		for person: Array in Main.INSIDES[kind]["people"]:
			check(r2.object_at(floori(person[1].x), floori(person[1].y)).is_empty() and r2.data.in_bounds(floori(person[1].x), floori(person[1].y)),
				"%s has somewhere to stand in the %s" % [person[0], kind])
		var door := r2.data.room_door()
		check(r2.object_at(door.x, door.y - 1).is_empty(), "and the way in is clear (%s)" % kind)
		r2.free()

	var lucy := Shop.stock(7, 100)
	check(lucy.any(func(id): return ItemDB.get_item(id).get("basic", false)), "Lucy sells everyday clothes")
	check(Shop.stock(7, 100, "", "tailors").all(func(id): return ItemDB.get_item(id).has("base")), "the tailors sell designed ones")
	check(lucy == Shop.stock(7, 100), "the same each time on the same day")
	Inventory.reset()


func _test_furniture_series() -> void:
	check(ItemDB.series.size() >= 6, "there are furniture series (%d)" % ItemDB.series.size())
	for id: String in ItemDB.items:
		var model: String = ItemDB.placeable(id).get("model", "")
		if model.begins_with("kaykit:") or model == "festive_tree":
			var mesh := Models.get_mesh(model)
			var tris := 0
			for s in mesh.get_surface_count():
				tris += mesh.surface_get_array_index_len(s) / 3
			# Bigger things can have a bit more detail.
			var size: Array = ItemDB.placeable(id)["footprint"]
			check(tris > 0 and tris < maxi(2500, 900 * int(size[0]) * int(size[1])), "%s is cheap enough to place (%d triangles)" % [id, tris])
	var pieces: Array = ItemDB.items.keys().filter(func(id): return ItemDB.get_item(id).has("series"))
	check(pieces.size() >= 100, "series pieces come in variants (%d items)" % pieces.size())
	for id: String in pieces:
		var def := ItemDB.get_item(id)
		var mesh := Models.get_mesh(def["placeable"]["model"] if def.has("placeable") else "series:" + id)
		var tris := 0
		for s in mesh.get_surface_count():
			tris += mesh.surface_get_array_index_len(s) / 3
		check(tris > 0 and tris < 1500, "%s has a model within budget (%d triangles)" % [id, tris])
		if def["build"]["kind"] in ["rug", "curtains", "sofa", "bed", "armchair"] and def["build"].get("kaykit", "") == "":
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
	# Tool recipes: one offer per better tool.
	var tool_offers := Journal.exchange.filter(func(o): return o.has("learn"))
	check(tool_offers.size() >= 10 and tool_offers.all(func(o): return Recipes.recipes.has(o["learn"]) and ItemDB.is_tool(o["learn"])),
		"the exchange has recipes for better tools")
	var golden: Dictionary = tool_offers.filter(func(o): return o["learn"] == "golden_axe")[0]
	Journal.stamps = 5000
	check(Journal.buy(golden, rng) != "" and Recipes.is_known("golden_axe") and Journal.stamps == 5000 - int(golden["cost"]),
		"buying one teaches you the recipe")
	check(Journal.can_buy(golden) != "", "and you can't buy it twice")
	check(Recipes.materials("golden_axe").has("gold_nugget") and Models.get_mesh("tool:golden_net").get_surface_count() > 0,
		"golden tools take gold and have models")
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
	_test_building_kits()
	Story.flags = saved_flags


func _test_building_kits() -> void:
	for kit: String in ["shop_kit", "tailor_kit", "museum_kit"]:
		var def := ItemDB.placeable(kit)
		var builds := ItemDB.placeable(def["builds"])
		check(def["footprint"] == builds["footprint"] and def.get("door", false) == builds.get("door", false),
			"the %s stakes out the same ground as the building" % kit)
		check(Models.get_mesh(def["model"]).get_surface_count() > 0, "the %s has a building site" % kit)
	Story.flags.clear()
	Inventory.reset()
	var d := IslandGenerator.generate(7)
	var w := World.new()
	add_child(w)
	w.setup(d)
	var spot := Rect2i()
	for r in range(3, 20):
		var rect := Rect2i(d.spawn + Vector2i(-6, r), Vector2i(4, 3))
		if spot.size == Vector2i.ZERO and w.can_place(rect, Vector3(-10, 0, -10)) and w.door_clear("shop_kit", rect, 0):
			spot = rect
	Story.flags["shop_kit"] = true
	check(Story.kit_missing(w, "shop_kit"), "a kit that's nowhere is missing")
	Inventory.add_item("shop_kit")
	check(not Story.kit_missing(w, "shop_kit"), "but not while it's in your pockets")
	check(not Story.finish_shop(w), "no shop before the kit's staked out")
	Inventory.reset()
	var site := w.place_item("shop_kit", spot, 0)
	check(site.get("plot_day", -1) == w.day_key and not Story.kit_missing(w, "shop_kit"), "the kit is staked out")
	check(w.pack_up(site) and Inventory.count_of("shop_kit") == 1, "and can be moved until it's built")
	Inventory.reset()
	site = w.place_item("shop_kit", spot, 0)
	check(not Story.finish_shop(w), "it goes up overnight")
	w.day_key += 1
	check(Story.finish_shop(w) and site["item"] == "lucy_shop" and site.get("fixed", false) and not site.has("plot_day"),
		"Lucy's shop stands where you staked it out")
	check(not w.pack_up(site), "and stays there")
	w.free()


func _test_critters() -> void:
	var d := IslandGenerator.generate(7)
	var w := World.new()
	add_child(w)
	w.setup(d)
	var c := w.critters
	var kinds := {}
	for z in d.height:
		for x in d.width:
			kinds[c.water_kind(x, z)] = true
	check(kinds.has("sea") and kinds.has("river") and kinds.has("pond"), "the island has sea, river and pond fishing (%s)" % str(kinds.keys()))
	for i in 20:
		var bug := c.pick(ItemDB.bugs, "trees", 12.0)
		check(bug.is_empty() or c._in_hours(bug, 12.0), "only bugs that are about at noon turn up (%s)" % bug.get("id", ""))
	check(c._in_hours(ItemDB.fish["tuna"], 2.0) and not c._in_hours(ItemDB.fish["tuna"], 12.0), "hours can wrap past midnight")
	# Find deep sea water next to the shore to fish in.
	var spot := Vector3.ZERO
	for z in d.height:
		for x in d.width:
			if spot == Vector3.ZERO and c.swim_kind(Vector3(x + 0.5, 0, z + 0.5)) == "sea" and c.swim_kind(Vector3(x + 1.5, 0, z + 0.5)) == "sea":
				spot = Vector3(x + 0.5, IslandData.SEA_LEVEL, z + 0.5)
	check(spot != Vector3.ZERO, "there's somewhere to cast")
	var player := Player.new()
	player.position = spot
	c.cast(spot)
	var f := c.add_fish("sea_bass", spot + Vector3(1.0, 0.03, 0))
	var bit := false
	for i in 400:
		c._update_fish(f, 0.05, player)
		if c.is_biting():
			bit = true
			break
	check(bit, "a fish near the bobber comes and bites")
	check(c.reel() == "sea_bass" and c.fish.is_empty(), "reeling in during the bite catches it")
	c.cast(spot)
	var g := c.add_fish("sea_bass", spot + Vector3(0.6, 0.03, 0))
	for i in 30:
		c._update_fish(g, 0.05, player)
	check(c.reel() == "", "reeling in too soon catches nothing")
	var bug := c.add_bug("ladybug", spot + Vector3(0, 0, 3), "grass")
	check(c.net(spot + Vector3(0.3, 0, 3)) == "ladybug" and c.bugs.is_empty(), "a net catches a bug")
	var hopper := c.add_bug("cricket", spot + Vector3(0, 0, 3), "grass")
	var node: Node3D = hopper["node"]
	var last := node.position
	var jump := 0.0
	var roam := 0.0
	for i in 600:
		c._hop(hopper, 1.0 / 60.0)
		jump = maxf(jump, node.position.distance_to(last))
		roam = maxf(roam, Vector2(node.position.x - spot.x, node.position.z - spot.z - 3).length())
		last = node.position
	check(roam > 0.05 and roam <= Critters.HOP_RANGE + 0.01, "crickets hop about near home")
	check(jump < 0.1, "moving smoothly, never jumping across in one frame")
	check(Critters.bug_scale("cricket") > Critters.bug_scale("white_butterfly"), "small bugs are drawn bigger than butterflies")
	c._remove_bug(hopper)
	var shy := c.add_bug("white_butterfly", spot + Vector3(1.5, 1, 0), "air")
	player._speed = Player.RUN_SPEED
	c._update_bug(shy, 0.05, player)
	check(shy["state"] == "flee", "running up scares bugs away")
	check(c.net(spot + Vector3(1.5, 0, 0)) == "", "and they can't be caught as they fly off")
	check(ItemDB.get_item("koi").get("category", "") == "fish" and ItemDB.get_item("koi")["price"] > 0, "fish are items worth selling")
	check(Models.get_mesh("drop:stag_beetle").get_surface_count() > 0, "bugs have models")
	player.free()
	w.free()


func _test_museum() -> void:
	var saved_flags := Story.flags.duplicate(true)
	Story.flags.clear()
	Journal.reset()
	var d := IslandGenerator.generate(7)
	var w := World.new()
	add_child(w)
	w.setup(d)
	check(not Story.museum_project_open(), "no museum talk before a home and a first catch")
	Story.flags["museum_gifts"] = ["sea_bass", "koi", "white_butterfly", "ladybug", "cicada"]
	Story.flags["museum_day"] = GameClock.day_key() - 1
	check(Story.finish_museum(w), "Bramble arrives the next day")
	var museum := w.building("museum_tent")
	check(not museum.is_empty() and museum.get("fixed", false), "with his museum tent")
	check(Journal.donated.size() == 5 and "koi" in Journal.caught, "the first specimens are on display")
	check(not Journal.donate("koi"), "the museum keeps one of each")
	check(Journal.donate("frog") and Journal.stats.get("donated", 0) == 6, "new ones are welcome and counted")
	check(Story._creature_fact().length() > 20, "Bramble has things to say about them")
	check(Story._and_list(["a", "b", "c"]) == "a, b and c", "lists read naturally")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(Journal.to_save()))
	Journal.from_save(saved)
	check(Journal.donated.size() == 6, "donations are saved")
	check(JournalMenu.hours_text([4, 21]) == "About from 4am to 9pm." and JournalMenu.hours_text([0, 24]) == "About all day.", "hours read nicely")
	w.free()
	Journal.reset()
	Story.flags = saved_flags


func _test_museum_building() -> void:
	var saved_flags := Story.flags.duplicate(true)
	Story.flags.clear()
	Journal.reset()
	var d := IslandGenerator.generate(7)
	var w := World.new()
	add_child(w)
	w.setup(d)
	Story.flags["museum_gifts"] = ["sea_bass", "koi", "white_butterfly", "ladybug", "cicada"]
	Story.flags["museum_day"] = GameClock.day_key() - 1
	Story.finish_museum(w)
	check(not Story.museum_building_open(), "the tent will do for a while")
	for id: String in ItemDB.fish.keys().slice(0, 10) + ItemDB.bugs.keys().slice(0, 10):
		Journal.donate(id)
	check(Story.museum_building_open(), "with %d donations Bramble wants a proper museum" % Story.MUSEUM_DONATIONS)
	Inventory.reset()
	Inventory.add_item("wood", 15)
	var needs := Story.MUSEUM_MATERIALS.duplicate()
	check(Story._offer(needs) == {"wood": 15}, "Bramble is offered only what's in your pockets")
	var gave := Story._take_materials(needs)
	check(gave == {"wood": 15} and int(needs["wood"]) == 25 and Inventory.count_of("wood") == 0, "materials can come a few at a time")
	Story.flags["museum_build_day"] = GameClock.day_key()
	check(not Story.finish_museum_building(w), "it takes a night to build")
	Story.flags["museum_build_day"] = GameClock.day_key() - 1
	check(Story.finish_museum_building(w) and not w.building("museum").is_empty() and w.building("museum_tent").is_empty(), "the tent becomes the museum")
	check(not Story.museum_building_open(), "and that's that")
	check(not Story._has_home(), "the museum isn't a home")
	var def := ItemDB.placeable("museum")
	var size: Array = def["room"]["size"]
	var hall := World.new()
	hall.interior = true
	hall.visitor = true
	hall.room_style = def["room"]["style"]
	add_child(hall)
	hall.setup(IslandData.room(size[0], size[1]))
	load("res://scripts/main.gd").fill_museum(hall)
	var shown := {}
	var full := 0
	for obj in hall.objects():
		if obj.get("item", "") in ["exhibit_tank", "exhibit_case"]:
			shown[obj["item"]] = int(shown.get(obj["item"], 0)) + 1
			if obj["exhibit"] != "":
				full += 1
				check(obj["exhibit"] in Journal.donated, "only donated creatures are on show")
	check(int(shown.get("exhibit_tank", 0)) == ItemDB.fish.size(), "a tank for every fish")
	check(int(shown.get("exhibit_case", 0)) == ItemDB.bugs.size(), "a case for every bug")
	check(full == Journal.donated.size(), "every donation is on show")
	hall.free()
	w.free()
	Inventory.reset()
	Journal.reset()
	Story.flags = saved_flags


func _test_neighbours() -> void:
	check(NpcData.neighbours().size() >= 8, "there are neighbours who might move in")
	for id: String in NpcData.neighbours():
		var n := NpcData.get_character(id)
		check(n.has("species") and n.has("home") and Story.NEIGHBOUR_TALK.has(n["personality"]), "%s is ready to move in" % id)
		check(ItemDB.series.has(n["inside"]["series"]) and ItemDB.has_item(n["inside"]["wall"]) and ItemDB.has_item(n["inside"]["floor"]), "%s's home can be furnished" % id)
	var kinds := {}
	for id: String in NpcData.neighbours():
		kinds[NpcData.get_character(id)["species"]["kind"]] = id
	for kind: String in CharacterModel.SPECIES:
		check(kinds.has(kind), "there's a %s among the neighbours" % kind)
		if kinds.has(kind):
			var m := NpcData.model(kinds[kind])
			add_child(m)
			check(m.find_child("Tail", true, false) != null and m.find_child("Tail", true, false).get_child_count() > 0, "%s has a tail" % kind)
			m.free()
	var d := IslandGenerator.generate(7)
	var w := World.new()
	add_child(w)
	w.setup(d)
	var spot := Rect2i()
	for r in range(3, 20):
		var rect := Rect2i(d.spawn + Vector2i(-6, r), Vector2i(3, 3))
		if spot.size == Vector2i.ZERO and w.can_place(rect, Vector3(-10, 0, -10)) and w.door_clear("plot_kit", rect, 0):
			spot = rect
	var plot := w.place_item("plot_kit", spot, 0)
	check(plot.get("plot_day", -1) == w.day_key, "a plot remembers the day it was staked out")
	var saved_flags := Story.flags.duplicate(true)
	Story.flags["invited"] = []
	w.day_key += 1
	check(Story.move_in(w).is_empty() and plot["item"] == "plot_kit", "plots wait for someone you've invited")
	w.day_key -= 1
	var wanted: String = NpcData.neighbours().keys()[3]
	Story.flags["invited"] = [wanted]
	check(Story.move_in(w).is_empty(), "nobody moves in the same day")
	w.day_key += 1
	var arrived := Story.move_in(w)
	check(arrived == [wanted] and Story.invited().is_empty(), "the one you invited moves in")
	Story.flags = saved_flags
	check(arrived.size() == 1 and plot["item"] == "neighbour_house" and plot["resident"] == arrived[0], "someone moves in the next day")
	check(w.building_of(arrived[0]) == plot and Models.key_for(plot) == "nhouse:" + arrived[0], "into a house in their own colours")
	check(Models.get_mesh(Models.key_for(plot)).get_surface_count() > 0, "the house has a model")
	check(Npc.out_at(10.0) and not Npc.out_at(20.0), "neighbours are out by day and home in the evening")
	var room := World.new()
	room.interior = true
	room.visitor = true
	add_child(room)
	room.setup(IslandData.room(7, 6))
	var chair := room.place_item("wooden_chair", Rect2i(1, 1, 1, 1), 0)
	check(not room.pack_up(chair), "you can't take things from a neighbour's home")
	room.free()
	var npc := Npc.new()
	w.add_child(npc)
	npc.setup(arrived[0], w, w.outside_door(plot)["position"], Vector3(0, 0, 1))
	npc.wanders = true
	npc.home = npc.position
	npc._pick_target()
	check(w.is_walkable(npc._target.x, npc._target.z), "neighbours stroll to places they can stand")
	# A long stroll never steps up or down a cliff.
	var saved_player := Game.player
	Game.player = null
	var jumped := false
	var last_y := npc.position.y
	for i in 3000:
		npc._wander(0.1)
		jumped = jumped or absf(npc.position.y - last_y) > 0.25
		last_y = npc.position.y
	Game.player = saved_player
	check(not jumped, "and never walk up or down cliffs")
	w.free()


func _test_friendship() -> void:
	var saved_flags := Story.flags.duplicate(true)
	Story.flags.clear()
	check(Story.hearts("biscuit") == 0, "new neighbours start as strangers")
	Story.befriend("biscuit", 8)
	check(Story.hearts("biscuit") == 2, "friendship fills hearts")
	Story.befriend("biscuit", 100)
	check(Story.hearts("biscuit") == 5, "up to five")
	var asked := 0
	for id: String in NpcData.neighbours():
		var want := Story.request_for(id)
		check(want == Story.request_for(id), "%s asks for the same thing all day" % id)
		check(want == "" or ItemDB.has_item(want), "%s asks for a real item (%s)" % [id, want])
		if want != "":
			asked += 1
	check(asked > 0 and asked < NpcData.neighbours().size(), "some neighbours ask for favours each day, not all (%d)" % asked)
	for p: String in Story.LIKES:
		for cat: String in Story.LIKES[p]:
			check(ItemDB.items.values().any(func(d): return d.get("category", "") == cat), "%s neighbours like things that exist (%s)" % [p, cat])
	for id: String in NpcData.neighbours():
		var piece := Story._their_piece(NpcData.get_character(id))
		check(ItemDB.has_item(piece) and ItemDB.get_item(piece).has("placeable"), "%s has furniture to give" % id)
	Story.flags = saved_flags


func _test_tours() -> void:
	var saved_flags := Story.flags.duplicate(true)
	Story.flags.clear()
	for seed_value in [3, 7, 42, 1234]:
		var d := IslandGenerator.generate(seed_value)
		var w := World.new()
		add_child(w)
		w.setup(d)
		var dock := w.add_dock(d.spawn)
		check(not dock.is_empty() and dock.get("fixed", false), "island %d has room for Marlow's dock" % seed_value)
		if not dock.is_empty():
			var spots := w.dock_spots(dock)
			check(w.is_walkable(spots["skipper"].x, spots["skipper"].z) and w.is_walkable(spots["arrive"].x, spots["arrive"].z),
				"Marlow and the ferry's passengers stand on open sand (island %d)" % seed_value)
			check(w.add_dock(d.spawn) == dock, "and there's only one dock")
			check(int(dock["rot"]) == 0, "on the south shore (island %d)" % seed_value)
			# An older island with the dock round the back gets it moved to the south.
			w.remove_object(dock["uid"])
			var north := Rect2i()
			for z in range(1, d.height / 2):
				for x in range(1, d.width - 2):
					if north.size == Vector2i.ZERO and w._dock_fits(Rect2i(x, z, 2, 2), 2):
						north = Rect2i(x, z, 2, 2)
			if north.size != Vector2i.ZERO:
				w.place_item("dock", north, 2)
				check(w.move_dock_south(d.spawn) and int(w.building("dock")["rot"]) == 0, "an old north-shore dock moves south")
		var t := IslandGenerator.generate_tour(seed_value * 7 + 1, d.native_fruit, d.native_flower)
		check(t.native_fruit != d.native_fruit and t.native_flower != d.native_flower,
			"a tour island grows other fruit and flowers (%s/%s vs %s/%s)" % [t.native_fruit, t.native_flower, d.native_fruit, d.native_flower])
		check(t.plaza == Rect2i() and not t.objects.any(func(o): return o["kind"] == "placed"), "and has no plaza or office")
		check(t.width < d.width and t.objects.any(func(o): return o["kind"] == "fruit_tree" and o["fruit"] == t.native_fruit), "it's small, with fruit trees")
		var tw := World.new()
		tw.tour = true
		add_child(tw)
		tw.setup(t)
		check(not tw.add_dock(Vector2i(t.width / 2, t.height / 2)).is_empty(), "Marlow can land on tour island %d" % seed_value)
		tw.free()
		w.free()
	var d := IslandGenerator.generate(7)
	var w := World.new()
	add_child(w)
	w.setup(d)
	check(not Story.finish_dock(w), "no ferry before you've arrived")
	Story.flags["intro_done"] = true
	check(not Story.finish_dock(w) and int(Story.flags["dock_from"]) == GameClock.day_key(), "nor on your first day")
	Story.flags["dock_from"] = GameClock.day_key() - 1
	check(Story.finish_dock(w) and not w.building("dock").is_empty(), "Marlow ties up the next day")
	check(ItemDB.get_item("tour_ticket").get("price", 1) == 0, "tickets can't be sold on")
	# Someone invited on a tour moves into the next plot.
	var spot := Rect2i()
	for r in range(3, 20):
		var rect := Rect2i(d.spawn + Vector2i(-6, r), Vector2i(3, 3))
		if spot.size == Vector2i.ZERO and w.can_place(rect, Vector3(-10, 0, -10)) and w.door_clear("plot_kit", rect, 0):
			spot = rect
	var free: Array = NpcData.neighbours().keys()
	free.sort()
	Story.flags["invited"] = free[-1]
	var plot := w.place_item("plot_kit", spot, 0)
	w.day_key += 1
	check(Story.move_in(w) == [free[-1]] and plot["resident"] == free[-1] and Story.invited().is_empty(), "an invitation from an older save still counts")
	Inventory.reset()
	Inventory.add_item("plot_kit")
	Story.flags["invited"] = [free[0]]
	check(Story.open_plots() == 1, "a plot in your pockets is an open plot")
	w.free()
	Story.flags = saved_flags


func _test_rare_islands() -> void:
	check(TourKinds.pick(1, 0.0, 0.5) == "plain", "the first tour lands somewhere ordinary")
	check(TourKinds.pick(5, 0.99, 0.5) == "plain" and TourKinds.pick(5, 0.0, 0.5) in TourKinds.rare_kinds(),
		"later ones are sometimes rare")
	var kinds_seen := {}
	for i in 40:
		kinds_seen[TourKinds.pick(2, 0.0, i / 40.0)] = true
	check(kinds_seen.size() == TourKinds.rare_kinds().size(), "every rare kind turns up")
	var plain := IslandGenerator.generate_tour(11, "apple", "tulip")
	var count := func(t: IslandData, kind: String) -> int: return t.objects.filter(func(o): return o["kind"] == kind).size()
	var orchard := IslandGenerator.generate_tour(11, "apple", "tulip", "orchard")
	var fruits := {}
	for o in orchard.objects:
		if o["kind"] == "fruit_tree":
			fruits[o["fruit"]] = true
	check(orchard.kind == "orchard" and count.call(orchard, "fruit_tree") > count.call(plain, "fruit_tree") * 2 and fruits.size() >= 4,
		"an orchard island is full of fruit trees of every kind")
	var meadow := IslandGenerator.generate_tour(11, "apple", "tulip", "meadow")
	var rare := meadow.objects.filter(func(o): return o["kind"] == "flower" and o["color"] in IslandGenerator.RARE_FLOWER_COLOURS)
	check(count.call(meadow, "flower") > count.call(plain, "flower") * 2 and not rare.is_empty(), "a meadow has lots of flowers, some in rare colours")
	check(not plain.objects.any(func(o): return o["kind"] == "flower" and o["color"] in IslandGenerator.RARE_FLOWER_COLOURS),
		"ordinary islands don't")
	var flower: Dictionary = rare[0]
	var picked := "%s_%s" % [flower["species"], flower["color"]]
	check(ItemDB.has_item(picked) and ItemDB.has_item(picked + "_plant") and ItemDB.is_rare_flower(flower["species"], flower["color"])
		and ItemDB.get_item(picked)["price"] > ItemDB.get_item("%s_red" % flower["species"])["price"], "rare colours are items worth more")
	var had_shop: bool = Story.flags.get("shop_done", false)
	Story.flags["shop_done"] = true
	var sold_rare := false
	for day in 40:
		for id in Shop.stock(7, day, "tulip"):
			sold_rare = sold_rare or ItemDB.get_item(id).get("flower_color", "") in IslandGenerator.RARE_FLOWER_COLOURS
	Story.flags["shop_done"] = had_shop
	check(not sold_rare, "and Lucy never sells them")
	var quarry := IslandGenerator.generate_tour(11, "apple", "tulip", "quarry")
	check(count.call(quarry, "rock") > count.call(plain, "rock"), "a rocky island has more rocks")
	var qw := World.new()
	qw.tour = true
	add_child(qw)
	qw.setup(quarry)
	var gold := 0
	for i in 400:
		gold += 1 if qw._roll_rock_item() == "gold_nugget" else 0
	check(gold > 20, "with gold in them (%d in 400)" % gold)
	qw.free()
	var morpho: Dictionary = ItemDB.bugs["blue_morpho"]
	check(not Critters.lives_here(morpho, "") and not Critters.lives_here(morpho, "fishy") and Critters.lives_here(morpho, "buggy"),
		"rare bugs only live on bug islands")
	check(ItemDB.fish.values().filter(func(f): return f.has("islands")).size() >= 3, "and there are rare fish for fishing islands")


func _test_tour_visitors() -> void:
	var saved_flags := Story.flags.duplicate(true)
	var saved_island := Game.island
	Story.reset()
	var d := IslandGenerator.generate(7)
	var w := World.new()
	add_child(w)
	w.setup(d)
	Game.island = w
	check(Story.visitor_today() == "", "nobody visits before you've met anyone")
	Story.flags["met"] = {"kiwi": GameClock.day_key()}
	Story.force_visitor = "kiwi"
	check(Story.visitor_today() == "", "nor on the day you met them")
	Story.flags["met"] = {"kiwi": GameClock.day_key() - 1}
	check(Story.visitor_today() == "kiwi", "someone met on a tour drops in on a later day")
	Story.flags["met"] = {"kiwi": 0}
	Story.force_visitor = ""
	var days := 0
	for day in 60:
		GameClock.offset_seconds += 86400
		days += 1 if Story.visitor_today() == "kiwi" else 0
	GameClock.offset_seconds -= 86400 * 60
	check(days > 10 and days < 40, "now and then (%d days in 60)" % days)
	var gift := Story.souvenir("kiwi", 3)
	check(ItemDB.has_item(gift) and gift != d.native_fruit, "they bring a souvenir from away (%s)" % gift)
	Story.force_visitor = "kiwi"
	var spot := Rect2i()
	for r in range(3, 20):
		var rect := Rect2i(d.spawn + Vector2i(-6, r), Vector2i(3, 3))
		if spot.size == Vector2i.ZERO and w.can_place(rect, Vector3(-10, 0, -10)) and w.door_clear("plot_kit", rect, 0):
			spot = rect
	var plot := w.place_item("plot_kit", spot, 0)
	plot["item"] = "neighbour_house"
	plot["resident"] = "kiwi"
	check(Story.visitor_today() == "", "and stop visiting once they live here")

	# A second island (a tour) keeps its plaza to itself.
	var other := World.new()
	add_child(other)
	other.setup(IslandGenerator.generate_tour(99, d.native_fruit, d.native_flower))
	var home_plaza: Vector4 = (w.get_node("Ground").get_child(0) as MeshInstance3D).material_override.get_shader_parameter("plaza")
	check(home_plaza == Vector4(d.plaza.position.x, d.plaza.position.y, d.plaza.size.x, d.plaza.size.y),
		"the home island's paving stays where its plaza is, whatever island was built since")
	other.free()

	# Moving out: with three settled neighbours, now and then one wonders about leaving.
	Story.reset()
	var homes: Array = []
	for r in range(3, 30):
		for dx: int in [-12, -6, 4, 10]:
			var rect := Rect2i(d.spawn + Vector2i(dx, r), Vector2i(3, 3))
			if homes.size() < 3 and w.can_place(rect, Vector3(-10, 0, -10)) and w.door_clear("plot_kit", rect, 0):
				var house := w.place_item("plot_kit", rect, 0)
				house["item"] = "neighbour_house"
				house["resident"] = ["biscuit", "maple", "clover"][homes.size()]
				homes.append(house)
	check(homes.size() == 3, "three neighbours for the moving-out checks")
	var start := GameClock.offset_seconds
	var thought := 0
	var last_day := -100
	var too_soon := false
	for day in 120:
		GameClock.offset_seconds += 86400
		Story.check_moving(w)
		if Story.thinking_of_moving() != "":
			thought += 1
			too_soon = too_soon or GameClock.day_key() - last_day < Story.MOVE_GAP_DAYS
			last_day = GameClock.day_key()
			# Asked to stay: nobody else wonders for a while.
			Story.flags.erase("moving")
			Story.flags["last_move"] = GameClock.day_key()
	GameClock.offset_seconds = start
	check(thought > 0 and thought <= 120 / Story.MOVE_GAP_DAYS + 1 and not too_soon, "now and then someone wonders about moving (%d times in 120 days)" % thought)
	Story.flags.erase("last_move")
	Story.flags["moving"] = {"id": "maple", "day": GameClock.day_key() - 1, "state": "thinking"}
	check(Story.check_moving(w).is_empty() and not Story.flags.has("moving") and not w.building_of("maple").is_empty(),
		"if nobody asked them, they stay")
	Story.flags["moving"] = {"id": "maple", "day": GameClock.day_key() - 1, "state": "leaving"}
	var house_uid: int = w.building_of("maple")["uid"]
	var gone := Story.check_moving(w)
	check(gone.get("who", "") == "maple" and gone.get("uid", -1) == house_uid and w.building_of("maple").is_empty()
		and w.get_object(house_uid)["item"] == "plot_kit", "told to follow their heart, they leave and the plot is free")
	Story.flags["invited"] = ["rosie"]
	check(Story.move_in(w).is_empty(), "nobody moves into it the same day")
	GameClock.offset_seconds += 86400
	w.day_key += 1
	check(Story.move_in(w) == ["rosie"], "and someone new can move in the next")
	w.day_key -= 1
	GameClock.offset_seconds = start
	for house in homes:
		w.remove_object(house["uid"])

	# Travelling visitors: from the day after you meet Lucy, most days, never two days running.
	Story.reset()
	var today := GameClock.day_key()
	check(Story.daily_visitor_today(today) == "", "no travelling visitors before you've met Lucy")
	Story.flags["met_lucy"] = true
	Story.flags["lucy_met_day"] = today - 1
	var seen := {}
	var last := ""
	var twice := false
	for day in range(today, today + 60):
		var v := Story.daily_visitor_today(day)
		if v != "":
			seen[v] = true
			twice = twice or v == last
		last = v
	check(seen.size() == Story.DAILY_VISITORS.size(), "all four come by in a couple of months (%d)" % seen.size())
	check(not twice, "never the same one two days running")
	for id: String in Story.DAILY_VISITORS:
		check(not NpcData.get_character(id).is_empty() and Shop.KEEPERS.has(id), "%s has a character and a stall" % id)
	var fabrics := Shop.stock(7, today, "", "fennel")
	check(fabrics.size() == Shop.FENNEL_PER_DAY and fabrics.all(func(id): return ItemDB.get_item(id).get("category", "") == "interior" \
		or ItemDB.placeable(id).get("rug", false)), "Fennel sells wallpaper, flooring, curtains and rugs")
	var seeds := Shop.stock(7, today, d.native_flower, "tansy")
	check(seeds.any(func(id): return ItemDB.get_item(id).get("category", "") == "flower_plant" \
		and ItemDB.is_rare_flower(ItemDB.get_item(id)["species"], ItemDB.get_item(id)["flower_color"])), "Tansy has a rare flower")
	check(seeds.any(func(id): return ItemDB.get_item(id).get("category", "") == "fruit" and id != d.native_fruit), "and fruit from elsewhere")
	var bug: String = ItemDB.bugs.keys()[0]
	var fish: String = ItemDB.fish.keys()[0]
	check(Shop.sell_price(bug, "basil") == roundi(Shop.sell_price(bug) * 1.5) and not Shop.can_sell(fish, "basil")
		and not Shop.can_sell("wood", "basil"), "Basil pays more for bugs, and only buys bugs")
	check(Shop.sell_price(fish, "marina") > Shop.sell_price(fish) and not Shop.can_sell(bug, "marina"), "Marina pays more for fish")
	w.free()
	Game.island = saved_island
	Story.reset()
	Story.flags = saved_flags


func _test_fruit_planting() -> void:
	var d := IslandGenerator.generate(7)
	var w := World.new()
	add_child(w)
	w.setup(d)
	var spot := Vector2i(-1, -1)
	for z in range(d.spawn.y + 6, d.height):
		for x in range(4, d.width - 4):
			if spot.x < 0 and w.can_plant_tree(Vector2i(x, z)):
				spot = Vector2i(x, z)
	check(spot.x >= 0, "there's somewhere to plant a tree")
	var foreign: String = IslandGenerator.FRUITS.filter(func(f): return f != d.native_fruit)[0]
	var tree := w.plant_fruit(foreign, spot)
	check(tree["kind"] == "fruit_tree" and tree["fruit"] == foreign and tree.has("planted"), "a planted fruit becomes a sapling")
	check(not w.can_plant_tree(spot + Vector2i(1, 0)), "trees need a little room")
	check(is_equal_approx(w.node_of(tree["uid"]).scale.x, w.growth_scale(tree)) and w.growth_scale(tree) < 0.3, "it starts small")
	w.shake(tree, Vector3.ZERO)
	check(int(tree["fruit_count"]) == 0, "and has nothing to shake down yet")
	var key := w.day_key
	for n in World.GROW_DAYS - 1:
		w._on_day_changed(key + n + 1)
	check(tree.has("planted") and w.node_of(tree["uid"]).scale.x > 0.6, "it grows a bit each night")
	w._on_day_changed(key + World.GROW_DAYS)
	check(not tree.has("planted") and int(tree["fruit_count"]) == 3 and is_equal_approx(w.node_of(tree["uid"]).scale.x, 1.0),
		"after %d nights it's a full tree with fruit" % World.GROW_DAYS)
	var saved_island := Game.island
	Game.island = w
	check(Shop.sell_price(foreign) == Shop.sell_price(d.native_fruit) * Shop.FOREIGN_FRUIT, "fruit from elsewhere sells for more")
	Game.island = saved_island
	var t := World.new()
	t.tour = true
	add_child(t)
	t.setup(IslandGenerator.generate_tour(5, d.native_fruit, d.native_flower))
	var anywhere := false
	for z in t.data.height:
		for x in t.data.width:
			anywhere = anywhere or t.can_plant_tree(Vector2i(x, z))
	check(not anywhere, "nothing gets planted on a tour island")
	t.free()
	w.free()


func _test_save_slots() -> void:
	var was := SaveGame.slot
	check(SaveGame.path(0) != SaveGame.path(1) and SaveGame.path(1) != SaveGame.path(2), "every file has its own save")
	# Only the scratch slot, so a real file is never touched.
	SaveGame.slot = 0
	SaveGame.delete()
	check(SaveGame.summary(0).is_empty(), "an empty file has nothing to show")
	SaveGame.write({"player_name": "Ada", "island_name": "Fern", "inventory": {"currency": 250},
		"day": 100, "started_day": 96, "player": {"look": {"hair": "bob"}}})
	var s := SaveGame.summary(0)
	check(s["player_name"] == "Ada" and s["island_name"] == "Fern" and s["acorns"] == 250 and s["days"] == 5
		and s["look"]["hair"] == "bob" and int(s["saved_at"]) > 0, "a file shows who, where, how far along and when")
	SaveGame.delete()
	check(not SaveGame.has_save(0), "and can be deleted")
	SaveGame.slot = was
	check(TitleScreen.skips_title({"screenshot": "x.png"}) and TitleScreen.skips_title({"new": ""})
		and not TitleScreen.skips_title({}) and not TitleScreen.skips_title({"screenshot": "x.png", "title": ""}),
		"game options on the command line skip the title screen (unless --title)")


func _test_music() -> void:
	check(Music.part_of_day(6.0) == "morning" and Music.part_of_day(11.9) == "morning" and Music.part_of_day(12.0) == "afternoon"
		and Music.part_of_day(17.5) == "afternoon" and Music.part_of_day(18.0) == "evening" and Music.part_of_day(3.0) == "evening",
		"morning from 6, afternoon from noon, evening from 6pm to 6am")
	check(Music.track_for(8.2) != Music.track_for(9.2) and Music.track_for(7.2) == Music.track_for(11.5)
		and Music.track_for(8.2) in Music.TRACKS["morning"], "the pieces take turns hour by hour")
	var all_load := true
	for part: String in Music.TRACKS:
		for path: String in Music.TRACKS[part]:
			all_load = all_load and load(path) is AudioStream
	check(all_load, "every piece of music loads")
	check(not Music.enabled, "and none plays in headless runs")


## Walks a player-sized point from `start` along `dir` for `frames` frames at walking pace.
func _walk(w: World, start: Vector2, dir: Vector2, frames: int) -> Vector3:
	var pos := Vector3(start.x, w.ground_height(start.x, start.y), start.y)
	for i in frames:
		var step := dir * Player.WALK_SPEED / 60.0
		if w.can_move(pos, pos.x + step.x, pos.z, Player.RADIUS):
			pos.x += step.x
		if w.can_move(pos, pos.x, pos.z + step.y, Player.RADIUS):
			pos.z += step.y
		pos.y = w.ground_height(pos.x, pos.z)
	return pos


func _test_ramps_and_sos() -> void:
	var climbs := 0
	var stuck := 0
	for seed_value in [3, 7, 42]:
		var d := IslandGenerator.generate(seed_value)
		var w := World.new()
		add_child(w)
		w.setup(d)
		for i: int in d.ramps:
			var up: Vector2i = d.ramps[i]["up"]
			var tile := Vector2i(i % d.width, i / d.width)
			if d.ramps.has(d.idx(tile.x - up.x, tile.y - up.y)):
				continue
			# The ramp's foot: up it from anywhere across its width, straight or a bit slanted.
			var top: float = d.ramps[i]["high"] * 2.0 - d.ramps[i]["low"]
			var side := Vector2(up.y, up.x)
			for lat: float in [-0.3, -0.15, 0.0, 0.15, 0.3]:
				for slant: float in [0.0, 0.2, -0.2]:
					var start := Vector2(tile) + Vector2(0.5, 0.5) - Vector2(up) * 0.6 + side * lat
					var end := _walk(w, start, (Vector2(up) + side * slant).normalized(), 90)
					climbs += 1
					stuck += 1 if end.y < top - 0.05 else 0
		if seed_value == 7:
			var spot := Main.rescue_spot(w)
			check(w.is_walkable(spot.x, spot.z) and Rect2(d.plaza.grow(3)).has_point(Vector2(spot.x, spot.z))
				and w.object_at(floori(spot.x), floori(spot.z)).is_empty(), "SOS brings you to open ground by the plaza")
			# Off the cliff edge onto a ledge you can't leave: SOS still finds the plaza.
			check(w.can_move(Vector3(spot.x, w.ground_height(spot.x, spot.z), spot.z), spot.x + 0.05, spot.z, Player.RADIUS)
				or w.can_move(Vector3(spot.x, w.ground_height(spot.x, spot.z), spot.z), spot.x, spot.z + 0.05, Player.RADIUS),
				"and you can walk away from there")
		w.free()
	check(climbs > 30 and stuck == 0, "every ramp can be walked up, even off-centre (%d of %d got stuck)" % [stuck, climbs])
	# A cliff is still a cliff.
	var d := IslandGenerator.generate(7)
	var w := World.new()
	add_child(w)
	w.setup(d)
	var blocked := 0
	var edges := 0
	for z in range(1, d.height - 1):
		for x in range(1, d.width - 1):
			if edges < 40 and d.tier(x, z) == 2 and d.tier(x, z + 1) == 1 and not d.is_ramp(x, z) and not d.is_ramp(x, z + 1) \
					and d.tile(x, z) == IslandData.Tile.GRASS and d.tile(x, z + 1) == IslandData.Tile.GRASS and w.is_walkable(x + 0.5, z + 0.5):
				edges += 1
				var end := _walk(w, Vector2(x + 0.5, z + 0.5), Vector2(0, 1), 40)
				blocked += 1 if end.y > IslandData.tier_height(2) - 0.05 else 0
	check(edges > 5 and blocked == edges, "but you can't walk off a cliff (%d of %d held)" % [blocked, edges])
	w.free()


func _test_built_crossings() -> void:
	check(ItemDB.get_item("bridge_kit").get("construct", "") == "bridge" and not ItemDB.has_item("incline_kit"),
		"there are bridge kits (slopes are landscaping now)")
	check(Models.get_mesh("drop:bridge_kit").get_faces().size() > 30, "and they have a model")
	var d := IslandGenerator.generate(7)
	var w := World.new()
	add_child(w)
	w.setup(d)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	# A slope from the foot of a cliff.
	var plan := {}
	var stand := Vector2i.ZERO
	for z in range(2, d.height - 2):
		for x in range(2, d.width - 2):
			for f: Vector2i in dirs:
				if plan.is_empty() and d.tier(x, z) == 1 and w.is_walkable(x + 0.5, z + 0.5):
					var p := w.incline_plan(Vector2i(x, z), f)
					if p.has("top"):
						plan = p
						stand = Vector2i(x, z)
	check(not plan.is_empty(), "somewhere on the island a slope fits at the foot of a cliff")
	if not plan.is_empty():
		var top: Vector2i = plan["top"]
		var dir: Vector2i = plan["dir"]
		var low := IslandData.tier_height(1)
		var high := IslandData.tier_height(2)
		check(w.incline_plan(top, dir).has("top"), "and from the top of it, facing down")
		w.build_incline(plan)
		check(d.is_ramp(top.x + dir.x, top.y + dir.y) and d.is_ramp(top.x + dir.x * 2, top.y + dir.y * 2), "building it lays a two-tile ramp")
		var foot := top + dir * 3
		var end := _walk(w, Vector2(foot) + Vector2(0.5, 0.5), -Vector2(dir), 90)
		check(end.y > high - 0.05, "you can walk up the new slope (got to %.2f of %.2f)" % [end.y, high])
		var back := _walk(w, Vector2(top) + Vector2(0.5, 0.5), Vector2(dir), 90)
		check(back.y < low + 0.05, "and back down it")
		check(w.incline_plan(foot, -dir).has("why"), "a second slope can't go on top of it")
		# Saved with the island and laid again on loading.
		var saved: Dictionary = JSON.parse_string(JSON.stringify(w.to_save()))
		var w2 := World.new()
		add_child(w2)
		w2.setup(IslandGenerator.generate(7), saved)
		check(w2.data.is_ramp(top.x + dir.x, top.y + dir.y) and w2.built_ramps.size() == 1, "the slope is still there after saving")
		w2.free()
	# A bridge over the river.
	var bridge := {}
	for z in range(2, d.height - 2):
		for x in range(2, d.width - 2):
			for f: Vector2i in dirs:
				if bridge.is_empty() and d.tile(x, z) == IslandData.Tile.GRASS and d.tile(x + f.x, z + f.y) == IslandData.Tile.WATER \
						and w.is_walkable(x + 0.5, z + 0.5):
					var p := w.bridge_plan(Vector2i(x, z), f)
					if p.has("length"):
						bridge = p
						stand = Vector2i(x, z)
	check(not bridge.is_empty(), "somewhere on the river a bridge fits")
	if not bridge.is_empty():
		var obj := w.build_bridge(bridge)
		var step := Vector2i(1, 0) if bridge["axis"] == "x" else Vector2i(0, 1)
		var first := Vector2i(bridge["x"], bridge["z"])
		var walkway := true
		for k in bridge["length"]:
			var t: Vector2i = first + step * int(k)
			walkway = walkway and w.is_walkable(t.x + 0.5, t.y + 0.5)
		check(obj["kind"] == "bridge" and walkway, "building it puts a walkable bridge over the water")
		var going := Vector2(first - stand).sign()
		var across := _walk(w, Vector2(stand) + Vector2(0.5, 0.5), going, 60 + 40 * int(bridge["length"]))
		var far := Vector2(stand) + Vector2(0.5, 0.5) + going * (int(bridge["length"]) + 1)
		check(Vector2(across.x, across.z).distance_to(far) < 0.6 or (Vector2(across.x, across.z) - Vector2(stand)).dot(going) > bridge["length"] + 0.5,
			"and you can walk across it")
		check(w.bridge_plan(stand, Vector2i(going)).has("why"), "but not build another in the same place")
	var sea := Vector2i(d.width / 2, d.height - 1)
	while sea.y > 0 and d.tile(sea.x, sea.y) != IslandData.Tile.SAND:
		sea.y -= 1
	check(w.bridge_plan(sea, Vector2i(0, 1)).has("why"), "no bridges out to sea")
	w.free()


func _test_landscaping() -> void:
	check(not ItemDB.has_item("cliff_pick") and IslandPhone.APPS.any(func(a): return a[0] == "landscape")
		and Player.LANDSCAPE_TOOLS.size() == 5 + World.PATH_KINDS.size(), "landscaping tools come from a phone app, not the pockets")
	# Working the ground out again gives the same island as the generator.
	var fresh := IslandGenerator.generate(7)
	var again := IslandGenerator.generate(7)
	IslandGenerator.reshape(again)
	check(again.corners == fresh.corners and again.splits.keys() == fresh.splits.keys(), "reshaping an untouched island changes nothing")
	var d := IslandGenerator.generate(7)
	var w := World.new()
	add_child(w)
	w.setup(d)
	# A spot in open, flat, low ground with room all round.
	var stand := Vector2i(-1, -1)
	for z in range(4, d.height - 4):
		for x in range(4, d.width - 4):
			if stand.x >= 0:
				break
			var ok := true
			for dz in range(-2, 3):
				for dx in range(-1, 4):
					var q := Vector2i(x + dx, z + dz)
					ok = ok and d.tile(q.x, q.y) == IslandData.Tile.GRASS and d.tier(q.x, q.y) == 1 and not d.is_ramp(q.x, q.y) \
						and w.object_at(q.x, q.y).is_empty() and w.is_walkable(q.x + 0.5, q.y + 0.5) and not d.plaza.grow(2).has_point(q)
			if ok:
				stand = Vector2i(x, z)
	check(stand.x >= 0, "there's open ground to landscape")
	if stand.x < 0:
		w.free()
		return
	var t := stand + Vector2i(1, 0)
	var raise := w.terraform_plan(stand, Vector2i(1, 0), "cliff")
	check(raise.get("verb", "") == "raise" and raise["tier"] == 2, "the cliff pick raises the ground beside you")
	w.terraform(raise)
	check(d.tier(t.x, t.y) == 2 and is_equal_approx(w.ground_height(t.x + 0.5, t.y + 0.5), IslandData.tier_height(2)), "a step up")
	var from := Vector3(stand.x + 0.5, w.ground_height(stand.x + 0.5, stand.y + 0.5), stand.y + 0.5)
	check(_walk(w, Vector2(from.x, from.z), Vector2(1, 0), 60).x < t.x + 0.1, "that you can't walk up")
	check(w.terraform_plan(stand, Vector2i(1, 0), "cliff").get("verb", "") == "lower", "and cuts it back again")
	w.terraform(w.terraform_plan(stand, Vector2i(1, 0), "cliff"))
	check(d.tier(t.x, t.y) == 1 and is_equal_approx(w.ground_height(t.x + 0.5, t.y + 0.5), IslandData.tier_height(1)), "back to level")
	var dig := w.terraform_plan(stand, Vector2i(1, 0), "water")
	check(dig.get("verb", "") == "dig", "the water spade digs out the ground beside you")
	w.terraform(dig)
	check(d.tile(t.x, t.y) == IslandData.Tile.WATER and not w.is_walkable(t.x + 0.5, t.y + 0.5) and w.critters.water_kind(t.x, t.y) != "",
		"into water fish can live in")
	check(w.terraform_plan(stand, Vector2i(1, 0), "cliff").has("why"), "the pick leaves water alone")
	var whole := d.ground_copy()
	whole.objects = d.objects
	var keep := {}
	for obj in d.objects:
		if obj["kind"] != "bridge":
			for q in w.footprint(obj):
				if d.in_bounds(q.x, q.y):
					keep[d.idx(q.x, q.y)] = true
	IslandGenerator.reshape(whole, keep)
	check(whole.corners == d.corners and whole.splits == d.splits, "reshaping just round a change gives the same ground as reshaping it all")
	check(w.terraform_plan(stand, Vector2i(1, 0), "water").get("verb", "") == "fill", "the spade fills it in again")
	# Kept with the island.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(w.to_save()))
	var w2 := World.new()
	add_child(w2)
	w2.setup(IslandGenerator.generate(7), saved)
	check(w2.data.tile(t.x, t.y) == IslandData.Tile.WATER and w2.land_edits.size() == 1, "landscaping is still there after saving")
	w2.free()
	# Somewhere it can't go.
	var plaza := d.plaza.get_center()
	check(w.terraform_plan(plaza, Vector2i(1, 0), "cliff").has("why"), "not in the plaza")
	var blocked := 0
	var tries := 0
	for z in range(2, d.height - 2):
		for x in range(2, d.width - 2):
			if tries < 20 and d.tile(x, z) == IslandData.Tile.GRASS and d.tier(x, z) == 1 and d.tile(x + 1, z) == IslandData.Tile.SAND:
				tries += 1
				blocked += 1 if w.terraform_plan(Vector2i(x - 1, z), Vector2i(1, 0), "water").has("why") else 0
	check(tries > 0 and blocked == tries, "no ponds dug against the beach (%d of %d)" % [blocked, tries])
	w.free()


func _test_trees_and_rocks() -> void:
	check(Player.LANDSCAPE_TOOLS.has("trees") and Player.LANDSCAPE_TOOLS.has("move"), "the landscaping app has tools for trees and for moving things")
	var d := IslandGenerator.generate(7)
	var w := World.new()
	add_child(w)
	w.setup(d)
	# A grown tree with open grass to the south to stand on.
	var tree: Dictionary = {}
	for obj in w.objects():
		if obj["kind"] == "tree" and w.is_walkable(obj["x"] + 0.5, obj["z"] + 1.5) and w.object_at(obj["x"], obj["z"] + 1).is_empty():
			tree = obj
			break
	check(not tree.is_empty(), "there's a tree to chop down")
	if tree.is_empty():
		w.free()
		return
	var spot := Vector2i(tree["x"], tree["z"])
	var at := Vector3(spot.x + 0.5, 0.0, spot.y + 1.6)
	var uid: int = tree["uid"]
	var wood_drops := func() -> int: return w.objects().filter(func(o): return o["kind"] == "drop" and o["item"] == "wood").size()
	var wood_before: int = wood_drops.call()
	check(not w.chop_down(tree, at) and not w.chop_down(tree, at) and tree["kind"] == "tree", "a tree stands up to a couple of chops")
	check(w.chop_down(tree, at) and tree["kind"] == "stump" and tree["tree"] == "tree" and tree["uid"] == uid and w.object_at(spot.x, spot.y) == tree,
		"the third brings it down to a stump")
	check(wood_drops.call() - wood_before == 3 and not tree.has("wood_left"), "and its wood")
	check(Models.key_for(tree).begins_with("stump:tree:") and Models.get_mesh(Models.key_for(tree)) != null, "stumps have a model")
	check(not w.is_walkable(spot.x + 0.5, spot.y + 0.5) and w.seats(tree).size() == 4, "a stump's in the way, and makes a seat")
	# Moving a rock somewhere new.
	var rock: Dictionary = w.objects().filter(func(o): return o["kind"] == "rock")[0]
	var from := Vector2i(rock["x"], rock["z"])
	var away := Vector3(-50, 0, -50)
	check(w.move_spot(rock, from, away) == "", "a rock can go back where it was")
	check(w.move_spot(rock, spot, away) != "" and w.move_spot(rock, d.plaza.get_center(), away) != "", "but not on the stump or the plaza")
	var water := Vector2i(-1, -1)
	var to := Vector2i(-1, -1)
	for z in range(2, d.height - 2):
		for x in range(2, d.width - 2):
			if water.x < 0 and d.tile(x, z) == IslandData.Tile.WATER:
				water = Vector2i(x, z)
			if to.x < 0 and Vector2i(x, z).distance_to(from) > 4.0 and w.move_spot(rock, Vector2i(x, z), away) == "":
				to = Vector2i(x, z)
	check(water.x >= 0 and w.move_spot(rock, water, away) != "", "nor in the water")
	check(to.x >= 0, "there's somewhere to move it to")
	check(w.move_spot(rock, to, Vector3(to.x + 0.5, 0, to.y + 0.5)) != "", "not where you're standing")
	# Carried by the Move tool: put back, then set down on the tile ahead.
	var mover := Player.new()
	add_child(mover)
	mover.setup(w, Vector3(to.x - 0.5, 0, to.y + 0.5), Appearance.DEFAULT)
	mover.facing = Vector3(1, 0, 0)
	var placing := Placement.new()
	placing.player = mover
	placing.world = w
	add_child(placing)
	var was_mode := Game.mode
	Game.mode = Game.Mode.PLAY
	placing.begin_move(rock)
	check(Game.mode == Game.Mode.PLACING and not w.node_of(rock["uid"]).visible, "the Move tool lifts a rock")
	placing.put_back()
	check(Game.mode == Game.Mode.PLAY and w.node_of(rock["uid"]).visible and w.object_at(from.x, from.y) == rock, "and can put it back")
	placing.begin_move(rock)
	placing._process(0.0)
	var use := InputEventAction.new()
	use.action = "use"
	use.pressed = true
	placing._unhandled_input(use)
	check(w.object_at(to.x, to.y) == rock and w.object_at(from.x, from.y).is_empty() and w.get_object(rock["uid"]) == rock
		and w.node_of(rock["uid"]) != null, "the rock moves, uid and all")
	# B with a tree in hand pockets it, looking just as it did, and it plants again from there.
	var pine: Dictionary = w.objects().filter(func(o): return o["kind"] == "tree")[0]
	var look := Models.key_for(pine)
	var pine_uid: int = pine["uid"]
	var pine_item := World.item_for(pine)
	Game.mode = Game.Mode.PLAY
	placing.begin_move(pine)
	var back := InputEventAction.new()
	back.action = "cancel"
	back.pressed = true
	placing._unhandled_input(back)
	var slot := Inventory.slots.find_custom(func(sl): return sl.get("id", "") == pine_item)
	check(Game.mode == Game.Mode.PLAY and w.get_object(pine_uid).is_empty() and slot >= 0
		and ItemDB.get_item(pine_item).get("category", "") == "nature", "B puts a carried tree in the pockets")
	var sample := World.nature_object(pine_item)
	sample["uid"] = -1
	var spot2 := Vector2i(-1, -1)
	for z in range(2, d.height - 2):
		for x in range(3, d.width - 2):
			var q := Vector2i(x, z)
			if spot2.x < 0 and q != to and w.move_spot(sample, q, away) == "" and w.object_at(x - 1, z).is_empty():
				spot2 = q
	check(spot2.x >= 0, "somewhere to plant it")
	if spot2.x >= 0 and slot >= 0:
		mover.position = Vector3(spot2.x - 0.5, 0, spot2.y + 0.5)
		placing.begin(slot)
		placing._process(0.0)
		placing._unhandled_input(use)
		var planted := w.object_at(spot2.x, spot2.y)
		check(planted.get("kind", "") == "tree" and Models.key_for(planted) == look and Inventory.count_of(pine_item) == 0,
			"and plants again from there, looking the same")
	Game.mode = was_mode
	mover.free()
	placing.free()
	# Trees want room round them.
	var other: Dictionary = w.objects().filter(func(o): return o["kind"] in ["tree", "fruit_tree"] and o["uid"] != uid)[0]
	var crowded := Vector2i(-1, -1)
	for q: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
		var c := Vector2i(other["x"], other["z"]) + q
		if crowded.x < 0 and w.move_spot(rock, c, away) == "":
			crowded = c
	if crowded.x >= 0:
		var tree2: Dictionary = w.objects().filter(func(o): return o["kind"] == "tree" and o["uid"] != other["uid"])[0]
		check(w.move_spot(tree2, crowded, away).contains("room"), "a tree can't go right beside another")
	# Kept with the island.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(w.to_save()))
	var w2 := World.new()
	add_child(w2)
	w2.setup(IslandGenerator.generate(7), saved)
	check(w2.object_at(spot.x, spot.y).get("kind", "") == "stump" and w2.object_at(to.x, to.y).get("uid", -1) == rock["uid"]
		and w2.object_at(from.x, from.y).is_empty(), "stumps and moved rocks are saved")
	w2.free()
	# Digging up: the stump goes, and a young tree comes up with its fruit.
	check(w.dig_out(tree) and w.object_at(spot.x, spot.y).is_empty() and w.get_object(uid).is_empty(), "the stump digs up")
	var fruit := d.native_fruit
	var sapling := w.plant_fruit(fruit, spot)
	var fruits := Inventory.count_of(fruit)
	check(w.dig_out(sapling) and Inventory.count_of(fruit) == fruits + 1 and w.object_at(spot.x, spot.y).is_empty(), "a young tree comes up whole, fruit back in the pockets")
	Inventory.remove_item(fruit, 1)
	w.free()


func _test_outdoor_decorations() -> void:
	var outdoor: Array[String] = []
	for id: String in ItemDB.items:
		if ItemDB.placeable(id).get("outdoor", false):
			outdoor.append(id)
	check(outdoor.size() >= 50, "lots of outdoor decorations (%d)" % outdoor.size())
	check(outdoor.all(func(id): return Models.get_mesh(ItemDB.placeable(id)["model"]) != null and ItemDB.get_item(id).get("price", 0) > 0),
		"each has a model and a price")
	check(["big_boulder", "great_crag", "standing_stone"].all(func(id): return outdoor.has(id)), "including big rocks")
	check(Recipes.recipes.has("log_pile") and Recipes.recipes.has("big_boulder"), "some can be made at the workbench")
	var d := IslandGenerator.generate(7)
	var w := World.new()
	add_child(w)
	w.setup(d)
	# Open, flat grass for an arch and a boulder.
	var at := Vector2i(-1, -1)
	var away := Vector3(-50, 0, -50)
	for z in range(4, d.height - 4):
		for x in range(4, d.width - 6):
			if at.x < 0 and w.can_place(Rect2i(x, z, 4, 1), away) and not d.plaza.grow(1).has_point(Vector2i(x, z)):
				at = Vector2i(x, z)
	check(at.x >= 0, "somewhere to put them")
	if at.x >= 0:
		var arch := w.place_item("garden_arch_blue", Rect2i(at, Vector2i(ItemDB.placeable("garden_arch_blue")["footprint"][0], 1)), 0)
		var rock := w.place_item("boulder", Rect2i(at + Vector2i(3, 0), Vector2i.ONE), 0)
		check(w.is_walkable(at.x + 0.5, at.y + 0.5) and not w.is_walkable(at.x + 3.5, at.y + 0.5), "you walk under an arch, not through a boulder")
		check(not w.can_place(Rect2i(at, Vector2i.ONE), away) and not arch.is_empty() and not rock.is_empty(), "but nothing else goes under it")
	w.free()
	# Not indoors.
	var room := World.new()
	room.interior = true
	add_child(room)
	room.setup(IslandData.room(6, 6))
	var placing := Placement.new()
	placing.world = room
	add_child(placing)
	Inventory.reset()
	Inventory.add_item("big_boulder")
	var was_mode := Game.mode
	Game.mode = Game.Mode.PLAY
	placing.begin(Inventory.slots.find_custom(func(sl): return sl.get("id", "") == "big_boulder"))
	check(Game.mode == Game.Mode.PLAY, "outdoor things can't go inside")
	Game.mode = was_mode
	placing.free()
	room.free()
	Inventory.reset()


func _test_paths_and_stairs() -> void:
	var d := IslandGenerator.generate(7)
	var w := World.new()
	add_child(w)
	w.setup(d)
	# Open, flat, low ground below a straight stretch of cliff to the north.
	var top := Vector2i(-1, -1)
	for z in range(4, d.height - 6):
		for x in range(4, d.width - 6):
			if top.x >= 0:
				break
			var plan := w.incline_plan(Vector2i(x, z), Vector2i(0, 1))
			if plan.has("top") and w.incline_plan(Vector2i(x + 1, z), Vector2i(0, 1)).has("top") and plan["dir"] == Vector2i(0, 1):
				top = Vector2i(x, z)
	check(top.x >= 0, "there's a cliff top with room for two slopes side by side")
	if top.x < 0:
		w.free()
		return
	w.build_incline(w.incline_plan(top, Vector2i(0, 1)))
	var beside := w.incline_plan(top + Vector2i(1, 0), Vector2i(0, 1))
	check(beside.has("top"), "a slope can go right beside another to make it wider (%s)" % beside.get("why", ""))
	w.build_incline(beside)
	check(d.is_ramp(top.x + 1, top.y + 1) and d.is_ramp(top.x + 1, top.y + 2), "and it does")
	# Paths: on the grass at the foot, then up the slope as stairs.
	var foot := top + Vector2i(0, 3)
	var lay := w.path_plan(foot + Vector2i(0, 1), Vector2i(0, -1), "stone")
	check(lay.get("kind", "") == "stone", "the path tool lays a stone path on grass")
	w.set_path(lay)
	check(w.path_plan(foot + Vector2i(0, 1), Vector2i(0, -1), "stone")["kind"] == "", "and the same path again takes it up")
	check(w.path_plan(foot + Vector2i(0, 1), Vector2i(0, -1), "brick")["kind"] == "brick", "or another kind swaps it")
	for k in [1, 2]:
		w.set_path(w.path_plan(top + Vector2i(0, k + 1), Vector2i(0, -1), "stone"))
	var stairs: float = w.ground_height(top.x + 0.5, top.y + 1.2)
	check(not is_equal_approx(stairs, d.height_at(top.x + 0.5, top.y + 1.2)), "a stone path turns the slope into stairs")
	var end := _walk(w, Vector2(foot) + Vector2(0.5, 0.5), Vector2(0, -1), 120)
	check(end.y > IslandData.tier_height(d.tier(top.x, top.y)) - 0.05, "which you can climb (got to %.2f)" % end.y)
	w.set_path(w.path_plan(top + Vector2i(0, 3), Vector2i(0, -1), "sand"))
	check(is_equal_approx(w.ground_height(top.x + 0.5, top.y + 2.5), d.height_at(top.x + 0.5, top.y + 2.5)), "sand on a slope stays a slope")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(w.to_save()))
	var w2 := World.new()
	add_child(w2)
	w2.setup(IslandGenerator.generate(7), saved)
	check(w2.paths.size() == w.paths.size() and w2.paths.get(d.idx(top.x, top.y + 1), "") == "stone", "paths are kept with the island")
	w2.free()
	# The slope tool takes away slopes you built, but not the island's own.
	var remove := w.slope_plan(top + Vector2i(1, 3), Vector2i(0, -1))
	check(remove.has("remove"), "facing a slope you built, the slope tool takes it away")
	w.remove_slope(remove)
	check(not d.is_ramp(top.x + 1, top.y + 1) and w.built_ramps.size() == 1, "and it's gone")
	# The island's own slopes can go too, and stay gone.
	var own := Vector2i(-1, -1)
	for i: int in d.ramps:
		var t := Vector2i(i % d.width, i / d.width)
		if own.x < 0 and w.built_ramps.all(func(r): return Vector2i(r[0], r[1]) + Vector2i(r[2], r[3]) != t and Vector2i(r[0], r[1]) + Vector2i(r[2], r[3]) * 2 != t):
			own = t
	var take := w.slope_plan(own - Vector2i(1, 0), Vector2i(1, 0))
	check(take.has("remove"), "the island's own slopes can be taken away")
	w.remove_slope(take)
	check(not d.is_ramp(own.x, own.y) and w.removed_ramps.size() == 1, "and they go")
	var kept: Dictionary = JSON.parse_string(JSON.stringify(w.to_save()))
	var w3 := World.new()
	add_child(w3)
	w3.setup(IslandGenerator.generate(7), kept)
	check(not w3.data.is_ramp(own.x, own.y) and w3.data.is_ramp(top.x, top.y + 1), "and stay gone after saving")
	w3.free()
	check(w.path_plan(d.plaza.get_center() - Vector2i(1, 0), Vector2i(1, 0), "stone").has("why"), "no paths over the plaza")
	w.free()


func _test_storage() -> void:
	Inventory.reset()
	Inventory.add_item("wood", 15)
	Inventory.add_item("flimsy_axe")
	var axe := -1
	for i in Inventory.slots.size():
		if Inventory.slots[i].get("id", "") == "flimsy_axe":
			axe = i
	Inventory.slots[axe]["durability"] = 7
	check(Inventory.store(0) and Inventory.store(axe) and Inventory.count_of("wood") == 0 and Inventory.storage.size() == 2,
		"pockets can be put away in storage")
	Inventory.add_item("wood", 5)
	Inventory.store(0)
	check(Inventory.storage.size() == 2 and Inventory.storage[0]["count"] == 20, "and join the stack already there")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(Inventory.to_save()))
	Inventory.reset()
	Inventory.from_save(saved)
	check(Inventory.storage.size() == 2 and int(Inventory.storage[1]["durability"]) == 7, "storage is saved, tools' wear and all")
	check(Inventory.retrieve(1) and Inventory.count_of("flimsy_axe") == 1 and Inventory.storage.size() == 1, "and things come back out")
	check(StorageMenu.group_of("wood") == "nature" and StorageMenu.group_of("meadow_dresser_sage") == "furniture", "storage sorts by kind")
	check(ItemDB.placeable("meadow_dresser_sage").get("storage", false), "dressers open storage at home")
	Inventory.reset()


func _test_weather() -> void:
	Story.reset()
	Weather.force = ""
	Weather.force_season = ""
	# Seasons by hemisphere.
	var october := {"month": 10, "day": 8}
	check(Weather.season_on(october)[0] == "spring", "October is spring in the south (the default)")
	Story.flags["hemisphere"] = "north"
	check(Weather.season_on(october)[0] == "autumn" and Weather.season_on({"month": 1, "day": 20})[0] == "winter",
		"and autumn in the north, where January's winter")
	Story.flags.erase("hemisphere")
	# Plans are the same however often you ask, and every kind of day turns up.
	var kinds := {}
	var sane := true
	for key in range(20000, 20400):
		var p := Weather.plan(key)
		kinds[p["kind"]] = true
		if p["kind"] in ["showers", "rain", "storm"]:
			sane = sane and p["from"] < p["to"]
		sane = sane and (not p["snow"] or Weather.season_on(Weather.date_of(key))[0] == "winter")
	check(Weather.plan(20123) == Weather.plan(20123), "a day's weather is the same every time you look")
	check(kinds.size() == Weather.KINDS.size() and sane, "a year has every kind of weather, and snow only in winter (%s)" % [kinds.keys()])
	Weather.force = "rain"
	Weather.update(12.0)
	check(Weather.rain > 0.5 and Weather.wetness > 0.5 and Weather.clouds > 0.9 and Weather.forecast() != "", "rain: wet ground under grey skies")
	var snail: Dictionary = ItemDB.bugs["snail"]
	check(Critters.weather_suits(snail) and not Critters.weather_suits(ItemDB.bugs["white_butterfly"]), "snails come out in the rain, butterflies hide")
	Weather.force = "clear"
	Weather.update(12.0)
	check(Weather.rain == 0.0 and Weather.wetness == 0.0 and not Critters.weather_suits(snail), "and not when it's dry")
	Weather.force = "snow"
	Weather.force_season = "winter"
	Weather.update(12.0)
	check(Weather.snow > 0.5 and Weather.rain == 0.0 and Weather.snow_cover > 0.5, "in deep winter it snows instead, and settles")
	Weather.force = "clear"
	Weather.force_season = "autumn"
	Weather.update(12.0)
	check(Weather.autumn > 0.0 and Weather.blossom == 0.0, "autumn turns the leaves")
	Weather.force = "clear"
	Weather.force_season = ""
	Weather.update(12.0)
	check(ItemDB.tool_type("umbrella_red") == "umbrella" and Models.get_mesh("umbrella:e0656b").get_faces().size() > 60,
		"there are umbrellas to hold up in the rain")
	check(InputMap.has_action("look_up"), "you can look up at the sky")
	# Tour islands keep their own time, weather and season, and home's come back after.
	var day := GameClock.day_key()
	GameClock.tour_shift = 8 * 3600
	Weather.force = ""
	Weather.tour = {"kind": "rain", "season": "autumn"}
	Weather.update(GameClock.hour_float())
	check(GameClock.day_key() == day and Weather.rain > 0.5 and Weather.season == "autumn" and Weather.autumn > 0.5,
		"a tour island has its own hour, weather and season, but it's still the same day")
	GameClock.tour_shift = 0
	Weather.tour = {}
	Weather.force = "clear"
	Weather.update(12.0)
	var t := World.new()
	t.tour = true
	add_child(t)
	t.setup(IslandGenerator.generate_tour(4242, "apple", "tulip"))
	var luck := RandomNumberGenerator.new()
	luck.seed = 7
	var found := load("res://scripts/main.gd").scatter_furniture(t, luck, Vector3(t.data.width / 2.0, 0, t.data.height - 4.0)) as int
	var pieces := t.objects().filter(func(o): return o["kind"] == "placed")
	check(found >= 1 and found <= 2 and pieces.size() == found, "a piece or two of furniture lies about on a tour island")
	if not pieces.is_empty():
		var before := Inventory.count_of(pieces[0]["item"])
		check(t.pack_up(pieces[0]) and Inventory.count_of(pieces[0]["item"]) == before + 1, "and you can pick it up")
	t.free()
	Inventory.reset()
	Story.reset()


func _test_sounds() -> void:
	# Every sound the game asks for by name is there (assets/sfx, tools/make_sfx.sh).
	var wanted := {}
	var calls := RegEx.create_from_string("Sfx\\.play(?:_at|_later)?\\(\"([a-z0-9_]+)\"")
	var dirs: Array[String] = ["res://scripts/", "res://scripts/autoload/", "res://scripts/ui/", "res://scripts/world/",
		"res://scripts/player/", "res://scripts/npc/"]
	for dir in dirs:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				for m in calls.search_all(FileAccess.get_file_as_string(dir + file)):
					wanted[m.get_string(1)] = true
	for s: String in Sfx.LAYERS.values():
		wanted[s] = true
	for s: Array in Sfx.STEPS.values():
		wanted[s[0]] = true
	for v in ["a", "e", "i", "o", "u"]:
		wanted["voice_" + v] = true
	for n in range(1, 5):
		wanted["bird_%d" % n] = true
	var missing := wanted.keys().filter(func(k): return Sfx.takes(k).is_empty())
	check(wanted.size() > 30 and missing.is_empty(), "every sound the game plays is there (%d; missing %s)" % [wanted.size(), missing])
	check(Sfx.takes("step_grass").size() >= 3, "footsteps come in a few takes")
	check(not is_equal_approx(Sfx.voice_pitch("poppy"), Sfx.voice_pitch("lucy")), "characters have their own voices")


func _test_tour_crossings_and_pole() -> void:
	# Tour islands: no big patch of land is cut off from the rest by a river.
	var cut_off := 0
	var tours := 0
	for n in range(1, 41):
		var t := IslandGenerator.generate_tour(n * 7919, "apple", "tulip")
		var labels := IslandGenerator.regions(t)
		var sizes := {}
		for l in labels:
			if l >= 0:
				sizes[l] = sizes.get(l, 0) + 1
		var big := sizes.values().filter(func(v): return v >= 120)
		tours += 1
		cut_off += 1 if big.size() > 1 else 0
		if n <= 8:
			# Marlow lands on the biggest piece.
			var w := World.new()
			w.tour = true
			add_child(w)
			w.setup(t)
			var dock := w.add_dock(Vector2i(t.width / 2, t.height / 2))
			if not dock.is_empty():
				var arrive: Vector3 = w.dock_spots(dock)["arrive"]
				var main := -1
				for l: int in sizes:
					if main < 0 or sizes[l] > sizes[main]:
						main = l
				var at := labels[t.idx(floori(arrive.x), floori(arrive.z))]
				check(at == main or at < 0, "Marlow lands on the main part of tour island %d" % n)
			w.free()
	check(cut_off <= 2, "tour islands aren't cut in two by rivers (%d of %d were)" % [cut_off, tours])
	# The vaulting pole: across a river, not over the sea.
	check(ItemDB.tool_type("vaulting_pole") == "pole" and not ItemDB.get_item("vaulting_pole").has("durability")
		and Recipes.recipes.has("vaulting_pole"), "there's a vaulting pole to make, and it never wears out")
	var d := IslandGenerator.generate(7)
	var w := World.new()
	add_child(w)
	w.setup(d)
	var vaults := 0
	var good := 0
	for z in range(2, d.height - 2):
		for x in range(2, d.width - 2):
			if vaults >= 12 or d.tile(x, z) != IslandData.Tile.WATER or d.tile(x, z - 1) != IslandData.Tile.GRASS:
				continue
			var from := Vector3(x + 0.5, w.ground_height(x + 0.5, z - 0.6), z - 0.6)
			if not w.is_walkable(from.x, from.z):
				continue
			var landing := w.vault_landing(from, Vector3(0, 0, 1))
			vaults += 1
			if landing.has("to"):
				var to: Vector3 = landing["to"]
				good += 1 if to.z > z + 0.9 and w.is_walkable(to.x, to.z) and to.y <= from.y + IslandData.MAX_STEP else 0
	check(vaults > 3 and good > 0, "the pole vaults from a riverbank to the far side (%d of %d spots)" % [good, vaults])
	var beach := Vector3.ZERO
	for z in range(d.height - 1, 0, -1):
		if beach == Vector3.ZERO and d.tile(d.width / 2, z) == IslandData.Tile.SAND and d.tile(d.width / 2, z + 1) == IslandData.Tile.OCEAN:
			beach = Vector3(d.width / 2 + 0.5, w.ground_height(d.width / 2 + 0.5, z + 0.5), z + 0.5)
	check(w.vault_landing(beach, Vector3(0, 0, 1)).has("why"), "but not out to sea")
	w.free()
	check(UIStyle.acorns(1250) == "1,250 Acorns" and UIStyle.acorns(7) == "7 Acorns" and UIStyle.acorns(1000000) == "1,000,000 Acorns",
		"acorns are counted with commas")
