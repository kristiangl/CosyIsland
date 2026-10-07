class_name CharacterModel
extends Node3D
## A modular chibi character built from an Appearance dictionary and rigged with simple
## pivots (body, head, shoulders, elbows, hips, knees). Animated in code: walk and run
## cycles, idle breathing and glances, blinking, and one-off actions. Faces +Z.

const P = preload("res://scripts/character/character_parts.gd")

## How far the light wraps round (see toon_light): faces stay mostly lit, bodies less so.
const FACE_WRAP := 0.5
const BODY_WRAP := 0.25

static var _flat: ShaderMaterial
var look: Dictionary = Appearance.DEFAULT.duplicate()
## Animal kinds, in the face shader's order (1 = cat).
const SPECIES := ["cat", "dog", "rabbit", "ferret", "mouse", "bird"]
## Animal characters: {"kind": one of SPECIES, "fur": Color, "fur2": Color (markings),
## "stripes": Color, "eyes": Color, "inner_ear": Color, "nose": Color, and for some kinds
## "short" (a British Shorthair cat), "lop" (rabbit), "beak", "crest" (bird)}. Empty for
## people.
var species: Dictionary = {}
## False for characters shown in menus, away from the island's world curvature.
var curved := true
## True in menus: lit with fixed daytime colours instead of the island's time of day.
var fixed_light := false

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
var _tail: Node3D
var _tool: MeshInstance3D
## True when the head is a generated model (assets/characters/heads/<kind>.res).
var _model_head := false
var _head_offset := Vector3.ZERO
## Use generated heads where they exist (off: the procedural heads throughout).
static var use_model_heads := true
static var _heads: Dictionary = {}
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
## KayKit clips (RigPose) over the hand-made walk: the clip playing, its time, and the
## one it's fading from; how much the clips show (0 while walking, 1 standing still).
var _clip := ""
var _clip_t := 0.0
var _last_clip := ""
var _last_clip_t := 0.0
var _fade := 1.0
var _layer := 0.0
var _rig: Array[Node3D] = []
var _sample := {}
var _sample_last := {}
## "fishing" or "sleeping": what the character is doing while standing (or lying) still.
var mode := ""

## How much thicker limbs and body are drawn than they're built (see _mesh).
const LEG_BULK := Vector3(1.2, 1.0, 1.15)
const ARM_BULK := Vector3(1.15, 1.0, 1.15)
const BODY_BULK := Vector3(1.08, 1.0, 1.08)

## How far apart a ferret's (generated head's) eyes are, wider than most.
const FERRET_EYE_X := 0.14

