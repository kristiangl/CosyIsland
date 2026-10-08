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
## The furniture being sat on, or -1.
var _seat_uid := -1
var _stand_spot := Vector3.ZERO
## True while the line is out.
var fishing := false
## How far since the last footstep, and how far a stride is.
var _stride := 0.0
const STRIDE := 0.62
## The landscaping tool in hand ("" when they're put away): see LANDSCAPE_TOOLS.
var landscaping := ""
var _line: MeshInstance3D
## A vault with the pole under way: from, to, and how far through (0 to 1; -1 if not).
var _vault_from := Vector3.ZERO
var _vault_to := Vector3.ZERO
var _vault_t := -1.0
const VAULT_TIME := 0.9


func setup(w: World, start: Vector3, look: Dictionary) -> void:
	world = w
	position = Vector3(start.x, world.ground_height(start.x, start.z), start.z)
	model = CharacterModel.new(look)
	add_child(model)
	model.set_tool(Inventory.equipped_id())
	Events.equipped_changed.connect(func(id: String): if landscaping == "": model.set_tool(id))
	_line = MeshInstance3D.new()
	var thread := CylinderMesh.new()
	thread.top_radius = 0.006
	thread.bottom_radius = 0.006
	thread.height = 1.0
	thread.radial_segments = 4
	thread.rings = 1
	_line.mesh = thread
	_line.material_override = Models.material()
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line.top_level = true
	_line.visible = false
	add_child(_line)


func _physics_process(delta: float) -> void:
	var active := Game.mode == Game.Mode.PLAY or Game.mode == Game.Mode.PLACING
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down") if active else Vector2.ZERO
	if _seat_uid >= 0:
		if _busy > 0.0:
			_busy -= delta
		# Any push on the stick, use or cancel gets back up.
		if input.length() > 0.5 or (active and _busy <= 0.0 and (Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("use"))):
			_stand_up()
		model.animate(delta, 0.0)
		return
	if _vault_t >= 0.0:
		_vault(delta)
		return
	if _busy > 0.0:
		_busy -= delta
		input = Vector2.ZERO
	if fishing:
		# Walking off reels the line in.
		if input.length() > 0.3:
			_reel()
		else:
			input = Vector2.ZERO
			_update_line()
	var dir := Vector3(input.x, 0, input.y)
	var running := Input.is_action_pressed("run") and Game.mode == Game.Mode.PLAY
	var target_speed := dir.length() * (RUN_SPEED if running else WALK_SPEED)
	var old_speed := _speed
	# Quick to get going, a touch quicker to stop.
	_speed = move_toward(_speed, target_speed, delta * (16.0 if target_speed > _speed else 24.0))
	var old_yaw := atan2(facing.x, facing.z)
	if dir.length() > 0.1:
		facing = facing.slerp(dir.normalized(), 1.0 - exp(-delta * 14.0)).normalized()
	if _speed > 0.01:
		var heading := dir.normalized() if dir.length() > 0.1 else facing
		var before := position
		_move(heading * _speed * delta)
		# A footstep every stride, on whatever's underfoot.
		_stride += Vector2(position.x - before.x, position.z - before.z).length()
		if _stride > STRIDE:
			_stride = 0.0
			Sfx.step(world.step_surface(position), running)
	if dir.length() > 0.5 and Game.mode == Game.Mode.PLAY:
		_check_doors(dir)
	var yaw := atan2(facing.x, facing.z)
	model.rotation.y = yaw
	var turn_rate := wrapf(yaw - old_yaw, -PI, PI) / maxf(delta, 0.0001)
	model.animate(delta, _speed, turn_rate, (_speed - old_speed) / maxf(delta, 0.0001))


func _unhandled_input(event: InputEvent) -> void:
	if Game.mode != Game.Mode.PLAY or _busy > 0.0 or _seat_uid >= 0:
		return
	if fishing:
		if event.is_action_pressed("use"):
			_reel()
		return
	if landscaping != "":
		if event.is_action_pressed("use"):
			var npc := _facing_npc()
			if npc:
				Story.talk_to(npc)
			else:
				_landscape()
			return
		for step: Array in [["tool_next", 1], ["tool_prev", -1]]:
			if event.is_action_pressed(step[0]):
				var at := LANDSCAPE_TOOLS.find(landscaping)
				set_landscaping(LANDSCAPE_TOOLS[posmod(at + step[1], LANDSCAPE_TOOLS.size())])
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


