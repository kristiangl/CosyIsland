class_name IslandGenerator
extends RefCounted
## Builds a random island from a seed. The same seed always gives the same island.
##
## Steps: coastline -> beach -> cliff tiers -> plaza -> rivers and bridges -> ponds ->
## ramps -> corner heights -> native species -> trees, rocks and flowers.

const WIDTH := 96
const HEIGHT := 80
const OCEAN_MARGIN := 9
const PLAZA_SIZE := 8
## Where the office and workbench sit in the plaza (top-left tile, plaza coordinates).
const OFFICE_AT := Vector2i(2, 0)
const WORKBENCH_AT := Vector2i(5, 4)
## Bumped when a change to generation would alter existing islands. Saves remember the
## version their island was made with, so old islands keep their shape.
##   1: first release. 2: rivers cross the beach instead of running along it.
##   3: bushes along the edges of the woods.
const VERSION := 3
const ROCK_COUNT := 6
const FRUIT_TREE_COUNT := 8
## Tour islands are smaller.
const TOUR_WIDTH := 64
const TOUR_HEIGHT := 56

## Kept in sync with data/items.json (checked by the tests).
const FRUITS := ["apple", "orange", "pear", "cherry", "peach", "plum"]
const FLOWERS := ["tulip", "pansy", "cosmos", "rose", "lily", "hyacinth", "windflower", "mum"]
const FLOWER_COLOURS := ["red", "red", "white", "yellow", "yellow"]

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Corner height on the beach by number of sea tiles touching that corner (0-4).
const SHORE_PROFILE: Array[float] = [IslandData.SAND_HEIGHT, 0.05, IslandData.SHORE_HEIGHT, -0.4, IslandData.OCEAN_FLOOR]
## For each corner (NW, NE, SE, SW): the two edge neighbours and the diagonal neighbour.
const CORNER_NEIGHBOURS := [
	[Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)],
	[Vector2i(1, 0), Vector2i(0, -1), Vector2i(1, -1)],
	[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(-1, 0), Vector2i(0, 1), Vector2i(-1, 1)],
]
const T := IslandData.Tile

var d: IslandData
var version := VERSION
## Tour islands: no plaza buildings, and natives other than these.
var tour := false
var avoid: Array = []
var rng := RandomNumberGenerator.new()
var ocean_dist: PackedInt32Array
var beach_width: PackedInt32Array
## Tiles where generated objects must not go (plaza, bridge ends, ramp landings).
var reserved: PackedByteArray
## Tiles holding a generated object.
var occupied: PackedByteArray


static func generate(seed_value: int, w: int = WIDTH, h: int = HEIGHT, gen_version: int = VERSION) -> IslandData:
	var g := IslandGenerator.new()
	g.version = gen_version
	return g._run(seed_value, w, h)


## A small wild island for a tour: no plaza or office, and a different fruit and flower
## from home's.
static func generate_tour(seed_value: int, home_fruit: String, home_flower: String) -> IslandData:
	var g := IslandGenerator.new()
	g.tour = true
	g.avoid = [home_fruit, home_flower]
	var data := g._run(seed_value, TOUR_WIDTH, TOUR_HEIGHT)
	data.plaza = Rect2i()
	return data


func _run(seed_value: int, w: int, h: int) -> IslandData:
	d = IslandData.new()
	d.setup(w, h)
	d.seed_value = seed_value
	rng.seed = seed_value
	reserved.resize(w * h)
	occupied.resize(w * h)

	_make_coastline()
	_compute_ocean_distance()
	_make_beach()
	_make_tiers()
	_choose_plaza()
	_make_rivers()
	_make_ponds()
	_merge_lagoons()
	_make_ramps()
	_compute_corners()
	_compute_splits()
	d.native_fruit = FRUITS[rng.randi() % FRUITS.size()]
	d.native_flower = FLOWERS[rng.randi() % FLOWERS.size()]
	while d.native_fruit in avoid:
		d.native_fruit = FRUITS[rng.randi() % FRUITS.size()]
	while d.native_flower in avoid:
		d.native_flower = FLOWERS[rng.randi() % FLOWERS.size()]
	_place_trees()
	_place_palms()
	_place_rocks()
	_place_flowers()
	if not tour:
		_place_plaza()
	if version >= 3:
		_place_bushes()
	return d


func _noise(seed_offset: int, frequency: float, octaves: int = 3) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = d.seed_value + seed_offset
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	n.fractal_octaves = octaves
	return n


# --- Terrain -------------------------------------------------------------------------

