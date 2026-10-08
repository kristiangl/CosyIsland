extends Node
## Item definitions loaded from data/items.json.
##
## Fruit and flower items are generated from their species tables so each species and
## colour gets an item id like "apple" or "tulip_red".

const DATA_PATH := "res://data/items.json"
const CLOTHING_PATH := "res://data/clothing.json"
const FURNITURE_DIR := "res://data/furniture/"
const CREATURES_PATH := "res://data/creatures.json"
const WHERE_TEXT := {
	"sea": "Caught in the sea.", "river": "Caught in a river.", "pond": "Caught in a pond.",
	"flowers": "Found among the flowers.", "air": "Found flitting about.", "grass": "Found in the grass.",
	"trees": "Found on a tree.", "rocks": "Found on a rock.", "beach": "Found on the beach.",
	"water": "Found by the water.",
}
## Placeable settings a series piece passes straight through to its items.
const PIECE_PLACEABLE := ["seat", "surface", "small", "light", "bed", "effects", "rug"]
## Which appearance keys a piece of clothing sets, by slot: style, colour, second colour,
## pattern.
## What Lucy pays for everyday clothes (see _make_basic).
const BASIC_PRICE := {"top": 240, "bottom": 200, "shoes": 160, "hat": 140}
const SLOT_KEYS := {
	"top": ["top", "top_color", "top_color2", "top_pattern"],
	"bottom": ["bottom", "bottom_color", "", ""],
	"shoes": ["shoes", "shoe_color", "", ""],
	"hat": ["hat", "hat_color", "", ""],
}

var items: Dictionary = {}
var fruits: Dictionary = {}
var flowers: Dictionary = {}
## Painted colourways for the original wooden furniture, by variant id (data/items.json
## "colourways"): {name, wood, dark, light}.
var woods: Dictionary = {}
## Fish and bugs by id (data/creatures.json), each also an item of the same id.
var fish: Dictionary = {}
var bugs: Dictionary = {}
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
		# Rare colours (only found on some tour islands) join the usual ones.
		for colour: String in fl.get("rare_colors", {}):
			fl["colors"][colour] = fl["rare_colors"][colour]
		for colour in fl["colors"]:
			# A picked flower: wear it in your hair or stand it in a bud vase.
			var picked := "%s_%s" % [id, colour]
			items[picked] = {
				"name": "%s %s" % [colour.capitalize(), fl["name"].to_lower()],
				"category": "flower", "stack": 10, "price": 40 if not is_rare_flower(id, colour) else 160, "color": fl["colors"][colour],
				"species": id, "flower_color": colour,
				"desc": "Freshly picked. Wear it in your hair, or put it in a vase.",
				"placeable": {"footprint": [1, 1], "model": "vase:" + picked, "rotatable": true, "small": true},
			}
			# The whole plant, dug up with a shovel: plant it somewhere else.
			items[picked + "_plant"] = {
				"name": "%s %s plant" % [colour.capitalize(), fl["name"].to_lower()],
				"category": "flower_plant", "stack": 10, "price": 80 if not is_rare_flower(id, colour) else 320, "color": fl["colors"][colour],
				"species": id, "flower_color": colour,
				"desc": "Roots and all. Plant it somewhere and it'll keep flowering.",
			}
	_load_clothing()
	_load_furniture()
	_load_colourways(data.get("colourways", {}))
	_load_creatures()


## A colour of flower only found on some tour islands.
func is_rare_flower(species: String, colour: String) -> bool:
	return flowers.get(species, {}).get("rare_colors", {}).has(colour)


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
## variants, as an item "<piece>_<variant>" built by SeriesModels from its "build" entry,
## or, for a piece with "kaykit", that KayKit model repainted by the variant's "paint".
## Cupboards that open home storage.
const STORAGE_KINDS := ["dresser", "wardrobe", "toy_box"]


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
				var footprint: Array = piece.get("footprint", [1, 1])
				items[id] = {
					"name": "%s (%s)" % [piece["name"], v["name"]], "category": "furniture", "stack": 1,
					"price": piece["price"], "color": "#" + v["wood"], "desc": piece.get("desc", ""),
					"series": data["id"], "base": piece["id"], "variant": v["id"],
					"swatch": ["#" + v["wood"], "#" + _bolder(v["fabric"][0], v["fabric"][1])],
					"build": {"kind": piece.get("kind", "kaykit"), "params": piece.get("params", {}), "variant": v, "footprint": footprint,
						"kaykit": piece.get("kaykit", "")},
				}
				if piece.has("room"):
					# Dresses the room, like wallpaper (curtains on the windows).
					items[id]["category"] = "interior"
					items[id]["interior"] = {"part": piece["room"]}
				else:
					var placeable := {"footprint": footprint, "model": "series:" + id, "rotatable": true}
					if piece.get("kind", "") in STORAGE_KINDS:
						placeable["storage"] = true
					for key: String in PIECE_PLACEABLE:
						if piece.has(key):
							placeable[key] = piece[key]
					items[id]["placeable"] = placeable
				_add_variant(piece["id"], id)
			if piece.has("recipe"):
				series_recipes["%s_%s" % [piece["id"], data["variants"][0]["id"]]] = {"materials": piece["recipe"]}


