class_name TitleBackdrop
extends Node3D
## Behind the title screen: an island from the game seen from out at sea, with the
## water close by and the island on the horizon. It's the island of the file played
## last (as it was saved), or a fresh one when there are no files yet.

## The island shown when there are no files.
const DEFAULT_SEED := 7
## Mid-morning: a blue sky and the sun behind the camera.
const HOUR := 10.0

var world: World
var day_night: DayNight
var camera: Camera3D
var _time := 0.0
var _base := Vector3.ZERO
var _look := Vector3.ZERO


func build(saved: Dictionary) -> void:
	var seed_value := int(saved.get("seed", DEFAULT_SEED))
	var gen := int(saved.get("gen", 1)) if saved.has("seed") else IslandGenerator.VERSION
	var data := IslandGenerator.generate(seed_value, IslandGenerator.WIDTH, IslandGenerator.HEIGHT, gen)
	world = World.new()
	world.name = "TitleIsland"
	add_child(world)
	# Seen from low down out at sea, the sea needs to run on to the horizon.
	var reach := TerrainBuilder.sea_reach
	TerrainBuilder.sea_reach = 1200
	world.setup(data, saved.get("world", {}))
	TerrainBuilder.sea_reach = reach
	day_night = DayNight.new()
	day_night.fixed_hour = HOUR
	add_child(day_night)
	# The island's a long way off: shadows reach it, and a little haze softens it.
	day_night.sun.directional_shadow_max_distance = 260.0
	day_night.env.fog_enabled = true
	day_night.env.fog_depth_begin = 200.0
	day_night.env.fog_depth_end = 900.0
	day_night.env.fog_density = 0.2
	camera = Camera3D.new()
	camera.fov = 22.0
	camera.far = 900.0
	add_child(camera)
	camera.current = true
	CameraRig.add_outline_pass(camera)
	# Far out at sea south of the island, low over the water and looking a little up, so
	# the island sits on the horizon on the left with sky above it for the menu.
	var centre := Vector3(data.width * 0.5, 0.0, data.height * 0.5)
	_base = centre + Vector3(-10.0, 10.0, data.height * 0.5 + 230.0)
	_look = centre + Vector3(46.0, 26.0, 0.0)
	RenderingServer.global_shader_parameter_set("curve_amount", 0.0)
	_place_camera()


func _process(delta: float) -> void:
	if camera == null:
		return
	_time += delta
	_place_camera()


## A slow bob and drift, like sitting in a boat.
func _place_camera() -> void:
	var bob := Vector3(sin(_time * 0.11) * 3.0, sin(_time * 0.7) * 0.12, 0.0)
	camera.position = _base + bob
	camera.look_at(_look + Vector3(bob.x * 0.6, 0, 0))
	RenderingServer.global_shader_parameter_set("curve_origin", camera.position)
