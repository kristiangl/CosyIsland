class_name AutoRig
extends RefCounted
## Rigs a generated base model that came without a skeleton: a chibi character in
## T-pose, facing +Z, standing on y = 0 with its arms along X (see
## docs/CHARACTER_PROMPTS.md). Joints are found from the body's shape (how far the arms
## reach, where the legs part, where the neck narrows); a tail, if there is one, is found
## by distance along the surface from its tip. Skin weights go by region with soft
## blends at the joints. Bones use Mixamo's names, plus Tail1..Tail4.

const TAIL_BONES := 4


## {"names", "parents", "rests" (joint positions), "bones" (4 per vertex),
## "weights" (4 per vertex), "joints" (what was measured)}. `arm_length` < 1 shortens
## long arms towards chibi proportions first (moving `verts`).
static func rig(verts: PackedVector3Array, indices: PackedInt32Array, with_tail: bool, arm_length: float = 1.0) -> Dictionary:
	var j := _joints(verts)
	if arm_length < 1.0:
		# Shorter and chunkier: pulled in towards the shoulder and fattened round the
		# arm's line (most along the arm, less at the shoulder and in the hand).
		var weld_before := _weld(verts)
		var arms_before := _find_arms(verts, weld_before, _graph(weld_before, indices), j)
		var from: float = j["shoulder_x"]
		var line := Vector2(j["arm_y"], j["arm_z"])
		var fatten := 1.0 + (1.0 - arm_length) * 1.6
		for v in verts.size():
			if arms_before.has(weld_before[v]) and absf(verts[v].x) > from:
				var x := absf(verts[v].x)
				var along := clampf((x - from) / (j["wrist_x"] - from), 0.0, 1.0)
				var f := lerpf(1.0, fatten, smoothstep(0.0, 0.35, along))
				var yz := line + (Vector2(verts[v].y, verts[v].z) - line) * f
				verts[v] = Vector3(signf(verts[v].x) * (from + (x - from) * arm_length), yz.x, yz.y)
		# Measured again, the shorter arms would be mistaken for the head's width:
		# just bring the arm joints in.
		for key: String in ["reach", "wrist_x", "elbow_x"]:
			j[key] = from + (j[key] - from) * arm_length
		j["thick"] = j["thick"] * fatten
	var names: Array[String] = ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
		"LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand",
		"LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]
	var parents: Array[int] = [-1, 0, 1, 2, 3, 4, 3, 6, 7, 8, 3, 10, 11, 12, 0, 14, 15, 16, 0, 18, 19, 20]
	var torso_y: Array = [j["hip_y"], lerpf(j["hip_y"], j["neck_y"], 0.25), lerpf(j["hip_y"], j["neck_y"], 0.5),
		lerpf(j["hip_y"], j["neck_y"], 0.75), j["neck_y"], j["neck_y"] + 0.03]
	var rests: Array[Vector3] = []
	var zc: float = j["zc"]
	for y: float in torso_y:
		rests.append(Vector3(0, y, zc))
	for s: float in [1.0, -1.0]:
		rests.append(Vector3(s * j["shoulder_x"] * 0.4, j["arm_y"], zc))
		rests.append(Vector3(s * j["shoulder_x"], j["arm_y"], zc))
		rests.append(Vector3(s * j["elbow_x"], j["arm_y"], zc))
		rests.append(Vector3(s * j["wrist_x"], j["arm_y"], zc))
	for s: float in [1.0, -1.0]:
		rests.append(Vector3(s * j["leg_x"], j["crotch_y"], j["leg_z"]))
		rests.append(Vector3(s * j["leg_x"], j["knee_y"], j["leg_z"]))
		rests.append(Vector3(s * j["leg_x"], j["ankle_y"], j["leg_z"]))
		rests.append(Vector3(s * j["leg_x"], j["ankle_y"] * 0.4, j["toe_z"]))
	var weld := _weld(verts)
	var graph := _graph(weld, indices)
	var arms := _find_arms(verts, weld, graph, j)
	var head := _find_head(verts, weld, graph, j, arms)
	var tail := {}
	if with_tail:
		tail = _find_tail(verts, weld, graph, j)
		if not tail.is_empty():
			var path: Array = tail["path"]
			for k in TAIL_BONES:
				names.append("Tail%d" % (k + 1))
				parents.append(0 if k == 0 else names.size() - 2)
				rests.append(path[int(float(k) / TAIL_BONES * (path.size() - 1))])
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(verts.size() * 4)
	weights.resize(verts.size() * 4)
	for v in verts.size():
		var w := _weights_for(verts[v], j, torso_y, arms.get(weld[v], 0.0), head.has(weld[v]))
		if tail.has("t") and tail["t"].has(weld[v]):
			var t: float = tail["t"][weld[v]]
			# Root (t = 1) blends into the hips; the rest runs Tail1 to Tail4, tip last.
			var f := clampf((1.0 - t) * TAIL_BONES - 0.5, 0.0, TAIL_BONES - 1.0)
			var k := int(f)
			var tw := {22 + k: 1.0 - (f - k)}
			if k + 1 < TAIL_BONES:
				tw[22 + k + 1] = f - k
			var root := smoothstep(0.82, 1.0, t)
			for b in w.keys():
				w[b] = w[b] * root
			for b in tw:
				w[b] = w.get(b, 0.0) + tw[b] * (1.0 - root)
		var top := w.keys()
		top.sort_custom(func(a, b): return w[a] > w[b])
		var total := 0.0
		for k in mini(4, top.size()):
			total += w[top[k]]
		for k in 4:
			bones[v * 4 + k] = top[k] if k < top.size() else 0
			weights[v * 4 + k] = w[top[k]] / total if k < top.size() else 0.0
	return {"names": names, "parents": parents, "rests": rests, "bones": bones, "weights": weights, "joints": j}


