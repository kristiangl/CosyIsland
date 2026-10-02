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
var _yaw := 0.0
var _hop := 0.0


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


func _process(delta: float) -> void:
	var look := rest_facing
	var player := Game.player
	if player and player.world == world:
		var to := player.position - position
		to.y = 0.0
		if to.length() < NOTICE:
			look = to.normalized()
	var goal := atan2(look.x, look.z)
	_yaw = lerp_angle(_yaw, goal, 1.0 - exp(-delta * 5.0))
	var turn := wrapf(goal - _yaw, -PI, PI)
	model.rotation.y = _yaw
	model.animate(delta, 0.0, turn * 2.0)
	if _hop > 0.0:
		_hop = maxf(0.0, _hop - delta)
		model.position.y = sin((1.0 - _hop / 0.35) * PI) * 0.18
	else:
		model.position.y = 0.0


## True if a point is inside the character (for walking into them).
func blocks(px: float, pz: float) -> bool:
	return Vector2(px - position.x, pz - position.z).length() < RADIUS


## A little hop of excitement.
func hop() -> void:
	_hop = 0.35


func cheer() -> void:
	model.play("cheer")
