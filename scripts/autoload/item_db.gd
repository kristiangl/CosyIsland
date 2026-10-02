extends Node
## Item definitions loaded from data/items.json.
##
## Fruit and flower items are generated from their species tables so each species and
## colour gets an item id like "apple" or "tulip_red".

const DATA_PATH := "res://data/items.json"

var items: Dictionary = {}
var fruits: Dictionary = {}
var flowers: Dictionary = {}


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
