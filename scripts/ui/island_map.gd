class_name IslandMap
extends Control
## The island from above: a painted image of the terrain with markers for the player,
## homes, the workbench and (on the full map) furniture. Used for the corner minimap
## and the full map.

## Image pixels per tile.
const PX := 4
const OCEAN := Color("8fcfe0")
const SHALLOWS := Color("ade2e6")
const FOAM := Color("e4f6f2")
const SAND := Color("f2e2b2")
const RIVER := Color("7cc4dc")
const GRASS: Array[Color] = [Color("a6d585"), Color("93c873"), Color("80b963"), Color("6eaa56")]
const CLIFF := Color("5d8a4b")
const BANK := Color("6f9f86")
const BRIDGE := Color("b98a5c")
const PAVING := Color("e8d8c4")
const HOME := Color("6cbfb0")
const OFFICE := Color("ef9a8a")

## Full map: furniture dots and a grid.
var detailed := false
## Tiles of sea to keep around the island.
var margin := 3.0

static var _texture: ImageTexture
static var _texture_for: IslandData
static var _task := -1
static var _task_for: IslandData
static var _painted: Image
## Tiles holding dry land, found while painting.
static var _land: Rect2i

var _homes: Array[Rect2] = []
var _offices: Array[Rect2] = []
var _benches: Array[Rect2] = []
var _furniture: Array[Vector2] = []
var _bridges: Array[Rect2] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	Events.placed_changed.connect(_collect_markers)
	_collect_markers()


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


## Waits for any painting still going on (call before quitting: every worker task
## has to be collected).
static func finish() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## Forget the painted terrain, e.g. after landscaping or loading another island.
static func invalidate() -> void:
	_texture_for = null
	_task_for = null


## The painted terrain, or null while it's still being painted on a worker thread.
## Call early (after loading an island) to get the painting started.
static func terrain_texture(data: IslandData) -> ImageTexture:
	if _texture_for == data and _texture != null:
		return _texture
	if _task_for != data:
		if _task >= 0:
			WorkerThreadPool.wait_for_task_completion(_task)
		_task_for = data
		_task = WorkerThreadPool.add_task(func(): _painted = paint(data), false, "Paint island map")
		return null
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_texture = ImageTexture.create_from_image(_painted)
		_painted = null
		_texture_for = data
		return _texture
	return null


