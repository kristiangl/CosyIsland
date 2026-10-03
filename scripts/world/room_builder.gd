class_name RoomBuilder
extends RefCounted
## Builds the inside of a home from a room's IslandData (see IslandData.room): a
## patterned floor, back and side walls with trims, and a doormat at the way out.
## The front is left open so the camera can look in, like a doll's house.

const WALL := 0.18
## Floor and wall looks. Patterns are listed in shaders/room_surface.gdshader.
const STYLES := {
	"tent": {
		"height": 1.9,
		"floor": {"pattern": 3, "a": "dcc79c", "b": "b89a6a"},
		"wall": {"pattern": 4, "a": "8fd0bf", "b": "6aa995"},
		"trim": "c39a6b", "base": "8a6b4f", "mat": "e08f74", "bunting": true,
	},
	"cottage": {
		"height": 2.3,
		"floor": {"pattern": 1, "a": "d9b083", "b": "b48a5e"},
		"wall": {"pattern": 2, "a": "fbf0d9", "b": "e9cfa8"},
		"trim": "f6ead2", "base": "8a6b4f", "mat": "8fb07a", "bunting": false,
	},
}
const BUNTING: Array[Color] = [Color("f2a7a0"), Color("f6d58c"), Color("9fd3c7"), Color("b9b3e6")]


## `look` can swap the wall and floor for wallpaper and flooring items:
## {"wall": item id, "floor": item id}.
static func build(data: IslandData, style_id: String, look: Dictionary = {}) -> Node3D:
	var style: Dictionary = STYLES.get(style_id, STYLES["tent"]).duplicate()
	for part: String in ["wall", "floor"]:
		var item: Dictionary = ItemDB.get_item(look.get(part, "")).get("interior", {})
		if not item.is_empty():
			style[part] = item
			if part == "wall":
				style["bunting"] = false
	var room := Node3D.new()
	room.name = "Room"
	var w := float(data.width)
	var d := float(data.height - 1)
	var y := IslandData.GRASS_HEIGHT
	var h: float = style["height"]

	var floor_kit := MeshKit.new()
	var a := floor_kit.vertex(Vector3(0, y, 0), Vector3.UP, Color.WHITE, Vector2(0, 0))
	var b := floor_kit.vertex(Vector3(w, y, 0), Vector3.UP, Color.WHITE, Vector2(w, 0))
	var c := floor_kit.vertex(Vector3(w, y, d), Vector3.UP, Color.WHITE, Vector2(w, d))
	var e := floor_kit.vertex(Vector3(0, y, d), Vector3.UP, Color.WHITE, Vector2(0, d))
	floor_kit.quad(a, b, c, e, Vector3.UP)
	var floor_mat := surface_material(style["floor"])
	floor_mat.set_shader_parameter("room_size", Vector2(w, d))
	room.add_child(_instance("Floor", floor_kit.commit(), floor_mat))

	# Walls, with UVs running continuously from the front-left round to the front-right.
	var walls := MeshKit.new()
	_wall(walls, Vector3(0, y, d), Vector3(0, y, 0), h, Vector3.RIGHT, 0.0)
	_wall(walls, Vector3(0, y, 0), Vector3(w, y, 0), h, Vector3.BACK, d)
	_wall(walls, Vector3(w, y, 0), Vector3(w, y, d), h, Vector3.LEFT, d + w)
	var wall_mat := surface_material(style["wall"])
	wall_mat.set_shader_parameter("is_wall", true)
	room.add_child(_instance("Walls", walls.commit(), wall_mat))

	var kit := MeshKit.new()
	var trim := Color(style["trim"])
	var base := Color(style["base"])
	# The floor slab, showing as a thick edge along the open front.
	_box(kit, Vector3(-WALL, y - 0.45, -WALL), Vector3(w + WALL, y - 0.004, d), base)
	# Wall bodies (seen at their front ends and tops), capped with a trim.
	_box(kit, Vector3(-WALL, y, -WALL), Vector3(w + WALL, y + h, -0.003), trim.darkened(0.08))
	_box(kit, Vector3(-WALL, y, 0), Vector3(-0.003, y + h, d), trim.darkened(0.08))
	_box(kit, Vector3(w + 0.003, y, 0), Vector3(w + WALL, y + h, d), trim.darkened(0.08))
	_box(kit, Vector3(-WALL - 0.03, y + h, -WALL - 0.03), Vector3(w + WALL + 0.03, y + h + 0.07, 0.04), trim)
	_box(kit, Vector3(-WALL - 0.03, y + h, 0), Vector3(0.04, y + h + 0.07, d + 0.03), trim)
	_box(kit, Vector3(w - 0.04, y + h, 0), Vector3(w + WALL + 0.03, y + h + 0.07, d + 0.03), trim)
	# Skirting boards.
	var skirting := trim.darkened(0.18)
	_box(kit, Vector3(0, y, 0), Vector3(w, y + 0.11, 0.035), skirting)
	_box(kit, Vector3(0, y, 0.035), Vector3(0.035, y + 0.11, d), skirting)
	_box(kit, Vector3(w - 0.035, y, 0.035), Vector3(w, y + 0.11, d), skirting)
	# The step out and its doormat.
	var door := data.room_door()
	_box(kit, Vector3(door.x, y - 0.45, d), Vector3(door.x + 1, y - 0.004, d + 1), base)
	kit.rounded_box(Vector3(door.x + 0.5, y + 0.005, d + 0.4), Vector3(0.86, 0.03, 0.62), Color(style["mat"]), 0.4)
	if style.get("bunting", false):
		_bunting(kit, Vector3(0.1, y + h - 0.05, 0.06), Vector3(w - 0.1, y + h - 0.05, 0.06))
	var props := _instance("Trim", kit.commit(), Models.material())
	room.add_child(props)
	return room