## Walking into a home's door goes inside; stepping onto a room's doormat goes out (or
## back to the main room), and walking into a door in a wall goes through to that room.
func _check_doors(dir: Vector3) -> void:
	if world.interior:
		if tile() == world.data.room_door():
			Events.home_left.emit()
			return
		var through := world.room_door_ahead(position, dir)
		if through >= 0:
			Events.room_door.emit(through)
		return
	var home := world.home_entrance(position, dir)
	if not home.is_empty():
		Events.home_entered.emit(home["uid"])


func _clear(px: float, pz: float) -> bool:
	if not world.can_move(position, px, pz, RADIUS):
		return false
	for npc in Game.npcs:
		if npc.world == world and npc.blocks(px, pz) and not npc.blocks(position.x, position.z):
			return false
	return true


## The character the player is facing and close enough to talk to, if any.
func _facing_npc() -> Npc:
	for npc in Game.npcs:
		if npc.world != world or not npc.visible:
			continue
		var to := npc.position - position
		to.y = 0.0
		if to.length() < 1.4 and facing.dot(to.normalized()) > 0.35:
			return npc
	return null


func face_towards(point: Vector3) -> void:
	var to := point - position
	to.y = 0.0
	if to.length() > 0.05:
		facing = to.normalized()
		model.rotation.y = atan2(facing.x, facing.z)


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
	var npc := _facing_npc()
	if npc:
		Story.talk_to(npc)
		return
	var tool_kind := ItemDB.tool_type(Inventory.equipped_id())
	var obj := _facing_object()
	var kind: String = obj.get("kind", "")
	if obj.has("x"):
		_turn_towards(obj)
	if kind == "placed":
		_interact(obj)
		return
	if kind == "stump":
		_sit_on(obj)
		return
	match tool_kind:
		"rod":
			_cast()
		"net":
			_swing_net()
		"pole":
			_start_vault()
		"axe", "shovel", "pickaxe":
			# Each tool has one job: the axe chops trees, the pickaxe breaks rocks and the
			# shovel digs up flowers. Anything else just gets a bump.
			_busy = SWING_TIME
			model.play({"axe": "chop", "shovel": "dig", "pickaxe": "mine"}[tool_kind])
			await get_tree().create_timer(IMPACT_TIME).timeout
			if kind == "bush":
				Sfx.play("rustle")
				world.shake(obj, position)
			elif kind in ["tree", "fruit_tree", "palm"]:
				if tool_kind == "axe":
					Sfx.play("chop")
					world.chop(obj, position)
					Inventory.wear_equipped()
				else:
					Sfx.play("rustle")
					world.shake(obj, position)
			elif kind == "rock":
				if tool_kind == "pickaxe":
					Sfx.play("mine")
					world.strike_rock(obj, position)
					Inventory.wear_equipped()
				else:
					Sfx.play("clonk")
					world.bump_rock(obj, position)
					Events.toast.emit("Clonk! A pickaxe would break bits off.")
				_recoil()
			elif kind == "flower" and tool_kind == "shovel":
				Sfx.play("dig")
				if world.dig_up(obj):
					Inventory.wear_equipped()
			else:
				# A swing at nothing in particular.
				Sfx.play("whoosh", -6.0)
		_:
			if kind in ["tree", "fruit_tree", "palm", "bush"]:
				_busy = SWING_TIME
				model.play("shake")
				Sfx.play("rustle")
				world.shake(obj, position)


# --- Landscaping ----------------------------------------------------------------------

## The landscaping tools, in the order the D-pad goes through them.
const LANDSCAPE_TOOLS := ["cliff", "water", "slope", "trees", "move", "path:stone", "path:brick", "path:wood",
	"path:terracotta", "path:sand", "path:dirt"]

## Takes out a landscaping tool from the phone's app ("" puts them away).
func set_landscaping(what: String) -> void:
	landscaping = what
	model.set_tool("landscape:" + what.get_slice(":", 0) if what != "" else Inventory.equipped_id())
	Events.landscaping_changed.emit(what)


## A tool's name for the HUD.
static func landscape_name(what: String) -> String:
	match what:
		"cliff":
			return "Cliffs"
		"water":
			return "Water"
		"slope":
			return "Slopes"
		"trees":
			return "Trees"
		"move":
			return "Move"
	return World.PATH_NAMES.get(what.get_slice(":", 1), "Path")