func _make_coastline() -> void:
	var coast := _noise(11, 0.05)
	var centre := Vector2(d.width, d.height) * 0.5
	var radius := 12.0
	var half := centre - Vector2(OCEAN_MARGIN, OCEAN_MARGIN)
	for z in d.height:
		for x in d.width:
			# Rounded-rectangle distance with a noisy edge.
			var q := (Vector2(x + 0.5, z + 0.5) - centre).abs() - (half - Vector2(radius, radius))
			var sd := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
			sd += coast.get_noise_2d(x, z) * 5.0
			d.tiles[d.idx(x, z)] = T.GRASS if sd < 0.0 else T.OCEAN

	# Lakes cut off from the sea become land, and stray islets sink.
	var sea := _flood(Vector2i(0, 0), func(x, z): return d.tile(x, z) == T.OCEAN)
	for i in d.tiles.size():
		if d.tiles[i] == T.OCEAN and not sea.has(i):
			d.tiles[i] = T.GRASS
	var biggest := {}
	var seen := {}
	for z in d.height:
		for x in d.width:
			var i := d.idx(x, z)
			if d.tiles[i] == T.GRASS and not seen.has(i):
				var comp := _flood(Vector2i(x, z), func(px, pz): return d.tile(px, pz) == T.GRASS)
				seen.merge(comp)
				if comp.size() > biggest.size():
					biggest = comp
	for i in d.tiles.size():
		if d.tiles[i] == T.GRASS and not biggest.has(i):
			d.tiles[i] = T.OCEAN


func _compute_ocean_distance() -> void:
	ocean_dist.resize(d.width * d.height)
	var queue: Array[Vector2i] = []
	for z in d.height:
		for x in d.width:
			var ocean := d.tile(x, z) == T.OCEAN
			ocean_dist[d.idx(x, z)] = 0 if ocean else 9999
			if ocean:
				queue.append(Vector2i(x, z))
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		var nd := ocean_dist[d.idx(p.x, p.y)] + 1
		for dir in DIRS:
			var n := p + dir
			if d.in_bounds(n.x, n.y) and ocean_dist[d.idx(n.x, n.y)] > nd:
				ocean_dist[d.idx(n.x, n.y)] = nd
				queue.append(n)


func _make_beach() -> void:
	var beach := _noise(23, 0.08, 2)
	beach_width.resize(d.width * d.height)
	for z in d.height:
		for x in d.width:
			var i := d.idx(x, z)
			beach_width[i] = 3 + int(round((beach.get_noise_2d(x, z) + 1.0) * 1.1))
			if d.tiles[i] == T.GRASS and ocean_dist[i] <= beach_width[i]:
				d.tiles[i] = T.SAND
			d.tiers[i] = 1 if d.tiles[i] == T.GRASS else 0


func _make_tiers() -> void:
	var tier_noise := _noise(37, 0.045, 3)
	var has_top_tier := rng.randf() < 0.75
	for z in d.height:
		for x in d.width:
			var i := d.idx(x, z)
			if d.tiles[i] != T.GRASS:
				continue
			var north := (d.height * 0.5 - z) / (d.height * 0.5)
			var f := north + tier_noise.get_noise_2d(x, z) * 0.45
			var inland := ocean_dist[i] - beach_width[i]
			if f > 0.12 and inland >= 4:
				d.tiers[i] = 2
				if has_top_tier and f > 0.55 and inland >= 8:
					d.tiers[i] = 3
	for _pass in 2:
		_open_tier(3)
		_open_tier(2)
	# A tier-3 tile must never touch tier 1 directly.
	var changed := true
	while changed:
		changed = false
		for z in d.height:
			for x in d.width:
				if d.tier(x, z) == 3 and _min_neighbour_tier(x, z) < 2:
					d.tiers[d.idx(x, z)] = 2
					changed = true


## Drops tiles of tier >= level to level - 1 unless they sit inside a full 3x3 block,
## so plateaus are never thinner than three tiles.
func _open_tier(level: int) -> void:
	var keep := PackedByteArray()
	keep.resize(d.width * d.height)
	for z in range(-2, d.height):
		for x in range(-2, d.width):
			if _block_at_least(x, z, level):
				for bz in 3:
					for bx in 3:
						keep[d.idx(x + bx, z + bz)] = 1
	for i in d.tiers.size():
		if d.tiers[i] >= level and keep[i] == 0:
			d.tiers[i] = level - 1


func _block_at_least(x0: int, z0: int, level: int) -> bool:
	for bz in 3:
		for bx in 3:
			if not d.in_bounds(x0 + bx, z0 + bz) or d.tier(x0 + bx, z0 + bz) < level:
				return false
	return true


func _min_neighbour_tier(x: int, z: int) -> int:
	var lowest := 99
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			lowest = min(lowest, d.tier(x + dx, z + dz))
	return lowest