## The more colourful of two hex colours (a fabric's print colour rather than its cream).
static func _bolder(a: String, b: String) -> String:
	return a if Color(a).s >= Color(b).s else b


## The original wooden furniture in painted colourways: "<id>_<variant>", the same
## model with its wood recoloured. The item itself is the natural-wood variant.
func _load_colourways(data: Dictionary) -> void:
	for v: Dictionary in data.get("variants", []):
		woods[v["id"]] = v
	for id: String in data.get("items", []):
		var def: Dictionary = items[id]
		def["base"] = id
		def["variant"] = "natural"
		def["swatch"] = [def["color"], def["color"]]
		_add_variant(id, id)
		for v: Dictionary in data.get("variants", []):
			var painted: Dictionary = def.duplicate(true)
			painted["name"] = "%s (%s)" % [def["name"], v["name"]]
			painted["color"] = "#" + v["wood"]
			painted["variant"] = v["id"]
			painted["swatch"] = ["#" + v["wood"], "#" + v["dark"]]
			painted["placeable"]["model"] = "%s:%s" % [def["placeable"]["model"], v["id"]]
			painted.erase("recipe")
			items["%s_%s" % [id, v["id"]]] = painted
			_add_variant(id, "%s_%s" % [id, v["id"]])


## Fish and bugs: an item each, worth selling (and, later, donating to the museum).
func _load_creatures() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CREATURES_PATH))
	for kind: String in ["fish", "bugs"]:
		for c: Dictionary in data[kind]:
			(fish if kind == "fish" else bugs)[c["id"]] = c
			var size := " %s-sized." % String(c["size"]).capitalize() if c.has("size") else ""
			items[c["id"]] = {
				"name": c["name"], "category": "fish" if kind == "fish" else "bug", "stack": 1,
				"price": c["price"], "color": "#" + c["colors"][0],
				"desc": WHERE_TEXT.get(c["where"], "") + size, "creature": c,
			}


func is_creature(id: String) -> bool:
	return fish.has(id) or bugs.has(id)


func _add_variant(base: String, id: String) -> void:
	if not _variants.has(base):
		_variants[base] = []
	_variants[base].append(id)


## Every variant of the same base as `id` (including itself), or [] if it has none.
func variants_of(id: String) -> Array:
	var list: Array = _variants.get(_def(id).get("base", ""), [])
	return list if list.size() > 1 else []


## The variant's own name, e.g. "Sage" for "Meadow Chair (Sage)".
func variant_name(id: String) -> String:
	var n := display_name(id)
	var open := n.rfind("(")
	return n.substr(open + 1, n.length() - open - 2) if open >= 0 and n.ends_with(")") else n


## Two colours that tell a variant apart (wood and fabric, or a garment's two colours).
func swatch(id: String) -> Array[Color]:
	var s: Array = _def(id).get("swatch", [])
	if s.size() < 2:
		return [color_of(id), color_of(id)]
	return [Color(s[0]), Color(s[1])]


func is_clothing(id: String) -> bool:
	return _def(id).get("category", "") == "clothing"


func get_item(id: String) -> Dictionary:
	return _def(id)


## An item's definition, making an everyday garment's the first time it's asked for.
func _def(id: String) -> Dictionary:
	var def: Dictionary = items.get(id, {})
	if def.is_empty() and id.begins_with("basic."):
		def = _make_basic(id)
	elif def.is_empty() and id.begins_with("nature."):
		def = _make_nature(id)
	return def


## Trees, bushes, rocks and stumps dug up into the pockets with the landscaping Move tool
## (World.item_for), each keeping its look: "nature.tree.<model>",
## "nature.fruit_tree.<fruit>.<model>", "nature.palm.<variant>", "nature.bush.<model>",
## "nature.rock.<model>", "nature.stump.<tree|palm>.<model>". Placed from the pockets,
## they're planted again (World.nature_object). {} if `id` isn't one.
func _make_nature(id: String) -> Dictionary:
	var p := id.split(".")
	if p.size() < 3:
		return {}
	var kind := p[1]
	var def := {"category": "nature", "stack": 1, "desc": "Dug up roots and all. Plant it again somewhere outside."}
	match kind:
		"tree":
			def.merge({"name": "Tree", "color": "#6faa5c"})
		"fruit_tree":
			if p.size() < 4 or not fruits.has(p[2]):
				return {}
			def.merge({"name": "%s tree" % String(fruits[p[2]]["name"]), "color": fruits[p[2]]["color"]})
		"palm":
			def.merge({"name": "Palm tree", "color": "#78bd7a"})
		"bush":
			def.merge({"name": "Bush", "color": "#80c17e"})
		"rock":
			def.merge({"name": "Rock", "color": "#bdb8cc", "desc": "A good solid rock. Set it down somewhere outside."})
		"stump":
			if p.size() < 4 or not p[2] in ["tree", "palm"]:
				return {}
			def.merge({"name": "Palm stump" if p[2] == "palm" else "Tree stump", "color": "#a87d62",
				"desc": "A stump, roots and all. Somewhere to sit outside."})
		_:
			return {}
	var obj := World.nature_object(id)
	if obj.is_empty():
		return {}
	def["placeable"] = {"footprint": [1, 1], "model": Models.key_for(obj), "nature": true, "rotatable": false}
	items[id] = def
	return def


