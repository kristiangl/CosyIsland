class_name CharacterModel
extends Node3D
## A modular chibi character built from an Appearance dictionary and rigged with simple
## pivots (body, head, shoulders, elbows, hips, knees). Animated in code: walk and run
## cycles, idle breathing and glances, blinking, and one-off actions. Faces +Z.

const P = preload("res://scripts/character/character_parts.gd")

## How far the light wraps round (see toon_light): faces stay mostly lit, bodies less so.
const FACE_WRAP := 0.5
const BODY_WRAP := 0.25

var look: Dictionary = Appearance.DEFAULT.duplicate()
## False for characters shown in menus, away from the island's world curvature.
var curved := true

var _hips: Node3D
var _waist: Node3D
var _body: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _elbow_l: Node3D
var _elbow_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _hand_r: Node3D
var _tool: MeshInstance3D
var _face: ShaderMaterial
var _tool_id := ""

# Animation state.
var _time := 0.0
var _phase := 0.0
var _last_step := 0.0
var _action := ""
var _action_t := 0.0
var _action_length := 0.4
var _sitting := false
var _blink_timer := 2.0
var _blink := 0.0
var _glance := 0.0
var _glance_timer := 4.0
## Current joint values, eased towards each frame's targets.
var _pose := {}

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
	# Hips carry the legs and bob up and down; the body bends at the hips. Parts are
	# built from the feet up, so the upper body's content is shifted back down.
	_hips = _pivot("Hips", Vector3.ZERO, self)
	var waist := _pivot("Waist", Vector3(0, P.HIP_Y, 0), _hips)
	_body = _pivot("Body", Vector3(0, -P.HIP_Y, 0), waist)
	_waist = waist
	_head = _pivot("Head", Vector3(0, P.NECK_Y, 0), _body)
	_leg_l = _pivot("LegL", Vector3(-P.LEG_X, P.HIP_Y, 0), _hips)
	_leg_r = _pivot("LegR", Vector3(P.LEG_X, P.HIP_Y, 0), _hips)
	_knee_l = _pivot("KneeL", Vector3(0, -P.LEG_UPPER, 0), _leg_l)
	_knee_r = _pivot("KneeR", Vector3(0, -P.LEG_UPPER, 0), _leg_r)
	_arm_l = _pivot("ArmL", P.SHOULDER * Vector3(-1, 1, 1), _body)
	_arm_r = _pivot("ArmR", P.SHOULDER, _body)
	_elbow_l = _pivot("ElbowL", Vector3(0, -P.ARM_UPPER, 0), _arm_l)
	_elbow_r = _pivot("ElbowR", Vector3(0, -P.ARM_UPPER, 0), _arm_r)
	_hand_r = _pivot("Hand", Vector3(0, -P.ARM_LOWER, 0), _elbow_r)
	_pose.clear()
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
	var legs := P.leg_skin(barefoot)
	var arms := P.arm_skin()
	for side in [[_leg_l, _knee_l], [_leg_r, _knee_r]]:
		_mesh(legs["upper"], skin, side[0])
		_mesh(legs["lower"], skin, side[1])
		if not barefoot:
			_mesh(P.shoe(look["shoes"]), shoe_mat, side[1])
	for side in [[_arm_l, _elbow_l], [_arm_r, _elbow_r]]:
		_mesh(arms["upper"], skin, side[0])
		_mesh(arms["lower"], skin, side[1])

	var top := P.top(look["top"])
	_mesh(top["torso"], top_mat, _body)
	for side in [[_arm_l, _elbow_l], [_arm_r, _elbow_r]]:
		if top["sleeve"]:
			_mesh(top["sleeve"], top_mat, side[0])
		if top["cuff"]:
			_mesh(top["cuff"], top_mat, side[1])
	if not Appearance.is_full_body_top(look):
		var bottom := P.bottom(look["bottom"])
		_mesh(bottom["hips"], bottom_mat, _body)
		for side in [[_leg_l, _knee_l], [_leg_r, _knee_r]]:
			if bottom["leg"]:
				_mesh(bottom["leg"], bottom_mat, side[0])
			if bottom["shin"]:
				_mesh(bottom["shin"], bottom_mat, side[1])

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


## Plays a one-off action: "chop" (overhead swing), "shake" (both hands on a tree),
## "pickup" (crouch and reach) or "cheer" (a happy hop, arms up).
func play(action: String) -> void:
	_action = action
	_action_t = 0.0
	_action_length = {"chop": 0.45, "shake": 0.5, "pickup": 0.35, "cheer": 0.9}.get(action, 0.4)
	if action == "cheer" and _face:
		_face.set_shader_parameter("eye_style", 2)


## Kept for older callers.
func swing(kind: String) -> void:
	play(kind)


