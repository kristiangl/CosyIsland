class_name NpcData
extends RefCounted
## The island's characters from data/characters.json: names, looks and species.

const DATA_PATH := "res://data/characters.json"
const NEIGHBOURS_PATH := "res://data/neighbours.json"

static var _data: Dictionary = {}


static func get_character(id: String) -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		for nid in neighbours():
			var n: Dictionary = neighbours()[nid]
			n["title"] = "Neighbour"
			n["tag"] = "#" + String(n["home"]["roof"])
			_data[nid] = n
	return _data.get(id, {})


static var _neighbours: Dictionary = {}


## The animal neighbours who can move to the island (data/neighbours.json).
static func neighbours() -> Dictionary:
	if _neighbours.is_empty():
		_neighbours = JSON.parse_string(FileAccess.get_file_as_string(NEIGHBOURS_PATH))["neighbours"]
	return _neighbours


static func is_neighbour(id: String) -> bool:
	return neighbours().has(id)


static func display_name(id: String) -> String:
	return get_character(id).get("name", id.capitalize())


## A character model dressed and furred for this character.
static func model(id: String, curved := true) -> CharacterModel:
	var def := get_character(id)
	var look := Appearance.DEFAULT.duplicate()
	look.merge(def.get("look", {}), true)
	var m := CharacterModel.new(look)
	m.curved = curved
	var sp: Dictionary = def.get("species", {})
	for key in sp:
		m.species[key] = sp[key] if key in ["kind", "head"] or sp[key] is bool else Color(sp[key])
	return m
