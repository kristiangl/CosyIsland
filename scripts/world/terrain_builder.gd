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
static var _foam_material: ShaderMaterial
static var _path_material: ShaderMaterial


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


static func foam_material() -> ShaderMaterial:
	if _foam_material == null:
		_foam_material = ShaderMaterial.new()
		_foam_material.shader = load("res://shaders/foam.gdshader")
	return _foam_material


static func path_material() -> ShaderMaterial:
	if _path_material == null:
		_path_material = ShaderMaterial.new()
		_path_material.shader = load("res://shaders/path.gdshader")
	return _path_material


## Neighbours of a tile and their bits in the path shader's mask.
const PATH_NEIGHBOURS := [
	[Vector2i(0, -1), 1], [Vector2i(1, 0), 2], [Vector2i(0, 1), 4], [Vector2i(-1, 0), 8],
	[Vector2i(1, -1), 16], [Vector2i(1, 1), 32], [Vector2i(-1, 1), 64], [Vector2i(-1, -1), 128],
]
## Steps on each tile of a slope laid with stairs.
const STEPS_PER_TILE := 3


## Paths (tile index -> kind, World.PATH_KINDS) as one mesh: laid just above the ground
## (their outer corners are rounded by the shader), and on slopes either stairs or, for
## sand and dirt, laid on the slope.
static func build_paths(d: IslandData, paths: Dictionary) -> ArrayMesh:
	var k := MeshKit.new()
	for i: int in paths:
		var x := i % d.width
		var z := i / d.width
		var kind: int = World.PATH_KINDS.find(paths[i])
		var mask := 0
		for nb: Array in PATH_NEIGHBOURS:
			var q: Vector2i = Vector2i(x, z) + nb[0]
			if d.in_bounds(q.x, q.y) and (paths.has(d.idx(q.x, q.y)) or d.plaza.has_point(q)):
				mask |= nb[1]
		if d.is_ramp(x, z) and paths[i] in World.STAIR_KINDS:
			_stairs(k, d.ramps[i], x, z, Color(kind / 8.0, 1.0, 1.0, 1.0))
			continue
		var col := Color(kind / 8.0, mask / 255.0, 1.0, 1.0)
		var lift := 0.012
		var p: Array[Vector3] = [
			Vector3(x, d.corner(x, z, IslandData.NW) + lift, z),
			Vector3(x + 1, d.corner(x, z, IslandData.NE) + lift, z),
			Vector3(x + 1, d.corner(x, z, IslandData.SE) + lift, z + 1),
			Vector3(x, d.corner(x, z, IslandData.SW) + lift, z + 1),
		]
		var n := (p[2] - p[0]).cross(p[1] - p[3]).normalized()
		if n.y < 0.0:
			n = -n
		var a := k.vertex(p[0], n, col, Vector2(0, 0))
		var b := k.vertex(p[1], n, col, Vector2(1, 0))
		var c := k.vertex(p[2], n, col, Vector2(1, 1))
		var e := k.vertex(p[3], n, col, Vector2(0, 1))
		k.quad(a, b, c, e, n)
	return k.commit()


## How high the stair tread is at (fx, fz) across a slope tile: the slope in steps,
## each tread level with the top of its stretch (so the slope never shows through).
static func stair_height(ramp: Dictionary, fx: float, fz: float) -> float:
	var up: Vector2i = ramp["up"]
	var s := fx if up.x > 0 else (1.0 - fx if up.x < 0 else (fz if up.y > 0 else 1.0 - fz))
	var step := mini(floori(s * STEPS_PER_TILE), STEPS_PER_TILE - 1)
	return lerpf(ramp["low"], ramp["high"], float(step + 1) / STEPS_PER_TILE) + 0.02


## Stairs up a slope tile (treads at `stair_height`), with risers and sides.
static func _stairs(k: MeshKit, ramp: Dictionary, x: int, z: int, col: Color) -> void:
	var up: Vector2i = ramp["up"]
	var high: float = ramp["high"]
	var low: float = ramp["low"]
	var u := Vector3(up.x, 0, up.y)
	var v := Vector3(-up.y, 0, up.x)
	var centre := Vector3(x + 0.5, 0, z + 0.5)
	var side := Color(col.r, col.g, 0.5, 1.0)
	var at := func(s: float, t: float, y: float) -> Vector3:
		return centre + u * (s - 0.5) + v * (t - 0.5) + Vector3(0, y, 0)
	for j in STEPS_PER_TILE:
		var s0 := float(j) / STEPS_PER_TILE
		var s1 := float(j + 1) / STEPS_PER_TILE
		var top := lerpf(low, high, s1) + 0.02
		var foot := lerpf(low, high, s0) - 0.12
		k.flat_quad(at.call(s0, 0.0, top), at.call(s1, 0.0, top), at.call(s1, 1.0, top), at.call(s0, 1.0, top), Vector3.UP, col)
		k.flat_quad(at.call(s0, 0.0, foot), at.call(s0, 1.0, foot), at.call(s0, 1.0, top), at.call(s0, 0.0, top), -u, side)
		for t: float in [0.0, 1.0]:
			k.flat_quad(at.call(s0, t, foot), at.call(s1, t, foot), at.call(s1, t, top), at.call(s0, t, top), v * (t * 2.0 - 1.0), side)


