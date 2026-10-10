class_name Npc
extends Node3D
## An island character standing at their spot: idles, looks round at the player when
## they come near, and turns to face whoever's talking to them. Talking is handled by
## Story; this is just the body.
##
## Neighbours living on the island also have pastimes while they're out, set going by
## `Neighbourhood`: fishing from the shore, catching bugs, chatting with each other,
## sitting on a bench, and playing games with you (hiding, racing). They find their way
## about with `walk_to` (`World.nav_path`).

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
## Where a wanderer keeps to (the plaza, for visitors), or an empty rect for anywhere
## within ROAM of home.
var bounds := Rect2()
## What they carry about ("prop" in characters.json, or neighbours.json for campers): a
## tool, or a held prop's model key.
var prop := ""
## The everyday thing a neighbour has in hand today (`Neighbourhood.daily_prop`), taken
## up again when a pastime's tool is put away.
var everyday := ""
## What they're up to: "" (strolling), "fishing", "bugs", "chat", "sit", "hide" (in a
## game of hide and seek), "race", "home" (walking back), "stretch" (morning stretches on
## the plaza), "visit" (at a friend's door for the evening) or "campfire" (sitting round
## one at dusk), and for how much longer.
var pastime := ""
var pastime_left := 0.0
## The hour they go indoors (later on campfire evenings).
var out_until := 18.0
## Who they're chatting with.
var partner: Npc
## In the rain, chatting: whose umbrella they're under (`shelter`), or that someone's
## under theirs (`sheltering`).
var shelter: Npc
var sheltering := false
var _flourish := 6.0
const WALK := 1.1
const ROAM := 7.0
var _yaw := 0.0
var _hop := 0.0
var _target := Vector3.ZERO
var _wait := 0.0
var _rng := RandomNumberGenerator.new()
## The way being walked (`walk_to`), and how fast.
var _route := PackedVector3Array()
var _route_speed := WALK
var _rerouted := false
## Where a pastime faces (the water, a bench's way, whoever they're chatting with).
var _face := Vector3.ZERO
## Time to the next little thing in a pastime (a cast, a swing of the net, a remark).
var _beat := 0.0
## Fishing: the bobber, the line, and where the bobber floats.
var _bobber: MeshInstance3D
var _line: MeshInstance3D
var _bob_at := Vector3.ZERO
var _bite := false
var _catches: Array[String] = []
var _catch_day := -1
## Sitting: the seat ({position, facing, height}) and where they stood before.
var _seat := {}
var _stood := Vector3.ZERO
var _lift := 0.0
var _seated := false
## A bubble over the head: "..." thinking of moving, "!" with a game in mind, and
## remarks while chatting (`_remark`, for `_remark_left` seconds).
var _bubble: Label3D
var _bubble_check := 0.0
var _remark := ""
var _remark_left := 0.0
var _time := 0.0
var _umbrella_check := 0.0
## Everyone has a favourite umbrella colour.
const UMBRELLAS := ["e0656b", "f2c94e", "6a9ac8", "8cc47a", "f2a7c0", "b9a6e6", "f2a65a", "9fd3c7"]
## Things said with a look while chatting.
const REMARKS := ["ha ha!", "oh!", "really?", "hmm...", "wow!", "no way!", "!", "?", "hee hee", "me too!", "ooh"]


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
	_rng.seed = hash(character_id) + Time.get_ticks_usec()
	model = NpcData.model(character_id)
	add_child(model)
	model.rotation.y = _yaw
	# Neighbours only carry theirs while camping or visiting (`carry`).
	carry("" if NpcData.is_neighbour(character_id) else NpcData.get_character(character_id).get("prop", ""))
	add_to_group("npcs")
	if NpcData.is_neighbour(character_id):
		_bubble = Label3D.new()
		_bubble.font = UIStyle.font(700)
		_bubble.font_size = 96
		_bubble.pixel_size = 0.009
		_bubble.modulate = UIStyle.BROWN
		_bubble.outline_modulate = UIStyle.CREAM
		_bubble.outline_size = 44
		_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bubble.no_depth_test = false
		_bubble.position = Vector3(0, 2.05, 0)
		_bubble.visible = false
		add_child(_bubble)


