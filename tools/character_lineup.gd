extends Node3D
## Renders a row of characters for checking the character art:
##   tools/screenshot_scene.sh out.png res://tools/character_lineup.tscn [--seed=N] [--angle=DEG]
## The first character is the default look; the rest are random.


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
	var count := 6
	var angle := deg_to_rad(float(Game.args.get("angle", "0")))
	for i in count:
		var look := Appearance.DEFAULT.duplicate() if i == 0 else Appearance.random(rng)
		var c := CharacterModel.new(look)
		c.position = Vector3((i - (count - 1) * 0.5) * 1.1, 0, 0)
		c.rotation.y = angle
		add_child(c)
	var cam := CameraRig.new()
	add_child(cam)
	cam.set_process(false)
	cam.camera.fov = 30
	cam.camera.position = Vector3(0, 2.2, 7.2)
	cam.camera.look_at(Vector3(0, 0.75, 0))