func _choose_plaza() -> void:
	var target := Vector2(d.width * 0.5, d.height * 0.6)
	var best := Vector2i(-1, -1)
	var best_dist := INF
	for z in d.height - PLAZA_SIZE:
		for x in d.width - PLAZA_SIZE:
			var dist := Vector2(x + PLAZA_SIZE * 0.5, z + PLAZA_SIZE * 0.5).distance_to(target)
			if dist < best_dist and _area_is(Rect2i(x - 1, z - 1, PLAZA_SIZE + 2, PLAZA_SIZE + 2), T.GRASS, 1):
				best_dist = dist
				best = Vector2i(x, z)
	if best.x < 0:
		best = Vector2i(int(target.x) - PLAZA_SIZE / 2, int(target.y) - PLAZA_SIZE / 2)
	d.plaza = Rect2i(best, Vector2i(PLAZA_SIZE, PLAZA_SIZE))
	d.spawn = d.plaza.get_center()
	_reserve_rect(d.plaza.grow(1))


func _area_is(rect: Rect2i, tile_type: int, tier_level: int) -> bool:
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if d.tile(x, z) != tile_type or d.tier(x, z) != tier_level:
				return false
	return true


func _reserve_rect(rect: Rect2i) -> void:
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if d.in_bounds(x, z):
				reserved[d.idx(x, z)] = 1


# --- Water ---------------------------------------------------------------------------

func _make_rivers() -> void:
	var meander := _noise(53, 0.12, 2)
	# Rivers keep well clear of the plaza; carving may come a little closer.
	var avoid := d.plaza.grow(5)
	var no_go := d.plaza.grow(1)
	var land_cost := func(x: int, z: int) -> float:
		if d.tier(x, z) >= 2 or avoid.has_point(Vector2i(x, z)):
			return -1.0
		# Beaches are dear, so rivers cut straight across them to the sea.
		var beach := 8.0 if version >= 2 and d.tile(x, z) == T.SAND else 0.0
		return 1.0 + (meander.get_noise_2d(x, z) + 1.0) * 2.5 + beach

	var south_mouth := func(x: int, z: int) -> bool:
		return z > d.height * 0.6
	var any_mouth := func(_x: int, _z: int) -> bool:
		return true
	# Try a few springs at the foot of the cliffs until one finds its way to the sea.
	var main: Array[Vector2i] = []
	var sources := _river_sources(avoid)
	for goal in [south_mouth, any_mouth]:
		for source in sources.slice(0, 12):
			main = _route(source, goal, land_cost)
			if main.size() > 6:
				break
		if main.size() > 6:
			break
	if main.size() <= 6:
		return
	_carve_river(main, no_go)
	_place_bridge(main)

	if rng.randf() < 0.65:
		var split := main[int(main.size() * rng.randf_range(0.35, 0.6))]
		var go_east := main[-1].x < d.width / 2
		var side_mouth := func(x: int, z: int) -> bool:
			return x > d.width * 0.72 if go_east else x < d.width * 0.28
		var branch_cost := func(x: int, z: int) -> float:
			var c: float = land_cost.call(x, z)
			if c < 0.0:
				return c
			if Vector2i(x, z).distance_to(split) > 3.0 and _near_water(x, z, 2):
				c += 25.0
			return c
		var branch := _route(split, side_mouth, branch_cost)
		if branch.size() > 4:
			_carve_river(branch, no_go)
			_place_bridge(branch.slice(3))


## Candidate river springs, best first: grass at the foot of a cliff, near the middle.
func _river_sources(avoid: Rect2i) -> Array[Vector2i]:
	var springs: Array[Vector2i] = []
	var fallback: Array[Vector2i] = []
	for z in d.height:
		for x in d.width:
			var p := Vector2i(x, z)
			if d.tile(x, z) != T.GRASS or d.tier(x, z) != 1 or avoid.grow(3).has_point(p):
				continue
			if d.tier(x, z - 1) == 2 and x > d.width * 0.25 and x < d.width * 0.75:
				springs.append(p)
			elif z < d.height * 0.5:
				fallback.append(p)
	_shuffle(springs)
	_shuffle(fallback)
	return springs + fallback


## Cheapest path over land from start to an ocean tile accepted by is_goal.
## cost(x, z) returns the cost of entering a land tile, or < 0 if it is blocked.
func _route(start: Vector2i, is_goal: Callable, cost: Callable) -> Array[Vector2i]:
	var best := {d.idx(start.x, start.y): 0.0}
	var came_from := {}
	var heap: Array[Vector2] = [Vector2(0.0, d.idx(start.x, start.y))]
	while not heap.is_empty():
		var top := _heap_pop(heap)
		var i := int(top.y)
		# Heap entries are 32-bit floats, so allow for rounding against the stored cost.
		if top.x > best.get(i, INF) + 0.001:
			continue
		var p := Vector2i(i % d.width, i / d.width)
		for dir in DIRS:
			var n := p + dir
			if not d.in_bounds(n.x, n.y):
				continue
			if d.tile(n.x, n.y) == T.OCEAN:
				if is_goal.call(n.x, n.y):
					var path: Array[Vector2i] = [p]
					var k := i
					while came_from.has(k):
						k = came_from[k]
						path.push_front(Vector2i(k % d.width, k / d.width))
					return path
				continue
			var step: float = cost.call(n.x, n.y)
			if step < 0.0:
				continue
			var ni := d.idx(n.x, n.y)
			var nc := top.x + step
			if nc < best.get(ni, INF):
				best[ni] = nc
				came_from[ni] = i
				_heap_push(heap, nc, ni)
	return []