func set_sitting(sitting: bool) -> void:
	_sitting = sitting


## Call every frame. speed in m/s, turn_rate in rad/s, accel in m/s².
func animate(delta: float, speed: float, turn_rate: float = 0.0, accel: float = 0.0) -> void:
	_time += delta
	_animate_blink(delta)
	var run := clampf((speed - 3.6) / 2.6, 0.0, 1.0)
	var t := _idle_pose(delta)
	if speed > 0.1 and not _sitting:
		_phase += TAU * delta * speed / lerpf(1.15, 1.6, run)
		_walk_pose(t, speed, run)
	if _sitting:
		_sit_pose(t)
	if _action != "":
		_action_pose(t, delta)
	# Lean into acceleration and round corners.
	t["body_roll"] += clampf(-turn_rate * 0.035 * minf(speed / 3.0, 1.0), -0.16, 0.16)
	t["body_pitch"] += clampf(accel * 0.012, -0.1, 0.12)
	t["head_yaw"] += clampf(turn_rate * 0.06, -0.3, 0.3)
	_apply(t, delta)


func _idle_pose(delta: float) -> Dictionary:
	# Now and then, glance one way and back.
	_glance_timer -= delta
	if _glance_timer <= 0.0:
		_glance = 0.0 if _glance != 0.0 else randf_range(-0.5, 0.5)
		_glance_timer = randf_range(1.2, 2.0) if _glance != 0.0 else randf_range(4.0, 9.0)
	return {
		"body_y": 0.0, "body_pitch": 0.0, "body_roll": 0.0, "body_yaw": 0.0,
		"squash": 1.0 + sin(_time * 2.2) * 0.012,
		"head_pitch": 0.0, "head_yaw": _glance, "head_roll": sin(_time * 0.9) * 0.025,
		"arm_l": 0.05, "arm_r": 0.05, "arm_l_out": 0.22, "arm_r_out": 0.22,
		"elbow_l": -0.15, "elbow_r": -0.15,
		"leg_l": 0.0, "leg_r": 0.0, "knee_l": 0.0, "knee_r": 0.0,
	}


func _walk_pose(t: Dictionary, speed: float, run: float) -> void:
	var s := sin(_phase)
	var c := cos(_phase)
	var leg_amp := lerpf(0.5, 0.85, run)
	var knee_amp := lerpf(0.75, 1.35, run)
	t["leg_l"] = -s * leg_amp
	t["leg_r"] = s * leg_amp
	# Knees lift as each leg swings forward.
	t["knee_l"] = maxf(0.0, c) * knee_amp + 0.06
	t["knee_r"] = maxf(0.0, -c) * knee_amp + 0.06
	var arm_amp := lerpf(0.45, 0.8, run)
	t["arm_l"] = s * arm_amp
	t["arm_r"] = -s * arm_amp
	t["elbow_l"] = -lerpf(0.3, 1.35, run) - maxf(0.0, -s) * 0.3
	t["elbow_r"] = -lerpf(0.3, 1.35, run) - maxf(0.0, s) * 0.3
	t["arm_l_out"] = 0.18
	t["arm_r_out"] = 0.18
	# Bob up as the legs pass, squash a touch as each foot lands.
	t["body_y"] = absf(c) * lerpf(0.035, 0.075, run)
	t["squash"] = 1.0 - (1.0 - absf(c)) * lerpf(0.02, 0.05, run)
	t["body_roll"] = s * 0.05
	t["body_yaw"] = s * 0.07
	t["body_pitch"] = lerpf(0.05, 0.22, run)
	t["head_pitch"] = -t["body_pitch"] * 0.6 + c * 0.02
	# A puff of dust on each footfall when running.
	if run > 0.5 and signf(c) != signf(_last_step):
		_puff(Vector3(P.LEG_X * signf(s), 0.05, 0.0))
	_last_step = c


func _sit_pose(t: Dictionary) -> void:
	t["leg_l"] = -1.45
	t["leg_r"] = -1.45
	t["knee_l"] = 1.4
	t["knee_r"] = 1.4
	t["arm_l"] = -0.35
	t["arm_r"] = -0.35
	t["elbow_l"] = -0.9
	t["elbow_r"] = -0.9
	t["arm_l_out"] = 0.15
	t["arm_r_out"] = 0.15
	t["body_pitch"] = -0.05


