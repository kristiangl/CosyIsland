class_name CharacterModel
extends Node3D
## A modular chibi character built from an Appearance dictionary, animated in code
## (walk cycle, idle breathing, blinking, tool swings). Faces +Z.

const P = preload("res://scripts/character/character_parts.gd")

## How far the light wraps round (see toon_light): faces stay mostly lit, bodies less so.
const FACE_WRAP := 0.5
const BODY_WRAP := 0.25

var look: Dictionary = Appearance.DEFAULT.duplicate()
## False for characters shown in menus, away from the island's world curvature.
var curved := true

var _body: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _hand_r: Node3D
var _tool: MeshInstance3D
var _face: ShaderMaterial
var _phase := 0.0
var _swing := -1.0  # 0..1 while swinging, -1 when idle
var _swing_kind := ""
var _blink_timer := 2.0
var _blink := 0.0
var _tool_id := ""

static var _shaders: Dictionary = {}


func _init(appearance: Dictionary = {}) -> void:
	if not appearance.is_empty():
		look = Appearance.sanitise(appearance)


func _ready() -> void:
	rebuild()


## Rebuilds every part from `look`. Call after changing the appearance.
func rebuild() -> void:
	for child in get_children():
		child.free()
	_body = _pivot("Body", Vector3.ZERO, self)
	_head = _pivot("Head", Vector3(0, P.NECK_Y, 0), _body)
	_leg_l = _pivot("LegL", Vector3(-P.LEG_X, P.HIP_Y, 0), _body)
	_leg_r = _pivot("LegR", Vector3(P.LEG_X, P.HIP_Y, 0), _body)
	_arm_l = _pivot("ArmL", P.SHOULDER * Vector3(-1, 1, 1), _body)
	_arm_r = _pivot("ArmR", P.SHOULDER, _body)
	_arm_l.rotation.z = -0.22
	_arm_r.rotation.z = 0.22
	_hand_r = _pivot("Hand", Vector3(0, -P.ARM_LENGTH, 0), _arm_r)
	_tool = MeshInstance3D.new()
	_tool.material_override = Models.material()
	_tool.rotation_degrees = Vector3(90, 0, 0)
	_hand_r.add_child(_tool)
	set_tool(_tool_id)

	var skin := _cloth(Appearance.color(look, "skin"))
	var top_mat := _cloth(Appearance.color(look, "top_color"), Appearance.color(look, "top_color2"),
		Appearance.index_of(look, "top_pattern"))
	var bottom_mat := _cloth(Appearance.color(look, "bottom_color"), Appearance.color(look, "bottom_color").lightened(0.5))
	var shoe_mat := _cloth(Appearance.color(look, "shoe_color"), Color("f7f4ee"))
	var hair_colour := Appearance.color(look, "hair_color")
	var hair_mat := _cloth(hair_colour, hair_colour.darkened(0.25))
	hair_mat.set_shader_parameter("shine", 0.7)

	# Body and limbs.
	_mesh(P.torso_skin(), skin, _body)
	var barefoot: bool = look["shoes"] == "none"
	for leg in [_leg_l, _leg_r]:
		_mesh(P.leg_skin(barefoot), skin, leg)
		if not barefoot:
			_mesh(P.shoe(look["shoes"]), shoe_mat, leg)
	for arm in [_arm_l, _arm_r]:
		_mesh(P.arm_skin(), skin, arm)

	var top := P.top(look["top"])
	_mesh(top["torso"], top_mat, _body)
	if top["sleeve"]:
		for arm in [_arm_l, _arm_r]:
			_mesh(top["sleeve"], top_mat, arm)
	if not Appearance.is_full_body_top(look):
		var bottom := P.bottom(look["bottom"])
		_mesh(bottom["hips"], bottom_mat, _body)
		if bottom["leg"]:
			for leg in [_leg_l, _leg_r]:
				_mesh(bottom["leg"], bottom_mat, leg)

	# Head, face and everything on it.
	_face = ShaderMaterial.new()
	_face.shader = _shader("face")
	_face.set_shader_parameter("skin", Appearance.color(look, "skin"))
	_face.set_shader_parameter("light_wrap", FACE_WRAP)
	_face.set_shader_parameter("curved", curved)
	_face.set_shader_parameter("eye_colour", Appearance.color(look, "eye_color"))
	_face.set_shader_parameter("brow_colour", hair_colour.darkened(0.35))
	_face.set_shader_parameter("eye_style", Appearance.index_of(look, "eyes"))
	_face.set_shader_parameter("brow_style", Appearance.index_of(look, "brows"))
	_face.set_shader_parameter("mouth_style", Appearance.index_of(look, "mouth"))
	_face.set_shader_parameter("cheek_style", Appearance.index_of(look, "cheeks"))
	var head_mesh := _mesh(P.head(), _face, _head)
	head_mesh.position = P.HEAD_CENTRE
	var hat_style: String = look["hat"]
	var hair_mesh := _mesh(P.hair(look["hair"], hat_style in ["cap", "beanie", "bucket", "straw"], hat_style == "beret"), hair_mat, _head)
	hair_mesh.position = P.HEAD_CENTRE
	# Hair, hats and glasses don't cast shadows, so faces stay bright under a brim.
	hair_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if hat_style != "none":
		var hat_mat := _cloth(Appearance.color(look, "hat_color"), Color("fff4e0") if hat_style != "flower_crown" else Color("f6d36b"))
		var hat_mesh := _mesh(P.hat(hat_style), hat_mat, _head)
		hat_mesh.position = P.HEAD_CENTRE
		hat_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if look["glasses"] != "none":
		var frame := _cloth(Color("4a4550"), Color("3a3a4a") if look["glasses"] == "sunnies" else Color("4a4550"))
		var glasses_mesh := _mesh(P.glasses(look["glasses"]), frame, _head)
		glasses_mesh.position = P.HEAD_CENTRE
		glasses_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_look(appearance: Dictionary) -> void:
	look = Appearance.sanitise(appearance)
	if is_inside_tree():
		rebuild()