func _carve_river(path: Array[Vector2i], no_go: Rect2i) -> void:
	for p in path:
		for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var q: Vector2i = p + off
			if d.is_land(q.x, q.y) and d.tier(q.x, q.y) <= 1 and not no_go.has_point(q):
				d.tiles[d.idx(q.x, q.y)] = T.WATER


## River water on the beach sits at sea level, so it becomes part of the sea: a little
## lagoon or inlet with a proper shoreline, instead of a second water surface fighting
## with the sea's.
func _merge_lagoons() -> void:
	var merged: Array[Vector2i] = []
	for i in d.tiles.size():
		if d.tiles[i] == T.WATER and d.tiers[i] == 0:
			d.tiles[i] = T.OCEAN
			merged.append(Vector2i(i % d.width, i / d.width))
	# Thin sandbars left between the lagoon and the sea wash away.
	if merged.is_empty():
		return
	for pass_i in 3:
		var washed: Array[int] = []
		for z in d.height:
			for x in d.width:
				var i := d.idx(x, z)
				if d.tiles[i] != T.SAND or reserved[i]:
					continue
				var n := d.tile(x, z - 1) == T.OCEAN
				var s := d.tile(x, z + 1) == T.OCEAN
				var e := d.tile(x + 1, z) == T.OCEAN
				var w := d.tile(x - 1, z) == T.OCEAN
				if (n and s) or (e and w) or int(n) + int(s) + int(e) + int(w) >= 3:
					washed.append(i)
		for i in washed:
			d.tiles[i] = T.OCEAN
	# So do little sand islands cut off from the shore.
	var mainland := {}
	for i in d.tiles.size():
		if d.tiles[i] == T.GRASS and not mainland.has(i):
			mainland.merge(_flood(Vector2i(i % d.width, i / d.width), func(x: int, z: int) -> bool: return d.tile(x, z) != T.OCEAN))
	for i in d.tiles.size():
		if d.tiles[i] == T.SAND and not mainland.has(i) and not reserved[i]:
			d.tiles[i] = T.OCEAN
	# Grass right at the water's edge becomes beach, so the shore slopes down gently.
	for p in merged:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var q := p + Vector2i(dx, dz)
				if d.tile(q.x, q.y) == T.GRASS and d.tier(q.x, q.y) == 1 and not reserved[d.idx(q.x, q.y)]:
					d.tiles[d.idx(q.x, q.y)] = T.SAND
					d.tiers[d.idx(q.x, q.y)] = 0


func _near_water(x: int, z: int, radius: int) -> bool:
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if d.tile(x + dx, z + dz) == T.WATER:
				return true
	return false


## Puts a plank bridge across the river where it crosses a short straight stretch,
## preferring the spot closest to the plaza.
func _place_bridge(path: Array[Vector2i]) -> void:
	var best := {}
	var best_dist := INF
	for p in path:
		for axis: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var a := p
			while d.tile(a.x - axis.x, a.y - axis.y) == T.WATER:
				a -= axis
			var length := 0
			while d.tile(a.x + axis.x * length, a.y + axis.y * length) == T.WATER:
				length += 1
			if length < 2 or length > 3:
				continue
			var before: Vector2i = a - axis
			var after: Vector2i = a + axis * length
			if not _good_bridge_end(before) or not _good_bridge_end(after) \
					or d.tier(before.x, before.y) != d.tier(after.x, after.y):
				continue
			# Both rails must run alongside water so the bridge sits on a straight reach.
			var side := Vector2i(axis.y, axis.x)
			var straight := true
			for k in length:
				var w := a + axis * k
				if d.tile(w.x + side.x, w.y + side.y) != T.WATER and d.tile(w.x - side.x, w.y - side.y) != T.WATER:
					straight = false
			if not straight:
				continue
			var dist := Vector2(a).distance_to(Vector2(d.plaza.get_center()))
			if dist < best_dist:
				best_dist = dist
				best = {"x": a.x, "z": a.y, "length": length, "axis": "x" if axis.x == 1 else "z"}
	if best.is_empty():
		return
	best["uid"] = d.new_uid()
	best["kind"] = "bridge"
	d.objects.append(best)
	var axis_v := Vector2i(1, 0) if best["axis"] == "x" else Vector2i(0, 1)
	for k in range(-1, best["length"] + 1):
		var q := Vector2i(best["x"], best["z"]) + axis_v * k
		reserved[d.idx(q.x, q.y)] = 1


