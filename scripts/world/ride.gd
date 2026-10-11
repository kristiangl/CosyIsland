class_name Ride
extends Node3D
## The moving parts of a big decoration (placeable "ride"), on its node in the world:
## the Ferris wheel turns with its cabins hanging level, the carousel goes round with its
## horses rising and falling, the teacups spin on their turning floor, the hot air
## balloon bobs on its ropes and the lucky cat beckons. The still parts are the model's
## "<model>_base" (LandmarkModels). Stops with the island (indoors, say).

var kind := ""
var _t := 0.0
## The part that turns (the wheel, the carousel's top, the teacups' floor, the balloon,
## the cat's paw), and the ones carried round with it (cabins, horses, cups).
var _main: MeshInstance3D
var _riders: Array[MeshInstance3D] = []


func _init(ride_kind: String, offset: float = 0.0) -> void:
	kind = ride_kind
	# Two of a kind don't move in step.
	_t = offset


func _ready() -> void:
	match kind:
		"ferris_wheel":
			_main = _part("landmark:ferris_ring")
			_main.position = Vector3(0, LandmarkModels.FERRIS_AXLE, 0)
			for i in LandmarkModels.FERRIS_CABS:
				_riders.append(_part("landmark:ferris_cab:%d" % i))
		"carousel":
			_main = _part("landmark:carousel_top")
			for i in LandmarkModels.HORSES:
				_riders.append(_part("landmark:horse:%d" % i))
		"teacups":
			_main = _part("landmark:teacup_floor")
			for i in LandmarkModels.CUPS:
				_riders.append(_part("landmark:teacup:%d" % i))
		"hot_air_balloon":
			_main = _part("landmark:balloon_up")
		"lucky_cat":
			_main = _part("landmark:lucky_paw")
			_main.position = LandmarkModels.CAT_SHOULDER
	_process(0.0)


func _part(key: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Models.get_mesh(key)
	Models.dress(mi, Models.material())
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	match kind:
		"ferris_wheel":
			var turn := _t * LandmarkModels.FERRIS_SPEED
			_main.rotation.z = turn
			for i in _riders.size():
				var a := turn + i * TAU / LandmarkModels.FERRIS_CABS
				_riders[i].position = Vector3(cos(a), sin(a), 0) * LandmarkModels.FERRIS_R + _main.position
				_riders[i].rotation.z = sin(_t * 1.3 + i) * 0.05
		"carousel":
			var turn := _t * LandmarkModels.CAROUSEL_SPEED
			_main.rotation.y = turn
			for i in _riders.size():
				_riders[i].transform = LandmarkModels.horse_spot(i, turn, _t)
		"teacups":
			var turn := _t * LandmarkModels.TEACUP_SPEED
			_main.rotation.y = turn
			for i in _riders.size():
				_riders[i].transform = LandmarkModels.cup_spot(i, turn, _t)
		"hot_air_balloon":
			_main.position.y = sin(_t * 0.9) * 0.07
			_main.rotation.z = sin(_t * 0.6) * 0.025
		"lucky_cat":
			_main.rotation.x = -0.25 + sin(_t * 3.0) * 0.35
