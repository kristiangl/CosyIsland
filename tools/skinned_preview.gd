extends Node3D
## Shows a rigged glTF character (from assets/characters/src) lit like the island:
##   tools/screenshot_scene.sh out.png res://tools/skinned_preview.tscn --file=human.glb
##     [--anim=NAME --time=SECONDS] [--angles=0,35,90] [--textured (its own material)]


func _ready() -> void:
	RenderingServer.global_shader_parameter_set("curve_amount", 0.0)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("e8f2e0")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var path := ProjectSettings.globalize_path("res://assets/characters/src/" + Game.args.get("file", "human.glb"))
	var angles: PackedStringArray = Game.args.get("angles", "0,35,90").split(",")
	for i in angles.size():
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		doc.append_from_file(path, state)
		var scene := doc.generate_scene(state)
		add_child(scene)
		scene.position = Vector3((i - (angles.size() - 1) * 0.5) * 1.3, 0, 0)
		scene.rotation_degrees.y = float(angles[i])
		if not Game.args.has("textured"):
			for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
				mi.material_override = Models.material()
		var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false).pop_front()
		if player and Game.args.has("anim"):
			player.play(Game.args["anim"])
			player.seek(float(Game.args.get("time", "0.5")), true)
			player.pause()
	var cam := Camera3D.new()
	cam.fov = 30
	var centre := Vector3(0, 0.5, 0)
	var eye := centre + Vector3(0, 0.5, 1.0).normalized() * (2.0 + angles.size() * 1.0)
	cam.transform = Transform3D(Basis.looking_at(centre - eye), eye)
	add_child(cam)
	CameraRig.add_outline_pass(cam)