func _good_bridge_end(p: Vector2i) -> bool:
	return d.is_land(p.x, p.y) and reserved[d.idx(p.x, p.y)] == 0


func _make_ponds() -> void:
	var count := rng.randi_range(1, 2)
	var attempts := 0
	while count > 0 and attempts < 200:
		attempts += 1
		var c := Vector2i(rng.randi_range(6, d.width - 7), rng.randi_range(6, d.height - 7))
		var level := d.tier(c.x, c.y)
		if d.tile(c.x, c.y) != T.GRASS or level < 1 or reserved[d.idx(c.x, c.y)] == 1:
			continue
		var rx := rng.randf_range(1.6, 2.8)
		var rz := rng.randf_range(1.4, 2.4)
		var cells: Array[Vector2i] = []
		var ok := true
		for z in range(c.y - 4, c.y + 5):
			for x in range(c.x - 4, c.x + 5):
				var inside := pow((x - c.x) / rx, 2) + pow((z - c.y) / rz, 2) <= 1.0
				# Every tile near the pond must be plain grass of the same tier.
				if d.tile(x, z) != T.GRASS or d.tier(x, z) != level or reserved[d.idx(x, z)] == 1:
					ok = false
				if inside:
					cells.append(Vector2i(x, z))
		if not ok or cells.size() < 5:
			continue
		for cell in cells:
			d.tiles[d.idx(cell.x, cell.y)] = T.WATER
		count -= 1


## Each plateau gets ramps (two tiles long) so the whole island can be walked.
func _make_ramps() -> void:
	for level in [2, 3]:
		var seen := {}
		for z in d.height:
			for x in d.width:
				var i := d.idx(x, z)
				if d.tier(x, z) >= level and d.tile(x, z) != T.OCEAN and not seen.has(i):
					var comp := _flood(Vector2i(x, z), func(px, pz): return d.tier(px, pz) >= level)
					seen.merge(comp)
					_add_ramps_to(comp, level, 2 if level == 2 else 1)


func _add_ramps_to(comp: Dictionary, level: int, wanted: int) -> void:
	var candidates: Array[Dictionary] = []
	for i in comp:
		var u := Vector2i(i % d.width, i / d.width)
		if d.tier(u.x, u.y) != level or d.tile(u.x, u.y) != T.GRASS:
			continue
		for dir in DIRS:
			if _ramp_fits(u, dir, level):
				var facing_bonus := 0.0 if dir == Vector2i(0, 1) else 6.0
				var score := Vector2(u).distance_to(Vector2(d.plaza.get_center())) + facing_bonus + rng.randf() * 10.0
				candidates.append({"top": u, "dir": dir, "score": score})
	candidates.sort_custom(func(a, b): return a["score"] < b["score"])
	var placed: Array[Vector2i] = []
	for c in candidates:
		if placed.size() >= wanted:
			break
		var far_enough := true
		for p in placed:
			if p.distance_to(c["top"]) < 14.0:
				far_enough = false
		if not far_enough or not _ramp_fits(c["top"], c["dir"], level):
			continue
		var dir: Vector2i = c["dir"]
		var a: Vector2i = c["top"] + dir
		var b: Vector2i = c["top"] + dir * 2
		var high := IslandData.tier_height(level)
		var low := IslandData.tier_height(level - 1)
		var mid := (high + low) * 0.5
		d.ramps[d.idx(a.x, a.y)] = {"up": -dir, "high": high, "low": mid}
		d.ramps[d.idx(b.x, b.y)] = {"up": -dir, "high": mid, "low": low}
		for k in range(0, 4):
			var q: Vector2i = c["top"] + dir * k
			var side := Vector2i(dir.y, dir.x)
			for s in [-1, 0, 1]:
				var r: Vector2i = q + side * s
				if d.in_bounds(r.x, r.y):
					reserved[d.idx(r.x, r.y)] = 1
		placed.append(c["top"])


func _ramp_fits(u: Vector2i, dir: Vector2i, level: int) -> bool:
	var side := Vector2i(dir.y, dir.x)
	for s in [-1, 1]:
		if d.tier(u.x + side.x * s, u.y + side.y * s) != level:
			return false
	for k in [1, 2, 3]:
		var q: Vector2i = u + dir * k
		if d.tile(q.x, q.y) != T.GRASS or d.tier(q.x, q.y) != level - 1 or d.is_ramp(q.x, q.y):
			return false
		if not d.in_bounds(q.x, q.y) or reserved[d.idx(q.x, q.y)] == 1:
			return false
		if k < 3:
			for s in [-1, 1]:
				var r: Vector2i = q + side * s
				if d.tile(r.x, r.y) != T.GRASS or d.tier(r.x, r.y) != level - 1 or d.is_ramp(r.x, r.y):
					return false
	return true