## The vertices with a mirror image across x = 0: the body without its tail (which
## curls off to one side).
static func _symmetric(verts: PackedVector3Array) -> PackedVector3Array:
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
static func _joints(all_verts: PackedVector3Array) -> Dictionary:
	var verts := _symmetric(all_verts)
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


## Bone weights by region, ignoring the tail: {bone index: weight}.
static func _weights_for(p: Vector3, j: Dictionary, torso_y: Array, on_arm: float, on_head: bool) -> Dictionary:
	var w := {}
	var ax := absf(p.x)
	var left := p.x >= 0.0
	# Torso and head, up the spine.
	var trunk := {}
	var from_neck := Vector2(p.x, p.z - j["neck_z"]).length()
	if on_head and (p.y >= torso_y[5] or from_neck > j["neck_w"] * 1.5):
		# The head, and cheeks hanging down beside the neck.
		trunk[5] = 1.0
	elif on_head:
		var t := smoothstep(j["neck_y"] - 0.02, torso_y[5], p.y)
		trunk[4] = 1.0 - t
		trunk[5] = t
	elif p.y >= torso_y[5]:
		trunk[5] = 1.0
	elif p.y <= torso_y[0]:
		trunk[0] = 1.0
	else:
		for k in 5:
			if p.y >= torso_y[k] and p.y < torso_y[k + 1]:
				var t: float = (p.y - torso_y[k]) / (torso_y[k + 1] - torso_y[k])
				trunk[k] = 1.0 - t
				trunk[k + 1] = t
	# Arms: reached from the hands without crossing the body, out past the shoulder.
	var arm := smoothstep(j["shoulder_x"] - 0.03, j["shoulder_x"] + 0.06, ax) * on_arm
	# Legs: below the hips, either side.
	var leg := 1.0 - smoothstep(j["crotch_y"] - 0.03, j["hip_y"] + 0.01, p.y)
	var torso_share := (1.0 - arm) * (1.0 - leg)
	for b in trunk:
		w[b] = w.get(b, 0.0) + trunk[b] * torso_share
	if arm > 0.0:
		var chain := [7, 8, 9] if left else [11, 12, 13]
		var e := smoothstep(j["elbow_x"] - 0.02, j["elbow_x"] + 0.02, ax)
		var h := smoothstep(j["wrist_x"] - 0.015, j["wrist_x"] + 0.015, ax)
		w[chain[0]] = w.get(chain[0], 0.0) + arm * (1.0 - e)
		w[chain[1]] = w.get(chain[1], 0.0) + arm * (e - h)
		w[chain[2]] = w.get(chain[2], 0.0) + arm * h
	if leg > 0.0:
		var side := smoothstep(-0.02, 0.02, p.x)
		var k := smoothstep(j["knee_y"] - 0.02, j["knee_y"] + 0.02, p.y)
		var a := smoothstep(j["ankle_y"] - 0.015, j["ankle_y"] + 0.015, p.y)
		var toe := smoothstep(j["leg_z"] + 0.02, j["toe_z"], p.z)
		for chain: Array in [[14, 15, 16, 17, side], [18, 19, 20, 21, 1.0 - side]]:
			var s: float = chain[4] * leg
			if s <= 0.0:
				continue
			# Thigh above the knee, shin to the ankle, then the foot and its toes.
			w[chain[0]] = w.get(chain[0], 0.0) + s * k
			w[chain[1]] = w.get(chain[1], 0.0) + s * (1.0 - k) * a
			w[chain[2]] = w.get(chain[2], 0.0) + s * (1.0 - k) * (1.0 - a) * (1.0 - toe)
			w[chain[3]] = w.get(chain[3], 0.0) + s * (1.0 - k) * (1.0 - a) * toe
	for b in w.keys():
		if w[b] <= 0.0001:
			w.erase(b)
	if w.is_empty():
		w[0] = 1.0
	return w


