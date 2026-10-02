class_name TerrainBuilder
extends RefCounted
## Turns IslandData into meshes: the ground (tops plus cliff walls), the sea, and the
## river and pond surfaces.

const GRASS_KIND := 1.0
const SAND_KIND := 0.75
const CLIFF_KIND := 0.5
const BED_KIND := 0.25
const LIP := 0.14
const OCEAN_BORDER := 16
const T := IslandData.Tile

static var _terrain_material: ShaderMaterial
static var _sea_material: ShaderMaterial
static var _fresh_material: ShaderMaterial


static func terrain_material() -> ShaderMaterial:
	if _terrain_material == null:
		_terrain_material = ShaderMaterial.new()
		_terrain_material.shader = load("res://shaders/terrain.gdshader")
	return _terrain_material


static func sea_material() -> ShaderMaterial:
	if _sea_material == null:
		_sea_material = ShaderMaterial.new()
		_sea_material.shader = load("res://shaders/water.gdshader")
	return _sea_material


static func fresh_material() -> ShaderMaterial:
	if _fresh_material == null:
		_fresh_material = ShaderMaterial.new()
		_fresh_material.shader = load("res://shaders/water.gdshader")
		_fresh_material.set_shader_parameter("shallow", Color("a6e6dc"))
		_fresh_material.set_shader_parameter("deep", Color("7cc8d8"))
		_fresh_material.set_shader_parameter("ripple_scale", 1.6)
		_fresh_material.set_shader_parameter("flow", Vector2(0.0, -0.4))
		_fresh_material.set_shader_parameter("shore_waves", 0.0)
		_fresh_material.set_shader_parameter("bank_foam", 0.5)
	return _fresh_material


static func build_ground(d: IslandData) -> ArrayMesh:
	var k := MeshKit.new()
	# Edge checks: direction, my two corners on that edge, the neighbour's matching corners.
	var edges := [
		[Vector2i(1, 0), IslandData.NE, IslandData.SE, IslandData.NW, IslandData.SW],
		[Vector2i(-1, 0), IslandData.NW, IslandData.SW, IslandData.NE, IslandData.SE],
		[Vector2i(0, 1), IslandData.SW, IslandData.SE, IslandData.NW, IslandData.NE],
		[Vector2i(0, -1), IslandData.NW, IslandData.NE, IslandData.SW, IslandData.SE],
	]
	for z in d.height:
		for x in d.width:
			var t := d.tile(x, z)
			if t == T.OCEAN:
				continue
			var kind := GRASS_KIND
			if t == T.SAND:
				kind = SAND_KIND
			elif t == T.WATER:
				kind = BED_KIND
			var c := Color(1, 1, 1, kind)
			var p := [
				Vector3(x, d.corner(x, z, IslandData.NW), z),
				Vector3(x + 1, d.corner(x, z, IslandData.NE), z),
				Vector3(x + 1, d.corner(x, z, IslandData.SE), z + 1),
				Vector3(x, d.corner(x, z, IslandData.SW), z + 1),
			]
			_top(k, p[0], p[1], p[2], c)
			_top(k, p[0], p[2], p[3], c)
			for e in edges:
				var dir: Vector2i = e[0]
				var nx := x + dir.x
				var nz := z + dir.y
				var ha: float = p[e[1]].y
				var hb: float = p[e[2]].y
				var na := IslandData.OCEAN_FLOOR
				var nb := IslandData.OCEAN_FLOOR
				if d.in_bounds(nx, nz):
					na = d.corner(nx, nz, e[3])
					nb = d.corner(nx, nz, e[4])
				if ha > na + 0.01 or hb > nb + 0.01:
					var out := Vector3(dir.x, 0, dir.y)
					var low_a := minf(na, ha)
					var low_b := minf(nb, hb)
					if t == T.GRASS and ha - low_a > 0.3 and hb - low_b > 0.3:
						# A lip of grass hanging over the top of the cliff.
						var lip := Vector3(0, LIP, 0)
						_wall(k, p[e[1]], p[e[2]], ha - LIP, hb - LIP, out, GRASS_KIND)
						_wall(k, p[e[1]] - lip, p[e[2]] - lip, low_a, low_b, out, CLIFF_KIND)
					else:
						_wall(k, p[e[1]], p[e[2]], low_a, low_b, out, CLIFF_KIND)
	return k.commit()


