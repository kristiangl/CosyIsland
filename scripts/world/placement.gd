class_name Placement
extends Node3D
## Grid placement mode: shows a ghost of the item in front of the player, snapped to
## the grid. A places it, B cancels, R / right bumper rotates. The landscaping Move tool
## uses it too, to carry a tree, bush, rock or stump to a new spot (begin_move; B puts it
## in the pockets), and so do those things when planted again from the pockets.

const VALID := Color(0.55, 1.0, 0.6, 0.55)
const INVALID := Color(1.0, 0.45, 0.4, 0.55)

var player: Player
var world: World
var _slot := -1
var _item := ""
var _size := Vector2i.ONE
var _rot := 0
var _rotatable := true
var _small := false
var _rug := false
var _on_table := false
var _rect := Rect2i()
var _valid := false
var _asking := false
var _ghost: MeshInstance3D
var _footprint: MeshInstance3D
var _material: ShaderMaterial
var _footprint_material: ShaderMaterial
## The island object being moved (begin_move) or planted from the pockets (a "nature"
## item: not on the island yet), or {} when placing an item.
var _moving: Dictionary = {}
var _planting := false
## Placing fences: the ghost shows how it'll join up, and you keep going until you run
## out or press B. The ghost's model, and where and how it was last worked out.
var _fence := false
var _fence_key := ""
var _fence_at := Vector3i(-9999, -9999, 0)
## Why it can't go on the tile ahead ("" if it can), worked out when that tile changes.
var _why := ""
var _spot_why := ""
var _checked := Vector2i(-9999, -9999)


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/ghost.gdshader")
	_ghost = MeshInstance3D.new()
	_ghost.material_override = _material
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)
	_footprint = MeshInstance3D.new()
	_footprint_material = ShaderMaterial.new()
	_footprint_material.shader = load("res://shaders/footprint.gdshader")
	_footprint.material_override = _footprint_material
	_footprint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	_footprint.mesh = plane
	add_child(_footprint)
	visible = false


func begin(slot: int) -> void:
	var item: String = Inventory.slots[slot].get("id", "")
	var def := ItemDB.placeable(item)
	if def.is_empty():
		return
	if world.visitor:
		Events.toast.emit("Best not rearrange someone else's home!")
		return
	if world.tour:
		Events.toast.emit("Better save that for home.")
		return
	if world.interior and (def.get("structure", false) or def.get("nature", false) or def.get("outdoor", false)):
		Events.toast.emit("That needs to go outside.")
		return
	if def.get("nature", false):
		_begin_planting(slot, item)
		return
	_slot = slot
	_item = item
	_size = Vector2i(def["footprint"][0], def["footprint"][1])
	_rotatable = def.get("rotatable", true)
	_small = def.get("small", false)
	_rug = def.get("rug", false)
	_fence = def.has("fence")
	_fence_at = Vector3i(-9999, -9999, 0)
	_rot = 0
	# Building kits show the building itself, to see how it'll sit.
	var ghost: String = def.get("model", "drop:" + item)
	if def.has("ghost"):
		ghost = ItemDB.placeable(def["ghost"]).get("model", ghost)
	_ghost.mesh = Models.get_mesh(ghost)
	visible = true
	Game.mode = Game.Mode.PLACING
	if _fence:
		Events.toast.emit(Prompts.fill("Fences join up with the ones beside them. {use} to place, {rotate} to turn, {cancel} when you're done."))
	else:
		Events.toast.emit(Prompts.fill("Where should it go? {use} to place, {rotate} to turn, {cancel} to put it away."))


## A tree, bush, rock or stump from the pockets, to plant again on the tile ahead.
func _begin_planting(slot: int, item: String) -> void:
	_moving = World.nature_object(item)
	if _moving.is_empty():
		return
	_moving["uid"] = -1
	_planting = true
	_slot = slot
	_item = item
	_size = Vector2i.ONE
	_rot = 0
	_rotatable = false
	_checked = Vector2i(-9999, -9999)
	_ghost.mesh = Models.get_mesh(Models.key_for(_moving))
	_ghost.scale = Vector3.ONE
	_ghost.rotation.y = 0.0
	visible = true
	Game.mode = Game.Mode.PLACING
	Events.toast.emit(Prompts.fill("Where should it go? {use} to plant it, {cancel} to keep it."))


