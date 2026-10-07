class_name IslandData
extends RefCounted
## Grid description of an island: tile types, cliff tiers, surface heights and objects.
##
## One tile is one world unit. Tile (x, z) covers x..x+1 and z..z+1 in world space, with
## north at -z (away from the camera). Every tile stores the heights of its four corners
## (NW, NE, SE, SW) so beaches and ramps can slope while cliffs stay sharp.

enum Tile { OCEAN, SAND, GRASS, WATER }

const SEA_LEVEL := 0.0
const OCEAN_FLOOR := -1.0
const SHORE_HEIGHT := -0.12
const SAND_HEIGHT := 0.15
const GRASS_HEIGHT := 0.35
const TIER_HEIGHT := 1.25
const RIVER_DEPTH := 0.75
const WATER_DROP := 0.28
## Largest height change the player can step across in one move.
const MAX_STEP := 0.3

const NW := 0
const NE := 1
const SE := 2
const SW := 3

var width: int
var height: int
var seed_value: int
var tiles: PackedByteArray
## Cliff tier: 0 for beach and ocean, 1..3 for the grass levels. Water uses the tier of its banks.
var tiers: PackedByteArray
var corners: PackedFloat32Array
## Ramp tiles: tile index -> {"up": Vector2i uphill direction, "high": float, "low": float}.
var ramps: Dictionary = {}
## Tiles split along a diagonal to round off cliff and bank corners:
## tile index -> {"corner": int, "h": float, "tile": Tile}. The half containing `corner`
## (bounded by the diagonal joining its two neighbouring corners) is flat at height `h`
## and looks like `tile`; the other half keeps the tile's own corner heights and type.
var splits: Dictionary = {}

var native_fruit: String
var native_flower: String
## For tour islands, which kind of island it is (TourKinds); "" at home.
var kind := ""
var plaza: Rect2i
var spawn: Vector2i
## Placed things: trees, rocks, flowers, dropped items and player furniture.
var objects: Array[Dictionary] = []
var next_uid: int = 1


func setup(w: int, h: int) -> void:
	width = w
	height = h
	tiles.resize(w * h)
	tiers.resize(w * h)
	corners.resize(w * h * 4)


func idx(x: int, z: int) -> int:
	return z * width + x


func in_bounds(x: int, z: int) -> bool:
	return x >= 0 and z >= 0 and x < width and z < height


func tile(x: int, z: int) -> int:
	if not in_bounds(x, z):
		return Tile.OCEAN
	return tiles[idx(x, z)]


func tier(x: int, z: int) -> int:
	if not in_bounds(x, z):
		return 0
	return tiers[idx(x, z)]


func is_land(x: int, z: int) -> bool:
	var t := tile(x, z)
	return t == Tile.SAND or t == Tile.GRASS


func is_ramp(x: int, z: int) -> bool:
	return ramps.has(idx(x, z))


## Lays a two-tile ramp down from the cliff top `top`, heading `dir` (as the generator
## does, for slopes built later): both tiles slope from the top's height to the tier below.
func add_ramp(top: Vector2i, dir: Vector2i) -> void:
	var level := tier(top.x, top.y)
	var high := tier_height(level)
	var low := tier_height(level - 1)
	var mid := (high + low) * 0.5
	var steps := [[top + dir, high, mid], [top + dir * 2, mid, low]]
	for step: Array in steps:
		var t: Vector2i = step[0]
		var ramp := {"up": -dir, "high": step[1], "low": step[2]}
		ramps[idx(t.x, t.y)] = ramp
		var hi: float = ramp["high"]
		var lo: float = ramp["low"]
		match -dir:
			Vector2i(0, -1):
				set_corners(t.x, t.y, hi, hi, lo, lo)
			Vector2i(0, 1):
				set_corners(t.x, t.y, lo, lo, hi, hi)
			Vector2i(1, 0):
				set_corners(t.x, t.y, lo, hi, hi, lo)
			_:
				set_corners(t.x, t.y, hi, lo, lo, hi)