func set_tool(item_id: String) -> void:
	_tool_id = item_id
	if _tool:
		_tool.mesh = Models.get_mesh("tool:" + item_id) if item_id != "" else null


## Starts a swing. kind is "chop" (overhead) or "shake" (both arms out).
func swing(kind: String) -> void:
	_swing = 0.0
	_swing_kind = kind


func animate(delta: float, speed: float) -> void:
	_animate_blink(delta)
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
		_head.rotation.x = -_body.rotation.x * 0.6
	else:
		for limb in [_leg_l, _leg_r, _arm_l, _arm_r]:
			limb.rotation.x = lerpf(limb.rotation.x, 0.0, 1.0 - exp(-delta * 12.0))
		_body.position.y = sin(_phase) * 0.008
		_body.rotation.x = lerpf(_body.rotation.x, 0.0, 1.0 - exp(-delta * 10.0))
		_head.rotation.x = lerpf(_head.rotation.x, 0.0, 1.0 - exp(-delta * 10.0))
		_head.rotation.z = sin(_phase * 0.5) * 0.03

	if _swing >= 0.0:
		_swing += delta / 0.42
		var t := clampf(_swing, 0.0, 1.0)
		if _swing_kind == "chop":
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


func _animate_blink(delta: float) -> void:
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 1.0
		_blink_timer = randf_range(2.0, 5.0)
	if _blink > 0.0:
		_blink = maxf(0.0, _blink - delta / 0.14)
		_face.set_shader_parameter("blink", sin(_blink * PI))


## Arm angle through a chop: wind up overhead, strike forward, then relax.
static func _chop_angle(t: float) -> float:
	if t < 0.35:
		return lerpf(0.0, -2.8, t / 0.35)
	if t < 0.6:
		return lerpf(-2.8, -1.1, ease((t - 0.35) / 0.25, 0.3))
	return lerpf(-1.1, 0.0, (t - 0.6) / 0.4)


func _pivot(pivot_name: String, pos: Vector3, parent: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = pivot_name
	pivot.position = pos
	parent.add_child(pivot)
	return pivot


func _mesh(mesh: ArrayMesh, material: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	parent.add_child(mi)
	return mi


func _cloth(a: Color, b: Color = Color.WHITE, pattern: int = 0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader("cloth")
	mat.set_shader_parameter("colour_a", a)
	mat.set_shader_parameter("colour_b", b)
	mat.set_shader_parameter("pattern", pattern)
	mat.set_shader_parameter("light_wrap", BODY_WRAP)
	mat.set_shader_parameter("curved", curved)
	return mat


static func _shader(shader_name: String) -> Shader:
	if not _shaders.has(shader_name):
		_shaders[shader_name] = load("res://shaders/%s.gdshader" % shader_name)
	return _shaders[shader_name]
