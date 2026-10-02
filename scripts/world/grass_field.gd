class_name GrassField
extends MultiMeshInstance3D
## Little grass clumps scattered over every grass tile, swaying in the wind.
## Tiles can be cleared (when something is built on them) and restored.

## Chance of a clump of tall blades on a grass tile.
const CLUMP_CHANCE := 0.4
const PER_TILE := 1

## Tile index -> first instance index for that tile.
var _first_instance: Dictionary = {}
var _transforms: Array[Transform3D] = []
var _per_tile := PER_TILE


func build(d: IslandData, density: float = 1.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = d.seed_value + 404
	_transforms.clear()
	_first_instance.clear()
	_per_tile = maxi(0, int(round(PER_TILE * density)))
	for z in d.height:
		for x in d.width:
			if d.tile(x, z) != IslandData.Tile.GRASS:
				continue
			_first_instance[d.idx(x, z)] = _transforms.size()
			for i in _per_tile:
				var px := x + rng.randf_range(0.15, 0.85)
				var pz := z + rng.randf_range(0.15, 0.85)
				var s := rng.randf_range(0.75, 1.25)
				# Grass grows thicker at the foot of cliffs and banks.
				var chance := CLUMP_CHANCE * (2.2 if _beside_higher(d, x, z) else 1.0)
				if d.surface_at(px, pz) != IslandData.Tile.GRASS or rng.randf() > chance * density:
					s = 0.0
				var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s))
				_transforms.append(Transform3D(b, Vector3(px, d.height_at(px, pz), pz)))

	if _transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _tuft_mesh()
	mm.instance_count = _transforms.size()
	for i in _transforms.size():
		mm.set_instance_transform(i, _transforms[i])
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass_tuft.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_tile_visible(d: IslandData, x: int, z: int, show: bool) -> void:
	var first: int = _first_instance.get(d.idx(x, z), -1)
	if first < 0 or multimesh == null:
		return
	for i in range(first, mini(first + _per_tile, _transforms.size())):
		var t := _transforms[i]
		if not show:
			t = Transform3D(Basis().scaled(Vector3.ZERO), t.origin)
		multimesh.set_instance_transform(i, t)


static func _beside_higher(d: IslandData, x: int, z: int) -> bool:
	var here := d.height_at(x + 0.5, z + 0.5)
	for dir in IslandGenerator.DIRS:
		if d.in_bounds(x + dir.x, z + dir.y) and d.height_at(x + dir.x + 0.5, z + dir.y + 0.5) > here + 0.5:
			return true
	return false


## A clump of curved grass blades, each two segments so it bends outwards.
static func _tuft_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	var blades := 7
	for i in blades:
		var a := TAU * i / blades + 0.4 * sin(i * 2.3)
		var out := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-sin(a), 0, cos(a))
		var height := 0.24 + 0.1 * ((i * 37) % 5) / 4.0
		var base := out * 0.04
		var mid := base + out * 0.05 + Vector3(0, height * 0.55, 0)
		var tip := base + out * 0.14 + Vector3(0, height, 0)
		var w := 0.035
		var n := Vector3.UP
		var p0 := k.vertex(base - side * w, n, Color(0, 0, 0, 1))
		var p1 := k.vertex(base + side * w, n, Color(0, 0, 0, 1))
		var p2 := k.vertex(mid + side * w * 0.7, n, Color(0.55, 0, 0, 1))
		var p3 := k.vertex(mid - side * w * 0.7, n, Color(0.55, 0, 0, 1))
		var p4 := k.vertex(tip, n, Color(1, 0, 0, 1))
		k.quad(p0, p1, p2, p3, out)
		k.tri(p3, p2, p4, out)
	return k.commit()
