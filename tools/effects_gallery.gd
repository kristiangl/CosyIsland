extends Node3D
## Every particle effect on one stage, for checking the art:
##   tools/screenshot_scene.sh out.png res://tools/effects_gallery.tscn [--night] [--frames=N]
## Back row: a campfire, candles and lanterns with their own effects. Middle row: the
## one-off bursts, fired again every second. Front: the ambient effects.


func _ready() -> void:
	var night := Game.args.has("night")
	RenderingServer.global_shader_parameter_set("curve_amount", 0.0)
	RenderingServer.global_shader_parameter_set("cel_lit", Vector3(0.64, 0.68, 0.88) if night else Vector3(1.0, 0.99, 0.96))
	RenderingServer.global_shader_parameter_set("cel_shadow", Vector3(0.42, 0.45, 0.66) if night else Vector3(0.76, 0.73, 0.91))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2d3557") if night else Color("cfe8c4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55, 20, 0)
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16, 10)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("4f6b5a") if night else Color("a6d585")
	ground.material_override = ground_mat
	ground.position = Vector3(0, 0, 1)
	add_child(ground)

	var row := ["campfire", "candle_set", "stone_lantern", "garden_lantern", "house"]
	for i in row.size():
		var id: String = row[i]
		var node := Node3D.new()
		node.position = Vector3((i - 2) * 2.4, 0, -1.5)
		add_child(node)
		var mi := MeshInstance3D.new()
		mi.mesh = Models.get_mesh(ItemDB.placeable(id)["model"])
		Models.dress(mi, Models.material())
		node.add_child(mi)
		if id == "house":
			node.scale = Vector3.ONE * 0.6
		for fx: Dictionary in ItemDB.placeable(id).get("effects", []):
			var e := Effects.emitter(fx["kind"])
			e.position = Vector3(fx["at"][0], fx["at"][1], fx["at"][2])
			e.emitting = true
			node.add_child(e)

	var bursts := ["sparkle", "confetti", "leaves", "chips", "sparks", "dust", "hearts", "crumbs", "splash", "zzz"]
	for i in bursts.size():
		var at := Vector3((i - 4.5) * 1.3, 0.6, 1.2)
		var label := Label3D.new()
		label.text = bursts[i]
		label.font_size = 40
		label.position = at + Vector3(0, -0.5, 0.4)
		add_child(label)
		_repeat(bursts[i], at, i * 0.07)
	for kind: String in (["fireflies", "spores", "moss_glow"] if night else ["petals", "motes"]):
		var e := Effects.emitter(kind)
		e.position = Vector3(0, 0.8, 3.0)
		e.emitting = true
		e.preprocess = 4.0
		add_child(e)

	var cam := Camera3D.new()
	cam.fov = 40
	var eye := Vector3(0, 6.5, 9.5)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.3, 0.5) - eye), eye)
	add_child(cam)
	CameraRig.add_outline_pass(cam)


func _repeat(kind: String, at: Vector3, delay: float) -> void:
	await get_tree().create_timer(0.5 + delay).timeout
	while is_inside_tree():
		Effects.burst(kind, at, self)
		await get_tree().create_timer(1.0).timeout