static func surface_material(look: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/room_surface.gdshader")
	mat.set_shader_parameter("pattern", look["pattern"])
	mat.set_shader_parameter("colour_a", Color(look["a"]))
	mat.set_shader_parameter("colour_b", Color(look["b"]))
	return mat


static func _instance(node_name: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	return mi


## One wall face from `from` to `to` along the floor, `h` high, facing `n`. `u0` is
## where its UV starts, so patterns carry on round the corners.
static func _wall(kit: MeshKit, from: Vector3, to: Vector3, h: float, n: Vector3, u0: float) -> void:
	var length := from.distance_to(to)
	var a := kit.vertex(from, n, Color.WHITE, Vector2(u0, 0))
	var b := kit.vertex(to, n, Color.WHITE, Vector2(u0 + length, 0))
	var c := kit.vertex(to + Vector3(0, h, 0), n, Color.WHITE, Vector2(u0 + length, h))
	var d := kit.vertex(from + Vector3(0, h, 0), n, Color.WHITE, Vector2(u0, h))
	kit.quad(a, b, c, d, n)


static func _box(kit: MeshKit, lo: Vector3, hi: Vector3, c: Color) -> void:
	kit.box((lo + hi) * 0.5, hi - lo, c)


## A string of little flags hanging along the back wall.
static func _bunting(kit: MeshKit, from: Vector3, to: Vector3) -> void:
	var count := int(from.distance_to(to) / 0.32)
	for i in count:
		var t0 := float(i) / count
		var t1 := float(i + 1) / count
		var sag := func(t: float) -> float: return -sin(t * PI) * 0.18
		var p0 := from.lerp(to, t0) + Vector3(0, sag.call(t0), 0)
		var p1 := from.lerp(to, t1) + Vector3(0, sag.call(t1), 0)
		var mid := (p0 + p1) * 0.5 + Vector3(0, -0.2, 0.01)
		var col := BUNTING[i % BUNTING.size()]
		var ia := kit.vertex(p0 + (p1 - p0) * 0.1, Vector3.BACK, col)
		var ib := kit.vertex(p1 - (p1 - p0) * 0.1, Vector3.BACK, col)
		var ic := kit.vertex(mid, Vector3.BACK, col)
		kit.tri(ia, ib, ic, Vector3.BACK)
		# The string.
		var s0 := kit.vertex(p0 + Vector3(0, 0.012, 0), Vector3.BACK, Color("8a6b4f"))
		var s1 := kit.vertex(p1 + Vector3(0, 0.012, 0), Vector3.BACK, Color("8a6b4f"))
		var s2 := kit.vertex(p1 - Vector3(0, 0.012, 0), Vector3.BACK, Color("8a6b4f"))
		var s3 := kit.vertex(p0 - Vector3(0, 0.012, 0), Vector3.BACK, Color("8a6b4f"))
		kit.quad(s0, s1, s2, s3, Vector3.BACK)
