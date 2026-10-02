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
		check(d.tiles.count(IslandData.Tile.WATER) >= 60, "seed %d has rivers and ponds" % s)
		var reach := _reachable_fraction(d)
		check(reach > 0.9, "seed %d: %.0f%% of land reachable from spawn" % [s, reach * 100.0])
	print("Generated 20 islands in %d ms" % (Time.get_ticks_msec() - t0))


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
	# Every part option should build a mesh without errors.
	for key in ["hair", "top", "bottom", "shoes", "hat", "glasses"]:
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
	w.free()

	# Islands saved before the DIY update get a workbench added on load.
	var old := IslandGenerator.generate(42)
	var old_objects: Array = old.objects.filter(func(o): return o["kind"] != "placed")
	var w3 := World.new()
	add_child(w3)
	w3.setup(IslandGenerator.generate(42), JSON.parse_string(JSON.stringify({"objects": old_objects, "next_uid": old.next_uid, "day_key": 0})))
	check(w3.objects().filter(func(o): return o["kind"] == "placed" and o["item"] == "workbench").size() == 1, "old saves get a plaza workbench")
	w3.free()
	Inventory.reset()
	Recipes.reset()
