class_name NpcData
extends RefCounted
## The island's characters from data/characters.json: names, looks and species.

const DATA_PATH := "res://data/characters.json"

static var _data: Dictionary = {}


static func get_character(id: String) -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data.get(id, {})


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
		m.species[key] = sp[key] if key == "kind" else Color(sp[key])
	return m