## Carries `obj` (a tree, bush, rock or stump) to set down on another tile; it stays
## where it was, out of sight, until it's set down, so nothing's lost if the game is
## saved or the move is called off.
func begin_move(obj: Dictionary) -> void:
	if Game.mode != Game.Mode.PLAY or not obj.get("kind", "") in World.MOVABLE_KINDS:
		return
	_moving = obj
	_slot = -1
	_item = ""
	_size = Vector2i.ONE
	_rot = 0
	_rotatable = false
	_small = false
	_rug = false
	_on_table = false
	_checked = Vector2i(-9999, -9999)
	_ghost.mesh = Models.get_mesh(Models.key_for(obj))
	var node := world.node_of(obj["uid"])
	_ghost.scale = node.scale if node else Vector3.ONE
	_ghost.rotation.y = node.rotation.y if node else 0.0
	if node:
		node.visible = false
	world.disturb(obj)
	visible = true
	Game.mode = Game.Mode.PLACING
	Events.toast.emit(Prompts.fill("Where should it go? {use} to set it down, {cancel} to pocket it."))


func _process(_delta: float) -> void:
	if Game.mode != Game.Mode.PLACING:
		return
	if not _moving.is_empty():
		_show_move()
		return
	var dir := player.cardinal()
	var size := _size if _rot % 2 == 0 else Vector2i(_size.y, _size.x)
	var front := player.tile() + dir
	# Small things can go on top of tables, boxes and the like.
	_on_table = _small and world.can_place_on_surface(front)
	if _on_table:
		_rect = Rect2i(front, Vector2i.ONE)
		_valid = true
	else:
		_rect = world.placement_rect(front, dir, size)
		if _rug:
			_valid = world.can_place_rug(_rect)
		else:
			_valid = world.can_place(_rect, player.position) and world.door_clear(_item, _rect, _rot) and not _someone_in(_rect)
	var centre := Vector2(_rect.position) + Vector2(_rect.size) * 0.5
	var y := world.ground_height(centre.x, centre.y)
	if _on_table:
		y += world.surface_height(front.x, front.y)
	_ghost.position = Vector3(centre.x, y + 0.02, centre.y)
	_ghost.rotation.y = -PI * 0.5 * _rot
	if _fence:
		# Shown joined to the fences beside it, as it'll be once it's down.
		var at := Vector3i(_rect.position.x, _rect.position.y, _rot)
		if at != _fence_at:
			_fence_at = at
			_ghost.mesh = Models.get_mesh(world.fence_key(_item, _rect.position, _rot))
		_ghost.rotation.y = 0.0
	_footprint.position = Vector3(centre.x, y + 0.03, centre.y)
	_footprint.scale = Vector3(_rect.size.x, 1, _rect.size.y)
	_material.set_shader_parameter("colour", VALID if _valid else INVALID)
	_footprint_material.set_shader_parameter("colour", VALID if _valid else INVALID)
	_footprint_material.set_shader_parameter("tiles", Vector2(_rect.size))
	# A little hop so it reads as "held, not yet placed".
	_ghost.position.y += 0.06 + 0.04 * sin(Time.get_ticks_msec() / 160.0)


## Whether an islander is standing in (or brushing against) `rect`.
func _someone_in(rect: Rect2i) -> bool:
	for npc in Game.npcs:
		if npc.world == world and npc.visible and Rect2(rect).grow(Npc.RADIUS).has_point(Vector2(npc.position.x, npc.position.z)):
			return true
	return false


