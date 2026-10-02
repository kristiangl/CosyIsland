class_name TerrainBuilder
extends RefCounted
## Turns IslandData into meshes: the ground (tops plus cliff walls), the sea, and the
## river and pond surfaces.

## Vertex colour alpha tells the terrain shader what it is drawing. Surfaces (grass and
## sand) carry the grass weight in red; walls with the grass kind are cliff-top lips.
const SURFACE_KIND := 1.0
const GRASS_KIND := 0.75
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
		_fresh_material.set_shader_parameter("deep", Color("95d8dc"))
		_fresh_material.set_shader_parameter("ripple_scale", 1.6)
		_fresh_material.set_shader_parameter("flow", Vector2(0.0, -0.4))
		_fresh_material.set_shader_parameter("shore_waves", 0.0)
		_fresh_material.set_shader_parameter("bank_foam", 0.5)
	return _fresh_material


static func build_ground(d: IslandData) -> ArrayMesh:
	var k := MeshKit.new()
	var weights := _grass_weights(d)
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
			var p: Array[Vector3] = [
				Vector3(x, d.corner(x, z, IslandData.NW), z),
				Vector3(x + 1, d.corner(x, z, IslandData.NE), z),
				Vector3(x + 1, d.corner(x, z, IslandData.SE), z + 1),
				Vector3(x, d.corner(x, z, IslandData.SW), z + 1),
			]
			var split: Dictionary = d.splits.get(d.idx(x, z), {})
			if split.is_empty():
				_top(k, p[0], p[1], p[2], t, weights, d.width)
				_top(k, p[0], p[2], p[3], t, weights, d.width)
			else:
				_split_top(k, d, p, split, t, weights)
			for e in edges:
				var dir: Vector2i = e[0]
				var mine := d.edge_heights(x, z, e[1], e[2])
				var theirs := Vector2(IslandData.OCEAN_FLOOR, IslandData.OCEAN_FLOOR)
				if d.in_bounds(x + dir.x, z + dir.y):
					theirs = d.edge_heights(x + dir.x, z + dir.y, e[3], e[4])
				if mine.x > theirs.x + 0.01 or mine.y > theirs.y + 0.01:
					var owner := t
					if not split.is_empty() and split["corner"] in [e[1], e[2]]:
						owner = split["tile"]
					var a := Vector3(p[e[1]].x, mine.x, p[e[1]].z)
					var b := Vector3(p[e[2]].x, mine.y, p[e[2]].z)
					_cliff(k, a, b, minf(theirs.x, mine.x), minf(theirs.y, mine.y), Vector3(dir.x, 0, dir.y), owner == T.GRASS)
	return k.commit()


## A tile cut along its diagonal: the corner half at the split height, the rest at the
## tile's own height, and a cliff along the diagonal between them.
static func _split_top(k: MeshKit, d: IslandData, p: Array[Vector3], split: Dictionary, t: int, weights: PackedFloat32Array) -> void:
	var c: int = split["corner"]
	var prev := (c + 3) % 4
	var next := (c + 1) % 4
	var opp := (c + 2) % 4
	var h: float = split["h"]
	var lifted := func(v: Vector3) -> Vector3: return Vector3(v.x, h, v.z)
	_top(k, lifted.call(p[prev]), lifted.call(p[c]), lifted.call(p[next]), split["tile"], weights, d.width)
	_top(k, p[prev], p[next], p[opp], t, weights, d.width)
	var rest := p[prev].y
	if absf(rest - h) < 0.01:
		return
	# Wall faces towards whichever half is lower.
	var towards_corner := (p[c] - p[opp]) * Vector3(1, 0, 1)
	var out := towards_corner.normalized() if rest > h else -towards_corner.normalized()
	var top := maxf(rest, h)
	var low := minf(rest, h)
	var upper_tile: int = t if rest > h else split["tile"]
	_cliff(k, Vector3(p[prev].x, top, p[prev].z), Vector3(p[next].x, top, p[next].z), low, low, out, upper_tile == T.GRASS)


static func _cliff(k: MeshKit, a: Vector3, b: Vector3, low_a: float, low_b: float, out: Vector3, grass_lip: bool) -> void:
	if grass_lip and a.y - low_a > 0.3 and b.y - low_b > 0.3:
		# A lip of grass hanging over the top of the cliff.
		var lip := Vector3(0, LIP, 0)
		_wall(k, a, b, a.y - LIP, b.y - LIP, out, GRASS_KIND)
		_wall(k, a - lip, b - lip, low_a, low_b, out, CLIFF_KIND)
	else:
		_wall(k, a, b, low_a, low_b, out, CLIFF_KIND)


## Two values per tile corner: the fraction of grass among the land tiles around it (for
## blending grass into sand along wobbly, rounded lines), and 0 if a tile around it rises
## above the lowest one (contact shade at the foot of cliffs), else 1.
static func _grass_weights(d: IslandData) -> PackedFloat32Array:
	var w := d.width + 1
	var out := PackedFloat32Array()
	out.resize(w * (d.height + 1) * 2)
	for cz in d.height + 1:
		for cx in w:
			var grass := 0
			var sandy := 0
			var lowest := INF
			var highest := -INF
			for off: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
				var tx := cx + off.x
				var tz := cz + off.y
				var tt := d.tile(tx, tz)
				if tt == T.GRASS:
					grass += 1
				elif tt == T.SAND or tt == T.OCEAN:
					sandy += 1
				if tt == T.GRASS and not d.is_ramp(tx, tz):
					var h := IslandData.tier_height(d.tier(tx, tz))
					lowest = minf(lowest, h)
					highest = maxf(highest, h)
			var i := (cz * w + cx) * 2
			out[i] = 1.0 if grass + sandy == 0 else float(grass) / (grass + sandy)
			out[i + 1] = 0.0 if highest - lowest > 0.3 else 1.0
	return out


static func _top(k: MeshKit, a: Vector3, b: Vector3, c: Vector3, t: int, weights: PackedFloat32Array, width: int) -> void:
	var n := (c - a).cross(b - a).normalized()
	if n.y < 0.0:
		n = -n
	var ids: Array[int] = []
	for v in [a, b, c]:
		var col := Color(1, 1, 1, BED_KIND)
		if t != T.WATER:
			var wi := int(round(v.z)) * (width + 1) + int(round(v.x))
			col = Color(weights[wi * 2], weights[wi * 2 + 1], 1, SURFACE_KIND)
		ids.append(k.vertex(v, n, col))
	k.tri(ids[0], ids[1], ids[2], n)


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
	# Land tiles whose corner was cut down to a river bed need water over that half.
	for i in d.splits:
		var split: Dictionary = d.splits[i]
		if split["tile"] != T.WATER:
			continue
		var x: int = i % d.width
		var z: int = i / d.width
		var y := maxf(IslandData.tier_height(split["tier"]) - IslandData.WATER_DROP, IslandData.SEA_LEVEL)
		var pts := [Vector3(x, y, z), Vector3(x + 1, y, z), Vector3(x + 1, y, z + 1), Vector3(x, y, z + 1)]
		var c: int = split["corner"]
		var a := k.vertex(pts[(c + 3) % 4], Vector3.UP, Color(0, 0, 0, 1))
		var b := k.vertex(pts[c], Vector3.UP, Color(0.4, 0, 0, 1))
		var e := k.vertex(pts[(c + 1) % 4], Vector3.UP, Color(0, 0, 0, 1))
		k.tri(a, b, e, Vector3.UP)
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
