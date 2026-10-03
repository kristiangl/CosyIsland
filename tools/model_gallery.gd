extends Node3D
## Shows every furniture model (or every item drop with --drops) in a grid, lit like the
## island, for checking the art:
##   tools/screenshot_scene.sh out.png res://tools/model_gallery.tscn [--drops] [--only=id,id]
##     [--keys=model_key,model_key]  (any Models key, e.g. tree:0,fruit_tree:1:apple:3)
##     [--series=meadow [--variant=sage]]  (one furniture series)  [--spacing=0.5]


func _ready() -> void:
	RenderingServer.global_shader_parameter_set("curve_amount", 0.0)
	RenderingServer.global_shader_parameter_set("cel_lit", Vector3(1.0, 0.99, 0.96))
	RenderingServer.global_shader_parameter_set("cel_shadow", Vector3(0.76, 0.73, 0.91))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("cfe8c4")
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

	var keys: Array[String] = []
	for id in ItemDB.items:
		var def := ItemDB.get_item(id)
		if Game.args.has("drops"):
			if def.get("category", "") in ["material", "fruit", "currency", "bottle", "interior"]:
				keys.append("drop:" + id)
		elif def.get("category", "") == "furniture":
			keys.append(def["placeable"]["model"])
	if Game.args.has("keys"):
		keys.assign(Game.args["keys"].split(","))
	elif Game.args.has("only"):
		keys.clear()
		for id in Game.args["only"].split(","):
			keys.append(ItemDB.placeable(id).get("model", "furniture:" + id))
	elif Game.args.has("series"):
		# One series: every piece in the first variant, or the one given (--variant=sage).
		keys.clear()
		var data: Dictionary = ItemDB.series[Game.args["series"]]
		var variant: String = Game.args.get("variant", data["variants"][0]["id"])
		for piece: Dictionary in data["pieces"]:
			keys.append("series:%s_%s" % [piece["id"], variant])
	var columns := mini(6, keys.size())
	var spacing := float(Game.args.get("spacing", 2.2 if not Game.args.has("drops") else 0.9))
	for i in keys.size():
		var mi := MeshInstance3D.new()
		mi.mesh = Models.get_mesh(keys[i])
		Models.dress(mi, Models.material())
		mi.position = Vector3((i % columns - (columns - 1) * 0.5) * spacing, 0, (i / columns) * spacing)
		add_child(mi)
	var rows := ceili(keys.size() / float(columns))
	var cam := Camera3D.new()
	cam.fov = 35
	var centre := Vector3(0, 0.4, (rows - 1) * spacing * 0.5)
	var eye := centre + Vector3(0, 1.0, 1.15).normalized() * spacing * columns * 1.0
	cam.transform = Transform3D(Basis.looking_at(centre - eye), eye)
	add_child(cam)
	CameraRig.add_outline_pass(cam)
