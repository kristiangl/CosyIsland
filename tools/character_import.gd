extends SceneTree
## Converts a rigged character base model (glTF from an auto-rigger, Mixamo bone names,
## in T-pose, facing +Z) into a skinned mesh for SkinnedBody:
##
##   /opt/godot/godot --headless --path . --script res://tools/character_import.gd -- --name=human
##
## Reads assets/characters/src/<name>.glb and writes assets/characters/<name>.res: an
## ArrayMesh with two surfaces (0: body, 1: head, for the face shader), its bones and
## the body's layout in the mesh's metadata. Only the bind pose is used (the rigger's
## own rest pose and animations are ignored): bones get the joint positions and no
## rotation, so a bone's identity rotation means "as in the T-pose".
##
## The model is scaled to HEIGHT and stood on y = 0. Each vertex's rest position goes
## in UV (x, y) and UV2.x (z), so shaders can paint clothes and faces in rest space
## while the skin moves.

const HEIGHT := 1.4
const SRC := "res://assets/characters/src/"
const OUT := "res://assets/characters/"


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var model_name: String = args.get("name", "human")
	var mesh := import_character(ProjectSettings.globalize_path(SRC + model_name + ".glb"))
	if mesh == null:
		push_error("Couldn't import " + model_name)
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		ResourceSaver.save(mesh, OUT + model_name + ".res", ResourceSaver.FLAG_COMPRESS)
		print("Imported %s: %d triangles, %d bones" % [model_name,
			(mesh.surface_get_array_index_len(0) + mesh.surface_get_array_index_len(1)) / 3, mesh.get_meta("bones").size()])
	quit()


static func import_character(path: String) -> ArrayMesh:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	var scene := doc.generate_scene(state)
	var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var source: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var skin := source.skin
	# Joint positions in the mesh's space, from the bind pose.
	var joints := {}
	for i in skin.get_bind_count():
		var bone := skin.get_bind_bone(i)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(i))
		joints[bone] = skin.get_bind_pose(i).affine_inverse().origin
	var arrays: Array = state.get_meshes()[0].mesh.get_surface_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones_in = arrays[Mesh.ARRAY_BONES]
	var weights_in = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# Stand it on the ground at the game's height.
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for p in verts:
		lo = lo.min(p)
		hi = hi.max(p)
	var scale := HEIGHT / (hi.y - lo.y)
	var shift := Vector3(-(lo.x + hi.x) * 0.5, -lo.y, 0.0)
	var placed := func(p: Vector3) -> Vector3: return (p + shift) * scale
	for v in verts.size():
		verts[v] = placed.call(verts[v])
	# Bones: names without the rigger's prefix, parents first.
	var names: Array[String] = []
	var parents: Array[int] = []
	var rests: Array[Vector3] = []
	for b in skeleton.get_bone_count():
		names.append(skeleton.get_bone_name(b).trim_prefix("mixamorig:").trim_prefix("mixamorig"))
		parents.append(skeleton.get_bone_parent(b))
		rests.append(placed.call(joints.get(b, Vector3.ZERO)))
	var head := names.find("Head")
	# Rest positions for the shaders.
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	for p in verts:
		uv.append(Vector2(p.x, p.y))
		uv2.append(Vector2(p.z, 0.0))
	# Split the head off for the face shader: triangles whose corners all belong mostly
	# to the head bone.
	var on_head := func(v: int) -> bool:
		for k in 4:
			if int(bones_in[v * 4 + k]) == head and float(weights_in[v * 4 + k]) >= 0.5:
				return true
		return false
	var body_tris := PackedInt32Array()
	var head_tris := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		if on_head.call(a) and on_head.call(b) and on_head.call(c):
			head_tris.append_array([a, b, c])
		else:
			body_tris.append_array([a, b, c])
	var mesh := ArrayMesh.new()
	for tris in [body_tris, head_tris]:
		var surface := []
		surface.resize(Mesh.ARRAY_MAX)
		surface[Mesh.ARRAY_VERTEX] = verts
		surface[Mesh.ARRAY_NORMAL] = normals
		surface[Mesh.ARRAY_TEX_UV] = uv
		surface[Mesh.ARRAY_TEX_UV2] = uv2
		surface[Mesh.ARRAY_BONES] = bones_in
		surface[Mesh.ARRAY_WEIGHTS] = weights_in
		surface[Mesh.ARRAY_INDEX] = tris
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	mesh.set_meta("bones", names)
	mesh.set_meta("parents", parents)
	mesh.set_meta("rests", rests)
	mesh.set_meta("head", _head_shape(verts, head_tris))
	scene.free()
	return mesh


## The head's centre and radii (ears left out of its width): {"centre", "radius"}.
static func _head_shape(verts: PackedVector3Array, tris: PackedInt32Array) -> Dictionary:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for i in tris:
		lo = lo.min(verts[i])
		hi = hi.max(verts[i])
	var centre := (lo + hi) * 0.5
	var radius := (hi - lo) * 0.5
	# Ears stick out at the sides; measure the width across the front of the face.
	var half := 0.0
	for i in tris:
		var p := verts[i]
		if p.z > centre.z + radius.z * 0.4:
			half = maxf(half, absf(p.x - centre.x))
	radius.x = half / sqrt(1.0 - 0.4 * 0.4)
	return {"centre": centre, "radius": radius}
