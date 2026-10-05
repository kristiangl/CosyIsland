extends SceneTree
## Converts a generated animal head (glTF from an image-to-3D service, facing +Z, up +Y)
## into a mesh that sits on CharacterModel's head pivot in place of the procedural head:
##
##   /opt/godot/godot --headless --path . --script res://tools/head_import.gd -- --name=cat [--from-body] [--size=1.0] [--eyes=0.45]
##
## Reads assets/characters/src/<name>.glb and writes assets/characters/heads/<name>.res.
## --from-body cuts the head off a full-body model standing in T-pose (BodyShape finds
## it); otherwise the whole model is the head. The face shader draws the eyes, mouth and
## markings, so every head is placed alike: its width at the muzzle matching
## P.HEAD_RADIUS (times --size), its eye line at EYE_Y and the face beside the muzzle at
## FACE_Z. The mesh's metadata says how far to move it to meet the body ("offset"), where
## the mouth goes ("mouth") and where a beak starts ("beak").

const P = preload("res://scripts/character/character_parts.gd")
const BodyShape = preload("res://tools/body_shape.gd")
const SRC := "res://assets/characters/src/"
const OUT := "res://assets/characters/heads/"
## Where the chin sits relative to the head's centre, tucked a little into the body.
const CHIN := -0.37
## Full-body models are measured at this height (BodyShape's slices assume it).
const BODY_HEIGHT := 1.4
## Heads are sized by their width at the height of the muzzle; --size scales that, for
## heads that look too big or small by it (hanging ears make a head look wider there).
const SIZES := {"dog": 1.2, "dog_upright": 0.9, "rabbit": 0.92, "rabbit_lop": 1.15, "mouse": 0.8,
	"bird": 0.88, "bird_sea": 0.88}
## Where the eyes go, as a share of the way up the middle of the head from chin to crown
## (--eyes). The face shader draws them at EYE_Y, with the face's surface beside the
## muzzle or beak at FACE_Z, so every head's eyes sit alike.
const EYES := {"cat": 0.42, "bird": 0.4}
const DEFAULT_EYES := 0.45
const EYE_X := 0.125
const EYE_Y := 0.0
const FACE_Z := 0.3
## Heads whose ears hang down below the chin.
const HANGING_EARS := ["dog", "rabbit_lop"]
## Rounds of smoothing for heads whose surface came out dented or crumpled.
const SMOOTHING := {"mouse": 12}


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var model_name: String = args.get("name", "cat")
	var mesh := import_head(ProjectSettings.globalize_path(SRC + model_name + ".glb"), args.has("from-body"),
		float(args.get("size", SIZES.get(model_name, 1.0))), int(args.get("smooth", SMOOTHING.get(model_name, 0))),
		float(args.get("eyes", EYES.get(model_name, DEFAULT_EYES))))
	if mesh == null:
		push_error("Couldn't import " + model_name)
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		ResourceSaver.save(mesh, OUT + model_name + ".res", ResourceSaver.FLAG_COMPRESS)
		print("Imported %s's head: %d triangles, moved %.2f to meet the body" % [model_name,
			mesh.surface_get_array_index_len(0) / 3, mesh.get_meta("offset").y])
	quit()


static func import_head(path: String, from_body: bool, size: float, smoothing := 0, eyes := DEFAULT_EYES) -> ArrayMesh:
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
		if OS.get_cmdline_user_args().has("--debug"):
			print(j)
		var weld := BodyShape.weld(verts)
		var graph := BodyShape.graph(weld, indices)
		var head := BodyShape.find_head(verts, weld, graph, j, BodyShape.find_arms(verts, weld, graph, j),
			HANGING_EARS.has(path.get_file().get_basename()))
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
	_fix_winding(out_verts, out_indices)
	_smooth(out_verts, out_indices, smoothing)
	# Smooth normals from the faces: some models come with noisy ones that shade in
	# patches.
	var welded := {}
	for t in range(0, out_indices.size(), 3):
		var a := out_verts[out_indices[t]]
		var face := (out_verts[out_indices[t + 2]] - a).cross(out_verts[out_indices[t + 1]] - a)
		for k in 3:
			var key := (out_verts[out_indices[t + k]] * 10000.0).round()
			welded[key] = welded.get(key, Vector3.ZERO) + face
	for v in out_verts.size():
		var sum: Vector3 = welded[(out_verts[v] * 10000.0).round()]
		if sum.length_squared() > 0.0:
			out_normals[v] = sum.normalized()
	# Sized by the width at the height of the muzzle's tip.
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
	# The eye line, part way up the middle of the head (between any ears).
	var chin_c := INF
	var crown := -INF
	for p in out_verts:
		if absf(p.x) < 0.06 / s:
			chin_c = minf(chin_c, p.y)
			crown = maxf(crown, p.y)
	var eye_y := lerpf(chin_c, crown, eyes)
	# How far forward the face is where the eyes go, beside the muzzle or beak.
	var face_z := -INF
	for p in out_verts:
		if absf(absf(p.x) - EYE_X / s) < 0.03 / s and absf(p.y - eye_y) < 0.03 / s:
			face_z = maxf(face_z, p.z)
	if face_z == -INF:
		face_z = tip.z - 0.06 / s
	# And down the middle at that height: a beak is whatever sticks out further.
	var brow_z := -INF
	for p in out_verts:
		if absf(p.x) < 0.04 / s and absf(p.y - eye_y) < 0.04 / s:
			brow_z = maxf(brow_z, p.z)
	var centre := Vector3(0.0, eye_y - EYE_Y / s, face_z - FACE_Z / s)
	for v in out_verts.size():
		out_verts[v] = (out_verts[v] - centre) * s
	# The chin (the underside in the middle, not hanging ears) should meet the body where
	# the procedural head's did: the game moves the head by this much.
	var chin := INF
	for p in out_verts:
		if absf(p.x) < P.HEAD_RADIUS.x * 0.4:
			chin = minf(chin, p.y)
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = out_verts
	surface[Mesh.ARRAY_NORMAL] = out_normals
	surface[Mesh.ARRAY_INDEX] = out_indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	mesh.set_meta("offset", Vector3(0.0, CHIN - chin, 0.0))
	# The nose goes on the muzzle's tip and the mouth under it (the shader's mouth_y).
	mesh.set_meta("mouth", (tip.y - centre.y) * s - 0.045)
	mesh.set_meta("beak", (maxf(brow_z, face_z) - centre.z) * s + 0.015)
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