## The everyday garment for a slot of `look` (its style and colours), or "" if what's
## worn there is a designed piece or nothing.
func basic_id(slot: String, look: Dictionary) -> String:
	var keys: Array = SLOT_KEYS[slot]
	var id := "basic.%s.%s.%s" % [slot, look.get(keys[0], ""), look.get(keys[1], "")]
	if keys[2] != "":
		id += ".%s.%s" % [look.get(keys[2], ""), look.get(keys[3], "")]
	return id if not _def(id).is_empty() else ""


## The garment `look` has on in a slot: a designed piece whose look matches, or the
## everyday one. "" for nothing (no hat, say).
func worn_item(slot: String, look: Dictionary) -> String:
	var keys: Array = SLOT_KEYS[slot]
	var style: Dictionary = Appearance.option(look, keys[0])
	if not style.get("designed", false):
		return basic_id(slot, look)
	for id: String in items:
		var def: Dictionary = items[id]
		if def.get("slot", "") == slot and def.has("base"):
			var wear: Dictionary = def["wear"]
			var same := true
			for k: String in wear:
				if look.get(k, "") != wear[k]:
					same = false
			if same:
				return id
	return ""


## Makes "basic.<slot>.<style>.<colour>[.<colour2>.<pattern>]" into an item, if each
## part is a real everyday option. {} if not.
func _make_basic(id: String) -> Dictionary:
	var p := id.split(".")
	if p.size() < 4 or not SLOT_KEYS.has(p[1]):
		return {}
	var slot := p[1]
	var keys: Array = SLOT_KEYS[slot]
	var look := {keys[0]: p[2], keys[1]: p[3]}
	if keys[2] != "":
		if p.size() < 6:
			return {}
		look[keys[2]] = p[4]
		look[keys[3]] = p[5]
	var names := {}
	for key: String in look:
		var found := {}
		for opt: Dictionary in Appearance.options(key):
			if opt["id"] == look[key]:
				found = opt
		if found.is_empty() or found.get("designed", false) or found["id"] == "none":
			return {}
		names[key] = found.get("name", String(found["id"]).capitalize())
	var hex: String = Appearance.option(look, keys[1]).get("color", "#ffffff")
	var hex2 := hex
	var name := "%s %s" % [names[keys[1]], names[keys[0]]]
	if keys[2] != "":
		hex2 = Appearance.option(look, keys[2]).get("color", hex)
		if look[keys[3]] != "plain":
			name += " (%s)" % names[keys[3]]
	items[id] = {
		"name": name, "category": "clothing", "stack": 1, "price": BASIC_PRICE[slot], "color": hex,
		"desc": "An everyday %s." % String(names[keys[0]]).to_lower(), "slot": slot, "wear": look,
		"basic": true, "swatch": [hex, hex2],
	}
	return items[id]


## A random everyday garment, for Lucy's rail.
func random_basic(rng: RandomNumberGenerator) -> String:
	var slot: String = ["top", "top", "top", "bottom", "bottom", "shoes", "hat", "hat"][rng.randi() % 8]
	var keys: Array = SLOT_KEYS[slot]
	var styles := Appearance.options(keys[0]).filter(func(o): return not o.get("designed", false) and o["id"] != "none")
	var colours := Appearance.options(keys[1])
	var look := {keys[0]: styles[rng.randi() % styles.size()]["id"], keys[1]: colours[rng.randi() % colours.size()]["id"]}
	if keys[2] != "":
		var patterns := Appearance.options(keys[3])
		look[keys[2]] = colours[rng.randi() % colours.size()]["id"]
		look[keys[3]] = "plain" if rng.randf() < 0.6 else patterns[rng.randi() % patterns.size()]["id"]
	return basic_id(slot, look)


func has_item(id: String) -> bool:
	return items.has(id) or not _def(id).is_empty()


func display_name(id: String) -> String:
	return _def(id).get("name", id)


func color_of(id: String) -> Color:
	return Color(_def(id).get("color", "#ffffff"))


func max_stack(id: String) -> int:
	return int(_def(id).get("stack", 1))


func is_tool(id: String) -> bool:
	return _def(id).get("category", "") == "tool"


func tool_type(id: String) -> String:
	return _def(id).get("tool", "")


func placeable(id: String) -> Dictionary:
	return _def(id).get("placeable", {})
