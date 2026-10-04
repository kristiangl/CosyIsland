class_name RigPose
extends RefCounted
## Poses a CharacterModel with KayKit's "Rig_Medium" animations (CC0, kaylousberg.com):
## walking, running, chopping, digging, fishing, sitting, lying down, cheering...
## The clips (assets/kaykit/rig_medium.res, made by tools/kaykit_import.gd) are sampled
## bone by bone and each joint's rotation is copied onto the matching pivot of our
## model, so our own parts, outfits and animals move with KayKit's animation.
##
## Rest poses differ (KayKit's is a T-pose; ours stands with arms down), so each pivot
## is first turned to match its bone's rest direction, then turned the way the bone has
## turned from rest.

## Our pivot -> KayKit bone, parents before children. The waist follows the chest.
const MAP := [
	["Hips", "hips"], ["Waist", "chest"], ["Head", "head"],
	["LegL", "upperleg.r"], ["KneeL", "lowerleg.r"], ["LegR", "upperleg.l"], ["KneeR", "lowerleg.l"],
	["ArmL", "upperarm.r"], ["ElbowL", "lowerarm.r"], ["ArmR", "upperarm.l"], ["ElbowR", "lowerarm.l"],
	["Hand", "hand.r"],
]
## The bone each limb points towards, for its direction at rest.
const CHILD := {"upperleg.r": "lowerleg.r", "lowerleg.r": "foot.r", "upperleg.l": "lowerleg.l",
	"lowerleg.l": "foot.l", "upperarm.r": "lowerarm.r", "lowerarm.r": "wrist.r", "upperarm.l": "lowerarm.l",
	"lowerarm.l": "wrist.l", "hand.r": "", "hips": "", "chest": "", "head": ""}
## Where KayKit's props sit in the right hand.
const SLOT := "handslot.r"
const PATH := "res://assets/kaykit/rig_medium.res"

static var library: AnimationLibrary
## Bone -> parent bone ("" for the root), and its rest transform relative to the parent.
static var _parents: Dictionary = {}
static var _rests: Dictionary = {}
## Bones in order, parents first.
static var _order: Array[String] = []
static var _rest_globals: Dictionary = {}
## Turns our hanging limb to its bone's rest direction.
static var _lines: Dictionary = {}
## Clip -> {bone: rotation track}, and its hips position track.
static var _tracks: Dictionary = {}


static func ready() -> bool:
	if library == null and ResourceLoader.exists(PATH):
		library = load(PATH)
		var bones: Dictionary = library.get_meta("bones")
		for name: String in bones:
			_parents[name] = bones[name][0]
			_rests[name] = bones[name][1]
		var left: Array = bones.keys()
		while not left.is_empty():
			for name: String in left.duplicate():
				if _parents[name] == "" or _parents[name] in _order:
					_order.append(name)
					left.erase(name)
		for name in _order:
			var parent: String = _parents[name]
			_rest_globals[name] = (_rest_globals[parent] if parent != "" else Transform3D.IDENTITY) * _rests[name]
		for name: String in CHILD:
			var child: String = CHILD[name]
			_lines[name] = Basis.IDENTITY
			if child != "":
				var dir: Vector3 = (_rest_globals[child].origin - _rest_globals[name].origin).normalized()
				_lines[name] = _arc(Vector3.DOWN, dir)
		# The hand carries on along the forearm.
		_lines["hand.r"] = _lines["lowerarm.r"]
	return library != null


## Where a held tool goes relative to our Hand pivot: KayKit's hand slot, carried
## through the same turn as the hand (tools are built handle up, like KayKit's).
static func slot() -> Transform3D:
	if not ready() or not _rest_globals.has(SLOT):
		return Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3.ZERO)
	var hand: Transform3D = _rest_globals["hand.r"]
	var local: Transform3D = hand.affine_inverse() * _rest_globals[SLOT]
	var b: Basis = _lines["hand.r"].inverse() * hand.basis.orthonormalized()
	return Transform3D(b * local.basis.orthonormalized(), b * local.origin)


