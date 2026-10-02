class_name Player
extends Node3D
## The player: grid-aware movement over the island heightfield, tool use and pick-ups.

const WALK_SPEED := 3.4
const RUN_SPEED := 6.4
const RADIUS := 0.26
const REACH := 0.8
## Seconds after starting a swing when the tool lands.
const IMPACT_TIME := 0.2
const SWING_TIME := 0.42

var world: World
var facing := Vector3(0, 0, 1)
var model: CharacterModel
var _speed := 0.0
var _busy := 0.0


func setup(w: World, start: Vector3, look: Dictionary) -> void:
	world = w
	position = Vector3(start.x, world.ground_height(start.x, start.z), start.z)
	model = CharacterModel.new(look)
	add_child(model)
	model.set_tool(Inventory.equipped_id())
	Events.equipped_changed.connect(model.set_tool)


func _physics_process(delta: float) -> void:
	var active := Game.mode == Game.Mode.PLAY or Game.mode == Game.Mode.PLACING
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down") if active else Vector2.ZERO
	if _busy > 0.0:
		_busy -= delta
		input = Vector2.ZERO
	var dir := Vector3(input.x, 0, input.y)
	var running := Input.is_action_pressed("run") and Game.mode == Game.Mode.PLAY
	var target_speed := dir.length() * (RUN_SPEED if running else WALK_SPEED)
	_speed = move_toward(_speed, target_speed, delta * 30.0)
	if dir.length() > 0.1:
		facing = facing.slerp(dir.normalized(), 1.0 - exp(-delta * 16.0)).normalized()
		_move(dir.normalized() * _speed * delta)
	model.rotation.y = atan2(facing.x, facing.z)
	model.animate(delta, _speed if dir.length() > 0.1 else 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if Game.mode != Game.Mode.PLAY or _busy > 0.0:
		return
	if event.is_action_pressed("use"):
		_use()
	elif event.is_action_pressed("pickup"):
		_pick_up()
	elif event.is_action_pressed("tool_next"):
		Inventory.cycle_tool(1)
	elif event.is_action_pressed("tool_prev"):
		Inventory.cycle_tool(-1)


func _move(step: Vector3) -> void:
	var nx := position.x + step.x
	if _clear(nx, position.z):
		position.x = nx
	var nz := position.z + step.z
	if _clear(position.x, nz):
		position.z = nz
	position.y = world.ground_height(position.x, position.z)


func _clear(px: float, pz: float) -> bool:
	for off in [Vector2.ZERO, Vector2(RADIUS, 0), Vector2(-RADIUS, 0), Vector2(0, RADIUS), Vector2(0, -RADIUS)]:
		if not world.can_step(position, px + off.x, pz + off.y):
			return false
	return true


func tile() -> Vector2i:
	return Vector2i(floori(position.x), floori(position.z))


## The tile the player is facing.
func target_tile() -> Vector2i:
	var p := position + facing * REACH
	return Vector2i(floori(p.x), floori(p.z))


## Facing snapped to one of the four grid directions.
func cardinal() -> Vector2i:
	if absf(facing.x) > absf(facing.z):
		return Vector2i(1 if facing.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if facing.z >= 0.0 else -1)


## The object in front of the player, checking a little to each side as well.
func _facing_object() -> Dictionary:
	for angle in [0.0, 0.5, -0.5]:
		var p := position + facing.rotated(Vector3.UP, angle) * REACH
		var obj := world.object_at(floori(p.x), floori(p.z))
		if not obj.is_empty():
			return obj
	return {}


func _use() -> void:
	var tool_kind := ItemDB.tool_type(Inventory.equipped_id())
	var obj := _facing_object()
	var kind: String = obj.get("kind", "")
	if obj.has("x"):
		_turn_towards(obj)
	match tool_kind:
		"axe", "shovel":
			_busy = SWING_TIME
			model.swing("chop")
			await get_tree().create_timer(IMPACT_TIME).timeout
			if kind in ["tree", "fruit_tree", "palm"]:
				if tool_kind == "axe":
					world.chop(obj, position)
					Inventory.wear_equipped()
				else:
					world.shake(obj, position)
			elif kind == "rock":
				world.strike_rock(obj, position)
				Inventory.wear_equipped()
				_recoil()
		_:
			if kind in ["tree", "fruit_tree", "palm"]:
				_busy = SWING_TIME
				model.swing("shake")
				world.shake(obj, position)
			elif kind == "placed":
				Events.toast.emit("Home sweet home! (You'll be able to go inside soon.)")


func _pick_up() -> void:
	for t in [tile(), target_tile()]:
		if world.pick_up(t.x, t.y):
			_busy = 0.25
			model.swing("shake")
			return


func _turn_towards(obj: Dictionary) -> void:
	var centre := Vector3(obj["x"] + 0.5, position.y, obj["z"] + 0.5)
	var to := centre - position
	to.y = 0.0
	if to.length() > 0.05:
		facing = to.normalized()


func _recoil() -> void:
	var back := -facing * 0.35
	var tw := create_tween()
	var goal := position + back
	if _clear(goal.x, goal.z):
		tw.tween_property(self, "position", Vector3(goal.x, world.ground_height(goal.x, goal.z), goal.z), 0.15) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func to_save() -> Dictionary:
	return {"x": position.x, "z": position.z, "fx": facing.x, "fz": facing.z, "look": model.look}