static func fresh_material() -> ShaderMaterial:
	if _fresh_material == null:
		_fresh_material = ShaderMaterial.new()
		_fresh_material.shader = load("res://shaders/water.gdshader")
		_fresh_material.set_shader_parameter("shallow", Color("a6e6dc"))
		_fresh_material.set_shader_parameter("deep", Color("95d8dc"))
		_fresh_material.set_shader_parameter("ripple_scale", 1.6)
		_fresh_material.set_shader_parameter("flow", Vector2(0.0, -0.4))
		_fresh_material.set_shader_parameter("shore_waves", 0.0)
		_fresh_material.set_shader_parameter("ripple_strength", 0.55)
	return _fresh_material


## The ground's tops and cliff walls, for the tiles in `area` (the whole island if empty:
## the island builds it in chunks so a change only remakes the chunks it touches).
static func build_ground(d: IslandData, area := Rect2i()) -> ArrayMesh:
	var k := MeshKit.new()
	if area.size == Vector2i.ZERO:
		area = Rect2i(0, 0, d.width, d.height)
	var weights := _grass_weights(d, area)
	# Edge checks: direction, my two corners on that edge, the neighbour's matching corners.
	var edges := [
		[Vector2i(1, 0), IslandData.NE, IslandData.SE, IslandData.NW, IslandData.SW],
		[Vector2i(-1, 0), IslandData.NW, IslandData.SW, IslandData.NE, IslandData.SE],
		[Vector2i(0, 1), IslandData.SW, IslandData.SE, IslandData.NW, IslandData.NE],
		[Vector2i(0, -1), IslandData.NW, IslandData.NE, IslandData.SW, IslandData.SE],
	]
	for z in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
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
		# A lip of grass hanging over the top of the cliff, with a scalloped edge.
		var lip := Vector3(0, LIP, 0)
		_wall(k, a, b, a.y - LIP, b.y - LIP, out, GRASS_KIND)
		_wall(k, a - lip, b - lip, low_a, low_b, out, CLIFF_KIND)
		_lip_drips(k, a - lip + out * 0.004, b - lip + out * 0.004, out)
	else:
		_wall(k, a, b, low_a, low_b, out, CLIFF_KIND)


## Three values per tile corner: the fraction of grass among the land tiles around it
## (for blending grass into sand along wobbly, rounded lines), 0 if the tiles around it
## are at different heights (a cliff edge) else 1, and the highest of them.
## Per tile corner: how grassy it is, whether it's at a cliff edge, and the highest
## ground round it (only the corners of tiles in `area` are filled in).
static func _grass_weights(d: IslandData, area: Rect2i) -> PackedFloat32Array:
	var w := d.width + 1
	var out := PackedFloat32Array()
	out.resize(w * (d.height + 1) * 3)
	for cz in range(area.position.y, area.end.y + 1):
		for cx in range(area.position.x, area.end.x + 1):
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
			var i := (cz * w + cx) * 3
			out[i] = 1.0 if grass + sandy == 0 else float(grass) / (grass + sandy)
			out[i + 1] = 0.0 if highest - lowest > 0.3 else 1.0
			out[i + 2] = highest
	return out


static func _top(k: MeshKit, a: Vector3, b: Vector3, c: Vector3, t: int, weights: PackedFloat32Array, width: int) -> void:
	var n := (c - a).cross(b - a).normalized()
	if n.y < 0.0:
		n = -n
	var ids: Array[int] = []
	for v in [a, b, c]:
		var col := Color(1, 1, 1, BED_KIND)
		if t != T.WATER:
			# At a cliff edge, the ground below gets a contact shade (green 0) and the
			# top a light rim (blue 0), so a drop reads even when its wall faces away.
			var wi := (int(round(v.z)) * (width + 1) + int(round(v.x))) * 3
			var foot := 1.0
			var rim := 1.0
			if weights[wi + 1] < 0.5:
				if v.y < weights[wi + 2] - 0.15:
					foot = 0.0
				else:
					rim = 0.0
			col = Color(weights[wi], foot, rim, SURFACE_KIND)
		ids.append(k.vertex(v, n, col))
	k.tri(ids[0], ids[1], ids[2], n)