## Actions: KayKit clip, the stretch of it used (seconds), and how long it plays here,
## so a swing lands when the game expects it to.
const ACTIONS := {
	"chop": ["Chop", 0.25, 1.05, 0.42],
	"dig": ["Dig", 0.4, 1.3, 0.42],
	"mine": ["Pickaxe", 0.47, 1.37, 0.42],
	# Brought down over the bug, like the axe's chop.
	"net": ["Chop", 0.36, 1.16, 0.42],
	"shake": ["Interact", 0.0, 1.3, 0.5],
	"pickup": ["PickUp", 0.1, 1.2, 0.5],
	"cheer": ["Cheering", 0.0, 1.67, 1.3],
	"eat": ["Use_Item", 0.0, 1.6, 1.6],
	"craft": ["Hammering", 0.0, 2.67, 1.5],
	"cast": ["Fishing_Cast", 0.6, 1.6, 0.5],
	"reel": ["Fishing_Catch", 0.0, 1.6, 0.6],
	"wave": ["Waving", 0.0, 2.13, 1.4],
}

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
	# The tool hand is the character's right (it faces +Z, so that's -X).
	_hand_r = _pivot("Hand", Vector3(0, -P.ARM_LOWER, 0), _elbow_l)
	_rig = [_hips, _waist, _head, _leg_l, _knee_l, _leg_r, _knee_r, _arm_l, _elbow_l, _arm_r, _elbow_r, _hand_r]
	_pose.clear()
	_tool = MeshInstance3D.new()
	_tool.material_override = Models.material()
	_tool.transform = RigPose.slot()
	_hand_r.add_child(_tool)
	set_tool(_tool_id)

	var animal := not species.is_empty()
	var skin_colour: Color = species["fur"] if animal else Appearance.color(look, "skin")
	var skin := _cloth(skin_colour)
	var top_mat := _cloth(Appearance.color(look, "top_color"), Appearance.color(look, "top_color2"),
		Appearance.index_of(look, "top_pattern"))
	var bottom_mat := _cloth(Appearance.color(look, "bottom_color"), Appearance.color(look, "bottom_color").lightened(0.5))
	var shoe_mat := _cloth(Appearance.color(look, "shoe_color"), Color("f7f4ee"))
	var hair_colour := Appearance.color(look, "hair_color")
	var hair_mat := _cloth(hair_colour, hair_colour.darkened(0.25))
	hair_mat.set_shader_parameter("shine", 0.7)

	# Head, face and everything on it.
	_face = ShaderMaterial.new()
	_face.shader = _shader("face")
	_face.set_shader_parameter("skin", skin_colour)
	_face.set_shader_parameter("light_wrap", FACE_WRAP)
	_face.set_shader_parameter("curved", curved)
	_face.set_shader_parameter("fixed_tints", fixed_light)
	_face.set_shader_parameter("eye_colour", Appearance.color(look, "eye_color"))
	_face.set_shader_parameter("brow_colour", hair_colour.darkened(0.35))
	_face.set_shader_parameter("eye_style", Appearance.index_of(look, "eyes"))
	_face.set_shader_parameter("brow_style", Appearance.index_of(look, "brows"))
	_face.set_shader_parameter("mouth_style", Appearance.index_of(look, "mouth"))
	_face.set_shader_parameter("cheek_style", Appearance.index_of(look, "cheeks"))
	_apply_face_adjustments()
	var head_parent := _head
	_tail = null
	# Body and limbs.
	_mesh(P.torso_skin(), skin, _body)
	var barefoot: bool = look["shoes"] == "none" or Appearance.option(look, "shoes").get("open", false)
	var legs := P.leg_skin(barefoot)
	var arms := P.arm_skin()
	for side in [[_leg_l, _knee_l], [_leg_r, _knee_r]]:
		_mesh(legs["upper"], skin, side[0])
		_mesh(legs["lower"], skin, side[1])
		if look["shoes"] != "none":
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
	# A generated head where there's one for this kind of animal (ears and all).
	var head_key := head_model_for(species) if animal and use_model_heads else ""
	_model_head = head_key != ""
	var head_mesh := _mesh(model_head(head_key) if _model_head else (AnimalParts.head() if animal else P.head()), _face, _head)
	# A generated head sits a little lower or higher so its chin meets the body; what's
	# worn on it (glasses, a ruff) moves with it.
	_head_offset = model_head(head_key).get_meta("offset", Vector3.ZERO) if _model_head else Vector3.ZERO
	head_mesh.position = P.HEAD_CENTRE + _head_offset
	# Animals have fur instead of hair, and their ears get in the way of hats.
	var hat_style: String = "none" if animal else look["hat"]
	if animal:
		_build_animal()
	else:
		var covers: String = Appearance.option(look, "hat").get("covers", "")
		var hair_mesh := _mesh(P.hair(look["hair"], covers == "full", covers == "top"), hair_mat, head_parent)
		hair_mesh.position = P.HEAD_CENTRE
		# Hair, hats and glasses don't cast shadows, so faces stay bright under a brim.
		hair_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if hat_style != "none":
		var hat_mat := _cloth(Appearance.color(look, "hat_color"), Color("fff4e0") if hat_style != "flower_crown" else Color("f6d36b"))
		var hat_mesh := _mesh(P.hat(hat_style), hat_mat, head_parent)
		hat_mesh.position = P.HEAD_CENTRE
		# Some hats can be worn different ways (a bow on either side, a cap backwards).
		var ways := Appearance.hat_positions(look)
		if not ways.is_empty():
			var rot: Array = ways[clampi(int(look.get("hat_pos", 0)), 0, ways.size() - 1)]["rot"]
			hat_mesh.rotation_degrees = Vector3(rot[0], rot[1], rot[2])
		hat_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if look.get("hair_flower", "") != "":
		# Tucked in above the left ear (an animal's, in front of it).
		var flower := MeshInstance3D.new()
		flower.mesh = Models.get_mesh("hairflower:" + look["hair_flower"])
		flower.material_override = Models.material() if curved else _flat_prop()
		var out := Vector3(0.68, 0.5, 0.55).normalized() if not animal else Vector3(0.5, 0.62, 0.6).normalized()
		flower.position = P.HEAD_CENTRE + _head_offset + out * 0.41
		flower.basis = Basis(Quaternion(Vector3.UP, out)).scaled(Vector3.ONE * (1.5 if not animal else 1.1))
		flower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head_parent.add_child(flower)
	if look["glasses"] != "none":
		var frame := _cloth(Color("4a4550"), Color("3a3a4a") if look["glasses"] == "sunnies" else Color("4a4550"))
		var glasses_mesh := _mesh(P.glasses(look["glasses"]), frame, head_parent)
		# Glasses follow the eyes: their height and spacing, plus their own nudges.
		var size := 1.0 + int(look.get("glasses_size", 0)) * 0.06
		var gap := 1.0 + int(look.get("eye_gap", 0)) * 0.08
		# Ferrets' eyes are set wider (see _build_animal).
		if _model_head and species.get("kind", "") == "ferret":
			gap *= FERRET_EYE_X / 0.125
		glasses_mesh.scale = Vector3(size * gap, size, 1.0)
		glasses_mesh.position = P.HEAD_CENTRE + _head_offset + Vector3(0, (int(look.get("eye_y", 0)) + int(look.get("glasses_y", 0))) * 0.01, 0)
		if _model_head:
			# Generated heads have their eyes a little higher (at 0, not -0.035).
			glasses_mesh.position.y += 0.035
		glasses_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Where the face features sit and how big they are, from the look's adjustments.
