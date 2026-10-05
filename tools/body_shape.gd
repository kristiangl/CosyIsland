extends RefCounted
## Measures a generated character model standing in T-pose (facing +Z, on y = 0, arms
## along X): where its joints are, and which vertices are its arms and its head. Used
## to cut the head off a full-body model (tools/head_import.gd).


## The vertices with a mirror image across x = 0: the body without its tail (which
## curls off to one side).
static func symmetric(verts: PackedVector3Array) -> PackedVector3Array:
	const CELL := 0.03
	var cells := {}
	for p in verts:
		cells[Vector3i((p / CELL).floor())] = true
	var out := PackedVector3Array()
	for p in verts:
		var m := Vector3i((Vector3(-p.x, p.y, p.z) / CELL).floor())
		var found := false
		for dz in range(-1, 2):
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if cells.has(m + Vector3i(dx, dy, dz)):
						found = true
		if found:
			out.append(p)
	return out


## Where the joints are, from horizontal slices through the T-pose (mirrored parts only).
static func joints(all_verts: PackedVector3Array) -> Dictionary:
	var verts := symmetric(all_verts)
	var top := 0.0
	var reach := 0.0
	for p in verts:
		top = maxf(top, p.y)
		reach = maxf(reach, absf(p.x))
	# The arms: the forearms' height and thickness, measured out past the head's width.
	var ys := PackedFloat32Array()
	var zs := PackedFloat32Array()
	for p in verts:
		if absf(p.x) > reach * 0.72 and absf(p.x) < reach * 0.86:
			ys.append(p.y)
			zs.append(p.z)
	ys.sort()
	var arm_y := ys[ys.size() / 2]
	var thick := (ys[int(ys.size() * 0.85)] - ys[int(ys.size() * 0.15)]) * 0.5 * 1.3
	zs.sort()
	var arm_z := zs[zs.size() / 2]
	# The torso's width just under the arms gives the shoulders.
	var widths := PackedFloat32Array()
	for p in verts:
		if p.y > arm_y - thick * 2.4 and p.y < arm_y - thick * 1.4 and absf(p.x) < reach * 0.5:
			widths.append(absf(p.x))
	widths.sort()
	var shoulder_x := widths[int(widths.size() * 0.9)] if not widths.is_empty() else reach * 0.35
	var wrist_x := reach - (reach - shoulder_x) * 0.3
	var elbow_x := (shoulder_x + wrist_x) * 0.5
	# The legs part at the crotch: the lowest height with something in the middle, in
	# front of where a tail could hang.
	var leg_zs := PackedFloat32Array()
	for p in verts:
		if p.y > 0.08 and p.y < 0.14:
			leg_zs.append(p.z)
	leg_zs.sort()
	var leg_z := leg_zs[leg_zs.size() / 2]
	var crotch_y := arm_y
	var y := 0.02
	while y < arm_y:
		var middle := false
		for p in verts:
			if absf(p.y - y) < 0.006 and absf(p.x) < 0.012 and absf(p.z - leg_z) < 0.06:
				middle = true
				break
		if middle:
			crotch_y = y
			break
		y += 0.005
	var leg_xs := PackedFloat32Array()
	for p in verts:
		if p.y > crotch_y * 0.5 and p.y < crotch_y * 0.8 and absf(p.z - leg_z) < 0.08:
			leg_xs.append(absf(p.x))
	leg_xs.sort()
	var leg_x := leg_xs[leg_xs.size() / 2] if not leg_xs.is_empty() else 0.06
	# The neck: the narrowest slice between the arms and the top of the head.
	var neck_y := arm_y + thick
	var narrowest := INF
	y = arm_y
	while y < arm_y + (top - arm_y) * 0.4:
		var w := 0.0
		for p in verts:
			if absf(p.y - y) < 0.006 and absf(p.x) < shoulder_x * 1.6:
				w = maxf(w, absf(p.x))
		if w > 0.0 and w < narrowest:
			narrowest = w
			neck_y = y
		y += 0.005
	var neck_z := 0.0
	var neck_n := 0
	for p in verts:
		if absf(p.y - neck_y) < 0.01 and absf(p.x) < narrowest * 1.1:
			neck_z += p.z
			neck_n += 1
	neck_z = neck_z / neck_n if neck_n > 0 else leg_z
	var toe_z := leg_z
	for p in verts:
		if p.y < crotch_y * 0.2:
			toe_z = maxf(toe_z, p.z)
	return {"arm_y": arm_y, "arm_z": arm_z, "thick": thick, "shoulder_x": shoulder_x, "elbow_x": elbow_x, "wrist_x": wrist_x,
		"crotch_y": crotch_y, "hip_y": crotch_y + (neck_y - crotch_y) * 0.12, "leg_x": leg_x, "leg_z": leg_z,
		"knee_y": crotch_y * 0.5, "ankle_y": crotch_y * 0.24, "toe_z": lerpf(leg_z, toe_z, 0.6), "neck_y": neck_y,
		"neck_w": narrowest, "neck_z": neck_z, "zc": leg_z, "reach": reach, "top": top}