## Little rounded tongues of grass hanging below the lip.
static func _lip_drips(k: MeshKit, a: Vector3, b: Vector3, out: Vector3) -> void:
	var length := a.distance_to(b)
	var count := maxi(2, int(round(length / 0.22)))
	var col := Color(1, 1, 1, GRASS_KIND)
	for i in count:
		var t0 := float(i) / count
		var t1 := float(i + 1) / count
		var p0 := a.lerp(b, t0)
		var p1 := a.lerp(b, t1)
		var mid := (p0 + p1) * 0.5
		var seed := absf(sin(mid.x * 12.9898 + mid.z * 78.233) * 43758.5453)
		var drop := 0.04 + fposmod(seed, 1.0) * 0.09
		var tip := mid - Vector3(0, drop, 0)
		var ids := [k.vertex(p0, out, col), k.vertex(p1, out, col), k.vertex(tip, out, col)]
		k.tri(ids[0], ids[1], ids[2], out)


static func _wall(k: MeshKit, top_a: Vector3, top_b: Vector3, low_a: float, low_b: float, outward: Vector3, kind: float) -> void:
	var col := Color(1, 1, 1, kind)
	var a := k.vertex(top_a, outward, col)
	var b := k.vertex(top_b, outward, col)
	var c := k.vertex(Vector3(top_b.x, low_b, top_b.z), outward, col)
	var dd := k.vertex(Vector3(top_a.x, low_a, top_a.z), outward, col)
	k.quad(a, b, c, dd, outward)


## Rivers and ponds: flat surfaces at each tile's water level, including the river half
## of land tiles cut along a diagonal. Banks get their foam from build_bank_foam().
static func build_fresh_water(d: IslandData) -> ArrayMesh:
	var k := MeshKit.new()
	var col := Color(0.4, 0, 0, 1)
	for z in d.height:
		for x in d.width:
			if d.tile(x, z) != T.WATER or _is_mouth(d, x, z):
				continue
			var y := d.water_surface(x, z)
			var ids: Array[int] = []
			for cxz: Vector2i in [Vector2i(x, z), Vector2i(x + 1, z), Vector2i(x + 1, z + 1), Vector2i(x, z + 1)]:
				ids.append(k.vertex(Vector3(cxz.x, y, cxz.y), Vector3.UP, col))
			k.quad(ids[0], ids[1], ids[2], ids[3], Vector3.UP)
	for i in d.splits:
		var split: Dictionary = d.splits[i]
		if split["tile"] != T.WATER:
			continue
		var y := _split_water_level(split)
		var pts := _tile_points(i % d.width, i / d.width, y)
		var c: int = split["corner"]
		k.tri(k.vertex(pts[(c + 3) % 4], Vector3.UP, col), k.vertex(pts[c], Vector3.UP, col),
			k.vertex(pts[(c + 1) % 4], Vector3.UP, col), Vector3.UP)
	return k.commit()


## Foam ribbons where rivers and ponds lap against their banks, straight edges and
## diagonals alike. Vertex alpha is 1 at the bank and fades out into the water.
static func build_bank_foam(d: IslandData) -> ArrayMesh:
	var k := MeshKit.new()
	var edges := [
		[Vector2i(1, 0), IslandData.NE, IslandData.SE, IslandData.NW, IslandData.SW],
		[Vector2i(-1, 0), IslandData.NW, IslandData.SW, IslandData.NE, IslandData.SE],
		[Vector2i(0, 1), IslandData.SW, IslandData.SE, IslandData.NW, IslandData.NE],
		[Vector2i(0, -1), IslandData.NW, IslandData.NE, IslandData.SW, IslandData.SE],
	]
	for z in d.height:
		for x in d.width:
			var i := d.idx(x, z)
			var split: Dictionary = d.splits.get(i, {})
			if d.tile(x, z) == T.WATER and not _is_mouth(d, x, z):
				var y := d.water_surface(x, z)
				var pts := _tile_points(x, z, y)
				for e in edges:
					var dir: Vector2i = e[0]
					# Edges belonging to a raised (filled) half are land, not water.
					if not split.is_empty() and split["corner"] in [e[1], e[2]]:
						continue
					if not d.in_bounds(x + dir.x, z + dir.y):
						continue
					var mine := d.edge_heights(x, z, e[1], e[2])
					var theirs := d.edge_heights(x + dir.x, z + dir.y, e[3], e[4])
					if theirs.x > mine.x + 0.2 and theirs.y > mine.y + 0.2:
						_foam_strip(k, pts[e[1]], pts[e[2]], -Vector3(dir.x, 0, dir.y))
				if not split.is_empty():
					var c: int = split["corner"]
					var inward := (pts[(c + 2) % 4] - pts[c]).normalized()
					_foam_strip(k, pts[(c + 3) % 4], pts[(c + 1) % 4], inward)
			elif not split.is_empty() and split["tile"] == T.WATER:
				var pts := _tile_points(x, z, _split_water_level(split))
				var c: int = split["corner"]
				var inward := (pts[c] - pts[(c + 2) % 4]).normalized()
				_foam_strip(k, pts[(c + 3) % 4], pts[(c + 1) % 4], inward)
	return k.commit()