## Height of the flat ground for a tier.
static func tier_height(t: int) -> float:
	if t <= 0:
		return SAND_HEIGHT
	return GRASS_HEIGHT + (t - 1) * TIER_HEIGHT


## Height of the water surface on a freshwater tile.
func water_surface(x: int, z: int) -> float:
	return maxf(tier_height(tier(x, z)) - WATER_DROP, SEA_LEVEL)


func corner(x: int, z: int, c: int) -> float:
	return corners[idx(x, z) * 4 + c]


func set_corners(x: int, z: int, nw: float, ne: float, se: float, sw: float) -> void:
	var i := idx(x, z) * 4
	corners[i] = nw
	corners[i + 1] = ne
	corners[i + 2] = se
	corners[i + 3] = sw


## Ground height at a world position, interpolated across the tile's corners.
func height_at(px: float, pz: float) -> float:
	var x := floori(px)
	var z := floori(pz)
	if not in_bounds(x, z):
		return OCEAN_FLOOR
	var fx := px - x
	var fz := pz - z
	var i := idx(x, z)
	if splits.has(i) and in_split_half(splits[i]["corner"], fx, fz):
		return splits[i]["h"]
	var north := lerpf(corner(x, z, NW), corner(x, z, NE), fx)
	var south := lerpf(corner(x, z, SW), corner(x, z, SE), fx)
	return lerpf(north, south, fz)


## True if a point (fractions within its tile) lies in the half containing `c`.
static func in_split_half(c: int, fx: float, fz: float) -> bool:
	match c:
		NW:
			return fx + fz < 1.0
		NE:
			return fz < fx
		SE:
			return fx + fz > 1.0
		_:
			return fx < fz


## Tile type of the surface at a world position (accounts for split tiles).
func surface_at(px: float, pz: float) -> int:
	var x := floori(px)
	var z := floori(pz)
	if not in_bounds(x, z):
		return Tile.OCEAN
	var i := idx(x, z)
	if splits.has(i) and in_split_half(splits[i]["corner"], px - x, pz - z):
		return splits[i]["tile"]
	return tiles[i]


## Heights at both ends of a tile edge running from corner a to corner b, taking the
## split half into account when the edge belongs to it.
func edge_heights(x: int, z: int, a: int, b: int) -> Vector2:
	var i := idx(x, z)
	if splits.has(i) and (splits[i]["corner"] == a or splits[i]["corner"] == b):
		return Vector2(splits[i]["h"], splits[i]["h"])
	return Vector2(corner(x, z, a), corner(x, z, b))


## True if the tile's four corners are level, so buildings and furniture can sit on it.
func is_flat(x: int, z: int) -> bool:
	if splits.has(idx(x, z)):
		return false
	var a := corner(x, z, NW)
	return is_equal_approx(a, corner(x, z, NE)) and is_equal_approx(a, corner(x, z, SE)) \
		and is_equal_approx(a, corner(x, z, SW))


func new_uid() -> int:
	next_uid += 1
	return next_uid - 1


## A room inside a home: a flat w x d floor (grass-type tiles, so the usual walking and
## placing rules apply) plus one doormat tile just past the middle of the front edge.
## Stepping onto the doormat leads back outside.
static func room(w: int, d: int) -> IslandData:
	var r := IslandData.new()
	r.setup(w, d + 1)
	for z in d + 1:
		for x in w:
			var i := r.idx(x, z)
			var floor := z < d or x == w / 2
			r.tiles[i] = Tile.GRASS if floor else Tile.OCEAN
			r.tiers[i] = 1
			r.set_corners(x, z, GRASS_HEIGHT, GRASS_HEIGHT, GRASS_HEIGHT, GRASS_HEIGHT)
	r.spawn = Vector2i(w / 2, d - 1)
	return r


## The doormat tile of a room.
func room_door() -> Vector2i:
	return Vector2i(width / 2, height - 1)
