class_name Npc
extends Node3D
## An island character standing at their spot: idles, looks round at the player when
## they come near, and turns to face whoever's talking to them. Talking is handled by
## Story; this is just the body.

const RADIUS := 0.32
## How close the player has to be for the character to notice them.
const NOTICE := 3.2

var id := ""
var model: CharacterModel
var world: World
## Which way the character faces when nobody's around.
var rest_facing := Vector3(0, 0, 1)
## Neighbours wander about near home by day (`home` is the spot outside their door) and
## are indoors in the evening and at night.
var wanders := false
## Wanders at any hour (someone camping on a tour island has no home to go to).
var always_out := false
## Visiting from a tour island for the day (wanders round the plaza).
var visiting := false
var home := Vector3.ZERO
const WALK := 1.1
const ROAM := 7.0
var _yaw := 0.0
var _hop := 0.0
var _target := Vector3.ZERO
var _wait := 0.0
var _rng := RandomNumberGenerator.new()
## A "..." bubble over the head of a neighbour who's thinking of moving away.
var _thought: Label3D
var _thought_check := 0.0
var _time := 0.0


## Out and about (for neighbours: from 7am until 6pm).
static func out_at(hour: float) -> bool:
	return hour >= 7.0 and hour < 18.0

func setup(character_id: String, w: World, spot: Vector3, facing: Vector3) -> void:
	id = character_id
	world = w
	name = NpcData.display_name(character_id)
	position = Vector3(spot.x, w.ground_height(spot.x, spot.z), spot.z)
	rest_facing = facing
	_yaw = atan2(facing.x, facing.z)
	model = NpcData.model(character_id)
	add_child(model)
	model.rotation.y = _yaw
	add_to_group("npcs")
	if NpcData.is_neighbour(character_id):
		_thought = Label3D.new()
		_thought.text = "..."
		_thought.font = UIStyle.font(700)
		_thought.font_size = 96
		_thought.pixel_size = 0.009
		_thought.modulate = UIStyle.BROWN
		_thought.outline_modulate = UIStyle.CREAM
		_thought.outline_size = 44
		_thought.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_thought.no_depth_test = false
		_thought.position = Vector3(0, 2.05, 0)
		_thought.visible = false
		add_child(_thought)


func _process(delta: float) -> void:
	_time += delta
	if _thought:
		_thought_check -= delta
		if _thought_check <= 0.0:
			_thought_check = 0.5
			_thought.visible = Story.thinking_of_moving() == id
		if _thought.visible:
			_thought.position.y = 2.05 + sin(_time * 2.4) * 0.05
	var speed := 0.0
	if wanders:
		visible = always_out or out_at(GameClock.hour_float())
		if not visible:
			position = home
			return
		speed = _wander(delta)
	var look := rest_facing
	var player := Game.player
	if speed > 0.0:
		look = (_target - position).normalized()
	elif player and player.world == world:
		var to := player.position - position
		to.y = 0.0
		if to.length() < NOTICE:
			look = to.normalized()
	var goal := atan2(look.x, look.z)
	_yaw = lerp_angle(_yaw, goal, 1.0 - exp(-delta * 5.0))
	var turn := wrapf(goal - _yaw, -PI, PI)
	model.rotation.y = _yaw
	model.animate(delta, speed, turn * 2.0)
	if _hop > 0.0:
		_hop = maxf(0.0, _hop - delta)
		model.position.y = sin((1.0 - _hop / 0.35) * PI) * 0.18
	else:
		model.position.y = 0.0


## Strolls between spots near home, pausing at each; stops while anyone's talking or
## the player is close by. Returns the walking speed this frame.
func _wander(delta: float) -> float:
	var player := Game.player
	if Story.talking or (player and player.world == world and Vector2(player.position.x - position.x, player.position.z - position.z).length() < 1.6):
		return 0.0
	if _wait > 0.0:
		_wait -= delta
		return 0.0
	var to := _target - position
	to.y = 0.0
	if _target == Vector3.ZERO or to.length() < 0.1:
		_wait = _rng.randf_range(1.5, 5.0)
		_pick_target()
		return 0.0
	var step := to.normalized() * minf(WALK * delta, to.length())
	var next := position + step
	if not world.is_walkable(next.x, next.z):
		_pick_target()
		return 0.0
	position = Vector3(next.x, world.ground_height(next.x, next.z), next.z)
	return WALK


func _pick_target() -> void:
	for attempt in 8:
		var p := home + Vector3(_rng.randf_range(-ROAM, ROAM), 0, _rng.randf_range(-ROAM, ROAM))
		if world.is_walkable(p.x, p.z) and world.object_at(floori(p.x), floori(p.z)).is_empty():
			_target = Vector3(p.x, world.ground_height(p.x, p.z), p.z)
			return
	_target = home


## True if a point is inside the character (for walking into them).
func blocks(px: float, pz: float) -> bool:
	return visible and Vector2(px - position.x, pz - position.z).length() < RADIUS


## A little hop of excitement.
func hop() -> void:
	_hop = 0.35


func cheer() -> void:
	model.play("cheer")
