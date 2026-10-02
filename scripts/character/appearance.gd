class_name Appearance
extends RefCounted
## Character appearance: a plain dictionary of option ids (saved as JSON), plus helpers
## over the catalogue in data/appearance.json.
##
## Keys and the catalogue list each one draws from:
##   skin, eyes, eye_color, brows, mouth, cheeks, hair, hair_color,
##   top, top_color, top_color2, top_pattern, bottom, bottom_color,
##   shoes, shoe_color, hat, hat_color, glasses

const DATA_PATH := "res://data/appearance.json"

## Which catalogue list each appearance key uses.
const SOURCES := {
	"skin": "skin", "eyes": "eyes", "eye_color": "eye_color", "brows": "brows",
	"mouth": "mouth", "cheeks": "cheeks", "hair": "hair", "hair_color": "hair_color",
	"top": "top", "top_color": "colors", "top_color2": "colors", "top_pattern": "pattern",
	"bottom": "bottom", "bottom_color": "colors", "shoes": "shoes", "shoe_color": "colors",
	"hat": "hat", "hat_color": "colors", "glasses": "glasses",
}

const DEFAULT := {
	"skin": "peach", "eyes": "classic", "eye_color": "brown", "brows": "soft",
	"mouth": "smile", "cheeks": "blush", "hair": "short", "hair_color": "brown",
	"top": "tee", "top_color": "coral", "top_color2": "white", "top_pattern": "plain",
	"bottom": "shorts", "bottom_color": "navy", "shoes": "sneakers", "shoe_color": "white",
	"hat": "none", "hat_color": "red", "glasses": "none",
}

static var _catalogue: Dictionary = {}


static func catalogue() -> Dictionary:
	if _catalogue.is_empty():
		_catalogue = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _catalogue


static func options(key: String) -> Array:
	return catalogue()[SOURCES[key]]


## Index of the chosen option for a key (what the shaders use for styles).
static func index_of(look: Dictionary, key: String) -> int:
	var list := options(key)
	for i in list.size():
		if list[i]["id"] == look.get(key, ""):
			return i
	return 0


static func option(look: Dictionary, key: String) -> Dictionary:
	return options(key)[index_of(look, key)]


static func color(look: Dictionary, key: String) -> Color:
	return Color(option(look, key).get("color", "#ff00ff"))


static func display_name(look: Dictionary, key: String) -> String:
	var opt := option(look, key)
	return opt.get("name", opt["id"].capitalize())


## Steps an option forwards or backwards, wrapping around.
static func step(look: Dictionary, key: String, direction: int) -> void:
	var list := options(key)
	look[key] = list[posmod(index_of(look, key) + direction, list.size())]["id"]


## A copy of the default look with any saved values that still exist in the catalogue.
static func sanitise(saved: Dictionary) -> Dictionary:
	var look := DEFAULT.duplicate()
	for key in SOURCES:
		if saved.has(key):
			for opt in options(key):
				if opt["id"] == saved[key]:
					look[key] = saved[key]
	return look


static func random(rng: RandomNumberGenerator) -> Dictionary:
	var look := DEFAULT.duplicate()
	for key in SOURCES:
		var list := options(key)
		look[key] = list[rng.randi() % list.size()]["id"]
	# Keep random characters tidy: mostly plain clothes, few hats and glasses.
	if rng.randf() < 0.6:
		look["top_pattern"] = "plain"
	if rng.randf() < 0.6:
		look["hat"] = "none"
	if rng.randf() < 0.75:
		look["glasses"] = "none"
	return look


static func is_full_body_top(look: Dictionary) -> bool:
	return option(look, "top").get("full_body", false)