func _apply_face_adjustments() -> void:
	var adj := func(key: String) -> float: return float(look.get(key, 0))
	var eye_scale: float = 1.0 + adj.call("eye_size") * 0.07
	_face.set_shader_parameter("eye_x", 0.125 + adj.call("eye_gap") * 0.01)
	_face.set_shader_parameter("eye_y", -0.035 + adj.call("eye_y") * 0.01)
	_face.set_shader_parameter("eye_scale", eye_scale)
	_face.set_shader_parameter("eye_tilt", adj.call("eye_tilt") * 0.07)
	_face.set_shader_parameter("brow_y", 0.085 + (eye_scale - 1.0) * 0.06 + adj.call("brow_y") * 0.008)
	_face.set_shader_parameter("brow_x", adj.call("brow_gap") * 0.008)
	_face.set_shader_parameter("brow_tilt", adj.call("brow_tilt") * 0.1)
	_face.set_shader_parameter("mouth_y", -0.13 + adj.call("mouth_y") * 0.009)
	_face.set_shader_parameter("mouth_scale", 1.0 + adj.call("mouth_size") * 0.1)
	_face.set_shader_parameter("nose_style", Appearance.index_of(look, "nose"))
	_face.set_shader_parameter("nose_y", -0.085 + adj.call("nose_y") * 0.008)
	_face.set_shader_parameter("nose_scale", 1.0 + adj.call("nose_size") * 0.12)
	_face.set_shader_parameter("cheek_y", -0.11 + adj.call("cheek_y") * 0.01)