## Carries `what` about (a tool or a "held:" model key; "" for nothing). Campers carry
## their neighbours.json "prop" while away from home (main.gd `_add_camper`, `_add_visitor`).
func carry(what: String) -> void:
	prop = what
	if model:
		model.set_tool(what)


func _process(delta: float) -> void:
	_time += delta
	_update_bubble(delta)
	_umbrella_check -= delta
	if _umbrella_check <= 0.0:
		_umbrella_check = 1.0
		_check_umbrella()
	if pastime == "":
		_show_off(delta)
	var speed := 0.0
	var look := rest_facing
	var player := Game.player
	var with_me := Story.talking and Game.camera != null and Game.camera.talk_with == self
	if wanders:
		var hour := GameClock.hour_float()
		visible = always_out or (hour >= 7.0 and hour < out_until)
		if not visible:
			if pastime != "":
				stop()
			_route.clear()
			position = home
			return
	if Story.talking:
		pass
	elif not _route.is_empty():
		speed = _follow(delta)
	elif pastime != "":
		speed = _pastime(delta)
	elif wanders:
		speed = _wander(delta)
	if speed > 0.0:
		var ahead := _route[0] if not _route.is_empty() else _target
		look = (ahead - position).normalized()
	elif _face != Vector3.ZERO and not with_me:
		look = _face
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
		model.position.y = _lift + sin((1.0 - _hop / 0.35) * PI) * 0.18
	else:
		model.position.y = _lift
	if _line and _line.visible:
		_line.global_transform = Player.line_between(model.tool_point(Player.ROD_TIP), _bob_at + Vector3(0, 0.08, 0))


## Strolls between spots near home, pausing at each; stops while anyone's talking or
## the player is close by. Returns the walking speed this frame.
func _wander(delta: float) -> float:
	var player := Game.player
	if player and player.world == world and Vector2(player.position.x - position.x, player.position.z - position.z).length() < 1.6:
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
	# The same rule as the player's: no stepping up or down cliffs.
	if not world.is_walkable(next.x, next.z) or not world.can_move(position, next.x, next.z, RADIUS):
		_pick_target()
		return 0.0
	position = Vector3(next.x, world.ground_height(next.x, next.z), next.z)
	return WALK


func _pick_target() -> void:
	for attempt in 8:
		var p := home + Vector3(_rng.randf_range(-ROAM, ROAM), 0, _rng.randf_range(-ROAM, ROAM))
		if bounds.has_area():
			p = Vector3(_rng.randf_range(bounds.position.x, bounds.end.x), 0, _rng.randf_range(bounds.position.y, bounds.end.y))
		# Somewhere on the same level as home (ramps aside, cliffs are in the way).
		if world.is_walkable(p.x, p.z) and world.object_at(floori(p.x), floori(p.z)).is_empty() \
				and absf(world.ground_height(p.x, p.z) - world.ground_height(home.x, home.z)) < 0.3:
			_target = Vector3(p.x, world.ground_height(p.x, p.z), p.z)
			return
	_target = home


# --- Finding the way -----------------------------------------------------------------

## Sets off for `to` by the way `World.nav_path` finds, at `speed`. False if there's no
## way there (they stay put).
func walk_to(to: Vector3, speed: float = WALK) -> bool:
	_route = world.nav_path(position, to)
	_route_speed = speed
	_wait = 0.0
	if _route.is_empty():
		return Vector2(to.x - position.x, to.z - position.z).length() < 0.3
	return true


## True while walking somewhere (`walk_to`).
func on_the_way() -> bool:
	return not _route.is_empty()


func _follow(delta: float) -> float:
	# Walking (not racing), wait for the player to get out of the way.
	var player := Game.player
	if pastime != "race" and player and player.world == world \
			and Vector2(player.position.x - position.x, player.position.z - position.z).length() < 0.8:
		return 0.0
	var next := _route[0]
	var to := Vector2(next.x - position.x, next.z - position.z)
	var step := minf(_route_speed * delta, to.length())
	if to.length() > 0.0001:
		var move := to.normalized() * step
		if world.is_walkable(position.x, position.z) and not world.is_walkable(position.x + move.x * 3.0, position.z + move.y * 3.0):
			# Something's been put down in the way since: find another way round (once),
			# or give up.
			if _rerouted:
				stop()
				return 0.0
			_rerouted = true
			_route = world.nav_path(position, _route[_route.size() - 1])
			if _route.is_empty():
				stop()
			return 0.0
		_rerouted = false
		position.x += move.x
		position.z += move.y
	position.y = world.ground_height(position.x, position.z)
	if to.length() - step < 0.05:
		_route.remove_at(0)
		if not _route.is_empty():
			# Straight on to a later point where the way is clear.
			var skip := world.shortcut(position, _route)
			if skip > 0:
				_route = _route.slice(skip)
	return _route_speed