## Paints the terrain at PX pixels per tile: tiers in steps of green, outlined cliffs,
## rivers with darker banks, and foam where the sea meets the land. The coast and the
## edge of the grass are smoothed so they don't follow the tile steps.
static func paint(data: IslandData) -> Image:
	var w := data.width * PX
	var h := data.height * PX
	var heights := PackedFloat32Array()
	heights.resize(w * h)
	var river := PackedByteArray()
	river.resize(w * h)
	# Red: dry land, green: grass (rivers count as both so they don't pull the edges in).
	var field := PackedByteArray()
	field.resize(w * h * 2)
	var dry_level := IslandData.SEA_LEVEL - 0.02
	for z in data.height:
		for x in data.width:
			var t := data.idx(x, z)
			var nw := data.corners[t * 4 + IslandData.NW]
			var ne := data.corners[t * 4 + IslandData.NE]
			var se := data.corners[t * 4 + IslandData.SE]
			var sw := data.corners[t * 4 + IslandData.SW]
			var split: Dictionary = data.splits.get(t, {})
			var tile_kind := data.tiles[t]
			for sz in PX:
				var fz := (sz + 0.5) / PX
				for sx in PX:
					var fx := (sx + 0.5) / PX
					var here := lerpf(lerpf(nw, ne, fx), lerpf(sw, se, fx), fz)
					var kind := tile_kind
					if not split.is_empty() and IslandData.in_split_half(split["corner"], fx, fz):
						here = split["h"]
						kind = split["tile"]
					var i := (z * PX + sz) * w + x * PX + sx
					heights[i] = here
					var wet := kind == IslandData.Tile.WATER
					river[i] = 1 if wet else 0
					field[i * 2] = 255 if wet or here >= dry_level else 0
					field[i * 2 + 1] = 255 if wet or kind == IslandData.Tile.GRASS else 0
	# Blur by shrinking to tile size and growing back smoothly.
	var land_field := Image.create_from_data(w, h, false, Image.FORMAT_RG8, field)
	land_field.resize(data.width, data.height, Image.INTERPOLATE_LANCZOS)
	land_field.resize(w, h, Image.INTERPOLATE_CUBIC)
	field = land_field.get_data()

	# 0 sea, 1 sand, 2 grass, 3 river.
	var cls := PackedByteArray()
	cls.resize(w * h)
	var land := Rect2i()
	for y in h:
		for x in w:
			var i := y * w + x
			cls[i] = 3 if river[i] == 1 else (0 if field[i * 2] < 128 else (2 if field[i * 2 + 1] >= 128 else 1))
	for z in data.height:
		for x in data.width:
			if cls[(z * PX + PX / 2) * w + x * PX + PX / 2] != 0:
				var t := Vector2i(x, z)
				land = Rect2i(t, Vector2i.ONE) if land.size == Vector2i.ZERO else land.expand(t).expand(t + Vector2i.ONE)
	_land = land

	var rgb := PackedByteArray()
	rgb.resize(w * h * 3)
	var plaza := Rect2(data.plaza).grow(0.25)
	var grass_top := GRASS.size()
	for y in h:
		for x in w:
			var i := y * w + x
			var here := heights[i]
			var colour := OCEAN
			match cls[i]:
				0:
					colour = FOAM if _next_to(cls, w, h, x, y, 1) or _next_to(cls, w, h, x, y, 2) \
						else (SHALLOWS if here > -0.55 else OCEAN)
				1:
					colour = SAND
				2:
					var tier := clampi(int(round((here - IslandData.GRASS_HEIGHT) / IslandData.TIER_HEIGHT)) + 1, 1, grass_top)
					colour = BANK if _next_to(cls, w, h, x, y, 3) else GRASS[tier - 1]
					if _in_rounded(plaza, Vector2(x + 0.5, y + 0.5) / PX, 1.8):
						colour = PAVING
					# Outline the top edge of every cliff.
					if _drop_beside(heights, w, h, x, y) > 0.6:
						colour = CLIFF
				3:
					colour = RIVER
			rgb[i * 3] = colour.r8
			rgb[i * 3 + 1] = colour.g8
			rgb[i * 3 + 2] = colour.b8
	return Image.create_from_data(w, h, false, Image.FORMAT_RGB8, rgb)


static func _in_rounded(rect: Rect2, p: Vector2, radius: float) -> bool:
	if not rect.has_area():
		return false
	var q := (p - rect.get_center()).abs() - (rect.size * 0.5 - Vector2(radius, radius))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) < radius


## True if a pixel beside (x, y) is of this class.
static func _next_to(cls: PackedByteArray, w: int, h: int, x: int, y: int, c: int) -> bool:
	var i := y * w + x
	return (x > 0 and cls[i - 1] == c) or (x < w - 1 and cls[i + 1] == c) \
		or (y > 0 and cls[i - w] == c) or (y < h - 1 and cls[i + w] == c)


## The biggest drop from (x, y) to a pixel beside it.
static func _drop_beside(heights: PackedFloat32Array, w: int, h: int, x: int, y: int) -> float:
	var i := y * w + x
	var low := heights[i]
	if x > 0:
		low = minf(low, heights[i - 1])
	if x < w - 1:
		low = minf(low, heights[i + 1])
	if y > 0:
		low = minf(low, heights[i - w])
	if y < h - 1:
		low = minf(low, heights[i + w])
	return heights[i] - low


func _collect_markers() -> void:
	_homes.clear()
	_offices.clear()
	_benches.clear()
	_furniture.clear()
	_bridges.clear()
	if Game.outdoors() == null:
		return
	for obj in Game.outdoors().objects():
		match obj["kind"]:
			"bridge":
				var tiles := Game.outdoors().footprint(obj)
				var r := Rect2(Vector2(tiles[0]), Vector2.ONE)
				for t in tiles:
					r = r.expand(Vector2(t) + Vector2.ONE)
				_bridges.append(r)
			"placed":
				if obj.has("on"):
					continue
				var rect := Rect2(obj["x"], obj["z"], obj["w"], obj["d"])
				var def := ItemDB.placeable(obj["item"])
				if obj["item"] == "island_office":
					_offices.append(rect)
				elif def.get("structure", false):
					_homes.append(rect)
				elif def.get("workbench", false):
					_benches.append(rect)
				else:
					_furniture.append(rect.get_center())