func _compute_corners() -> void:
	# Tiles sharing each corner, as offsets from the tile, in NW/NE/SE/SW order.
	var corner_tiles := [
		[Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)],
		[Vector2i(0, -1), Vector2i(1, -1), Vector2i(0, 0), Vector2i(1, 0)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(-1, 1), Vector2i(0, 1)],
	]
	for z in d.height:
		for x in d.width:
			var i := d.idx(x, z)
			var t: int = d.tiles[i]
			if t == T.GRASS:
				if d.ramps.has(i):
					_set_ramp_corners(x, z, d.ramps[i])
				else:
					var hgt := IslandData.tier_height(d.tiers[i])
					d.set_corners(x, z, hgt, hgt, hgt, hgt)
			elif t == T.WATER:
				var bed := IslandData.tier_height(d.tiers[i]) - IslandData.RIVER_DEPTH
				d.set_corners(x, z, bed, bed, bed, bed)
			else:
				# Beach and sea: each corner's height depends on how many of the four tiles
				# around it are sea, so the waterline cuts diagonally across tiles.
				var hs: Array[float] = []
				for c in 4:
					var near_grass := false
					var oceans := 0
					for off in corner_tiles[c]:
						var nt := d.tile(x + off.x, z + off.y)
						near_grass = near_grass or (nt == T.GRASS and d.tier(x + off.x, z + off.y) == 1)
						if nt == T.OCEAN:
							oceans += 1
					hs.append(IslandData.GRASS_HEIGHT if near_grass else SHORE_PROFILE[oceans])
				d.set_corners(x, z, hs[0], hs[1], hs[2], hs[3])

## Rounds off cliff and riverbank corners. A convex corner of higher ground loses a
## diagonal half to the level below; an inside corner of lower ground gains a half from
## the level above. Inside corners next to a cut are skipped, so diagonal staircases turn
## into one straight diagonal rather than a zigzag.
func _compute_splits() -> void:
	var no_split := {}
	for o in d.objects:
		if o["kind"] == "bridge":
			var axis := Vector2i(1, 0) if o["axis"] == "x" else Vector2i(0, 1)
			for k in range(-1, o["length"] + 1):
				var q := Vector2i(o["x"], o["z"]) + axis * k
				no_split[d.idx(q.x, q.y)] = true
	var cuts := {}
	for z in d.height:
		for x in d.width:
			var i := d.idx(x, z)
			if d.tiles[i] != T.GRASS or no_split.has(i):
				continue
			var h := _flat_height(x, z)
			if is_nan(h):
				continue
			var options := []
			for c in 4:
				var n: Array = CORNER_NEIGHBOURS[c]
				var low := _common_level(x, z, n, [T.GRASS, T.WATER])
				if not low.is_empty() and low["h"] < h - 0.3:
					options.append({"corner": c, "h": low["h"], "tile": low["tile"], "tier": low["tier"]})
			if options.size() == 1:
				cuts[i] = options[0]
	var fills := {}
	for z in d.height:
		for x in d.width:
			var i := d.idx(x, z)
			if not d.tiles[i] in [T.GRASS, T.WATER] or no_split.has(i) or cuts.has(i):
				continue
			var h := _flat_height(x, z)
			if is_nan(h):
				continue
			var options := []
			for c in 4:
				var n: Array = CORNER_NEIGHBOURS[c]
				var high := _common_level(x, z, n, [T.GRASS])
				var a: Vector2i = Vector2i(x, z) + n[0]
				var b: Vector2i = Vector2i(x, z) + n[1]
				if not high.is_empty() and high["h"] > h + 0.3 \
						and not cuts.has(d.idx(a.x, a.y)) and not cuts.has(d.idx(b.x, b.y)):
					options.append({"corner": c, "h": high["h"], "tile": T.GRASS, "tier": high["tier"]})
			if options.size() == 1:
				fills[i] = options[0]
	d.splits = cuts
	d.splits.merge(fills)
	for i in d.splits:
		reserved[i] = 1


## Height of a flat, plain (not ramp, not sloped) tile, or NAN.
func _flat_height(x: int, z: int) -> float:
	if not d.in_bounds(x, z) or d.is_ramp(x, z) or not d.is_flat(x, z):
		return NAN
	return d.corner(x, z, IslandData.NW)