## The arms: everything joined to the hand tips without coming in past the shoulders.
## Returns a set of welded ids.
static func find_arms(verts: PackedVector3Array, weld: PackedInt32Array, graph: Dictionary, j: Dictionary) -> Dictionary:
	var pos := {}
	for v in verts.size():
		pos[weld[v]] = verts[v]
	var arms := {}
	var stack: Array[int] = []
	for id: int in pos:
		var p: Vector3 = pos[id]
		if absf(p.x) > j["reach"] * 0.92 and absf(p.y - j["arm_y"]) < j["thick"] * 3.0:
			arms[id] = 1.0
			stack.append(id)
	var inner: float = j["shoulder_x"] - 0.04
	# The arm keeps to a tube round its line, so cheeks and chest just above or below
	# it stay put.
	var tube: float = j["thick"] * 1.5
	var line := Vector2(j["arm_y"], j["arm_z"])
	while not stack.is_empty():
		var at: int = stack.pop_back()
		for n: int in graph.get(at, {}):
			var p: Vector3 = pos[n]
			# The hand's fingers spread wider than the arm; near the body, how much a
			# vertex follows the arm fades out across the edge of the tube.
			var hand: bool = absf(p.x) > j["wrist_x"]
			var limit: float = tube * (2.2 if hand else 1.35)
			var d := Vector2(p.y, p.z).distance_to(line)
			if not arms.has(n) and absf(p.x) > inner and d < limit:
				arms[n] = 1.0 if hand else 1.0 - smoothstep(tube * 0.85, limit, d)
				stack.append(n)
	return arms


## The head: everything joined to the top of the head without going down through the
## neck or into the arms, so cheeks that hang down beside the neck still count.
static func find_head(verts: PackedVector3Array, weld: PackedInt32Array, graph: Dictionary, j: Dictionary, arms: Dictionary) -> Dictionary:
	var pos := {}
	var top := -1
	for v in verts.size():
		pos[weld[v]] = verts[v]
		if top < 0 or verts[v].y > (pos[top] as Vector3).y:
			top = weld[v]
	var head := {top: true}
	var stack: Array[int] = [top]
	var floor_y: float = j["arm_y"] - j["thick"]
	while not stack.is_empty():
		var at: int = stack.pop_back()
		for n: int in graph.get(at, {}):
			var p: Vector3 = pos[n]
			var in_neck: bool = p.y < j["neck_y"] + 0.015 and Vector2(p.x, p.z - j["neck_z"]).length() < j["neck_w"] * 1.3
			if not head.has(n) and not arms.has(n) and not in_neck and p.y > floor_y:
				head[n] = true
				stack.append(n)
	return head


## Vertices at the same spot (split by UV seams) share an id.
static func weld(verts: PackedVector3Array) -> PackedInt32Array:
	var ids := {}
	var out := PackedInt32Array()
	out.resize(verts.size())
	for v in verts.size():
		var key := (verts[v] * 10000.0).round()
		if not ids.has(key):
			ids[key] = ids.size()
		out[v] = ids[key]
	return out


## Neighbours of each welded vertex: {id: {id: edge length}}, plus positions.
static func graph(weld: PackedInt32Array, indices: PackedInt32Array) -> Dictionary:
	var edges := {}
	for t in range(0, indices.size(), 3):
		for e in 3:
			var a := weld[indices[t + e]]
			var b := weld[indices[t + (e + 1) % 3]]
			if a == b:
				continue
			if not edges.has(a):
				edges[a] = {}
			if not edges.has(b):
				edges[b] = {}
			edges[a][b] = true
			edges[b][a] = true
	return edges