func _show_move() -> void:
	var t := player.tile() + player.cardinal()
	if t != _checked:
		_checked = t
		_spot_why = world.move_spot(_moving, t, player.position)
	# Islanders wander about, so they're checked every frame.
	_why = _spot_why if _spot_why != "" or not _someone_in(Rect2i(t, Vector2i.ONE)) else "Someone's standing there!"
	_valid = _why == ""
	_rect = Rect2i(t, Vector2i.ONE)
	var y := world.ground_height(t.x + 0.5, t.y + 0.5)
	_ghost.position = Vector3(t.x + 0.5, y + 0.1 + 0.05 * sin(Time.get_ticks_msec() / 160.0), t.y + 0.5)
	_footprint.position = Vector3(t.x + 0.5, y + 0.03, t.y + 0.5)
	_footprint.scale = Vector3.ONE
	_material.set_shader_parameter("colour", VALID if _valid else INVALID)
	_footprint_material.set_shader_parameter("colour", VALID if _valid else INVALID)
	_footprint_material.set_shader_parameter("tiles", Vector2.ONE)


func _unhandled_input(event: InputEvent) -> void:
	if Game.mode != Game.Mode.PLACING or _asking:
		return
	if not _moving.is_empty():
		_move_input(event)
		return
	if event.is_action_pressed("use"):
		get_viewport().set_input_as_handled()
		if _valid:
			var builds: String = ItemDB.placeable(_item).get("builds", "")
			if builds != "" and not await _confirm(builds):
				return
			if _on_table:
				world.place_on_surface(_item, _rect.position, _rot)
			else:
				world.place_item(_item, _rect, _rot)
				if not _rug and not ItemDB.placeable(_item).get("walk_through", false):
					player.step_back_from(_rect)
			Inventory.remove_from_slot(_slot)
			Journal.add("placed")
			Sfx.play("place")
			if _fence and Inventory.slots[_slot].get("id", "") == _item:
				# More to come: carry on along the line.
				_fence_at = Vector3i(-9999, -9999, 0)
				return
			if builds != "":
				Events.toast.emit("Staked out! It'll be built tonight.")
			else:
				Events.toast.emit("Perfect spot!" if _item != "tent_kit" else "Your tent is up! Welcome home.")
			_end()
		else:
			Events.toast.emit("It won't fit there. Try a flat, clear spot.")
	elif event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_end()
	elif event.is_action_pressed("rotate") and _rotatable:
		_rot = (_rot + 1) % 4


## Buildings are there to stay, so check first. Returns true to build here.
func _confirm(builds: String) -> bool:
	_asking = true
	Game.mode = Game.Mode.MENU
	Game.dialogue.ask("", "Build %s here?" % ItemDB.display_name(builds), ["Build it here", "Somewhere else"])
	var pick: int = await Game.dialogue.picked
	Game.mode = Game.Mode.PLACING
	_asking = false
	return pick == 0


func _move_input(event: InputEvent) -> void:
	if event.is_action_pressed("use"):
		get_viewport().set_input_as_handled()
		if not _valid:
			Events.toast.emit(_why)
			Sfx.play("ui_error", -4.0)
			return
		if _planting:
			world.plant_item(_item, _rect.position)
			Inventory.remove_from_slot(_slot)
		else:
			world.move_object(_moving, _rect.position)
		player.step_back_from(_rect)
		player.model.play("dig")
		Sfx.play("dig")
		Effects.burst("dust", _ghost.position)
		Journal.add("landscaped")
		_end()
	elif event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		if _planting:
			_end()
		elif world.pocket(_moving):
			# Into the pockets instead of back where it was.
			player.model.play("pickup")
			Sfx.play("pop")
			Events.toast.emit("You put the %s in your pockets." % ItemDB.display_name(World.item_for(_moving)).to_lower())
			_end()


## Calls off a move: the thing's back where it was.
func put_back() -> void:
	if _moving.is_empty():
		return
	if _planting:
		_end()
		return
	var node := world.node_of(_moving["uid"])
	if node:
		node.visible = true
	_end()


func _end() -> void:
	visible = false
	_moving = {}
	_planting = false
	_fence = false
	_ghost.scale = Vector3.ONE
	Game.mode = Game.Mode.PLAY