func _action_pose(t: Dictionary, delta: float) -> void:
	_action_t += delta / _action_length
	var a := clampf(_action_t, 0.0, 1.0)
	match _action:
		"chop":
			if a < 0.4:
				# Wind up: right arm back over the head, body twisting away.
				var w := ease(a / 0.4, 0.5)
				t["arm_r"] = lerpf(0.0, -2.7, w)
				t["elbow_r"] = lerpf(-0.2, -0.9, w)
				t["arm_l"] = lerpf(0.0, -1.2, w)
				t["body_yaw"] = 0.25 * w
				t["body_pitch"] = -0.08 * w
				t["squash"] = 1.0 - 0.04 * w
			elif a < 0.6:
				# Strike forward and down.
				var w := ease((a - 0.4) / 0.2, 0.3)
				t["arm_r"] = lerpf(-2.7, -0.85, w)
				t["elbow_r"] = lerpf(-0.9, -0.1, w)
				t["arm_l"] = lerpf(-1.2, -0.7, w)
				t["body_yaw"] = lerpf(0.25, -0.15, w)
				t["body_pitch"] = lerpf(-0.08, 0.22, w)
			else:
				var w := (a - 0.6) / 0.4
				t["arm_r"] = lerpf(-0.85, t["arm_r"], w)
				t["arm_l"] = lerpf(-0.7, t["arm_l"], w)
				t["body_pitch"] = lerpf(0.22, t["body_pitch"], w)
		"shake":
			var w := sin(a * PI)
			t["arm_l"] = -1.45 * w
			t["arm_r"] = -1.45 * w
			t["elbow_l"] = -0.25
			t["elbow_r"] = -0.25
			t["body_roll"] = sin(a * TAU * 3.0) * 0.08 * w
			t["body_pitch"] = 0.1 * w
		"pickup":
			var w := sin(a * PI)
			t["body_y"] = -0.1 * w
			t["body_pitch"] = 0.45 * w
			t["leg_l"] = -0.55 * w
			t["leg_r"] = -0.55 * w
			t["knee_l"] = 1.0 * w
			t["knee_r"] = 1.0 * w
			t["arm_r"] = -1.1 * w
			t["arm_l"] = -0.6 * w
			t["elbow_r"] = -0.2
		"cheer":
			var w := sin(minf(a * 1.4, 1.0) * PI * 0.5)
			t["arm_l"] = -2.8 * w
			t["arm_r"] = -2.8 * w
			t["arm_l_out"] = 0.45
			t["arm_r_out"] = 0.45
			t["elbow_l"] = -0.2
			t["elbow_r"] = -0.2
			t["body_y"] = maxf(0.0, sin(a * PI * 2.0)) * 0.12
			t["head_pitch"] = -0.15 * w
	if _action_t >= 1.0:
		if _action == "cheer" and _face:
			_face.set_shader_parameter("eye_style", Appearance.index_of(look, "eyes"))
		_action = ""


## Eases every joint towards its target and writes it to the pivots.
func _apply(t: Dictionary, delta: float) -> void:
	var fast := 1.0 - exp(-delta * 22.0)
	for key in t:
		_pose[key] = lerpf(_pose.get(key, t[key]), t[key], fast)
	_hips.position.y = _pose["body_y"]
	_waist.rotation = Vector3(_pose["body_pitch"], _pose["body_yaw"], _pose["body_roll"])
	_waist.scale = Vector3(1.0 + (1.0 - _pose["squash"]) * 0.5, _pose["squash"], 1.0 + (1.0 - _pose["squash"]) * 0.5)
	_head.rotation = Vector3(_pose["head_pitch"], _pose["head_yaw"], _pose["head_roll"])
	_arm_l.rotation = Vector3(_pose["arm_l"], 0.0, -_pose["arm_l_out"])
	_arm_r.rotation = Vector3(_pose["arm_r"], 0.0, _pose["arm_r_out"])
	_elbow_l.rotation.x = _pose["elbow_l"]
	_elbow_r.rotation.x = _pose["elbow_r"]
	_leg_l.rotation.x = _pose["leg_l"]
	_leg_r.rotation.x = _pose["leg_r"]
	_knee_l.rotation.x = _pose["knee_l"]
	_knee_r.rotation.x = _pose["knee_r"]


## A little dust cloud left behind at the feet.
func _puff(offset: Vector3) -> void:
	var parent := get_parent()
	if parent == null or not is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.12
	sphere.radial_segments = 8
	sphere.rings = 4
	mi.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.98, 0.92, 0.75)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(mi)
	mi.global_position = global_transform * offset
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.8, 0.45).from(Vector3.ONE * 0.5)
	tw.tween_property(mi, "position:y", mi.position.y + 0.15, 0.45)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(mi.queue_free)


func _animate_blink(delta: float) -> void:
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 1.0
		_blink_timer = randf_range(2.0, 5.0)
	if _blink > 0.0:
		_blink = maxf(0.0, _blink - delta / 0.14)
		_face.set_shader_parameter("blink", sin(_blink * PI))


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
