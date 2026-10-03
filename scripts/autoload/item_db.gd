extends Node
## Item definitions loaded from data/items.json.
##
## Fruit and flower items are generated from their species tables so each species and
## colour gets an item id like "apple" or "tulip_red".

const DATA_PATH := "res://data/items.json"
const CLOTHING_PATH := "res://data/clothing.json"
const FURNITURE_DIR := "res://data/furniture/"
## Placeable settings a series piece passes straight through to its items.
const PIECE_PLACEABLE := ["seat", "surface", "small", "light", "bed", "effects"]
## Which appearance keys a piece of clothing sets, by slot: style, colour, second colour,
## pattern.
const SLOT_KEYS := {
	"top": ["top", "top_color", "top_color2", "top_pattern"],
	"bottom": ["bottom", "bottom_color", "", ""],
	"shoes": ["shoes", "shoe_color", "", ""],
	"hat": ["hat", "hat_color", "", ""],
}

var items: Dictionary = {}
var fruits: Dictionary = {}
var flowers: Dictionary = {}
## Furniture series by id: {name, desc, variants, pieces} as in data/furniture/<id>.json.
var series: Dictionary = {}
## DIY recipes for series pieces (the first variant of each piece with a recipe), merged
## into Recipes.
var series_recipes: Dictionary = {}
## Item ids of every variant of a base (clothes and series furniture), in data order.
var _variants: Dictionary = {}


func _ready() -> void:
	var text := FileAccess.get_file_as_string(DATA_PATH)
	var data: Dictionary = JSON.parse_string(text)
	items = data["items"]
	fruits = data["fruits"]
	flowers = data["flowers"]
	for id in fruits:
		var f: Dictionary = fruits[id]
		items[id] = {
			"name": f["name"], "category": "fruit", "stack": 10, "price": 100,
			"color": f["color"], "desc": "A fresh, juicy %s." % f["name"].to_lower(),
		}
	for id in flowers:
		var fl: Dictionary = flowers[id]
		for colour in fl["colors"]:
			items["%s_%s" % [id, colour]] = {
				"name": "%s %s" % [colour.capitalize(), fl["name"].to_lower() + "s"],
				"category": "flower", "stack": 10, "price": 40, "color": fl["colors"][colour],
				"species": id, "flower_color": colour,
				"desc": "Freshly picked. They'd look lovely planted somewhere.",
			}
	_load_clothing()
	_load_furniture()


## Designed clothes come as bases with colourways (data/clothing.json); each colourway
## becomes an item "<base>_<variant>" that sets part of the character's look when worn.
func _load_clothing() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLOTHING_PATH))
	for base: Dictionary in data["clothes"]:
		var keys: Array = SLOT_KEYS[base["slot"]]
		for v: Dictionary in base["variants"]:
			var look := {keys[0]: base["style"], keys[1]: v["colors"][0]}
			if keys[2] != "":
				look[keys[2]] = v["colors"][1]
				look[keys[3]] = v.get("pattern", "plain")
			var hex := "#ffffff"
			var hex2 := ""
			for c in Appearance.options("top_color"):
				if c["id"] == v["colors"][0]:
					hex = c["color"]
				if v["colors"].size() > 1 and c["id"] == v["colors"][1]:
					hex2 = c["color"]
			items["%s_%s" % [base["id"], v["id"]]] = {
				"name": "%s (%s)" % [base["name"], v["name"]], "category": "clothing", "stack": 1,
				"price": base["price"], "color": hex, "desc": base.get("desc", ""),
				"theme": base.get("theme", ""), "slot": base["slot"], "wear": look,
				"base": base["id"], "variant": v["id"], "swatch": [hex, hex2 if hex2 != "" else hex],
			}
			_add_variant(base["id"], "%s_%s" % [base["id"], v["id"]])


## Furniture series (data/furniture/*.json): every piece comes in each of its series'
## variants, as an item "<piece>_<variant>" built by SeriesModels from its "build" entry.
func _load_furniture() -> void:
	var files := Array(DirAccess.get_files_at(FURNITURE_DIR))
	files.sort()
	for file: String in files:
		if not file.ends_with(".json"):
			continue
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FURNITURE_DIR + file))
		series[data["id"]] = data
		for piece: Dictionary in data["pieces"]:
			for v: Dictionary in data["variants"]:
				var id := "%s_%s" % [piece["id"], v["id"]]
				var placeable := {"footprint": piece["footprint"], "model": "series:" + id, "rotatable": true}
				for key: String in PIECE_PLACEABLE:
					if piece.has(key):
						placeable[key] = piece[key]
				items[id] = {
					"name": "%s (%s)" % [piece["name"], v["name"]], "category": "furniture", "stack": 1,
					"price": piece["price"], "color": "#" + v["wood"], "desc": piece.get("desc", ""),
					"series": data["id"], "base": piece["id"], "variant": v["id"], "placeable": placeable,
					"swatch": ["#" + v["wood"], "#" + _bolder(v["fabric"][0], v["fabric"][1])],
					"build": {"kind": piece["kind"], "params": piece.get("params", {}), "variant": v},
				}
				_add_variant(piece["id"], id)
			if piece.has("recipe"):
				series_recipes["%s_%s" % [piece["id"], data["variants"][0]["id"]]] = {"materials": piece["recipe"]}


## The more colourful of two hex colours (a fabric's print colour rather than its cream).
static func _bolder(a: String, b: String) -> String:
	return a if Color(a).s >= Color(b).s else b


func _add_variant(base: String, id: String) -> void:
	if not _variants.has(base):
		_variants[base] = []
	_variants[base].append(id)


## Every variant of the same base as `id` (including itself), or [] if it has none.
func variants_of(id: String) -> Array:
	var list: Array = _variants.get(items.get(id, {}).get("base", ""), [])
	return list if list.size() > 1 else []


## The variant's own name, e.g. "Sage" for "Meadow Chair (Sage)".
func variant_name(id: String) -> String:
	var n := display_name(id)
	var open := n.rfind("(")
	return n.substr(open + 1, n.length() - open - 2) if open >= 0 and n.ends_with(")") else n


## Two colours that tell a variant apart (wood and fabric, or a garment's two colours).
func swatch(id: String) -> Array[Color]:
	var s: Array = items.get(id, {}).get("swatch", [])
	if s.size() < 2:
		return [color_of(id), color_of(id)]
	return [Color(s[0]), Color(s[1])]


func is_clothing(id: String) -> bool:
	return items.get(id, {}).get("category", "") == "clothing"


func get_item(id: String) -> Dictionary:
	return items.get(id, {})


func has_item(id: String) -> bool:
	return items.has(id)


func display_name(id: String) -> String:
	return items.get(id, {}).get("name", id)


func color_of(id: String) -> Color:
	return Color(items.get(id, {}).get("color", "#ffffff"))


func max_stack(id: String) -> int:
	return int(items.get(id, {}).get("stack", 1))


func is_tool(id: String) -> bool:
	return items.get(id, {}).get("category", "") == "tool"


func tool_type(id: String) -> String:
	return items.get(id, {}).get("tool", "")


func placeable(id: String) -> Dictionary:
	return items.get(id, {}).get("placeable", {})
