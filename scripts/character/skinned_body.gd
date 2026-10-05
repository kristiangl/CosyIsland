class_name SkinnedBody
extends Node3D
## A generated base body (a rigged model converted by tools/character_import.gd) worn by
## a CharacterModel in place of its procedural body. The model's pivots still do all
## the animating; every frame each bone copies the rotation of the pivot it follows.
## Bones have no rotation at rest, so the T-pose is the identity and the arms need a
## turn to match the pivots' hanging rest.

const P = preload("res://scripts/character/character_parts.gd")
const DIR := "res://assets/characters/"

## Which pivot each bone follows. Pivots ending _l sit on the character's right (-X),
## where Mixamo puts its "Right" bones.
const FOLLOW := {
	"Hips": "hips", "Spine": "waist", "Spine1": "waist", "Spine2": "body", "Neck": "body", "Head": "head",
	"LeftShoulder": "body", "LeftArm": "arm_r", "LeftForeArm": "elbow_r", "LeftHand": "elbow_r",
	"RightShoulder": "body", "RightArm": "arm_l", "RightForeArm": "elbow_l", "RightHand": "hand",
	"LeftUpLeg": "leg_r", "LeftLeg": "knee_r", "LeftFoot": "knee_r", "LeftToeBase": "knee_r",
	"RightUpLeg": "leg_l", "RightLeg": "knee_l", "RightFoot": "knee_l", "RightToeBase": "knee_l",
	"Tail1": "tail",
}
## Each tail bone after the first bends this much of the way the first does, so a
## wag curls along the tail.
const TAIL_CURL := 0.6
## Arm bones lie along X in the T-pose; the pivots hang down.
const ARM_TURN := {"Left": -PI * 0.5, "Right": PI * 0.5}

static var _meshes: Dictionary = {}

var skeleton: Skeleton3D
var mesh: MeshInstance3D
## Procedural head space (a _head pivot's children) mapped onto this head, for hair,
## hats and glasses.
var head_frame: Node3D
## The tool hand pivot's frame, for the held tool.
var grip: Node3D
var _pivot_of: Array[Node3D] = []
var _turn: Array[Basis] = []
var _parents: Array = []
var _rests: Array = []
var _globals: Array[Basis] = []
var _tail_first := -1


## Whether there's a base model for this kind of character ("human", "cat"...).
static func has_model(kind: String) -> bool:
	return _meshes.has(kind) or ResourceLoader.exists(DIR + kind + ".res")


static func mesh_for(kind: String) -> ArrayMesh:
	if not _meshes.has(kind):
		_meshes[kind] = load(DIR + kind + ".res")
	return _meshes[kind]


## The body's layout in rest space, for the body shader.
static func layout(kind: String) -> Dictionary:
	var m := mesh_for(kind)
	var names: Array = m.get_meta("bones")
	var rests: Array = m.get_meta("rests")
	var at := func(bone: String) -> Vector3: return rests[names.find(bone)]
	return {"shoulder_x": at.call("LeftArm").x, "elbow_x": at.call("LeftForeArm").x, "wrist_x": at.call("LeftHand").x,
		"arm_y": at.call("LeftArm").y, "neck_y": at.call("Neck").y, "hip_y": at.call("Hips").y,
		"knee_y": at.call("LeftLeg").y, "ankle_y": at.call("LeftFoot").y}


## The head's centre and radii in rest space: {"centre", "radius"}.
static func head_shape(kind: String) -> Dictionary:
	return mesh_for(kind).get_meta("head")


func setup(kind: String, pivots: Dictionary, body_material: Material, head_material: Material) -> void:
	var m := mesh_for(kind)
	var names: Array = m.get_meta("bones")
	_parents = m.get_meta("parents")
	_rests = m.get_meta("rests")
	skeleton = Skeleton3D.new()
	add_child(skeleton)
	var skin := Skin.new()
	for i in names.size():
		skeleton.add_bone(names[i])
	for i in names.size():
		var parent: int = _parents[i]
		skeleton.set_bone_parent(i, parent)
		var local: Vector3 = _rests[i] - (_rests[parent] if parent >= 0 else Vector3.ZERO)
		skeleton.set_bone_rest(i, Transform3D(Basis(), local))
		skin.add_named_bind(names[i], Transform3D(Basis(), -_rests[i]))
		var follow: String = FOLLOW.get(names[i], "")
		_pivot_of.append(pivots.get(follow))
		var side := "Left" if names[i].begins_with("Left") else ("Right" if names[i].begins_with("Right") else "")
		var arm: bool = side != "" and (names[i].contains("Arm") or names[i].contains("Hand"))
		_turn.append(Basis(Vector3.BACK, ARM_TURN[side]) if arm else Basis())
		_globals.append(Basis())
	_tail_first = names.find("Tail1")
	skeleton.reset_bone_poses()
	mesh = MeshInstance3D.new()
	mesh.mesh = m
	mesh.skin = skin
	skeleton.add_child(mesh)
	mesh.skeleton = NodePath("..")
	mesh.set_surface_override_material(0, body_material)
	mesh.set_surface_override_material(1, head_material)
	# Head things: procedural head space (origin at the neck, head centred at
	# P.HEAD_CENTRE) scaled and moved onto this head.
	var shape := head_shape(kind)
	var head_bone := BoneAttachment3D.new()
	head_bone.bone_name = "Head"
	skeleton.add_child(head_bone)
	head_frame = Node3D.new()
	var k: Vector3 = shape["radius"] / P.HEAD_RADIUS
	head_frame.transform = Transform3D(Basis.from_scale(k), shape["centre"] - _rests[names.find("Head")] - k * P.HEAD_CENTRE)
	head_bone.add_child(head_frame)
	var hand_bone := BoneAttachment3D.new()
	hand_bone.bone_name = "RightHand"
	skeleton.add_child(hand_bone)
	grip = Node3D.new()
	grip.basis = Basis(Vector3.BACK, ARM_TURN["Right"]).inverse()
	hand_bone.add_child(grip)
	drive()


## Poses the bones from their pivots (call after the pivots have moved).
func drive() -> void:
	if Game.args.has("tpose"):
		# Checking a rig: leave it in its rest pose.
		return
	var to_model: Transform3D = (get_parent() as Node3D).global_transform.affine_inverse()
	for i in _parents.size():
		var pivot := _pivot_of[i]
		var parent: int = _parents[i]
		var parent_global := _globals[parent] if parent >= 0 else Basis()
		var g := parent_global
		if pivot == null and _tail_first >= 0 and i > _tail_first:
			# Later tail bones curl after the first.
			var curl := Quaternion.IDENTITY.slerp(skeleton.get_bone_pose_rotation(_tail_first), TAIL_CURL)
			skeleton.set_bone_pose_rotation(i, curl)
			_globals[i] = parent_global * Basis(curl)
			continue
		if pivot:
			var rel: Transform3D = to_model * pivot.global_transform
			g = rel.basis.orthonormalized() * _turn[i]
			if parent < 0:
				# The hips pivot sits on the ground: the hips bone swings about it.
				skeleton.set_bone_pose_position(i, rel.origin + rel.basis.orthonormalized() * _rests[i])
		skeleton.set_bone_pose_rotation(i, (parent_global.inverse() * g).get_rotation_quaternion())
		_globals[i] = g
