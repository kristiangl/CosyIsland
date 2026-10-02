class_name CharacterModel
extends Node3D
## A chibi villager built from simple shapes, animated in code (walk cycle, idle
## breathing, tool swings). Faces +Z.

const SKIN := Color("f6d3b3")
const HAIR := Color("5a3a2a")
const SHIRT := Color("e98b6b")
const SHORTS := Color("4f6d8f")
const SHOES := Color("5b4636")

var _body: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _hand_r: Node3D
var _tool: MeshInstance3D
var _phase := 0.0
var _swing := -1.0  # 0..1 while swinging, -1 when idle
var _swing_kind := ""


func _ready() -> void:
	_body = _part("Body", Vector3.ZERO, _body_mesh())
	_head = _part("Head", Vector3(0, 0.0, 0), _head_mesh(), _body)
	_leg_l = _part("LegL", Vector3(-0.09, 0.38, 0), _leg_mesh(), _body)
	_leg_r = _part("LegR", Vector3(0.09, 0.38, 0), _leg_mesh(), _body)
	_arm_l = _part("ArmL", Vector3(-0.22, 0.68, 0), _arm_mesh(), _body)
	_arm_r = _part("ArmR", Vector3(0.22, 0.68, 0), _arm_mesh(), _body)
	_arm_l.rotation.z = -0.25
	_arm_r.rotation.z = 0.25
	_hand_r = Node3D.new()
	_hand_r.position = Vector3(0, -0.27, 0)
	_arm_r.add_child(_hand_r)
	_tool = MeshInstance3D.new()
	_tool.material_override = Models.material()
	_tool.rotation_degrees = Vector3(90, 0, 0)
	_hand_r.add_child(_tool)


func _part(part_name: String, pos: Vector3, mesh: ArrayMesh, parent: Node3D = null) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = part_name
	pivot.position = pos
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Models.material()
	pivot.add_child(mi)
	(parent if parent else self).add_child(pivot)
	return pivot


func set_tool(item_id: String) -> void:
	_tool.mesh = Models.get_mesh("tool:" + item_id) if item_id != "" else null


## Starts a swing. kind is "chop" (overhead) or "shake" (both arms out).
func swing(kind: String) -> void:
	_swing = 0.0
	_swing_kind = kind


func animate(delta: float, speed: float) -> void:
	var moving := speed > 0.05
	_phase += delta * (4.0 + speed * 2.2) if moving else delta * 2.0
	var stride := clampf(speed / 6.0, 0.0, 1.0)
	if moving:
		var s := sin(_phase * 2.0)
		_leg_l.rotation.x = s * (0.5 + stride * 0.4)
		_leg_r.rotation.x = -s * (0.5 + stride * 0.4)
		_arm_l.rotation.x = -s * (0.4 + stride * 0.5)
		_arm_r.rotation.x = s * (0.4 + stride * 0.5)
		_body.position.y = absf(cos(_phase * 2.0)) * 0.06
		_body.rotation.x = 0.05 + stride * 0.12
	else:
		for limb in [_leg_l, _leg_r, _arm_l, _arm_r]:
			limb.rotation.x = lerpf(limb.rotation.x, 0.0, 1.0 - exp(-delta * 12.0))
		_body.position.y = sin(_phase) * 0.008
		_body.rotation.x = lerpf(_body.rotation.x, 0.0, 1.0 - exp(-delta * 10.0))

	if _swing >= 0.0:
		_swing += delta / 0.42
		var t := clampf(_swing, 0.0, 1.0)
		if _swing_kind == "chop":
			# Wind up over the head, then strike forward and down.
			var a := _chop_angle(t)
			_arm_r.rotation.x = a
			_arm_l.rotation.x = a * 0.6
			_body.rotation.x = 0.15 if t > 0.35 and t < 0.7 else 0.0
		else:
			var a := -1.4 * sin(t * PI)
			_arm_r.rotation.x = a
			_arm_l.rotation.x = a
			_body.rotation.z = sin(t * TAU * 3.0) * 0.06 * (1.0 - t)
		if _swing >= 1.0:
			_swing = -1.0
			_body.rotation.z = 0.0


## Arm angle through a chop: wind up overhead, strike forward, then relax.
static func _chop_angle(t: float) -> float:
	if t < 0.35:
		return lerpf(0.0, -2.8, t / 0.35)
	if t < 0.6:
		return lerpf(-2.8, -1.1, ease((t - 0.35) / 0.25, 0.3))
	return lerpf(-1.1, 0.0, (t - 0.6) / 0.4)


func _body_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	k.sphere(Vector3(0, 0.56, 0), Vector3(0.2, 0.22, 0.17), MeshKit.lin(SHIRT), 6, 10, 0.25)
	k.sphere(Vector3(0, 0.41, 0), Vector3(0.19, 0.11, 0.16), MeshKit.lin(SHORTS), 4, 10, 0.2)
	return k.commit()


func _head_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	var y := 1.02
	k.sphere(Vector3(0, y, 0), Vector3(0.34, 0.31, 0.32), MeshKit.lin(SKIN), 8, 14, 0.15)
	# Hair: a cap with bangs over the forehead and a fuller back.
	k.sphere(Vector3(0, y + 0.11, -0.01), Vector3(0.355, 0.24, 0.35), MeshKit.lin(HAIR), 6, 14, 0.2)
	k.sphere(Vector3(0, y - 0.02, -0.09), Vector3(0.34, 0.27, 0.26), MeshKit.lin(HAIR), 6, 12, 0.2)
	var eye := MeshKit.lin(Color("2b2230"))
	var white := MeshKit.lin(Color.WHITE)
	var blush := MeshKit.lin(Color("f29a96"))
	for s in [-1.0, 1.0]:
		k.sphere(Vector3(s * 0.11, y - 0.06, 0.29), Vector3(0.036, 0.06, 0.025), eye, 4, 8)
		k.sphere(Vector3(s * 0.11 + 0.012, y - 0.035, 0.31), Vector3.ONE * 0.013, white, 3, 6)
		k.sphere(Vector3(s * 0.19, y - 0.13, 0.235), Vector3(0.05, 0.026, 0.02), blush, 3, 8)
	k.sphere(Vector3(0, y - 0.15, 0.285), Vector3(0.022, 0.012, 0.012), MeshKit.lin(Color("b0564f")), 3, 6)
	return k.commit()


func _arm_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	k.cylinder(Vector3.ZERO, Vector3(0, -0.22, 0), 0.06, 0.05, MeshKit.lin(SHIRT), 6, false)
	k.sphere(Vector3(0, -0.26, 0), Vector3.ONE * 0.06, MeshKit.lin(SKIN), 4, 8)
	return k.commit()


func _leg_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	k.cylinder(Vector3.ZERO, Vector3(0, -0.3, 0), 0.065, 0.06, MeshKit.lin(SKIN), 6, false)
	k.sphere(Vector3(0, -0.33, 0.03), Vector3(0.075, 0.055, 0.1), MeshKit.lin(SHOES), 4, 8)
	return k.commit()
