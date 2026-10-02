class_name GrassField
extends MultiMeshInstance3D
## Little grass clumps scattered over every grass tile, swaying in the wind.
## Tiles can be cleared (when something is built on them) and restored.

const PER_TILE := 4

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
				var px := x + rng.randf_range(0.1, 0.9)
				var pz := z + rng.randf_range(0.1, 0.9)
				var s := rng.randf_range(0.7, 1.3)
				if d.surface_at(px, pz) != IslandData.Tile.GRASS:
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


static func _tuft_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	var blades := 7
	for i in blades:
		var a := TAU * i / blades + 0.3
		var lean := Vector3(cos(a), 0, sin(a)) * 0.08
		var side := Vector3(-sin(a), 0, cos(a)) * 0.05
		var base := lean * 0.5
		var height := 0.12 + 0.04 * (i % 3)
		var n := Vector3.UP
		var p0 := k.vertex(base - side, n, Color(0, 0, 0, 1))
		var p1 := k.vertex(base + side, n, Color(0, 0, 0, 1))
		var p2 := k.vertex(base + lean + Vector3(0, height, 0), n, Color(1, 0, 0, 1))
		k.tri(p0, p1, p2, Vector3(cos(a), 0, sin(a)))
	return k.commit()