## The landscaping tool in hand on the tile ahead.
func _landscape() -> void:
	var what := landscaping
	var kind := what.get_slice(":", 0)
	if kind == "trees":
		_landscape_trees()
		return
	if kind == "move":
		_lift()
		return
	var plan: Dictionary
	match kind:
		"cliff", "water":
			plan = world.terraform_plan(tile(), cardinal(), what)
		"slope":
			plan = world.slope_plan(tile(), cardinal())
		_:
			plan = world.path_plan(tile(), cardinal(), what.get_slice(":", 1))
	if plan.has("why"):
		Events.toast.emit(plan["why"])
		Sfx.play("ui_error", -4.0)
		return
	_busy = SWING_TIME
	model.play("mine" if kind == "cliff" else "dig")
	await get_tree().create_timer(IMPACT_TIME).timeout
	var t: Vector2i = plan.get("tile", tile() + cardinal())
	match kind:
		"cliff", "water":
			world.terraform(plan)
			if kind == "cliff":
				Sfx.play("rumble")
				Sfx.play("mine", -4.0)
			else:
				Sfx.play("splash" if plan["verb"] == "dig" else "dig")
		"slope":
			if plan.has("remove"):
				world.remove_slope(plan)
			else:
				world.build_incline(plan)
				t = plan["top"] + plan["dir"]
			Sfx.play("rumble", -3.0)
		_:
			world.set_path(plan)
			Sfx.play("place" if plan["kind"] in ["wood"] else ("dig" if plan["kind"] in ["", "sand", "dirt"] else "clonk"), -2.0)
	var at := Vector3(t.x + 0.5, world.ground_height(t.x + 0.5, t.y + 0.5), t.y + 0.5)
	Effects.burst("splash" if plan.get("verb", "") == "dig" else "dust", at + Vector3(0, 0.2, 0))
	if kind == "cliff":
		Effects.burst("pebbles", at + Vector3(0, 0.3, 0))
	Journal.add("landscaped")


## The Trees tool: chops at a grown tree (World.FELL_CHOPS bring it down, leaving a
## stump) or digs up a bush, a stump or a young tree.
func _landscape_trees() -> void:
	var obj := _facing_object()
	var kind: String = obj.get("kind", "")
	if not kind in ["tree", "fruit_tree", "palm", "bush", "stump"]:
		Events.toast.emit("Rocks can be shifted with the Move tool." if kind == "rock" else "Face a tree, a bush or a stump.")
		Sfx.play("ui_error", -4.0)
		return
	_turn_towards(obj)
	var felling := kind in ["tree", "fruit_tree", "palm"] and not obj.has("planted")
	_busy = SWING_TIME
	model.play("chop" if felling else "dig")
	await get_tree().create_timer(IMPACT_TIME).timeout
	if felling:
		Sfx.play("chop")
		if world.chop_down(obj, position):
			Sfx.play("creak", -2.0, 0.7)
			Journal.add("landscaped")
	elif world.dig_out(obj):
		Sfx.play("dig")
		Journal.add("landscaped")


## The Move tool: digs up the tree, bush, rock or stump ahead to carry somewhere else
## (Placement shows where it'll go).
func _lift() -> void:
	var obj := _facing_object()
	if not obj.get("kind", "") in World.MOVABLE_KINDS:
		Events.toast.emit("Face a tree, a bush, a rock or a stump to move it.")
		Sfx.play("ui_error", -4.0)
		return
	_turn_towards(obj)
	_busy = SWING_TIME
	model.play("dig")
	await get_tree().create_timer(IMPACT_TIME).timeout
	Sfx.play("dig")
	Events.lift_requested.emit(obj)


# --- Vaulting -------------------------------------------------------------------------

## Plants the pole at the water's edge and hops over to the other bank.
func _start_vault() -> void:
	var landing := world.vault_landing(position, facing)
	if landing.has("why"):
		Events.toast.emit(landing["why"])
		return
	_vault_from = position
	_vault_to = landing["to"]
	_vault_t = 0.0
	_speed = 0.0
	model.play("chop")
	Sfx.play("whoosh")


func _vault(delta: float) -> void:
	_vault_t = minf(1.0, _vault_t + delta / VAULT_TIME)
	# A smooth arc over the water, highest in the middle.
	var t := smoothstep(0.0, 1.0, _vault_t)
	position = _vault_from.lerp(_vault_to, t) + Vector3(0, sin(_vault_t * PI) * 1.4, 0)
	model.animate(delta, 0.0)
	if _vault_t >= 1.0:
		_vault_t = -1.0
		position = _vault_to
		Effects.burst("step", position)
		Sfx.play("thud", -2.0)


# --- Fishing and bugs ----------------------------------------------------------------

func _cast() -> void:
	var spot: Variant = world.critters.cast_spot(position, facing) if world.critters else null
	if spot == null:
		Events.toast.emit("Face the water to cast your line.")
		return
	_busy = 0.5
	model.play("cast")
	Sfx.play("whoosh", -3.0, 1.2)
	await get_tree().create_timer(0.3).timeout
	world.critters.cast(spot)
	fishing = true
	model.mode = "fishing"
	_line.visible = true
	_update_line()