# --- Pastimes ------------------------------------------------------------------------

## Goes fishing for `seconds`: walks to `stand` and casts into the water at `water`.
func go_fishing(stand: Vector3, water: Vector3, seconds: float) -> bool:
	stop()
	if not walk_to(stand):
		return false
	pastime = "fishing"
	pastime_left = seconds
	_bob_at = water
	_beat = -1.0
	_set_tool(_own_tool("rod"))
	return true


## Goes about with a net for `seconds`, swinging it at bugs now and then.
func catch_bugs(seconds: float) -> void:
	stop()
	pastime = "bugs"
	pastime_left = seconds
	_beat = _rng.randf_range(3.0, 6.0)
	_set_tool(_own_tool("net"))


## Has a chat with `other` for `seconds`, meeting at `stand` (beside them).
func chat_with(other: Npc, stand: Vector3, seconds: float) -> bool:
	stop()
	if stand != Vector3.ZERO and not walk_to(stand):
		return false
	pastime = "chat"
	pastime_left = seconds
	partner = other
	_beat = _rng.randf_range(1.0, 2.5)
	return true


## Goes and sits on a seat (`World.seats` spot) for `seconds`.
func sit_on(seat: Dictionary, seconds: float) -> bool:
	stop()
	var front: Vector3 = seat["position"] + seat["facing"] * 0.75
	if not walk_to(front):
		return false
	pastime = "sit"
	pastime_left = seconds
	_seat = seat
	return true


## Hides at `spot` (in a game of hide and seek), facing `facing`.
func hide_at(spot: Vector3, facing: Vector3) -> void:
	stop()
	position = Vector3(spot.x, world.ground_height(spot.x, spot.z), spot.z)
	pastime = "hide"
	_face = facing
	_yaw = atan2(facing.x, facing.z)


## Runs to `to` as fast as `speed`. False if there's no way there.
func race_to(to: Vector3, speed: float) -> bool:
	stop()
	if not walk_to(to, speed):
		return false
	pastime = "race"
	return true


## Lines up at `spot` for morning stretches, facing the front (`Neighbourhood` calls the
## moves).
func stretch_at(spot: Vector3) -> bool:
	stop()
	if not walk_to(spot):
		return false
	pastime = "stretch"
	_face = Vector3(0, 0, 1)
	return true


## Goes round to a friend's for the evening: waits at `stand` by their door, facing it.
func visit(stand: Vector3, door: Vector3) -> bool:
	stop()
	if not walk_to(stand):
		return false
	pastime = "visit"
	var to := door - stand
	to.y = 0.0
	_face = to.normalized() if to.length() > 0.01 else Vector3(0, 0, -1)
	return true


## Goes and sits by the campfire at `fire`, on the ground at `spot`, toasting a
## marshmallow.
func warm_up(spot: Vector3, fire: Vector3) -> bool:
	stop()
	if not walk_to(spot):
		return false
	pastime = "campfire"
	var to := fire - spot
	to.y = 0.0
	_face = to.normalized() if to.length() > 0.01 else Vector3(0, 0, 1)
	_beat = _rng.randf_range(3.0, 8.0)
	return true


## Walks back home (after a game far from it), then strolls about there again.
func go_home() -> void:
	stop()
	if walk_to(home):
		pastime = "home"


## Puts the pastime away: tools back in the pocket, up off the seat, the line reeled in.
func stop() -> void:
	if _seated:
		model.set_sitting(false)
		if _stood != Vector3.ZERO:
			position = _stood
	_seat = {}
	_seated = false
	_lift = 0.0
	if _bobber:
		_bobber.visible = false
		_line.visible = false
	if model.mode in ["fishing", "floor"]:
		model.mode = ""
	if partner and partner.partner == self and partner.pastime == "chat":
		partner.partner = null
		partner.pastime_left = minf(partner.pastime_left, 0.5)
		if partner.shelter == self:
			partner.shelter = null
		partner.sheltering = false
		partner._umbrella_check = 0.0
	partner = null
	shelter = null
	sheltering = false
	_umbrella_check = 0.0
	_route.clear()
	_face = Vector3.ZERO
	_stood = Vector3.ZERO
	_bite = false
	_remark_left = 0.0
	if pastime in ["fishing", "bugs", "campfire"] or prop != everyday:
		carry(everyday)
	pastime = ""
	pastime_left = 0.0
	_wait = _rng.randf_range(2.0, 6.0)