func _draw() -> void:
	if Game.outdoors() == null:
		return
	var data := Game.outdoors().data
	var tex := terrain_texture(data)
	if tex == null:
		draw_rect(Rect2(Vector2.ZERO, size), OCEAN)
		return
	# Frame the island (plus a little sea), keeping the control's shape.
	var view := Rect2(_land).grow(margin)
	var aspect := size.x / size.y
	if view.size.x / view.size.y < aspect:
		view = view.grow_individual((view.size.y * aspect - view.size.x) * 0.5, 0, (view.size.y * aspect - view.size.x) * 0.5, 0)
	else:
		view = view.grow_individual(0, (view.size.x / aspect - view.size.y) * 0.5, 0, (view.size.x / aspect - view.size.y) * 0.5)
	var s := size / view.size
	var o := -view.position * s
	draw_rect(Rect2(Vector2.ZERO, size), OCEAN)
	var src := Rect2(view.position * PX, view.size * PX).intersection(Rect2(Vector2.ZERO, tex.get_size()))
	draw_texture_rect_region(tex, Rect2(o + src.position / PX * s, src.size / PX * s), src)
	if detailed:
		# A faint grid every 16 tiles, like a paper map.
		var line := Color(1, 1, 1, 0.25)
		for gx in range(16, data.width, 16):
			draw_line(Vector2(o.x + gx * s.x, 0), Vector2(o.x + gx * s.x, size.y), line, 1.0)
		for gz in range(16, data.height, 16):
			draw_line(Vector2(0, o.y + gz * s.y), Vector2(size.x, o.y + gz * s.y), line, 1.0)
	for r in _bridges:
		draw_rect(Rect2(o + r.position * s, r.size * s), BRIDGE)
	if detailed:
		for p in _furniture:
			draw_circle(o + p * s, maxf(1.5, s.x * 0.35), UIStyle.BROWN_LIGHT)
	var icon := clampf(s.x * 2.4, 7.0, 16.0)
	for r in _benches:
		var c := o + r.get_center() * s
		draw_rect(Rect2(c - Vector2(icon, icon * 0.6) * 0.5, Vector2(icon, icon * 0.6)), UIStyle.BROWN)
	for r in _homes:
		_draw_home(o + r.get_center() * s, icon, HOME)
	for r in _offices:
		_draw_home(o + r.get_center() * s, icon * 1.3, OFFICE)
	var player := Game.player
	if player and player.world == Game.outdoors():
		_draw_player(o + Vector2(player.position.x, player.position.z) * s, Vector2(player.facing.x, player.facing.z), icon)


func _draw_home(c: Vector2, sz: float, colour: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -sz * 0.75), c + Vector2(sz * 0.7, sz * 0.5), c + Vector2(-sz * 0.7, sz * 0.5)])
	draw_colored_polygon(pts, colour)
	pts.append(pts[0])
	draw_polyline(pts, UIStyle.CREAM, maxf(1.0, sz * 0.12))


func _draw_player(c: Vector2, dir: Vector2, sz: float) -> void:
	if dir.length() < 0.01:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var side := Vector2(-dir.y, dir.x)
	draw_circle(c, sz * 0.75, Color(UIStyle.CREAM, 0.9))
	var pts := PackedVector2Array([c + dir * sz * 0.65, c - dir * sz * 0.4 + side * sz * 0.45,
		c - dir * sz * 0.15, c - dir * sz * 0.4 - side * sz * 0.45])
	draw_colored_polygon(pts, UIStyle.ACCENT)
	pts.append(pts[0])
	draw_polyline(pts, UIStyle.BROWN, maxf(1.0, sz * 0.1))