## Ears, tail, snout, beak or ruff, and the face shader's fur markings.
func _build_animal() -> void:
	var kind: String = species["kind"]
	var base := _model_head
	var fur: Color = species["fur"]
	var fur2: Color = species.get("fur2", fur)
	var fur3: Color = species.get("stripes", fur2)
	_face.set_shader_parameter("species", SPECIES.find(kind) + 1)
	_face.set_shader_parameter("fur_b", fur2)
	_face.set_shader_parameter("fur_c", fur3)
	_face.set_shader_parameter("cat_blaze", species.get("blaze", false))
	_face.set_shader_parameter("cactus", species.get("cactus", false))
	_face.set_shader_parameter("eye_colour", species.get("eyes", Color("6a4430")))
	_face.set_shader_parameter("brow_style", 0)
	_face.set_shader_parameter("nose_colour", species.get("nose", Color("d98f98")))
	_face.set_shader_parameter("whisker_colour", fur2.lightened(0.45) if fur.get_luminance() < 0.4 else fur.darkened(0.45))
	# Where the eyes and mouth sit on each kind of face.
	var face: Array = {"cat": [-0.02, -0.145], "dog": [0.0, -0.2], "rabbit": [-0.01, -0.165],
		"ferret": [-0.03, -0.2], "mouse": [-0.01, -0.21], "bird": [0.01, -0.2]}[kind]
	_face.set_shader_parameter("eye_y", face[0])
	_face.set_shader_parameter("mouth_y", face[1])
	if base:
		# A generated head has its eye line at 0 and says where its muzzle and beak are.
		var head := model_head(head_model_for(species))
		_face.set_shader_parameter("face_lift", -face[0])
		_face.set_shader_parameter("mouth_y", float(head.get_meta("mouth", face[1])) + face[0])
		# The insides of standing ears.
		if head.has_meta("ear_map"):
			_face.set_shader_parameter("ear_map", head.get_meta("ear_map"))
			_face.set_shader_parameter("ear_rect", head.get_meta("ear_rect"))
			_face.set_shader_parameter("inner_ear", species.get("inner_ear", Color("e3a5aa")))
		# Ferrets have big round eyes, set wide.
		if kind == "ferret":
			_face.set_shader_parameter("eye_scale", 1.35)
			_face.set_shader_parameter("eye_x", FERRET_EYE_X)
		# Snouts get a nose on the tip and the mouth a little lower, under it.
		var nose: float = {"dog": 1.3, "ferret": 0.7, "mouse": 0.65}.get(kind, 0.0)
		if nose > 0.0:
			_face.set_shader_parameter("snout_nose", nose)
			_face.set_shader_parameter("mouth_y", float(head.get_meta("mouth", face[1])) + face[0] - 0.025)
		if kind == "ferret":
			# A ferret's muzzle tip is low on its head; its nose sits just under the eyes.
			_face.set_shader_parameter("mouth_y", face[0] - 0.125)
		if kind == "bird":
			_face.set_shader_parameter("beak_z", head.get_meta("beak", 10.0))
			_face.set_shader_parameter("beak_colour", species.get("beak", Color("e8a040")))
	if kind != "bird" and not base:
		var ear_colour: Color = fur2 if kind == "dog" else fur
		var ears := _mesh(AnimalParts.ears(kind, species.get("lop", false), species.get("short", false)), _cloth(ear_colour, species.get("inner_ear", Color("e3a5aa"))), _head)
		ears.position = P.HEAD_CENTRE
	match kind:
		"cat":
			if species.get("short", false):
				# A British Shorthair: no ruff, and a round, chubby-cheeked face.
				for child in _head.get_children():
					if child is MeshInstance3D and child.material_override == _face:
						child.scale = Vector3(1.1, 0.98, 1.03)
			elif not base:
				# (A generated head doesn't need the procedural ruff.)
				var ruff := _mesh(AnimalParts.ruff(), _cloth(fur, fur2), _head)
				ruff.position = P.HEAD_CENTRE + _head_offset
		"dog", "ferret", "mouse" when not base:
			var snout := _mesh(AnimalParts.snout(kind), _cloth(fur if kind == "dog" else fur2, species.get("nose", Color("3a3236"))), _head)
			snout.position = P.HEAD_CENTRE
		"bird" when not base:
			var beak := _mesh(AnimalParts.beak(), _cloth(species.get("beak", Color("f2b14a")), species.get("crest", fur3)), _head)
			beak.position = P.HEAD_CENTRE
	_tail = _pivot("Tail", Vector3(0, P.HIP_Y - 0.02, -0.14), _hips)
	# Second tail colour: a rabbit's pom-pom, a ferret's dark tail, a mouse's pink one.
	var tail2: Color = {"ferret": fur3, "mouse": species.get("inner_ear", Color("e3a5aa")), "bird": fur3}.get(kind, fur2)
	_mesh(AnimalParts.tail(kind), _cloth(fur, tail2), _tail)


func set_look(appearance: Dictionary) -> void:
	look = Appearance.sanitise(appearance)
	if is_inside_tree():
		rebuild()


func set_tool(item_id: String) -> void:
	_tool_id = item_id
	if _tool:
		# Landscaping tools are model keys of their own ("landscape:cliff").
		_tool.mesh = null if item_id == "" else Models.get_mesh(item_id if ":" in item_id else "tool:" + item_id)


