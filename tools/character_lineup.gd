extends Node3D
## Renders a row of characters for checking the character art:
##   tools/screenshot_scene.sh out.png res://tools/character_lineup.tscn [--seed=N] [--angle=DEG]
##     [--vary=KEY [--only=id,id]] [--base=key:id,key:id] [--npcs] [--close]
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
	if Game.args.has("poses"):
		_pose_sheet(base)
		return
	if Game.args.has("npcs"):
		# The island's characters from the front, three-quarters and behind.
		var spots := [[-2.6, 0.0], [-1.5, 35.0], [-0.5, 180.0], [0.6, 0.0], [1.7, -35.0], [2.7, 180.0]]
		for i in spots.size():
			var m := NpcData.model("poppy" if i < 3 else "lucy")
			m.position.x = spots[i][0]
			m.rotation.y = deg_to_rad(spots[i][1])
			add_child(m)
		_add_camera()
		return
	if Game.args.has("vary"):
		# One character per option of the given key, on the --base look.
		var only: PackedStringArray = Game.args.get("only", "").split(",", false)
		for opt in Appearance.options(Game.args["vary"]):
			if not only.is_empty() and not opt["id"] in only:
				continue
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
	_add_camera()


func _add_camera() -> void:
	var cam := CameraRig.new()
	add_child(cam)
	cam.set_process(false)
	cam.camera.fov = 30
	cam.camera.position = Vector3(0, 2.2, 7.2)
	cam.camera.look_at(Vector3(0, 0.75, 0))
	if Game.args.has("close"):
		# Close and from above, like the character creator, for checking clothes.
		cam.camera.position = Vector3(0, 2.4, 4.6)
		cam.camera.look_at(Vector3(0, 0.45, 0))


## One character per pose, frozen part-way through: idle, walk, run, chop, pickup, sit,
## cheer, shake. Each is stepped with fixed time steps to the interesting moment.
func _pose_sheet(look: Dictionary) -> void:
	var poses := [["idle", 0.0, 0.5], ["walk", 3.4, 0.33], ["run", 6.4, 0.3], ["chop", 0.0, 0.17],
		["pickup", 0.0, 0.17], ["sit", 0.0, 0.5], ["cheer", 0.0, 0.35], ["shake", 0.0, 0.2], ["eat", 0.0, 0.55], ["craft", 0.0, 0.42]]
	var spacing := minf(0.85, 7.0 / poses.size())
	for i in poses.size():
		var c := CharacterModel.new(look)
		c.position = Vector3((i - (poses.size() - 1) * 0.5) * spacing, 0, 0)
		c.rotation.y = deg_to_rad(float(Game.args.get("angle", "35")))
		add_child(c)
		var pose: String = poses[i][0]
		var speed: float = poses[i][1]
		var time: float = poses[i][2]
		if pose in ["chop", "pickup", "cheer", "shake", "eat", "craft"]:
			c.play(pose)
		if pose == "sit":
			c.set_sitting(true)
			c.position.y = 0.12
		var steps := int(time / 0.01)
		for s in steps:
			c.animate(0.01, speed)
	_add_camera()
