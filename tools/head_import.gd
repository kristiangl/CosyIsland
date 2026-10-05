extends SceneTree
## Converts a generated animal head (glTF from an image-to-3D service, facing +Z, up +Y)
## into a mesh that sits on CharacterModel's head pivot in place of the procedural head:
##
##   /opt/godot/godot --headless --path . --script res://tools/head_import.gd -- --name=cat [--from-body] [--size=1.0]
##
## Reads assets/characters/src/<name>.glb and writes assets/characters/heads/<name>.res.
## --from-body cuts the head off a full-body model standing in T-pose (BodyShape finds
## it); otherwise the whole model is the head. The face shader draws the eyes, mouth and
## markings, so the head is placed where the procedural head was: the tip of the muzzle
## just below the head's centre, the head's width there matching P.HEAD_RADIUS (times
## --size), centred on the origin.

const P = preload("res://scripts/character/character_parts.gd")
const BodyShape = preload("res://tools/body_shape.gd")
const SRC := "res://assets/characters/src/"
const OUT := "res://assets/characters/heads/"
## Full-body models are measured at this height (BodyShape's slices assume it).
const BODY_HEIGHT := 1.4


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var model_name: String = args.get("name", "cat")
	var mesh := import_head(ProjectSettings.globalize_path(SRC + model_name + ".glb"), args.has("from-body"),
		float(args.get("size", "1.0")))
	if mesh == null:
		push_error("Couldn't import " + model_name)
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		ResourceSaver.save(mesh, OUT + model_name + ".res", ResourceSaver.FLAG_COMPRESS)
		print("Imported %s's head: %d triangles" % [model_name, mesh.surface_get_array_index_len(0) / 3])
	quit()


static func import_head(path: String, from_body: bool, size: float) -> ArrayMesh:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	var arrays: Array = state.get_meshes()[0].mesh.get_surface_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var xform := _node_xform(state)
	for v in verts.size():
		verts[v] = xform * verts[v]
		normals[v] = (xform.basis * normals[v]).normalized()
	var keep := PackedInt32Array()
	if from_body:
		# Stand the body up at the height BodyShape measures, then keep the triangles
		# that are all head.
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for p in verts:
			lo = lo.min(p)
			hi = hi.max(p)
		var scale := BODY_HEIGHT / (hi.y - lo.y)
		for v in verts.size():
			verts[v] = (verts[v] - Vector3((lo.x + hi.x) * 0.5, lo.y, 0.0)) * scale
		var j := BodyShape.joints(verts)
		var weld := BodyShape.weld(verts)
		var graph := BodyShape.graph(weld, indices)
		var head := BodyShape.find_head(verts, weld, graph, j, BodyShape.find_arms(verts, weld, graph, j))
		for t in range(0, indices.size(), 3):
			if head.has(weld[indices[t]]) and head.has(weld[indices[t + 1]]) and head.has(weld[indices[t + 2]]):
				keep.append_array([indices[t], indices[t + 1], indices[t + 2]])
	else:
		keep = indices
	# Only the vertices the head uses, renumbered.
	var remap := {}
	var out_verts := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_indices := PackedInt32Array()
	for i in keep:
		if not remap.has(i):
			remap[i] = out_verts.size()
			out_verts.append(verts[i])
			out_normals.append(normals[i])
		out_indices.append(remap[i])
	# Where the face goes: anchored on the muzzle tip, scaled by the width there.
	var tip := Vector3(0, 0, -INF)
	for p in out_verts:
		if p.z > tip.z:
			tip = p
	var low := INF
	var high := -INF
	for p in out_verts:
		low = minf(low, p.y)
		high = maxf(high, p.y)
	var half := 0.0
	for p in out_verts:
		if absf(p.y - tip.y) < (high - low) * 0.05:
			half = maxf(half, absf(p.x))
	var s := P.HEAD_RADIUS.x / half * size
	var centre := Vector3(0.0, tip.y + 0.11 / s, tip.z - P.HEAD_RADIUS.z / s)
	for v in out_verts.size():
		out_verts[v] = (out_verts[v] - centre) * s
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = out_verts
	surface[Mesh.ARRAY_NORMAL] = out_normals
	surface[Mesh.ARRAY_INDEX] = out_indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	return mesh


## The mesh node's transform all the way up.
static func _node_xform(state: GLTFState) -> Transform3D:
	var nodes := state.get_nodes()
	for i in nodes.size():
		if nodes[i].mesh >= 0:
			var xform := Transform3D.IDENTITY
			var at := i
			while at >= 0:
				xform = nodes[at].xform * xform
				at = nodes[at].parent
			return xform
	return Transform3D.IDENTITY