## Plays a one-off action from ACTIONS: "chop", "dig", "net", "shake", "pickup",
## "cheer", "eat", "craft", "cast", "reel" or "wave".
func play(action: String) -> void:
	_action = action
	_action_t = 0.0
	_action_length = ACTIONS[action][3] if ACTIONS.has(action) else 0.4
	if action == "cheer" and _face:
		_face.set_shader_parameter("eye_style", 2)


## Holds something in the right hand for a while (a fruit being eaten, say), then goes
## back to the tool.
func hold(mesh: Mesh, seconds: float, size: float = 0.55) -> void:
	if _tool == null:
		return
	_tool.mesh = mesh
	_tool.rotation_degrees = Vector3.ZERO
	_tool.scale = Vector3.ONE * size
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(_tool):
		_tool.transform = RigPose.slot()
		set_tool(_tool_id)


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
	var moving := speed > 0.1 and not _sitting and mode == ""
	if moving:
		_phase += TAU * delta * speed / lerpf(1.15, 1.6, run)
		_walk_pose(t, speed, run)
	# Lean into acceleration and round corners.
	t["body_roll"] += clampf(-turn_rate * 0.035 * minf(speed / 3.0, 1.0), -0.16, 0.16)
	t["body_pitch"] += clampf(accel * 0.012, -0.1, 0.12)
	t["head_yaw"] += clampf(turn_rate * 0.06, -0.3, 0.3)
	_apply(t, delta)
	_play_clips(delta, moving)


## The KayKit layer: an action if one's playing, else sitting, lying, fishing or idling,
## faded in over the walk when standing still.
func _play_clips(delta: float, moving: bool) -> void:
	if not RigPose.ready():
		_action = ""
		return
	var clip := "Idle_A"
	var time := _time
	var loop := true
	if _action != "":
		var spec: Array = ACTIONS.get(_action, ACTIONS["chop"])
		_action_t += delta / _action_length
		clip = spec[0]
		time = lerpf(spec[1], spec[2], clampf(_action_t, 0.0, 1.0))
		loop = false
		if _action_t >= 1.0:
			if _action in ["cheer", "eat"] and _face:
				_face.set_shader_parameter("eye_style", Appearance.index_of(look, "eyes"))
			_action = ""
	elif mode == "sleeping":
		clip = "Lie_Idle"
	elif _sitting:
		clip = "Sit_Chair_Idle"
	elif mode == "fishing":
		clip = "Fishing_Idle"
	if clip != _clip:
		_last_clip = _clip
		_last_clip_t = _clip_t
		_fade = 0.0 if _clip != "" else 1.0
		_clip = clip
	_fade = minf(1.0, _fade + delta / 0.15)
	var length := RigPose.length(clip)
	_clip_t = fposmod(time, length) if loop else time
	var want := 0.0 if moving and _action == "" else 1.0
	_layer = move_toward(_layer, want, delta / 0.12)
	if _layer <= 0.0:
		return
	RigPose.sample(_clip, _clip_t, _sample)
	if _fade < 1.0 and _last_clip != "":
		RigPose.sample(_last_clip, _last_clip_t, _sample_last)
		RigPose.blend(_sample_last, _sample, _fade)
		RigPose.apply(_rig, _sample_last, P.HIP_Y, 0.0 if _sitting else 1.0, _layer)
	else:
		RigPose.apply(_rig, _sample, P.HIP_Y, 0.0 if _sitting else 1.0, _layer)
	# Clips don't squash; the walk does.
	_waist.scale = _waist.scale.lerp(Vector3.ONE, _layer)
	# The hand-made glance on top.
	_head.rotate_object_local(Vector3.UP, _pose.get("head_yaw", 0.0) * _layer)


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


