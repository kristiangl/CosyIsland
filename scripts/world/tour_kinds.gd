class_name TourKinds
extends RefCounted
## The kinds of island Marlow's tours land on (data/tour_islands.json): plain ones, and
## now and then a rare one (an orchard, a flower meadow, a rocky island, bug and fishing
## islands) with more of one thing and some things found nowhere else.

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/tour_islands.json"))
	return _data


## A kind's settings ({} for an unknown kind).
static func get_kind(id: String) -> Dictionary:
	return data()["kinds"].get(id, {})


static func rare_kinds() -> Array:
	return data()["kinds"].keys().filter(func(id): return id != "plain")


## Which kind of island trip number `trip` lands on. The first is always plain.
static func pick(trip: int, roll: float, roll_kind: float) -> String:
	if trip <= 1 or roll >= float(data()["rare_chance"]):
		return "plain"
	var total := 0.0
	for id: String in rare_kinds():
		total += float(get_kind(id).get("weight", 1))
	var at := roll_kind * total
	for id: String in rare_kinds():
		at -= float(get_kind(id).get("weight", 1))
		if at <= 0.0:
			return id
	return rare_kinds()[-1]