## Some models wind patches of triangles the wrong way round, so their insides show.
## Triangles that share an edge should run along it in opposite directions: spread that
## from triangle to triangle, then turn each connected piece to face out from the
## middle (Godot's front faces wind clockwise).
static func _fix_winding(verts: PackedVector3Array, indices: PackedInt32Array) -> void:
	var ids := {}
	var weld := PackedInt32Array()
	for p in verts:
		var key := (p * 10000.0).round()
		if not ids.has(key):
			ids[key] = ids.size()
		weld.append(ids[key])
	var tris := indices.size() / 3
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for p in verts:
		lo = lo.min(p)
		hi = hi.max(p)
	var middle := (lo + hi) * 0.5
	# Undirected edge -> the triangles on it.
	var edges := {}
	for t in tris:
		for e in 3:
			var a := weld[indices[t * 3 + e]]
			var b := weld[indices[t * 3 + (e + 1) % 3]]
			var key := Vector2i(mini(a, b), maxi(a, b))
			if not edges.has(key):
				edges[key] = []
			edges[key].append(t)
	var flip := {}
	for start in tris:
		if flip.has(start):
			continue
		flip[start] = false
		var piece: Array[int] = [start]
		var stack: Array[int] = [start]
		while not stack.is_empty():
			var t: int = stack.pop_back()
			for e in 3:
				var a := weld[indices[t * 3 + e]]
				var b := weld[indices[t * 3 + (e + 1) % 3]]
				var on: Array = edges[Vector2i(mini(a, b), maxi(a, b))]
				if on.size() != 2:
					continue
				var u: int = on[0] if on[1] == t else on[1]
				if flip.has(u):
					continue
				# Does u run a -> b too? Then one of them is backwards.
				var same := false
				for f in 3:
					if weld[indices[u * 3 + f]] == a and weld[indices[u * 3 + (f + 1) % 3]] == b:
						same = true
				flip[u] = flip[t] != same
				piece.append(u)
				stack.append(u)
		# Which way is out: most of a head faces away from its middle.
		var vote := 0.0
		for t in piece:
			var i := t * 3
			var face := (verts[indices[i + 1]] - verts[indices[i]]).cross(verts[indices[i + 2]] - verts[indices[i]])
			var d := face.dot(verts[indices[i]] + verts[indices[i + 1]] + verts[indices[i + 2]] - middle * 3.0)
			vote += -d if flip[t] else d
		for t in piece:
			if flip[t] != (vote > 0.0):
				var i := t * 3
				var keep := indices[i + 1]
				indices[i + 1] = indices[i + 2]
				indices[i + 2] = keep


## Taubin smoothing (a step in, then a slightly bigger step out, so it doesn't shrink):
## evens out dents and crumples while keeping the shape.
static func _smooth(verts: PackedVector3Array, indices: PackedInt32Array, rounds: int) -> void:
	if rounds <= 0:
		return
	var ids := {}
	var weld := PackedInt32Array()
	for p in verts:
		var key := (p * 10000.0).round()
		if not ids.has(key):
			ids[key] = ids.size()
		weld.append(ids[key])
	var pos := PackedVector3Array()
	pos.resize(ids.size())
	for v in verts.size():
		pos[weld[v]] = verts[v]
	var links: Array[Dictionary] = []
	links.resize(ids.size())
	for i in links.size():
		links[i] = {}
	for t in range(0, indices.size(), 3):
		for e in 3:
			var a := weld[indices[t + e]]
			var b := weld[indices[t + (e + 1) % 3]]
			links[a][b] = true
			links[b][a] = true
	for r in rounds * 2:
		var amount := 0.5 if r % 2 == 0 else -0.53
		var moved := pos.duplicate()
		for i in pos.size():
			if links[i].is_empty():
				continue
			var mid := Vector3.ZERO
			for n: int in links[i]:
				mid += pos[n]
			moved[i] = pos[i] + (mid / links[i].size() - pos[i]) * amount
		pos = moved
	for v in verts.size():
		verts[v] = pos[weld[v]]
