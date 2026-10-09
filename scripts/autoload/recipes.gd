extends Node
## DIY recipes (data/recipes.json, plus furniture series pieces) and which ones the
## player knows. Everything you'd make and keep has one: whatever has no recipe written
## down gets one worked out from what it's made of and what it costs (`made_up`).

signal learned(item_id: String)

const DATA_PATH := "res://data/recipes.json"
## Used up when customising something at the workbench.
const KIT := "customisation_kit"

var recipes: Dictionary = {}
var known: Array[String] = []


func _ready() -> void:
	recipes = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))["recipes"]
	recipes.merge(ItemDB.series_recipes)
	var ids: Array = ItemDB.items.keys()
	ids.sort()
	for id: String in ids:
		if not recipes.has(id) and craftable(id):
			recipes[id] = {"materials": made_up(id)}
	reset()


## Whether an item is something you'd make at a workbench: furniture and outdoor things,
## wallpaper, flooring, rugs and curtains, designed clothes and umbrellas. One recipe
## per piece: its other colourways are made by customising it.
static func craftable(id: String) -> bool:
	var def := ItemDB.get_item(id)
	if def.get("basic", false) or id.contains("."):
		return false
	match def.get("category", ""):
		"furniture", "interior", "clothing":
			pass
		"tool":
			if def.get("tool", "") != "umbrella":
				return false
		_:
			return false
	var placeable: Dictionary = def.get("placeable", {})
	if placeable.get("structure", false) or placeable.has("builds") or placeable.has("room") or placeable.has("inside"):
		return false
	var all := ItemDB.variants_of(id)
	return all.is_empty() or all[0] == id


## What a thing takes to make, worked out from its name and price: stone for rocks and
## walls, clay for pots and tiles, iron for lamps and pans, gold for trophies and gems,
## cloth for soft things and clothes, branches for plants and wicker, and wood for the
## rest (and the frames of the others). Dearer things take more.
static func made_up(id: String) -> Dictionary:
	var def := ItemDB.get_item(id)
	var words := (id + " " + String(def.get("name", ""))).to_lower()
	var price := int(def.get("price", 200))
	var units := clampi(roundi(price / 110.0), 2, 24)
	var category: String = def.get("category", "")
	if category == "clothing":
		return {"cloth": clampi(roundi(price / 90.0), 2, 10)}
	if category == "tool":
		return {"cloth": 3, "tree_branch": 2}
	var main := "wood"
	for entry: Array in MADE_OF:
		if (entry[1] as Array).any(func(w: String): return words.contains(w)):
			main = entry[0]
			break
	if category == "interior" and main == "wood" and words.contains("wallpaper"):
		return {"wood": maxi(1, units / 2), "clay": maxi(1, units - units / 2)}
	match main:
		"gold_nugget":
			return {"gold_nugget": clampi(units / 6, 1, 3), "wood": maxi(2, units / 2)}
		"wood":
			return {"wood": units}
	# Mostly the main stuff, with a wooden frame, except for things made all of it.
	var whole: bool = category == "interior" or (ALL_OF as Array).any(func(w: String): return words.contains(w))
	if whole:
		return {main: units}
	var frame := maxi(1, units / 3)
	return {main: units - frame, "wood": frame}


## Words in an item's id or name, and what it's mostly made of. The first match wins.
const MADE_OF := [
	["wood", ["crate", "wooden", "log", "plank", "barrel", "stage", "sign", "box", "potato"]],
	["gold_nugget", ["gold", "trophy", "golden", "gem"]],
	["iron_nugget", ["iron", "lamp", "lantern", "hydrant", "frying_pan", "stove", "oven", "fridge", "bell", "kettle",
		"camera", "skates", "water_tower", "clock", "radio", "cauldron", "telescope", "sink"]],
	["stone", ["rock", "boulder", "stone", "crag", "pebble", "rubble", "grave", "shrine", "well", "outcrop", "brick",
		"statue", "fountain", "post", "pillar"]],
	["clay", ["pot", "vase", "jar", "plate", "mug", "tile", "teacup", "planter", "cactus", "bowl", "teapot", "dinner",
		"burger", "cookie", "chocolate"]],
	["cloth", ["rug", "carpet", "curtain", "cushion", "pillow", "plush", "sofa", "armchair", "bed", "sleeping", "tent",
		"canopy", "fabric", "pennant", "flag", "quilt", "blanket", "hammock", "beanbag", "futon", "mat", "parasol"]],
	["tree_branch", ["tree", "fir", "shrub", "bush", "wreath", "broom", "basket", "wicker", "rush", "straw"]],
]
## Things made all of their main stuff, without a wooden frame.
const ALL_OF := ["rock", "boulder", "crag", "pebble", "rubble", "rug", "carpet", "curtain", "cushion", "pillow",
	"plush", "pennant", "flag", "brick", "plate", "pot", "jar", "mug", "teacup", "tree", "fir", "shrub", "bush", "wreath"]


## Back to the starter set.
func reset() -> void:
	known.clear()
	for id in recipes:
		if recipes[id].get("known", false):
			known.append(id)


func materials(id: String) -> Dictionary:
	return recipes.get(id, {}).get("materials", {})


func makes(id: String) -> int:
	return int(recipes.get(id, {}).get("count", 1))


func is_known(id: String) -> bool:
	return known.has(id)


func can_craft(id: String) -> bool:
	for mat in materials(id):
		if Inventory.count_of(mat) < int(materials(id)[mat]):
			return false
	return true


## Uses up the materials and adds the result to the pockets. Returns false if the
## materials are missing or the result won't fit.
func craft(id: String) -> bool:
	if not can_craft(id):
		return false
	# The result must fit once the materials are gone; check with a dry run on a copy.
	var before := Inventory.to_save()
	for mat in materials(id):
		Inventory.remove_item(mat, int(materials(id)[mat]))
	if Inventory.add_item(id, makes(id)) > 0:
		Inventory.from_save(before)
		return false
	Journal.add("crafted")
	return true


## Remakes the item in a pocket slot as another variant of itself (a new colourway),
## using a customisation kit. Returns "" on success, or why not.
func customise(slot: int, new_id: String) -> String:
	var entry := Inventory.slots[slot]
	if entry.is_empty() or entry["id"] == new_id or not new_id in ItemDB.variants_of(entry["id"]):
		return "That can't be changed into that."
	if Inventory.count_of(KIT) < 1:
		return "You need a customisation kit. Lucy sells them."
	entry["id"] = new_id
	Inventory.remove_item(KIT, 1)
	Journal.add("customised")
	if slot == Inventory.equipped_slot:
		Events.equipped_changed.emit(new_id)
	return ""


## Learns a random recipe the player doesn't know yet. Returns its id, or "" if they
## know them all.
func learn_random(rng: RandomNumberGenerator) -> String:
	var unknown: Array[String] = []
	for id in recipes:
		if not known.has(id):
			unknown.append(id)
	if unknown.is_empty():
		return ""
	var id := unknown[rng.randi() % unknown.size()]
	known.append(id)
	learned.emit(id)
	return id


## Learns a particular recipe (from a milestone or the stamp exchange).
func learn(id: String) -> void:
	if recipes.has(id) and not known.has(id):
		known.append(id)
		learned.emit(id)
		Sfx.play("jingle_learn", 0.0, 1.0, 0.0)


func to_save() -> Array:
	return known.duplicate()


func from_save(saved: Array) -> void:
	reset()
	for id in saved:
		if recipes.has(id) and not known.has(id):
			known.append(id)