static func _top(k: MeshKit, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (c - a).cross(b - a).normalized()
	if n.y < 0.0:
		n = -n
	k.tri(k.vertex(a, n, col), k.vertex(b, n, col), k.vertex(c, n, col), n)


static func _wall(k: MeshKit, top_a: Vector3, top_b: Vector3, low_a: float, low_b: float, outward: Vector3, kind: float) -> void:
	var col := Color(1, 1, 1, kind)
	var a := k.vertex(top_a, outward, col)
	var b := k.vertex(top_b, outward, col)
	var c := k.vertex(Vector3(top_b.x, low_b, top_b.z), outward, col)
	var dd := k.vertex(Vector3(top_a.x, low_a, top_a.z), outward, col)
	k.quad(a, b, c, dd, outward)


## Rivers and ponds. Vertex red is 0 where the water meets a bank.
static func build_fresh_water(d: IslandData) -> ArrayMesh:
	var k := MeshKit.new()
	for z in d.height:
		for x in d.width:
			if d.tile(x, z) != T.WATER:
				continue
			var y := d.water_surface(x, z)
			var corners_xz := [Vector2i(x, z), Vector2i(x + 1, z), Vector2i(x + 1, z + 1), Vector2i(x, z + 1)]
			var ids: Array[int] = []
			for cxz in corners_xz:
				var bank := false
				for off in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
					var tt := d.tile(cxz.x + off.x, cxz.y + off.y)
					bank = bank or (tt != T.WATER and tt != T.OCEAN)
				ids.append(k.vertex(Vector3(cxz.x, y, cxz.y), Vector3.UP, Color(0.0 if bank else 0.4, 0, 0, 1)))
			k.quad(ids[0], ids[1], ids[2], ids[3], Vector3.UP)
	return k.commit()


## The sea: a fine grid around the island (shore distance in vertex red) plus a coarse
## outer skirt reaching to the horizon.
static func build_sea(d: IslandData) -> ArrayMesh:
	var w := d.width + 1
	var h := d.height + 1
	var dist := PackedFloat32Array()
	dist.resize(w * h)
	for cz in h:
		for cx in w:
			var shore := false
			for off in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
				shore = shore or d.tile(cx + off.x, cz + off.y) != T.OCEAN
			dist[cz * w + cx] = 0.0 if shore else 999.0
	_chamfer(dist, w, h)

	var k := MeshKit.new()
	var b := OCEAN_BORDER
	var row := w + b * 2
	for gz in range(-b, h + b):
		for gx in range(-b, w + b):
			var cx := clampi(gx, 0, w - 1)
			var cz := clampi(gz, 0, h - 1)
			var outside := Vector2(gx - cx, gz - cz).length()
			var shore := clampf((dist[cz * w + cx] + outside) / 12.0, 0.0, 1.0)
			# Ground height under this point (green, offset by 0.5) so foam sits on the waterline.
			var ground := d.height_at(gx, gz) if outside == 0.0 else IslandData.OCEAN_FLOOR
			k.vertex(Vector3(gx, IslandData.SEA_LEVEL, gz), Vector3.UP, Color(shore, clampf(ground + 0.5, 0.0, 1.0), 0, 1))
	for iz in h + b * 2 - 1:
		for ix in row - 1:
			var a := iz * row + ix
			k.quad(a, a + 1, a + row + 1, a + row, Vector3.UP)

	# Coarse skirt out to the horizon, just under the fine grid.
	var reach := 240
	var step := 16
	var y := IslandData.SEA_LEVEL - 0.03
	for sz in range(-reach, d.height + reach, step):
		for sx in range(-reach, d.width + reach, step):
			if sx >= -b and sx + step <= w + b and sz >= -b and sz + step <= h + b:
				continue
			var q := [
				k.vertex(Vector3(sx, y, sz), Vector3.UP, Color(1, 0, 0, 1)),
				k.vertex(Vector3(sx + step, y, sz), Vector3.UP, Color(1, 0, 0, 1)),
				k.vertex(Vector3(sx + step, y, sz + step), Vector3.UP, Color(1, 0, 0, 1)),
				k.vertex(Vector3(sx, y, sz + step), Vector3.UP, Color(1, 0, 0, 1)),
			]
			k.quad(q[0], q[1], q[2], q[3], Vector3.UP)
	return k.commit()


## Two-pass chamfer distance transform (close to Euclidean, in tiles).
static func _chamfer(dist: PackedFloat32Array, w: int, h: int) -> void:
	const D := 1.4142
	for z in h:
		for x in w:
			var i := z * w + x
			var v := dist[i]
			if x > 0: v = minf(v, dist[i - 1] + 1.0)
			if z > 0:
				v = minf(v, dist[i - w] + 1.0)
				if x > 0: v = minf(v, dist[i - w - 1] + D)
				if x < w - 1: v = minf(v, dist[i - w + 1] + D)
			dist[i] = v
	for z in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := z * w + x
			var v := dist[i]
			if x < w - 1: v = minf(v, dist[i + 1] + 1.0)
			if z < h - 1:
				v = minf(v, dist[i + w] + 1.0)
				if x < w - 1: v = minf(v, dist[i + w + 1] + D)
				if x > 0: v = minf(v, dist[i + w - 1] + D)
			dist[i] = v