## The arms: everything joined to the hand tips without coming in past the shoulders.
## Returns a set of welded ids.
static func _find_arms(verts: PackedVector3Array, weld: PackedInt32Array, graph: Dictionary, j: Dictionary) -> Dictionary:
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
static func _find_head(verts: PackedVector3Array, weld: PackedInt32Array, graph: Dictionary, j: Dictionary, arms: Dictionary) -> Dictionary:
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
static func _weld(verts: PackedVector3Array) -> PackedInt32Array:
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
static func _graph(weld: PackedInt32Array, indices: PackedInt32Array) -> Dictionary:
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


## Distance along the surface from `start` to every welded vertex, and the step
## each was reached from.
static func _dijkstra(pos: Dictionary, graph: Dictionary, start: int) -> Array:
	var dist := {start: 0.0}
	var from := {}
	var heap: Array = [[0.0, start]]
	while not heap.is_empty():
		var top: Array = _pop(heap)
		var d: float = top[0]
		var v: int = top[1]
		if d > dist.get(v, INF):
			continue
		for n: int in graph.get(v, {}):
			var nd: float = d + (pos[v] as Vector3).distance_to(pos[n])
			if nd < dist.get(n, INF):
				dist[n] = nd
				from[n] = v
				_push(heap, [nd, n])
	return [dist, from]


static func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if heap[parent][0] <= heap[i][0]:
			break
		var tmp: Array = heap[parent]
		heap[parent] = heap[i]
		heap[i] = tmp
		i = parent


static func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var i := 0
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < heap.size() and heap[l][0] < heap[m][0]:
			m = l
		if r < heap.size() and heap[r][0] < heap[m][0]:
			m = r
		if m == i:
			break
		var tmp: Array = heap[m]
		heap[m] = heap[i]
		heap[i] = tmp
		i = m
	return top


## The tail: its tip is the point furthest along the surface from the lower back that
## isn't a hand, foot or the head. Everything closer to the tip than the root is tail.
## Returns {"t": {welded id: 0 at the tip .. 1 at the root}, "path": root-to-tip points}.
static func _find_tail(verts: PackedVector3Array, weld: PackedInt32Array, graph: Dictionary, j: Dictionary) -> Dictionary:
	var pos := {}
	for v in verts.size():
		pos[weld[v]] = verts[v]
	# The root: the back of the body, low down in the middle.
	var root := -1
	var back := INF
	for id: int in pos:
		var p: Vector3 = pos[id]
		if absf(p.x) < 0.04 and p.y > j["crotch_y"] and p.y < j["hip_y"] + 0.12 and p.z < back:
			back = p.z
			root = id
	if root < 0:
		return {}
	var from_root: Array = _dijkstra(pos, graph, root)
	var tip := -1
	var far := 0.0
	for id: int in from_root[0]:
		var p: Vector3 = pos[id]
		var d: float = from_root[0][id]
		var hand: bool = absf(p.x) > j["shoulder_x"] and absf(p.y - j["arm_y"]) < j["thick"] * 2.5
		var head: bool = p.y > j["neck_y"]
		var foot: bool = p.y < j["ankle_y"] * 2.0 and p.z > j["leg_z"] - 0.05
		if not hand and not head and not foot and d > far:
			far = d
			tip = id
	if tip < 0 or far < 0.2:
		return {}
	var from_tip: Array = _dijkstra(pos, graph, tip)
	var length: float = from_tip[0][root]
	var t := {}
	for id: int in from_tip[0]:
		var d: float = from_tip[0][id]
		if d < length:
			t[id] = d / length
	# The middle of the tail, root to tip, for the bones: follow the shortest path.
	var path: Array[Vector3] = []
	var at := root
	while at != tip and from_tip[1].has(at):
		path.append(pos[at])
		at = from_tip[1][at]
	path.append(pos[tip])
	return {"t": t, "path": path}