## Each frame of a pastime once they've got there. Returns the walking speed.
func _pastime(delta: float) -> float:
	pastime_left -= delta
	if pastime_left <= 0.0 and pastime in ["fishing", "bugs", "chat", "sit"]:
		stop()
		return 0.0
	_beat -= delta
	var speed := 0.0
	match pastime:
		"fishing":
			_fishing()
		"bugs":
			if _beat > 0.6:
				speed = _wander(delta)
			elif _beat <= 0.0:
				_swing_net()
		"chat":
			if partner and is_instance_valid(partner):
				var to := partner.position - position
				to.y = 0.0
				if to.length() > 0.01:
					_face = to.normalized()
			if _beat <= 0.0:
				_beat = _rng.randf_range(2.0, 4.5)
				_say_something()
		"sit":
			if not _seated and _seat.size() > 0:
				_sit_down()
		"race", "home":
			# Got there.
			stop()
		"campfire":
			if model.mode != "floor":
				model.mode = "floor"
				_set_tool("held:marshmallow")
			if _beat <= 0.0:
				_beat = _rng.randf_range(5.0, 11.0)
				_remark = ["so cosy", "mmm...", "toasty!", "look, sparks!", "ahh", "one more?"][_rng.randi() % 6]
				_remark_left = 2.0
	return speed


## A rod or a net of their own, by how keen they are.
func _own_tool(kind: String) -> String:
	var best := "sturdy" if Story.hearts(id) >= 3 or NpcData.get_character(id).get("personality", "") == "sporty" else "flimsy"
	return "%s_%s" % [best, kind]


func _set_tool(tool: String) -> void:
	prop = tool
	model.set_tool(tool)


func _fishing() -> void:
	var water := _bob_at - position
	water.y = 0.0
	if water.length() > 0.01:
		_face = water.normalized()
	if _beat > 0.0:
		return
	if _bobber == null:
		_bobber = MeshInstance3D.new()
		_bobber.mesh = Models.get_mesh("bobber")
		_bobber.material_override = Models.material()
		_bobber.top_level = true
		add_child(_bobber)
		_line = Player.fishing_line()
		add_child(_line)
	if not _bobber.visible:
		# Cast, and wait for a bite.
		model.play("cast")
		model.mode = "fishing"
		_bobber.position = _bob_at
		_bobber.visible = true
		_line.visible = true
		_bite = false
		Effects.burst("splash", _bob_at)
		_beat = _rng.randf_range(8.0, 20.0)
	elif not _bite:
		# A bite: the bobber goes under.
		_bite = true
		var tw := _bobber.create_tween()
		tw.tween_property(_bobber, "position:y", _bob_at.y - 0.12, 0.08)
		tw.tween_property(_bobber, "position:y", _bob_at.y, 0.25)
		Effects.burst("bite", _bob_at)
		_beat = 0.5
	else:
		# Reel in: something on the line, more often than not.
		_bobber.visible = false
		_line.visible = false
		model.mode = ""
		if _rng.randf() < 0.7 and world.critters:
			var fish := world.critters.pick(ItemDB.fish, world.critters.water_kind(floori(_bob_at.x), floori(_bob_at.z)), GameClock.hour_float())
			if not fish.is_empty():
				_show_catch(fish["id"], 0.8)
		_beat = _rng.randf_range(2.5, 4.0)


func _swing_net() -> void:
	_beat = _rng.randf_range(4.0, 9.0)
	model.play("net")
	Sfx.play_at("whoosh", global_position, -8.0)
	if _rng.randf() < 0.3 and world.critters:
		var where := "air" if _rng.randf() < 0.6 else "grass"
		var bug := world.critters.pick(ItemDB.bugs, where, GameClock.hour_float())
		if not bug.is_empty():
			# Held up once the swing's come round.
			get_tree().create_timer(0.45).timeout.connect(_show_catch.bind(bug["id"], 2.2))


