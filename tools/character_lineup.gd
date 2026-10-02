extends Node3D
## Renders a row of characters for checking the character art:
##   tools/screenshot_scene.sh out.png res://tools/character_lineup.tscn [--seed=N] [--angle=DEG]
##     [--vary=KEY] [--base=key:id,key:id]
## Without --vary: the --base look (default look if none) and five random ones.
## With --vary: one character per option of KEY, all on the --base look.


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Game.args.get("seed", "1"))
	RenderingServer.global_shader_parameter_set("curve_amount", 0.0)
	RenderingServer.global_shader_parameter_set("cel_lit", Vector3(1.0, 0.99, 0.96))
	RenderingServer.global_shader_parameter_set("cel_shadow", Vector3(0.76, 0.73, 0.91))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("e9f3e2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, 25, 0)
	add_child(sun)
	var looks: Array[Dictionary] = []
	var base := Appearance.DEFAULT.duplicate()
	for pair in Game.args.get("base", "").split(",", false):
		var kv: PackedStringArray = pair.split(":")
		base[kv[0]] = kv[1]
	if Game.args.has("vary"):
		# One character per option of the given key, on the --base look.
		for opt in Appearance.options(Game.args["vary"]):
			var look := base.duplicate()
			look[Game.args["vary"]] = opt["id"]
			looks.append(look)
	else:
		looks.append(base)
		for i in 5:
			looks.append(Appearance.random(rng))
	var count := looks.size()
	var spacing := 1.1 if count <= 6 else 6.6 / count
	var angle := deg_to_rad(float(Game.args.get("angle", "0")))
	for i in count:
		var c := CharacterModel.new(looks[i])
		c.position = Vector3((i - (count - 1) * 0.5) * spacing, 0, 0)
		c.rotation.y = angle
		add_child(c)
	var cam := CameraRig.new()
	add_child(cam)
	cam.set_process(false)
	cam.camera.fov = 30
	cam.camera.position = Vector3(0, 2.2, 7.2)
	cam.camera.look_at(Vector3(0, 0.75, 0))