static func length(clip: String) -> float:
	return library.get_animation(clip).length if ready() and library.has_animation(clip) else 0.0


## Each bone's local rotation (and the hips' position, as "@hips") at `time` into a clip.
static func sample(clip: String, time: float, out: Dictionary) -> void:
	var anim := library.get_animation(clip)
	if not _tracks.has(clip):
		var found := {}
		for name in _order:
			found[name] = anim.find_track(NodePath(name), Animation.TYPE_ROTATION_3D)
		found["@hips"] = anim.find_track(NodePath("hips"), Animation.TYPE_POSITION_3D)
		_tracks[clip] = found
	var tracks: Dictionary = _tracks[clip]
	time = clampf(time, 0.0, anim.length)
	for name in _order:
		var t: int = tracks[name]
		out[name] = anim.rotation_track_interpolate(t, time) if t >= 0 else Quaternion(_rests[name].basis)
	var h: int = tracks["@hips"]
	out["@hips"] = anim.position_track_interpolate(h, time) if h >= 0 else _rests["hips"].origin


## Mixes two samples: `a` towards `b` by `w`, into `a`.
static func blend(a: Dictionary, b: Dictionary, w: float) -> void:
	for key in a:
		if key == "@hips":
			a[key] = (a[key] as Vector3).lerp(b[key], w)
		else:
			a[key] = (a[key] as Quaternion).slerp(b[key], w)


## Turns the model's pivots (`pivots` in MAP order) towards a sample by `weight`, over
## whatever pose they already have. `lift` scales how far the hips move up and down (0
## keeps them still, as when sitting on a seat).
static func apply(pivots: Array[Node3D], pose: Dictionary, hip_height: float, lift: float = 1.0, weight: float = 1.0) -> void:
	var globals := {}
	for name in _order:
		var parent: String = _parents[name]
		var local := Transform3D(Basis(pose[name] as Quaternion), _rests[name].origin)
		if name == "hips":
			local.origin = pose["@hips"]
		globals[name] = (globals[parent] if parent != "" else Transform3D.IDENTITY) * local
	# Where each pivot points in the clip, relative to the model.
	var wants := {}
	for i in MAP.size():
		var pivot := pivots[i]
		if pivot == null:
			continue
		var bone: String = MAP[i][1]
		var g: Transform3D = globals[bone]
		var want: Basis = g.basis.orthonormalized() * _rest_globals[bone].basis.orthonormalized().inverse() * _lines[bone]
		var parent_name: StringName = pivot.get_parent().name
		var parent_basis: Basis = wants.get(parent_name, _up_to(pivot.get_parent() as Node3D, pivots[0], wants))
		pivot.quaternion = pivot.quaternion.slerp(Quaternion((parent_basis.inverse() * want).orthonormalized()), weight)
		wants[pivot.name] = want
		if i == 0:
			# Turn about the hip joint (our hips pivot sits at the feet), and follow the
			# hips up and down, scaled to our height.
			var rest: Vector3 = _rest_globals["hips"].origin
			var moved: Vector3 = (g.origin - rest) * (hip_height / maxf(rest.y, 0.01))
			moved.y *= lift
			var joint := Vector3(0, hip_height, 0)
			pivot.position = pivot.position.lerp(joint - want * joint + moved, weight)


## A pivot's rotation relative to the model in the clip: the nearest pivot above it that
## the clip has turned, then the plain pivots between (whose rotation is the rest one).
static func _up_to(node: Node3D, hips: Node3D, wants: Dictionary) -> Basis:
	var b := Basis.IDENTITY
	while node != null and node != hips.get_parent():
		if wants.has(node.name):
			return wants[node.name] * b
		b = Basis(node.quaternion) * b
		node = node.get_parent() as Node3D
	return b


## The shortest rotation taking direction a to direction b.
static func _arc(a: Vector3, b: Vector3) -> Basis:
	var axis := a.cross(b)
	if axis.length() < 0.0001:
		return Basis.IDENTITY if a.dot(b) > 0.0 else Basis(Vector3.FORWARD, PI)
	return Basis(axis.normalized(), a.angle_to(b))