## What they've caught today (fish and bugs, item ids), to give you one now and then
## (Story._share_catch).
func catches_today() -> Array[String]:
	return _catches if _catch_day == GameClock.day_key() else ([] as Array[String])


## Holds up something just caught, with a cheer.
func _show_catch(item: String, size: float) -> void:
	if _catch_day != GameClock.day_key():
		_catch_day = GameClock.day_key()
		_catches.clear()
	if not item in _catches:
		_catches.append(item)
	model.play("cheer")
	model.hold(Models.get_mesh("drop:" + item), 1.4, size)
	Effects.burst("sparkle", position + Vector3(0, 1.3, 0))
	if Game.player and Game.player.world == world and position.distance_to(Game.player.position) < 12.0:
		Sfx.play_at("jingle_catch", global_position, -10.0)


func _sit_down() -> void:
	_stood = position
	var facing: Vector3 = _seat["facing"]
	position = _seat["position"] - facing * 0.04
	_face = facing
	_yaw = atan2(facing.x, facing.z)
	_lift = float(_seat["height"]) - CharacterParts.HIP_Y + 0.05
	_seated = true
	model.set_sitting(true)


func _say_something() -> void:
	_remark = REMARKS[_rng.randi() % REMARKS.size()]
	_remark_left = 1.6
	if _rng.randf() < 0.25:
		hop()
	elif _rng.randf() < 0.15:
		Effects.burst("hearts", position + Vector3(0, 1.7, 0))


# --- The bubble over the head ----------------------------------------------------------

func _update_bubble(delta: float) -> void:
	if _bubble == null:
		return
	_remark_left -= delta
	_bubble_check -= delta
	if _bubble_check <= 0.0 or (_remark_left <= 0.0 and _bubble.text == _remark and _remark != ""):
		_bubble_check = 0.3
		var text := ""
		var shout := false
		if Story.thinking_of_moving() == id:
			text = "..."
		elif Game.neighbourhood and Game.neighbourhood.calling(id):
			text = "!"
			shout = true
		elif _remark_left > 0.0 and pastime in ["chat", "campfire"]:
			text = _remark
		if text != _bubble.text:
			_bubble.text = text
			_bubble.font_size = 128 if shout else (96 if text == "..." else 56)
			_bubble.modulate = Color("e0794a") if shout else UIStyle.BROWN
		_bubble.visible = text != "" and visible
	if _bubble.visible:
		_bubble.position.y = 2.05 + sin(_time * (5.0 if _bubble.text == "!" else 2.4)) * 0.05


## True if a point is inside the character (for walking into them).
func blocks(px: float, pz: float) -> bool:
	return visible and Vector2(px - position.x, pz - position.z).length() < RADIUS


## Out in the rain or snow, up goes the umbrella (unless they're under a friend's).
func _check_umbrella() -> void:
	var wet := (Weather.rain > 0.1 or Weather.snow > 0.1) and world != null and not world.interior
	var under := wet and shelter != null and is_instance_valid(shelter) and pastime == "chat" and _route.is_empty()
	# The umbrella takes the hand that carries their prop (set first: it puts umbrellas away).
	if prop != "":
		model.set_tool("" if wet else prop)
	model.set_umbrella(UMBRELLAS[absi(hash(id)) % UMBRELLAS.size()] if wet and not under else "")
	model.share_umbrella(wet and sheltering)


## The umbrella a neighbour would give you: theirs is their favourite colour.
static func umbrella_item(character_id: String) -> String:
	const ITEMS := ["umbrella_red", "umbrella_yellow", "umbrella_blue", "umbrella_green", "umbrella_pink", "umbrella_lilac",
		"umbrella_red", "umbrella_green"]
	return ITEMS[absi(hash(character_id)) % ITEMS.size()]


## Now and then someone with a net gives it a practice swing.
func _show_off(delta: float) -> void:
	if not prop.ends_with("_net") or Story.talking:
		return
	_flourish -= delta
	if _flourish <= 0.0:
		_flourish = _rng.randf_range(7.0, 14.0)
		model.play("net")


## A little hop of excitement.
func hop() -> void:
	Sfx.play_at("boing", global_position, -4.0, Sfx.voice_pitch(id) * 0.8)
	_hop = 0.35


func cheer() -> void:
	model.play("cheer")
