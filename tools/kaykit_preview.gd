extends Node3D
## Shows KayKit characters straight from their glTF files (textures and all), posed by a
## KayKit animation, next to our own player for comparison:
##   tools/screenshot_scene.sh out.png res://tools/kaykit_preview.tscn --src=/path/to/KayKit
##     [--chars=path.glb,path.glb] (relative to --src) [--anim=Rig_Medium_Tools.glb:Chop]
##     [--t=0.4] (seconds into it) [--ours] [--angle=30]


func _ready() -> void:
	RenderingServer.global_shader_parameter_set("curve_amount", 0.0)
	RenderingServer.global_shader_parameter_set("cel_lit", Vector3(1.0, 0.99, 0.96))
	RenderingServer.global_shader_parameter_set("cel_shadow", Vector3(0.76, 0.73, 0.91))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("cfe8c4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55, 20, 0)
	add_child(sun)

	var src: String = Game.args.get("src", "")
	var chars: PackedStringArray = Game.args.get("chars", "").split(",", false)
	var models: Array[Node3D] = []
	for path in chars:
		var scene := load_glb(src.path_join(path))
		if scene:
			scene.scale = Vector3.ONE * float(Game.args.get("scale", "0.5"))
			models.append(scene)
	if Game.args.has("ours"):
		var me := CharacterModel.new(Appearance.DEFAULT)
		me.set_meta("ours", true)
		models.append(me)
	# --anims=file:name,file:name poses one model per animation instead.
	var anims: PackedStringArray = Game.args.get("anims", "").split(",", false)
	if Game.args.has("retarget"):
		# Our own character, posed by each clip (as exported to the game) through RigPose.
		RigPose.ready()
		for a in anims:
			var parts: PackedStringArray = a.split(":")
			var me := CharacterModel.new(Appearance.DEFAULT)
			add_child(me)
			var pose := {}
			RigPose.sample(parts[1], float(parts[2]) if parts.size() > 2 else 0.4, pose)
			RigPose.apply(me._rig, pose, CharacterParts.HIP_Y)
			remove_child(me)
			models.append(me)
	elif not anims.is_empty():
		var base := models[0]
		models.clear()
		for a in anims:
			var copy := load_glb(src.path_join(chars[0]))
			copy.scale = base.scale
			copy.set_meta("anim", a)
			models.append(copy)
	var anim: String = Game.args.get("anim", "")
	var library: AnimationLibrary = null
	var anim_name := ""
	if anim != "":
		var parts := anim.split(":")
		var anim_scene := load_glb(src.path_join("KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium").path_join(parts[0]))
		var player: AnimationPlayer = anim_scene.find_children("*", "AnimationPlayer", true, false)[0]
		library = player.get_animation_library("")
		anim_name = parts[1]
		print("Animations: ", library.get_animation_list())
	var spacing := float(Game.args.get("spacing", "1.3"))
	for i in models.size():
		var m := models[i]
		m.position.x = (i - (models.size() - 1) * 0.5) * spacing
		m.rotation_degrees.y = float(Game.args.get("angle", "25"))
		add_child(m)
		if m.has_meta("anim"):
			var parts: PackedStringArray = String(m.get_meta("anim")).split(":")
			var anim_scene := load_glb(src.path_join("KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium").path_join(parts[0]))
			var source: AnimationPlayer = anim_scene.find_children("*", "AnimationPlayer", true, false)[0]
			var ap := AnimationPlayer.new()
			m.add_child(ap)
			ap.root_node = ap.get_path_to(m)
			ap.add_animation_library("", source.get_animation_library(""))
			ap.play(parts[1])
			ap.seek(float(parts[2]) if parts.size() > 2 else 0.4, true)
			ap.pause()
		elif library and not m.has_meta("ours"):
			var ap := AnimationPlayer.new()
			m.add_child(ap)
			ap.root_node = ap.get_path_to(m)
			ap.add_animation_library("", library)
			ap.play(anim_name)
			ap.seek(float(Game.args.get("t", "0.4")), true)
			ap.pause()
	var cam := Camera3D.new()
	cam.fov = 30
	add_child(cam)
	cam.position = Vector3(0, 2.0, 6.0)
	cam.look_at(Vector3(0, 0.8, 0))


static func load_glb(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		push_error("Can't load " + path)
		return null
	return doc.generate_scene(state)