## The line from the rod tip to the bobber.
func _update_line() -> void:
	var tip := position + facing * 0.75 + Vector3(0, 1.15, 0)
	var end := world.critters.bobber.position + Vector3(0, 0.08, 0)
	var span := end - tip
	_line.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, span.normalized())).scaled(Vector3(1, span.length(), 1)),
		(tip + end) * 0.5)


func _reel() -> void:
	fishing = false
	model.mode = ""
	_line.visible = false
	var id := world.critters.reel()
	if id == "":
		return
	_landed(id, "Got it! A %s!", 0.8)


func _swing_net() -> void:
	_busy = SWING_TIME
	model.play("net")
	Sfx.play("whoosh")
	await get_tree().create_timer(IMPACT_TIME).timeout
	var id := world.critters.net(position + facing * 0.9) if world.critters else ""
	if id == "":
		return
	_landed(id, "Caught it! A %s!", 2.2)


## Holds up something just caught, and puts it in the pockets.
func _landed(id: String, line: String, size: float) -> void:
	if Inventory.add_item(id) > 0:
		Events.toast.emit("Your pockets are full, so you let it go.")
		return
	Inventory.wear_equipped()
	Journal.catch(id)
	_busy = 1.2
	model.play("cheer")
	model.hold(Models.get_mesh("drop:" + id), 1.4, size)
	Effects.burst("sparkle", position + Vector3(0, 1.3, 0))
	Sfx.play("jingle_catch", 0.0, 1.0, 0.0)
	Events.toast.emit(line % ItemDB.display_name(id).to_lower())


func _interact(obj: Dictionary) -> void:
	var def := ItemDB.placeable(obj["item"])
	if def.get("bed", false):
		_bed(obj)
	elif def.has("seat"):
		_sit_on(obj)
	elif def.get("workbench", false):
		Events.workbench_opened.emit()
	elif def.get("mirror", false):
		Story.use_mirror()
	elif def.get("storage", false) and world.interior and not world.visitor:
		Events.storage_opened.emit()
	elif def.has("room"):
		Events.home_entered.emit(obj["uid"])
	elif def.get("shopfront", false) and Story.npc(def.get("keeper", "lucy")):
		Story.talk_to(Story.npc(def.get("keeper", "lucy")))
	elif def.get("museum", false) and Story.npc("bramble"):
		Story.talk_to(Story.npc("bramble"))
	else:
		Events.toast.emit("What a lovely %s." % ItemDB.display_name(obj["item"]).to_lower())


## Beds offer a sleep: the clock moves on to the chosen time of day.
const SLEEPS := [["Until morning", 7.0], ["Until noon", 12.0], ["Until evening", 18.0], ["Until midnight", 0.0]]


func _bed(obj: Dictionary) -> void:
	if Game.dialogue == null:
		_sit_on(obj)
		return
	Game.mode = Game.Mode.MENU
	var options: Array = SLEEPS.map(func(e): return e[0])
	options.append_array(["Just sit", "Never mind"])
	Game.dialogue.ask("", "Have a little sleep?", options)
	var pick: int = await Game.dialogue.picked
	Game.mode = Game.Mode.PLAY
	if pick < SLEEPS.size():
		_lie_in(obj)
		Events.sleep_requested.emit(SLEEPS[pick][1])
	elif pick == SLEEPS.size():
		_sit_on(obj)


func _sit_on(obj: Dictionary) -> void:
	var spots := world.seats(obj)
	if spots.is_empty():
		return
	spots.sort_custom(func(a, b): return a["position"].distance_to(position) < b["position"].distance_to(position))
	var spot: Dictionary = spots[0]
	_seat_uid = obj["uid"]
	_stand_spot = position
	facing = spot["facing"]
	var seat_pos: Vector3 = spot["position"] - facing * 0.04
	_busy = 0.25
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position", seat_pos, 0.22).set_trans(Tween.TRANS_QUAD)
	# Lift the model so the hips rest on the seat.
	tw.tween_property(model, "position:y", spot["height"] - CharacterParts.HIP_Y + 0.05, 0.22)
	model.rotation.y = atan2(facing.x, facing.z)
	model.set_sitting(true)
	Sfx.play("creak", -4.0)
	if not Story.flags.get("seat_hint", false):
		Story.flags["seat_hint"] = true
		Events.toast.emit(Prompts.fill("Move, or press {use}, to get up again."))