## If the three neighbours around a corner are flat, of one allowed type and at one
## height, returns {"h", "tile", "tier"}; otherwise {}.
func _common_level(x: int, z: int, offsets: Array, allowed: Array) -> Dictionary:
	var first: Vector2i = Vector2i(x, z) + offsets[0]
	var t := d.tile(first.x, first.y)
	var h := _flat_height(first.x, first.y)
	if is_nan(h) or not t in allowed:
		return {}
	for off in offsets:
		var q: Vector2i = Vector2i(x, z) + off
		if d.tile(q.x, q.y) != t or not is_equal_approx(_flat_height(q.x, q.y), h):
			return {}
	return {"h": h, "tile": t, "tier": d.tier(first.x, first.y)}


func _set_ramp_corners(x: int, z: int, ramp: Dictionary) -> void:
	var up: Vector2i = ramp["up"]
	var hi: float = ramp["high"]
	var lo: float = ramp["low"]
	if up == Vector2i(0, -1):
		d.set_corners(x, z, hi, hi, lo, lo)
	elif up == Vector2i(0, 1):
		d.set_corners(x, z, lo, lo, hi, hi)
	elif up == Vector2i(1, 0):
		d.set_corners(x, z, lo, hi, hi, lo)
	else:
		d.set_corners(x, z, hi, lo, lo, hi)


# --- Objects -------------------------------------------------------------------------

func _add_object(obj: Dictionary) -> void:
	obj["uid"] = d.new_uid()
	d.objects.append(obj)
	occupied[d.idx(obj["x"], obj["z"])] = 1


func _free(x: int, z: int) -> bool:
	return d.in_bounds(x, z) and occupied[d.idx(x, z)] == 0 and reserved[d.idx(x, z)] == 0


## A tile where a tree or rock may go: flat open ground with all eight neighbours unoccupied.
func _open_spot(x: int, z: int, tile_type: int) -> bool:
	if d.tile(x, z) != tile_type or d.is_ramp(x, z) or not _free(x, z):
		return false
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if not d.in_bounds(x + dx, z + dz) or occupied[d.idx(x + dx, z + dz)] == 1:
				return false
	return true


func _place_trees() -> void:
	var forest := _noise(71, 0.07, 2)
	var trees: Array[Dictionary] = []
	for z in d.height:
		for x in d.width:
			if not _open_spot(x, z, T.GRASS):
				continue
			var chance := 0.02 + maxf(forest.get_noise_2d(x, z), 0.0) * 0.6
			if rng.randf() < chance:
				var tree := {"kind": "tree", "x": x, "z": z, "wood_left": 3, "variant": rng.randi() % 4}
				_add_object(tree)
				trees.append(tree)
	# The native fruit trees grow near the plaza.
	var centre := Vector2(d.plaza.get_center())
	trees.sort_custom(func(a, b): return centre.distance_to(Vector2(a["x"], a["z"])) < centre.distance_to(Vector2(b["x"], b["z"])))
	var near := trees.slice(0, mini(trees.size(), FRUIT_TREE_COUNT * 3))
	for k in mini(FRUIT_TREE_COUNT, near.size()):
		var pick: Dictionary = near.pop_at(rng.randi() % near.size())
		pick["kind"] = "fruit_tree"
		pick["fruit"] = d.native_fruit
		pick["fruit_count"] = 3


func _place_palms() -> void:
	var wanted := rng.randi_range(7, 11)
	var spots: Array[Vector2i] = []
	for z in d.height:
		for x in d.width:
			if _open_spot(x, z, T.SAND) and ocean_dist[d.idx(x, z)] >= 2:
				spots.append(Vector2i(x, z))
	_shuffle(spots)
	for p in spots:
		if wanted <= 0:
			break
		if _open_spot(p.x, p.y, T.SAND):
			_add_object({"kind": "palm", "x": p.x, "z": p.y, "variant": rng.randi() % 4})
			wanted -= 1


func _place_rocks() -> void:
	var spots: Array[Vector2i] = []
	for z in d.height:
		for x in d.width:
			if _rock_spot(x, z):
				spots.append(Vector2i(x, z))
	_shuffle(spots)
	var placed: Array[Vector2i] = []
	for p in spots:
		if placed.size() >= ROCK_COUNT:
			break
		var far := true
		for q in placed:
			if q.distance_to(p) < 7.0:
				far = false
		if far and _rock_spot(p.x, p.y):
			_add_object({"kind": "rock", "x": p.x, "z": p.y, "hits_left": 8, "variant": rng.randi() % 4})
			placed.append(p)


## Rocks need open, flat grass of one tier all around so they can be hit from any side.
func _rock_spot(x: int, z: int) -> bool:
	if not _open_spot(x, z, T.GRASS):
		return false
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if d.tile(x + dx, z + dz) != T.GRASS or d.tier(x + dx, z + dz) != d.tier(x, z) \
					or d.is_ramp(x + dx, z + dz) or reserved[d.idx(x + dx, z + dz)] == 1:
				return false
	return true