## River tiles opening onto the sea are left to the sea itself, so the river runs into
## it rather than ending in a ledge.
static func _is_mouth(d: IslandData, x: int, z: int) -> bool:
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if d.in_bounds(x + dir.x, z + dir.y) and d.tile(x + dir.x, z + dir.y) == T.OCEAN:
			return true
	return false


static func _foam_strip(k: MeshKit, a: Vector3, b: Vector3, inward: Vector3) -> void:
	var width := 0.24
	var lift := Vector3(0, 0.015, 0)
	var length := a.distance_to(b)
	var u0 := a.x + a.z
	var ids := [
		k.vertex(a + lift, Vector3.UP, Color(1, 1, 1, 1), Vector2(u0, 0)),
		k.vertex(b + lift, Vector3.UP, Color(1, 1, 1, 1), Vector2(u0 + length, 0)),
		k.vertex(b + lift + inward * width, Vector3.UP, Color(1, 1, 1, 0), Vector2(u0 + length, 1)),
		k.vertex(a + lift + inward * width, Vector3.UP, Color(1, 1, 1, 0), Vector2(u0, 1)),
	]
	k.quad(ids[0], ids[1], ids[2], ids[3], Vector3.UP)


static func _split_water_level(split: Dictionary) -> float:
	return maxf(IslandData.tier_height(split["tier"]) - IslandData.WATER_DROP, IslandData.SEA_LEVEL)


static func _tile_points(x: int, z: int, y: float) -> Array[Vector3]:
	return [Vector3(x, y, z), Vector3(x + 1, y, z), Vector3(x + 1, y, z + 1), Vector3(x, y, z + 1)]


## The sea: a fine grid around the island (shore distance in vertex red) plus a coarse
## outer skirt reaching to the horizon.
## How far the sea reaches past the island, in tiles (the title screen, seen from low
## down, wants it to run on further).
static var sea_reach := 240


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

	# Coarse skirt out to the horizon, level with the fine grid. It's one grid whose lines
	# carry on from the fine grid's (1 apart alongside it, 16 apart beyond), so every
	# edge it shares has the same vertices on both sides: no hairline cracks for the ink
	# outline to catch when it's seen from low down, as on the title screen.
	var xs := _skirt_lines(-b, w + b - 1, sea_reach)
	var zs := _skirt_lines(-b, h + b - 1, sea_reach)
	var base := k.verts.size()
	for z in zs:
		for x in xs:
			k.vertex(Vector3(x, IslandData.SEA_LEVEL, z), Vector3.UP, Color(1, 0, 0, 1))
	var cols := xs.size()
	for iz in zs.size() - 1:
		for ix in cols - 1:
			var inside := xs[ix] >= -b and xs[ix + 1] <= w + b - 1 and zs[iz] >= -b and zs[iz + 1] <= h + b - 1
			if not inside:
				var a := base + iz * cols + ix
				k.quad(a, a + 1, a + cols + 1, a + cols, Vector3.UP)
	return k.commit()


## Grid lines for the sea skirt along one axis: every 1 across the fine grid from `lo`
## to `hi`, then every 16 out to 240 and every 80 beyond that, out to `reach`.
static func _skirt_lines(lo: int, hi: int, reach: int) -> PackedFloat32Array:
	var gaps := PackedFloat32Array()
	var at := 0
	while at < reach:
		at += 16 if at < 240 else 80
		gaps.append(mini(at, reach))
	var out := PackedFloat32Array()
	for i in range(gaps.size() - 1, -1, -1):
		out.append(lo - gaps[i])
	for v in range(lo, hi + 1):
		out.append(v)
	for g in gaps:
		out.append(hi + g)
	return out


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