## Climbs into bed: lying on the back, head on the pillow at the headboard end.
func _lie_in(obj: Dictionary) -> void:
	var node := world.node_of(obj["uid"])
	if node == null:
		return
	_stand_spot = position
	_busy = 0.3
	var height: float = ItemDB.placeable(obj["item"]).get("seat", 0.3)
	position = node.global_transform * Vector3(0, 0, 0.15)
	facing = node.global_basis * Vector3.BACK
	model.rotation.y = atan2(facing.x, facing.z)
	model.position.y = maxf(height - 0.12, 0.0)
	model.mode = "sleeping"
	Sfx.play("cloth")


## Gets out of bed and stands beside it, back where we got in.
## Off the seat or out of bed, ready to go (before being fetched by SOS).
func stand() -> void:
	if _seat_uid >= 0:
		_seat_uid = -1
		model.set_sitting(false)
	get_up()


func get_up() -> void:
	if model.mode != "sleeping":
		return
	model.mode = ""
	model.position.y = 0.0
	position = _stand_spot


func _stand_up() -> void:
	_seat_uid = -1
	model.set_sitting(false)
	# Step off to the front if there's room, else to a side, the back, or where we came
	# from: somewhere clear (no furniture, nobody standing there) that we can walk away from.
	var side := Vector3(-facing.z, 0, facing.x)
	var goal := _stand_spot
	for offset: Vector3 in [facing * 0.85, side * 0.85, -side * 0.85, -facing * 0.85]:
		var c := position + offset
		if _free_spot(c):
			goal = Vector3(c.x, world.ground_height(c.x, c.z), c.z)
			break
	_busy = 0.2
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position", goal, 0.2).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(model, "position:y", 0.0, 0.2)


## Somewhere to stand: open ground nobody's on, with a way to walk off from it.
func _free_spot(c: Vector3) -> bool:
	if not world.is_walkable(c.x, c.z):
		return false
	var at := Vector3(c.x, world.ground_height(c.x, c.z), c.z)
	for npc in Game.npcs:
		if npc.world == world and npc.blocks(c.x, c.z):
			return false
	for step: Vector2 in [Vector2(0.3, 0), Vector2(-0.3, 0), Vector2(0, 0.3), Vector2(0, -0.3)]:
		if world.can_move(at, c.x + step.x, c.z + step.y, RADIUS):
			return true
	return false


## Eats something from the pockets: up to the mouth, crumbs, hearts.
func eat(item_id: String) -> void:
	Journal.add("eaten")
	_busy = 1.6
	model.play("eat")
	model.hold(Models.get_mesh("drop:" + item_id), 1.4)
	for i in 3:
		await get_tree().create_timer(0.35 + i * 0.3).timeout
		Effects.burst("crumbs", position + facing * 0.25 + Vector3(0, 1.0, 0))
		if i == 0:
			Sfx.play("munch")
	await get_tree().create_timer(0.35).timeout
	Effects.burst("hearts", position + Vector3(0, 1.6, 0))


## Crafting at the workbench: hammering with sparkles, then a pop of confetti.
func craft_animation() -> void:
	_busy = 1.6
	model.play("craft")
	var bench := position + facing * 0.8 + Vector3(0, 0.85, 0)
	for i in 4:
		await get_tree().create_timer(0.3).timeout
		Effects.burst("sparks", bench)
		Sfx.play("hammer", -2.0)
	await get_tree().create_timer(0.3).timeout
	Effects.burst("confetti", bench + Vector3(0, 0.2, 0))
	Sfx.play("jingle_craft", 0.0, 1.0, 0.0)
	Effects.burst("sparkle", bench + Vector3(0, 0.3, 0))


func is_sitting() -> bool:
	return _seat_uid >= 0


func _pick_up() -> void:
	for t in [tile(), target_tile()]:
		if world.pick_up(t.x, t.y):
			_busy = 0.3
			model.play("pickup")
			return
	# Things on tables come off first, then furniture can be packed back into the pockets.
	var front := target_tile()
	var on_table := world.surface_item_at(front.x, front.y)
	if not on_table.is_empty():
		if world.pack_up(on_table):
			_busy = 0.3
			model.play("pickup")
		return
	var obj := _facing_object()
	if obj.get("kind", "") == "placed":
		_turn_towards(obj)
		if world.pack_up(obj):
			_busy = 0.3
			model.play("pickup")
		return
	# Rugs last: the one in front, or the one underfoot.
	var rug := world.rug_at(front.x, front.y)
	if rug.is_empty():
		rug = world.rug_at(tile().x, tile().y)
	if not rug.is_empty() and world.pack_up(rug):
		_busy = 0.3
		model.play("pickup")


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