## Eases every joint towards its target and writes it to the pivots.
func _apply(t: Dictionary, delta: float) -> void:
	var fast := 1.0 - exp(-delta * 22.0)
	for key in t:
		_pose[key] = lerpf(_pose.get(key, t[key]), t[key], fast)
	# Every joint in full, so nothing a clip left behind lingers.
	_hips.position = Vector3(0, _pose["body_y"], 0)
	_hips.rotation = Vector3.ZERO
	_hand_r.rotation = Vector3.ZERO
	_waist.rotation = Vector3(_pose["body_pitch"], _pose["body_yaw"], _pose["body_roll"])
	_waist.scale = Vector3(1.0 + (1.0 - _pose["squash"]) * 0.5, _pose["squash"], 1.0 + (1.0 - _pose["squash"]) * 0.5)
	_head.rotation = Vector3(_pose["head_pitch"], _pose["head_yaw"], _pose["head_roll"])
	_arm_l.rotation = Vector3(_pose["arm_l"], 0.0, -_pose["arm_l_out"])
	_arm_r.rotation = Vector3(_pose["arm_r"], 0.0, _pose["arm_r_out"])
	_elbow_l.rotation = Vector3(_pose["elbow_l"], 0, 0)
	_elbow_r.rotation = Vector3(_pose["elbow_r"], 0, 0)
	_leg_l.rotation = Vector3(_pose["leg_l"], 0, 0)
	_leg_r.rotation = Vector3(_pose["leg_r"], 0, 0)
	_knee_l.rotation = Vector3(_pose["knee_l"], 0, 0)
	_knee_r.rotation = Vector3(_pose["knee_r"], 0, 0)
	if _tail:
		# Dogs wag; rabbits twitch; the rest sway slowly.
		var wag: Array = {"dog": [10.0, 0.35], "rabbit": [6.0, 0.12], "bird": [3.0, 0.1]}.get(species["kind"], [1.7, 0.2])
		_tail.rotation = Vector3(-_pose["body_pitch"] * 0.5, 0.0, sin(_time * float(wag[0])) * float(wag[1]))


## A little dust cloud left behind at the feet.
func _puff(offset: Vector3) -> void:
	if not is_inside_tree():
		return
	Effects.burst("step", global_transform * offset)

func _animate_blink(delta: float) -> void:
	if _tool:
		_tool.visible = mode != "sleeping"
	if mode == "sleeping":
		# Eyes shut, fast asleep.
		_face.set_shader_parameter("blink", 1.0)
		_blink = 0.0
		_blink_timer = 1.0
		return
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
	# Sturdy, KayKit-ish limbs and body: everything on them (skin, sleeves, trouser
	# legs, shoes) thickened together so clothes still fit.
	if parent in [_leg_l, _leg_r, _knee_l, _knee_r]:
		mi.scale = LEG_BULK
	elif parent in [_arm_l, _arm_r, _elbow_l, _elbow_r]:
		mi.scale = ARM_BULK
	elif parent == _body:
		mi.scale = BODY_BULK
	parent.add_child(mi)
	return mi


## The generated head an animal wears ("" for none): its own "head" if it names one,
## else its kind with "_short" (British Shorthair cats) or "_lop" (lop ears), else just
## its kind, whichever has a model.
static func head_model_for(animal: Dictionary) -> String:
	var kind: String = animal.get("kind", "")
	var options: Array[String] = []
	if animal.has("head"):
		options.append(animal["head"])
	if animal.get("short", false):
		options.append(kind + "_short")
	if animal.get("lop", false):
		options.append(kind + "_lop")
	options.append(kind)
	for key in options:
		if has_model_head(key):
			return key
	return ""


## Whether there's a generated head by this name (assets/characters/heads/).
static func has_model_head(kind: String) -> bool:
	return _heads.has(kind) or ResourceLoader.exists("res://assets/characters/heads/%s.res" % kind)


## The generated head for this kind of animal (see tools/head_import.gd).
static func model_head(kind: String) -> ArrayMesh:
	if not _heads.has(kind):
		_heads[kind] = load("res://assets/characters/heads/%s.res" % kind)
	return _heads[kind]


func _cloth(a: Color, b: Color = Color.WHITE, pattern: int = 0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader("cloth")
	mat.set_shader_parameter("colour_a", a)
	mat.set_shader_parameter("colour_b", b)
	mat.set_shader_parameter("pattern", pattern)
	mat.set_shader_parameter("light_wrap", BODY_WRAP)
	mat.set_shader_parameter("curved", curved)
	mat.set_shader_parameter("fixed_tints", fixed_light)
	return mat


## The prop material for things worn outside the island (menus), with no world curve.
static func _flat_prop() -> ShaderMaterial:
	if _flat == null:
		_flat = Models.material().duplicate()
		_flat.set_shader_parameter("curved", false)
	return _flat


static func _shader(shader_name: String) -> Shader:
	if not _shaders.has(shader_name):
		_shaders[shader_name] = load("res://shaders/%s.gdshader" % shader_name)
	return _shaders[shader_name]
