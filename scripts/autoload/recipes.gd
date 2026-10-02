extends Node
## DIY recipes (data/recipes.json) and which ones the player knows.

signal learned(item_id: String)

const DATA_PATH := "res://data/recipes.json"

var recipes: Dictionary = {}
var known: Array[String] = []


func _ready() -> void:
	recipes = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))["recipes"]
	reset()


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
	return true


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


func to_save() -> Array:
	return known.duplicate()


func from_save(saved: Array) -> void:
	reset()
	for id in saved:
		if recipes.has(id) and not known.has(id):
			known.append(id)
