class_name TitleButterflies
extends Control
## A few butterflies flitting about the title screen: each wanders on a gently turning
## heading, flaps (wings squashed sideways, as if seen from above) and steers back when
## it nears the edge. All drawn by this one control.

## [wing, wing tip, spots] for each butterfly, like the island's own.
const KINDS := [
	["fbf8f0", "3a3a3a", "f2c14e"],
	["f6d34a", "3a3a3a", "fff4c8"],
	["3a6f9a", "7ce0c8", "f6e27a"],
	["f2a7a0", "6b4f3a", "fff0ea"],
	["f2994a", "3a3030", "fff0d8"],
]
const COUNT := 6

var _flies: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
# The wing shapes, for a butterfly facing up (-y), right side only.
var _upper := PackedVector2Array([Vector2(0, -2), Vector2(9, -13), Vector2(16, -11), Vector2(15, -3), Vector2(4, 1)])
var _lower := PackedVector2Array([Vector2(0, 0), Vector2(5, 1), Vector2(11, 5), Vector2(9, 10), Vector2(2, 6)])


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 7
	for i in COUNT:
		_flies.append({
			"pos": Vector2(_rng.randf_range(0.05, 0.95), _rng.randf_range(0.1, 0.9)),
			"heading": _rng.randf() * TAU,
			"turn": 0.0,
			"speed": _rng.randf_range(55.0, 95.0),
			"phase": _rng.randf() * TAU,
			"size": _rng.randf_range(1.5, 2.1),
			"kind": i % KINDS.size(),
			"placed": false,
		})


func _process(delta: float) -> void:
	if size.x <= 0.0:
		return
	for f in _flies:
		if not f["placed"]:
			f["pos"] = f["pos"] * size
			f["placed"] = true
		# Wander: the turn rate drifts, and pulls back towards the middle near the edges.
		f["turn"] = clampf(f["turn"] + _rng.randf_range(-3.0, 3.0) * delta, -1.6, 1.6)
		var pos: Vector2 = f["pos"]
		var heading: float = f["heading"]
		var margin := 70.0
		if pos.x < margin or pos.x > size.x - margin or pos.y < margin or pos.y > size.y - margin:
			var to_middle := (size * 0.5 - pos).angle()
			f["turn"] = wrapf(to_middle - heading + PI * 0.5, -PI, PI) * 1.5
		heading += f["turn"] * delta
		f["heading"] = heading
		f["phase"] += delta * 14.0
		# Up is -y, so a heading of 0 flies up the screen; a little hop with each flap.
		var dir := Vector2(sin(heading), -cos(heading))
		var hop := 0.6 + 0.6 * absf(sin(f["phase"]))
		f["pos"] = pos + dir * f["speed"] * hop * delta
	queue_redraw()


func _draw() -> void:
	for f in _flies:
		if not f["placed"]:
			continue
		var kind: Array = KINDS[f["kind"]]
		var wing := Color(kind[0])
		var tip := Color(kind[1])
		var spot := Color(kind[2])
		var flap := 0.25 + 0.75 * absf(cos(f["phase"]))
		var s: float = f["size"]
		for side: float in [1.0, -1.0]:
			draw_set_transform(f["pos"], f["heading"], Vector2(side * flap * s, s))
			# The wings: a darker edge, the colour inside it, and a spot.
			draw_colored_polygon(_upper, tip)
			draw_colored_polygon(_lower, tip)
			draw_set_transform(f["pos"], f["heading"], Vector2(side * flap * s * 0.82, s * 0.82))
			draw_colored_polygon(_upper, wing)
			draw_colored_polygon(_lower, wing)
			draw_circle(Vector2(10, -8), 2.2, spot)
		draw_set_transform(f["pos"], f["heading"], Vector2(s, s))
		draw_rect(Rect2(-1.2, -6, 2.4, 13), Color("3a3030"))
	draw_set_transform(Vector2.ZERO)
