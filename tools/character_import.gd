extends SceneTree
## Converts a rigged character base model (glTF from an auto-rigger, Mixamo bone names,
## in T-pose, facing +Z) into a skinned mesh for SkinnedBody:
##
##   /opt/godot/godot --headless --path . --script res://tools/character_import.gd -- --name=human [--tail] [--arms=0.7]
##
## A model that comes without a skeleton is rigged by AutoRig (with a tail if --tail;
## --arms shortens long arms to that fraction of their length).
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
	# Models without a skeleton are rigged here; --tail looks for a tail to rig too.
	var mesh := import_character(ProjectSettings.globalize_path(SRC + model_name + ".glb"), args.has("tail"),
		float(args.get("arms", "1.0")))
	if mesh == null:
		push_error("Couldn't import " + model_name)
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		ResourceSaver.save(mesh, OUT + model_name + ".res", ResourceSaver.FLAG_COMPRESS)
		print("Imported %s: %d triangles, %d bones" % [model_name,
			(mesh.surface_get_array_index_len(0) + mesh.surface_get_array_index_len(1)) / 3, mesh.get_meta("bones").size()])
	quit()


static func import_character(path: String, with_tail: bool = false, arm_length: float = 1.0) -> ArrayMesh:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	var scene := doc.generate_scene(state)
	var source: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var arrays: Array = state.get_meshes()[0].mesh.get_surface_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var rigged := source.skin != null
	if not rigged:
		# An unrigged model: take its node's placement along.
		var xform := _node_xform(state, source)
		for v in verts.size():
			verts[v] = xform * verts[v]
			normals[v] = (xform.basis * normals[v]).normalized()
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
	var names: Array[String] = []
	var parents: Array[int] = []
	var rests: Array[Vector3] = []
	var bones_in
	var weights_in
	if rigged:
		# Joint positions from the bind pose; bone names without the rigger's prefix.
		var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
		var joints := {}
		for i in source.skin.get_bind_count():
			var bone := source.skin.get_bind_bone(i)
			if bone < 0:
				bone = skeleton.find_bone(source.skin.get_bind_name(i))
			joints[bone] = source.skin.get_bind_pose(i).affine_inverse().origin
		for b in skeleton.get_bone_count():
			names.append(skeleton.get_bone_name(b).trim_prefix("mixamorig:").trim_prefix("mixamorig"))
			parents.append(skeleton.get_bone_parent(b))
			rests.append(placed.call(joints.get(b, Vector3.ZERO)))
		bones_in = arrays[Mesh.ARRAY_BONES]
		weights_in = arrays[Mesh.ARRAY_WEIGHTS]
	else:
		var rig := AutoRig.rig(verts, indices, with_tail, arm_length)
		names.assign(rig["names"])
		parents.assign(rig["parents"])
		rests.assign(rig["rests"])
		bones_in = rig["bones"]
		weights_in = rig["weights"]
	scene.free()
	var head := names.find("Head")
	# Rest positions for the shaders.
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	# UV2.y: which part a vertex belongs to (0 body, 1 arm, 2 tail), from its weights.
	var arm_bones := []
	var tail_bones := []
	for b in names.size():
		if names[b].contains("Arm") or names[b].contains("Hand"):
			arm_bones.append(b)
		elif names[b].begins_with("Tail"):
			tail_bones.append(b)
	for v in verts.size():
		var arm := 0.0
		var tail := 0.0
		for k in 4:
			var b := int(bones_in[v * 4 + k])
			var w := float(weights_in[v * 4 + k])
			arm += w if b in arm_bones else 0.0
			tail += w if b in tail_bones else 0.0
		uv.append(Vector2(verts[v].x, verts[v].y))
		uv2.append(Vector2(verts[v].z, 1.0 if arm >= 0.5 else (2.0 if tail >= 0.5 else 0.0)))
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
	mesh.set_meta("import", {"tail": with_tail, "arms": arm_length})
	return mesh


## A glTF node's transform all the way up.
static func _node_xform(state: GLTFState, source: Node3D) -> Transform3D:
	var nodes := state.get_nodes()
	for i in nodes.size():
		if nodes[i].mesh >= 0:
			var xform := Transform3D.IDENTITY
			var at := i
			while at >= 0:
				xform = nodes[at].xform * xform
				at = nodes[at].parent
			return xform
	return source.transform


## Where the face goes, as the head's centre and radii for the face shader, which draws
## features on a head of radius P.HEAD_RADIUS with the nose and mouth just below its
## centre. Anchored on the tip of the muzzle (the head's most forward point), with the
## head's width there setting the scale. {"centre", "radius"}.
static func _head_shape(verts: PackedVector3Array, tris: PackedInt32Array) -> Dictionary:
	const PROCEDURAL := Vector3(0.38, 0.35, 0.36)
	var tip := Vector3(0, 0, -INF)
	for i in tris:
		if verts[i].z > tip.z:
			tip = verts[i]
	var half := 0.0
	for i in tris:
		if absf(verts[i].y - tip.y) < 0.03:
			half = maxf(half, absf(verts[i].x))
	var radius := PROCEDURAL * (half / PROCEDURAL.x)
	# The muzzle sits a little below the centre, at the front.
	var centre := Vector3(0.0, tip.y + 0.11 * radius.y / PROCEDURAL.y, tip.z - radius.z)
	return {"centre": centre, "radius": radius}
