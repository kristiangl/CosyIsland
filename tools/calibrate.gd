extends Node3D
## Renders flat grey quads under the cel lighting and prints their pixel values, to
## check the lighting maths: lit should equal the palette colour, shadow = colour * tint.
##   xvfb-run godot --path . --rendering-driver opengl3 res://tools/calibrate.tscn -- --shadows


func _ready() -> void:
	RenderingServer.global_shader_parameter_set("cel_lit", Vector3(1, 1, 1))
	RenderingServer.global_shader_parameter_set("cel_shadow", Vector3(0.5, 0.5, 0.5))
	# Expect lit = 0.5 and away-facing = 0.25 (sRGB), with --shadows as in the game.
	RenderingServer.global_shader_parameter_set("curve_amount", 0.0)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-90, 0, 0)
	sun.shadow_enabled = Game.args.has("shadows")
	add_child(sun)
	for i in 2:
		var k := MeshKit.new()
		# Both quads face the camera; the second has normals pointing away from the sun.
		var n := Vector3.UP if i == 0 else Vector3.DOWN
		var c := Color(0.5, 0.5, 0.5, 0)
		var ids := [k.vertex(Vector3(-1, 0, -1), n, c), k.vertex(Vector3(1, 0, -1), n, c), k.vertex(Vector3(1, 0, 1), n, c), k.vertex(Vector3(-1, 0, 1), n, c)]
		k.quad(ids[0], ids[1], ids[2], ids[3], Vector3.UP)
		var mi := MeshInstance3D.new()
		mi.mesh = k.commit()
		mi.material_override = Models.material()
		mi.position = Vector3(-1.2 + i * 2.4, 0, 0)
		add_child(mi)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 6, 0.001)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	for f in 10:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	print("lit-facing: ", img.get_pixel(w / 2 - w / 8, h / 2), "  away-facing: ", img.get_pixel(w / 2 + w / 8, h / 2))
	get_tree().quit()
