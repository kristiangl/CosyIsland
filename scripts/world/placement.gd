class_name Placement
extends Node3D
## Grid placement mode: shows a ghost of the item in front of the player, snapped to
## the grid. A places it, B cancels, R / right bumper rotates.

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
	if world.interior and def.get("structure", false):
		Events.toast.emit("That needs to go outside.")
		return
	_slot = slot
	_item = item
	_size = Vector2i(def["footprint"][0], def["footprint"][1])
	_rotatable = def.get("rotatable", true)
	_small = def.get("small", false)
	_rug = def.get("rug", false)
	_rot = 0
	# Building kits show the building itself, to see how it'll sit.
	var ghost: String = def.get("model", "drop:" + item)
	if def.has("ghost"):
		ghost = ItemDB.placeable(def["ghost"]).get("model", ghost)
	_ghost.mesh = Models.get_mesh(ghost)
	visible = true
	Game.mode = Game.Mode.PLACING
	Events.toast.emit(Prompts.fill("Where should it go? {use} to place, {rotate} to turn, {cancel} to put it away."))


func _process(_delta: float) -> void:
	if Game.mode != Game.Mode.PLACING:
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
			_valid = world.can_place(_rect, player.position) and world.door_clear(_item, _rect, _rot)
	var centre := Vector2(_rect.position) + Vector2(_rect.size) * 0.5
	var y := world.ground_height(centre.x, centre.y)
	if _on_table:
		y += world.surface_height(front.x, front.y)
	_ghost.position = Vector3(centre.x, y + 0.02, centre.y)
	_ghost.rotation.y = -PI * 0.5 * _rot
	_footprint.position = Vector3(centre.x, y + 0.03, centre.y)
	_footprint.scale = Vector3(_rect.size.x, 1, _rect.size.y)
	_material.set_shader_parameter("colour", VALID if _valid else INVALID)
	_footprint_material.set_shader_parameter("colour", VALID if _valid else INVALID)
	_footprint_material.set_shader_parameter("tiles", Vector2(_rect.size))
	# A little hop so it reads as "held, not yet placed".
	_ghost.position.y += 0.06 + 0.04 * sin(Time.get_ticks_msec() / 160.0)


func _unhandled_input(event: InputEvent) -> void:
	if Game.mode != Game.Mode.PLACING or _asking:
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
			Inventory.remove_from_slot(_slot)
			Journal.add("placed")
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


func _end() -> void:
	visible = false
	Game.mode = Game.Mode.PLAY