func _place_flowers() -> void:
	var clusters := rng.randi_range(6, 9)
	var attempts := 0
	while clusters > 0 and attempts < 500:
		attempts += 1
		var c := Vector2i(rng.randi_range(0, d.width - 1), rng.randi_range(0, d.height - 1))
		if d.tile(c.x, c.y) != T.GRASS or not _free(c.x, c.y):
			continue
		var colour: String = FLOWER_COLOURS[rng.randi() % FLOWER_COLOURS.size()]
		var planted := 0
		for k in rng.randi_range(4, 8):
			var p := c + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
			if d.tile(p.x, p.y) == T.GRASS and not d.is_ramp(p.x, p.y) and _free(p.x, p.y):
				# Clusters are mostly one colour with the odd stray.
				var col: String = colour if rng.randf() < 0.8 else FLOWER_COLOURS[rng.randi() % FLOWER_COLOURS.size()]
				_add_object({"kind": "flower", "x": p.x, "z": p.y, "species": d.native_flower, "color": col})
				planted += 1
		if planted > 0:
			clusters -= 1


## Bushes along the edges of the woods, alone or in twos and threes, never boxing
## anything in: each needs open ground all round apart from its own cluster.
func _place_bushes() -> void:
	var near_trees := {}
	for obj in d.objects:
		if obj["kind"] in ["tree", "fruit_tree"]:
			for dz in range(-3, 4):
				for dx in range(-3, 4):
					near_trees[Vector2i(obj["x"] + dx, obj["z"] + dz)] = true
	var spots: Array[Vector2i] = []
	for z in d.height:
		for x in d.width:
			if near_trees.has(Vector2i(x, z)) and _open_spot(x, z, T.GRASS):
				spots.append(Vector2i(x, z))
	_shuffle(spots)
	var wanted := rng.randi_range(14, 22)
	for p in spots:
		if wanted <= 0:
			break
		if not _open_spot(p.x, p.y, T.GRASS):
			continue
		_add_object({"kind": "bush", "x": p.x, "z": p.y, "variant": rng.randi() % 4})
		wanted -= 1
		# Sometimes a second one alongside.
		var side: Vector2i = p + (Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(0, 1))
		if rng.randf() < 0.4 and d.tile(side.x, side.y) == T.GRASS and not d.is_ramp(side.x, side.y) and _free(side.x, side.y):
			_add_object({"kind": "bush", "x": side.x, "z": side.y, "variant": rng.randi() % 4})


## The plaza starts with the island office and a DIY workbench everyone can use.
func _place_plaza() -> void:
	var o := d.plaza.position + OFFICE_AT
	d.objects.append({"uid": d.new_uid(), "kind": "placed", "item": "island_office", "x": o.x, "z": o.y,
		"w": 4, "d": 3, "rot": 0, "fixed": true})
	var p := d.plaza.position + WORKBENCH_AT
	d.objects.append({"uid": d.new_uid(), "kind": "placed", "item": "workbench", "x": p.x, "z": p.y,
		"w": 2, "d": 1, "rot": 0, "fixed": true})


# --- Helpers -------------------------------------------------------------------------

## 4-connected flood fill. Returns a Dictionary used as a set of tile indices.
func _flood(start: Vector2i, accept: Callable) -> Dictionary:
	var result := {}
	if not d.in_bounds(start.x, start.y) or not accept.call(start.x, start.y):
		return result
	var stack: Array[Vector2i] = [start]
	result[d.idx(start.x, start.y)] = true
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		for dir in DIRS:
			var n := p + dir
			if d.in_bounds(n.x, n.y) and not result.has(d.idx(n.x, n.y)) and accept.call(n.x, n.y):
				result[d.idx(n.x, n.y)] = true
				stack.append(n)
	return result


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func _heap_push(heap: Array[Vector2], cost: float, index: int) -> void:
	heap.append(Vector2(cost, index))
	var c := heap.size() - 1
	while c > 0:
		var parent := (c - 1) >> 1
		if heap[parent].x <= heap[c].x:
			break
		var tmp := heap[parent]
		heap[parent] = heap[c]
		heap[c] = tmp
		c = parent


static func _heap_pop(heap: Array[Vector2]) -> Vector2:
	var top := heap[0]
	var last: Vector2 = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var c := 0
	while true:
		var l := c * 2 + 1
		var r := l + 1
		var m := c
		if l < heap.size() and heap[l].x < heap[m].x:
			m = l
		if r < heap.size() and heap[r].x < heap[m].x:
			m = r
		if m == c:
			break
		var tmp := heap[m]
		heap[m] = heap[c]
		heap[c] = tmp
		c = m
	return top
