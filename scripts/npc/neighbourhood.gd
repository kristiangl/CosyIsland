class_name Neighbourhood
extends Node
## What the neighbours who live on the island get up to while they're out (each one's
## `Npc.pastime`), and the games they ask you to play. Made by main.gd (`Game.neighbourhood`).
##
## Every few seconds anyone strolling about may take up something to do for a while, by
## their personality and the weather (LIKES): fishing from a shore near home, catching
## bugs, a chat with another neighbour, a sit on a bench or a stump. Most days they have
## something in hand as well (`daily_prop`: a takeaway coffee, a juice box, the paper...).
##
## A few times a day one of them has a game in mind and shows a "!" over their head
## (`calling`). Talking to them (Story._game_offer) starts it (`start`):
##   "hide"   hide and seek: they and a couple of others hide behind trees and houses
##            while you count, and you've HIDE_TIME to find them all (walk up to them);
##   "catch"  catch them a particular fish or bug that's about right now, in CATCH_TIME;
##   "race"   a race to somewhere (the plaza, Marlow's dock, Lucy's shop...), with a
##            flag at the finish: first one there wins.
## The HUD shows how it's going (`Hud.show_game`). After, whoever asked has a "!" again
## until you talk to them (Story._game_result): a present if you won.

const THINK := 2.0
## The chance, each THINK, that someone strolling about takes up a pastime.
const TAKE_UP := 0.07
const HIDE_TIME := 150.0
const CATCH_TIME := 180.0
const RACE_TIME := 120.0
## How long someone waits with a "!" before giving up on asking.
const OFFER_TIME := 240.0
const GAMES_PER_DAY := 3
## How close you have to get to a hider to find them, and to the flag to finish a race.
const FIND := 1.5
const FINISH := 1.7
## How fast each kind of neighbour runs a race (the player runs at Player.RUN_SPEED).
const RACE_SPEED := {"sporty": 5.6, "cheerful": 5.0, "bookish": 4.6, "sleepy": 4.3}
## What each kind of neighbour likes to do, and how much.
const LIKES := {
	"cheerful": {"chat": 4.0, "bugs": 2.0, "fishing": 1.0, "sit": 1.0},
	"bookish": {"sit": 4.0, "chat": 2.0, "fishing": 2.0, "bugs": 1.0},
	"sporty": {"bugs": 4.0, "fishing": 3.0, "chat": 2.0, "sit": 1.0},
	"sleepy": {"sit": 4.0, "fishing": 2.0, "chat": 1.0, "bugs": 0.5},
}
## Which games each kind of neighbour likes to ask for.
const GAMES := {
	"cheerful": {"hide": 3.0, "race": 1.0, "catch": 1.0},
	"bookish": {"catch": 3.0, "hide": 1.0, "race": 1.0},
	"sporty": {"race": 3.0, "catch": 1.0, "hide": 1.0},
	"sleepy": {"hide": 2.0, "catch": 2.0, "race": 0.5},
}
## Things to have in hand for the day (Models "held:" keys), and extra ones by personality.
const EVERYDAY := ["coffee_cup", "juice_box", "lollipop", "parcel", "tote", "ice_cream", "bouquet"]
const EVERYDAY_LIKES := {
	"cheerful": ["balloon", "lollipop", "ice_cream", "bouquet"],
	"bookish": ["newspaper", "book", "teacup", "coffee_cup"],
	"sporty": ["juice_box", "ball", "frisbee"],
	"sleepy": ["coffee_cup", "mug", "teddy", "coffee_cup"],
}

## A game someone's asking to play: {"by", "game", "left"} and the game's details
## ("what" to catch; "at" and "name" of the finish).
var offer := {}
## The game being played: {"kind", "by", "left"}, and "hiders" and "found" (ids) for hide
## and seek, "what" for catching, "at" and "name" for a race.
var game := {}
## How the last game went, until it's talked over: {"by", "game", "won"} (+ "what").
var result := {}
var hud: Hud
## Whether neighbours take up pastimes and ask to play of their own accord (off for
## screenshots and tests).
var spontaneous := true
var _think := 1.0
## Seconds until someone might next ask to play.
var _next_offer := 0.0
var _rng := RandomNumberGenerator.new()
var _flag: MeshInstance3D
var _status_check := 0.0
## Shore spots near each neighbour's home to fish from: id -> [{"stand", "water"}].
var _fishing_spots := {}


func _ready() -> void:
	_rng.randomize()
	_next_offer = _rng.randf_range(90.0, 180.0)
	Events.day_changed.connect(func(_key: int): _new_day())
	Events.caught.connect(_on_caught)


## The neighbours living on the island who are out of doors right now.
func residents() -> Array[Npc]:
	var out: Array[Npc] = []
	for n in Game.npcs:
		if is_instance_valid(n) and n.wanders and not n.visiting and not n.always_out and NpcData.is_neighbour(n.id) \
				and n.world == Game.island and n.visible:
			out.append(n)
	return out


## Something to have in hand all day, or "" (about half the days).
static func daily_prop(id: String, day: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id) + day * 131
	if rng.randf() < 0.45:
		return ""
	var pool: Array = EVERYDAY + EVERYDAY_LIKES.get(NpcData.get_character(id).get("personality", "cheerful"), [])
	return "held:" + String(pool[rng.randi() % pool.size()])


func _new_day() -> void:
	_stretch_time = 0.0
	for n in Game.npcs:
		if is_instance_valid(n) and n.wanders and not n.visiting and NpcData.is_neighbour(n.id):
			n.everyday = daily_prop(n.id, GameClock.day_key())
			n.out_until = 18.0
			if n.pastime == "":
				n.carry(n.everyday)


## The island's moved on to another day (`Main._catch_up`, under the sunrise): any game
## is called off and every neighbour starts the day afresh from their front door.
func fresh_start() -> void:
	_new_day()
	if not game.is_empty():
		game = {}
		if _flag:
			_flag.visible = false
		if hud:
			hud.hide_game()
	offer = {}
	for n in Game.npcs:
		if is_instance_valid(n) and n.wanders and not n.visiting and not n.always_out and NpcData.is_neighbour(n.id) \
				and n.world == Game.island:
			n.restart()


func _process(delta: float) -> void:
	var island := Game.island
	if island == null:
		return
	# The way-finding graph gets built a bit at a time.
	var ready := island.prepare_nav(2500)
	if Game.mode == Game.Mode.PLAY:
		_play(delta)
	_stretching(delta)
	_think -= delta
	if _think > 0.0 or not ready:
		return
	_think = THINK
	if not spontaneous:
		return
	var wet := Weather.rain > 0.1 or Weather.snow > 0.1
	routine(GameClock.hour_float(), wet)
	for n in residents():
		if wet and n.pastime in ["fishing", "bugs", "sit"]:
			n.stop()
		elif n.pastime == "" and not n.on_the_way() and not _in_game(n.id) and _rng.randf() < TAKE_UP:
			take_up(n, _choose(LIKES.get(NpcData.get_character(n.id).get("personality", "cheerful"), LIKES["cheerful"]), wet))
	if Game.mode == Game.Mode.PLAY:
		_maybe_offer()


func _choose(weights: Dictionary, wet: bool) -> String:
	var total := 0.0
	for what: String in weights:
		if not wet or what == "chat":
			total += float(weights[what])
	var roll := _rng.randf() * total
	for what: String in weights:
		if not wet or what == "chat":
			roll -= float(weights[what])
			if roll <= 0.0:
				return what
	return ""


## Sets `n` off on a pastime ("fishing", "bugs", "chat" or "sit"). False if there's
## nowhere to do it (no shore near, nobody to chat with, no free seat).
func take_up(n: Npc, what: String) -> bool:
	match what:
		"fishing":
			var spot := _fishing_spot(n)
			return not spot.is_empty() and n.go_fishing(spot["stand"], spot["water"], _rng.randf_range(60.0, 150.0))
		"bugs":
			n.catch_bugs(_rng.randf_range(50.0, 110.0))
			return true
		"chat":
			return _start_chat(n)
		"sit":
			var seat := _free_seat(n)
			return not seat.is_empty() and n.sit_on(seat, _rng.randf_range(40.0, 100.0))
	return false


func _start_chat(n: Npc) -> bool:
	var best: Npc = null
	for other in residents():
		if other != n and other.pastime in ["", "sit"] and not other.on_the_way() and not _in_game(other.id) \
				and other.position.distance_to(n.position) < 22.0 and (best == null or other.position.distance_to(n.position) < best.position.distance_to(n.position)):
			best = other
	if best == null:
		return false
	# Meet beside them, on whichever side there's room.
	var away := n.position - best.position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3(1, 0, 0)
	# In the rain they huddle under one umbrella.
	var wet := Weather.rain > 0.1 or Weather.snow > 0.1
	for turn: float in [0.0, 0.8, -0.8, 1.6, -1.6]:
		var stand := best.position + away.rotated(Vector3.UP, turn) * (0.75 if wet else 1.1)
		if Game.island.can_move(Vector3(stand.x, Game.island.ground_height(stand.x, stand.z), stand.z), stand.x, stand.z, Npc.RADIUS):
			var seconds := _rng.randf_range(30.0, 60.0)
			if n.chat_with(best, stand, seconds):
				best.chat_with(n, Vector3.ZERO, seconds + 15.0)
				if wet:
					n.shelter = best
					best.sheltering = true
				return true
			return false
	return false


## A shore spot near `n`'s home to fish from: {"stand", "water"}, or {}.
func _fishing_spot(n: Npc) -> Dictionary:
	var w := Game.island
	if w.critters == null:
		return {}
	if not _fishing_spots.has(n.id):
		var spots: Array[Dictionary] = []
		var c := Vector2i(floori(n.home.x), floori(n.home.z))
		var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for z in range(c.y - 16, c.y + 17):
			for x in range(c.x - 16, c.x + 17):
				if not w.data.in_bounds(x, z) or not w.is_walkable(x + 0.5, z + 0.5):
					continue
				for d: Vector2i in dirs:
					# Only look properly where there's water a couple of tiles off.
					if w.critters.water_kind(x + d.x * 2, z + d.y * 2) == "":
						continue
					var stand := Vector3(x + 0.5, w.ground_height(x + 0.5, z + 0.5), z + 0.5)
					var water: Variant = w.critters.cast_spot(stand, Vector3(d.x, 0, d.y))
					if water != null and w.can_move(stand, stand.x, stand.z, Npc.RADIUS):
						spots.append({"stand": stand, "water": water})
		_fishing_spots[n.id] = spots
	var choices: Array = _fishing_spots[n.id].duplicate()
	while not choices.is_empty():
		var spot: Dictionary = choices.pop_at(_rng.randi() % choices.size())
		var taken := false
		for other in residents():
			if other != n and other.pastime == "fishing" and other._bob_at.distance_to(spot["water"]) < 2.5:
				taken = true
		if not taken:
			return spot
	return {}


## A seat outside near `n` that nobody's on (a bench, a stump...): a `World.seats` spot,
## or {}.
func _free_seat(n: Npc) -> Dictionary:
	var w := Game.island
	var near: Array[Dictionary] = []
	for obj in w.objects():
		if obj["kind"] != "stump" and not (obj["kind"] == "placed" and ItemDB.placeable(obj["item"]).has("seat") \
				and not ItemDB.placeable(obj["item"]).get("bed", false)):
			continue
		if Vector2(obj["x"] - n.position.x, obj["z"] - n.position.z).length() > 16.0:
			continue
		for spot: Dictionary in w.seats(obj):
			var free := not (Game.player and Game.player.is_sitting() and Game.player.position.distance_to(spot["position"]) < 0.6)
			for other in residents():
				if other != n and (other.position.distance_to(spot["position"]) < 0.6 or (other._seat.size() > 0 and other._seat["position"].distance_to(spot["position"]) < 0.1)):
					free = false
			if free:
				near.append(spot)
	return {} if near.is_empty() else near[_rng.randi() % near.size()]


# --- The day's routine -----------------------------------------------------------------

## Morning stretches on the plaza from STRETCH_FROM till STRETCH_TO on dry days, the
## moves called in time (`_stretching`), which you can join in with (`join_stretches`);
## a friend going round to another's for the evening (`visits`: waiting by their door
## from VISIT_FROM, then inside with them until VISIT_TO); and on evenings with a campfire
## lit outside, gathering round it until CAMPFIRE_TO.
const STRETCH_FROM := 7.0
const STRETCH_TO := 8.0
## Reach up, touch your toes, a wave side to side, a jump, arms out.
const STRETCHES := ["cheer", "pickup", "wave", "jump", "shake"]
const STRETCH_BEAT := 1.9
## How long you have to stretch along with everyone for their thanks (once a day).
const STRETCH_SECONDS := 40.0
const VISIT_FROM := 17.3
const VISIT_TO := 22.0
const CAMPFIRE_FROM := 17.0
const CAMPFIRE_TO := 20.0
var _stretch_beat := 0.0
var _stretch_move := 0
var _stretch_time := 0.0
var _stretch_spots: Array[Vector3] = []
var _stretch_day := -1
## Tonight's visits (guest -> host), for `_visits_day`.
var _visits := {}
var _visits_day := -1


## Keeps everyone to the day's routine (each THINK): stretches, visits, the campfire.
func routine(hour: float, wet: bool) -> void:
	var stretch_time := hour >= STRETCH_FROM and hour < STRETCH_TO and not wet
	var spots := stretch_spots() if stretch_time else ([] as Array[Vector3])
	var fire := campfire() if hour >= CAMPFIRE_FROM and hour < CAMPFIRE_TO else {}
	var slot := 0
	for n in residents():
		if _in_game(n.id):
			continue
		if stretch_time:
			if n.pastime != "stretch" and slot < spots.size():
				n.stretch_at(spots[slot])
			slot += 1
			continue
		if n.pastime == "stretch":
			# All done: off home again.
			n.go_home()
		var host := host_of(n.id)
		if host != "" and hour >= VISIT_FROM and n.pastime != "visit":
			var house := Game.island.building_of(host)
			if not house.is_empty():
				var door := Game.island.outside_door(house)
				var side := Vector3(door["facing"].z, 0, -door["facing"].x)
				n.out_until = 18.0
				n.visit(door["position"] + side * 0.9 + door["facing"] * 0.4, door["position"])
			continue
		if not fire.is_empty() and n.pastime != "campfire" and host == "" and guest_of(n.id) == "" and (hash(n.id) + GameClock.day_key()) % 3 != 0:
			var at := _fireside(fire, n)
			if at != Vector3.ZERO and n.warm_up(at, _fire_at(fire)):
				n.out_until = CAMPFIRE_TO
	if not stretch_time and Game.player and Game.player.stretching:
		Game.player.stretching = false


## Calls the moves for morning stretches, and counts how long you've joined in.
func _stretching(delta: float) -> void:
	var hour := GameClock.hour_float()
	if hour < STRETCH_FROM or hour >= STRETCH_TO:
		return
	_stretch_beat -= delta
	var player := Game.player
	if _stretch_beat <= 0.0:
		_stretch_beat = STRETCH_BEAT
		var move: String = STRETCHES[_stretch_move % STRETCHES.size()]
		_stretch_move += 1
		for n in residents():
			if n.pastime == "stretch" and not n.on_the_way():
				n.model.play(move)
		if player and player.stretching:
			player.model.play(move)
	if player and player.stretching and Game.mode == Game.Mode.PLAY:
		_stretch_time += delta
		if _stretch_time >= STRETCH_SECONDS and int(Story.flags.get("stretched", -1)) != GameClock.day_key():
			Story.flags["stretched"] = GameClock.day_key()
			Journal.add("stretches")
			for n in residents():
				if n.pastime == "stretch":
					Story.befriend(n.id, 1)
					n.hop()
			Effects.burst("sparkle", player.position + Vector3(0, 1.4, 0))
			Sfx.play("jingle_ding", -2.0, 1.0, 0.0)
			Events.toast.emit("What a lovely stretch! Everyone's feeling limber.")


## Where everyone stands for stretches: a row across the middle of the plaza, facing
## the front, with room for you at the end (worked out once a day).
func stretch_spots() -> Array[Vector3]:
	if _stretch_day == GameClock.day_key() and not _stretch_spots.is_empty():
		return _stretch_spots
	_stretch_day = GameClock.day_key()
	_stretch_spots.clear()
	var w := Game.island
	var plaza := w.data.plaza
	if not plaza.has_area():
		return _stretch_spots
	var c := Vector2(plaza.get_center())
	for row in 4:
		for k in 12:
			var x := c.x + (k / 2 + 0.5) * 1.3 * (1 if k % 2 == 0 else -1)
			var at := Vector3(x, 0, c.y + 1.0 + row * 1.3)
			at.y = w.ground_height(at.x, at.z)
			if _stretch_spots.size() < 7 and plaza.grow(1).has_point(Vector2i(floori(at.x), floori(at.z))) \
					and w.can_move(at, at.x, at.z, Npc.RADIUS) and _stretch_spots.all(func(p): return p.distance_to(at) > 1.1):
				_stretch_spots.append(at)
	return _stretch_spots


## Joins in with the stretches: you take the next free place in the row.
func join_stretches() -> void:
	var player := Game.player
	var spots := stretch_spots()
	if player == null or spots.is_empty():
		return
	var taken := 0
	for n in residents():
		if n.pastime == "stretch":
			taken += 1
	var at: Vector3 = spots[mini(taken, spots.size() - 1)]
	player.position = at
	player.facing = Vector3(0, 0, 1)
	player.stretching = true
	_stretch_time = 0.0


## Tonight's visits: guest -> host, one or two a night (if there's anyone to visit),
## the same all day.
func visits(day: int) -> Dictionary:
	if _visits_day == day:
		return _visits
	_visits_day = day
	_visits = {}
	if Game.island == null:
		return _visits
	var ids: Array = []
	for obj in Game.island.objects():
		if obj.has("resident") and not obj["resident"] in ids:
			ids.append(obj["resident"])
	ids.sort()
	if ids.size() < 2:
		return _visits
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 977 + 13
	for i in (1 if ids.size() < 4 else 2):
		if rng.randf() < 0.6:
			var guest: String = ids[rng.randi() % ids.size()]
			var host: String = ids[rng.randi() % ids.size()]
			if guest != host and not _visits.has(guest) and not _visits.has(host) and not guest in _visits.values() and not host in _visits.values():
				_visits[guest] = host
	return _visits


## Whose home `guest` is going round to this evening ("" if nobody's).
func host_of(guest: String) -> String:
	return visits(GameClock.day_key()).get(guest, "")


## Who's coming round to `host`'s this evening ("" if nobody).
func guest_of(host: String) -> String:
	var tonight := visits(GameClock.day_key())
	for guest: String in tonight:
		if tonight[guest] == host:
			return guest
	return ""


## A campfire outside on the island, near the plaza if there are several ({} if none).
func campfire() -> Dictionary:
	var w := Game.island
	var best := {}
	var plaza := Vector2(w.data.plaza.get_center())
	for obj in w.objects():
		if obj["kind"] == "placed" and obj["item"] == "campfire" \
				and (best.is_empty() or Vector2(obj["x"], obj["z"]).distance_to(plaza) < Vector2(best["x"], best["z"]).distance_to(plaza)):
			best = obj
	return best


func _fire_at(fire: Dictionary) -> Vector3:
	var fp: Array = ItemDB.placeable(fire["item"])["footprint"]
	return Vector3(fire["x"] + fp[0] * 0.5, 0, fire["z"] + fp[1] * 0.5)


## A place on the ground round the fire nobody else has taken, that `n` can get to.
func _fireside(fire: Dictionary, n: Npc) -> Vector3:
	var w := Game.island
	var centre := _fire_at(fire)
	for i in 8:
		var a := TAU * i / 8.0 + 0.4
		var at := centre + Vector3(cos(a), 0, sin(a)) * 1.45
		at.y = w.ground_height(at.x, at.z)
		var free := w.can_move(at, at.x, at.z, Npc.RADIUS)
		for other in residents():
			if other != n and (other.position.distance_to(at) < 0.8 or (other.on_the_way() and other._route[other._route.size() - 1].distance_to(at) < 0.8)):
				free = false
		if free and not w.nav_path(n.position, at).is_empty():
			return at
	return Vector3.ZERO


# --- Games ---------------------------------------------------------------------------

## True if `id` has a "!" over their head: wanting to play, or wanting to talk about how
## a game went.
func calling(id: String) -> bool:
	return offer.get("by", "") == id or result.get("by", "") == id


func _in_game(id: String) -> bool:
	return game.get("by", "") == id or id in game.get("hiders", []) or offer.get("by", "") == id or result.get("by", "") == id


## Games played so far today.
func played_today() -> int:
	var log: Dictionary = Story.flags.get("games", {})
	return int(log.get("count", 0)) if int(log.get("day", -1)) == GameClock.day_key() else 0


func _maybe_offer() -> void:
	if not offer.is_empty() or not game.is_empty() or not result.is_empty() or Story.talking:
		return
	_next_offer -= THINK
	if _next_offer > 0.0 or played_today() >= GAMES_PER_DAY:
		return
	var player := Game.player
	if player == null or player.world != Game.island or player.landscaping != "":
		return
	var near: Array[Npc] = []
	var met: Array = Story.flags.get("met_neighbours", [])
	for n in residents():
		if n.id in met and n.pastime in ["", "sit", "bugs"] and n.position.distance_to(player.position) < 25.0:
			near.append(n)
	if near.is_empty():
		return
	var n: Npc = near[_rng.randi() % near.size()]
	var weights: Dictionary = GAMES.get(NpcData.get_character(n.id).get("personality", "cheerful"), GAMES["cheerful"])
	# A weighted shuffle: each game draws once, the best draw is asked first.
	var kinds: Array = weights.keys()
	var draw := {}
	for kind: String in kinds:
		draw[kind] = _rng.randf() * float(weights[kind])
	kinds.sort_custom(func(a, b): return draw[a] > draw[b])
	for kind: String in kinds:
		if make_offer(n, kind):
			return
	_next_offer = 60.0


## `n` would like to play `kind`: a "!" goes up over their head. False if that game
## can't be played just now (nothing to catch at this hour, nowhere to race to).
func make_offer(n: Npc, kind: String) -> bool:
	var details := {}
	match kind:
		"catch":
			var what := _something_to_catch()
			if what == "":
				return false
			details["what"] = what
		"race":
			var goal := _race_goal(n)
			if goal.is_empty():
				return false
			details = goal
	offer = {"by": n.id, "game": kind, "left": OFFER_TIME}
	offer.merge(details)
	if n.pastime != "":
		n.stop()
	return true


## The offer `id` is making ({} if none).
func offer_for(id: String) -> Dictionary:
	return offer if offer.get("by", "") == id else {}


## How the game `id` asked for went ({} if there's nothing to talk about).
func result_for(id: String) -> Dictionary:
	return result if result.get("by", "") == id else {}


func clear_result() -> void:
	result = {}


## Not now: they'll ask again another time.
func decline() -> void:
	offer = {}
	_next_offer = _rng.randf_range(300.0, 600.0)


## A fish or bug that's about right now and not too rare (an item id), or "".
func _something_to_catch() -> String:
	var w := Game.island
	if w.critters == null:
		return ""
	var hour := GameClock.hour_float()
	var waters := w.critters.waters()
	var pool: Array[String] = []
	for c: Dictionary in ItemDB.fish.values() + ItemDB.bugs.values():
		var fish := ItemDB.fish.has(c["id"])
		if int(c.get("weight", 1)) < 4 or not Critters._in_hours(c, hour) or not Critters.weather_suits(c) \
				or not Critters.lives_here(c, w.data.kind) or (fish and not c["where"] in waters):
			continue
		pool.append(c["id"])
	pool.sort()
	return "" if pool.is_empty() else pool[_rng.randi() % pool.size()]


## Somewhere to race `n` to: {"at", "name"}, a good run away but not too far, that you
## can get to as well; or {}.
func _race_goal(n: Npc) -> Dictionary:
	var w := Game.island
	var goals: Array[Dictionary] = []
	var plaza := Main.visitor_spot(w, Vector2.ZERO)
	if not plaza.is_empty():
		goals.append({"at": plaza["at"], "name": "the plaza"})
	var dock := w.building("dock")
	if not dock.is_empty():
		goals.append({"at": w.dock_spots(dock)["arrive"], "name": "Marlow's dock"})
	for place: Array in [["lucy_shop", "Lucy's shop"], ["tailor_shop", "the tailors'"], ["museum_tent", "the museum tent"],
			["museum", "the museum"], ["island_office", "Poppy's office"]]:
		var obj := w.building(place[0])
		if not obj.is_empty():
			goals.append({"at": w.outside_door(obj)["position"], "name": place[1]})
	while not goals.is_empty():
		var goal: Dictionary = goals.pop_at(_rng.randi() % goals.size())
		var way := w.nav_path(n.position, goal["at"])
		var length := _length(n.position, way)
		if way.is_empty() or length < 12.0 or length > 80.0:
			continue
		# A fair race: about as far for you as for them.
		if Game.player:
			var yours := w.nav_path(Game.player.position, goal["at"])
			if yours.is_empty() or _length(Game.player.position, yours) < 12.0:
				continue
		return goal
	return {}


static func _length(from: Vector3, way: PackedVector3Array) -> float:
	var total := 0.0
	var at := from
	for p in way:
		total += Vector2(p.x - at.x, p.z - at.z).length()
		at = p
	return total


## Starts the game `n` asked for (in the middle of talking to them: Story._game_offer).
## Hide and seek fades out while everyone hides.
func start(n: Npc) -> void:
	if offer.get("by", "") != n.id:
		return
	Story.flags["games"] = {"day": GameClock.day_key(), "count": played_today() + 1}
	game = offer.duplicate()
	game["kind"] = offer["game"]
	game.erase("game")
	offer = {}
	match game["kind"]:
		"hide":
			game["left"] = HIDE_TIME
			game["hiders"] = []
			game["found"] = []
			game["hiding"] = true
			await _hide_everyone(n)
			game.erase("hiding")
		"catch":
			game["left"] = CATCH_TIME
		"race":
			game["left"] = RACE_TIME
			_put_flag(game["at"])
	_status_check = 0.0


## Hide and seek: `n` and up to two others hide while the screen's dark.
func _hide_everyone(n: Npc) -> void:
	var hiders: Array[Npc] = [n]
	for other in residents():
		if other != n and hiders.size() < 3 and not _in_game(other.id) and other.pastime != "race":
			hiders.append(other)
	var spots := hiding_spots(hiders.size(), Game.player.position if Game.player else n.position)
	if hud:
		await hud.fade_out()
	var ids: Array = []
	for i in mini(hiders.size(), spots.size()):
		hiders[i].hide_at(spots[i]["at"], spots[i]["facing"])
		ids.append(hiders[i].id)
	game["hiders"] = ids
	if ids.is_empty():
		# Nowhere to hide: call it off.
		game = {}
	if hud:
		await get_tree().create_timer(0.4).timeout
		await hud.fade_in()


## Places to hide out of sight of the camera: just north of trees and buildings (behind
## them as you look), well away from `from`, spread out, and somewhere you can get to.
## [{"at", "facing"}].
func hiding_spots(count: int, from: Vector3) -> Array[Dictionary]:
	var w := Game.island
	var candidates: Array[Dictionary] = []
	for obj in w.objects():
		var tall: bool = obj["kind"] in ["tree", "fruit_tree", "palm"] or (obj["kind"] == "placed" and ItemDB.placeable(obj["item"]).has("room"))
		if not tall:
			continue
		var width := int(obj.get("w", 1))
		var x: int = obj["x"] + _rng.randi() % maxi(1, width)
		var z: int = obj["z"] - 1
		var at := Vector3(x + 0.5, w.ground_height(x + 0.5, z + 0.5), z + 0.5)
		var away := Vector2(at.x - from.x, at.z - from.z).length()
		if away < 8.0 or away > 35.0 or not w.can_move(at, at.x, at.z, Npc.RADIUS):
			continue
		candidates.append({"at": at, "facing": Vector3(0, 0, 1)})
	var spots: Array[Dictionary] = []
	while spots.size() < count and not candidates.is_empty():
		var spot: Dictionary = candidates.pop_at(_rng.randi() % candidates.size())
		var apart := true
		for s: Dictionary in spots:
			apart = apart and s["at"].distance_to(spot["at"]) > 6.0
		if apart and not w.nav_path(from, spot["at"]).is_empty():
			spots.append(spot)
	return spots


func _put_flag(at: Vector3) -> void:
	if _flag == null:
		_flag = MeshInstance3D.new()
		_flag.mesh = Models.get_mesh("goal_flag")
		_flag.material_override = Models.material()
		_flag.scale = Vector3.ONE * 1.5
	if _flag.get_parent() != Game.island:
		if _flag.get_parent():
			_flag.get_parent().remove_child(_flag)
		Game.island.add_child(_flag)
	_flag.position = at + Vector3(0.6, 0, 0)
	_flag.visible = true


## Ready, steady, go! (big on the screen), then off runs whoever you're racing.
func count_down(n: Npc) -> void:
	for word: String in ["3", "2", "1"]:
		if hud:
			hud.big_note(word)
		Sfx.play("ui_move", 0.0, 0.9, 0.0)
		await get_tree().create_timer(0.7).timeout
	if hud:
		hud.big_note("Go!")
	Sfx.play("jingle_ding", 0.0, 1.0, 0.0)
	var speed: float = RACE_SPEED.get(NpcData.get_character(n.id).get("personality", "cheerful"), 5.0)
	if game.get("kind", "") != "race":
		return
	if n.race_to(game["at"], speed):
		game["off"] = true
	else:
		game = {}


## Ticks the offer and the game while you're free to play.
func _play(delta: float) -> void:
	if not offer.is_empty():
		offer["left"] = float(offer["left"]) - delta
		var by := Story.npc(offer["by"])
		if float(offer["left"]) <= 0.0 or by == null or not by.visible:
			decline()
	if not result.is_empty():
		var by := Story.npc(result["by"])
		if by == null or not by.visible:
			result = {}
		elif result.get("come_over", false) and Game.player and not by.on_the_way() and not Story.talking \
				and by.position.distance_to(Game.player.position) < 3.0:
			# Back from the finish (or found last): straight into telling you about it.
			result.erase("come_over")
			Story.talk_to(by)
	# Nothing counts while everyone's hiding, or before the off in a race.
	if game.is_empty() or game.get("hiding", false) or (game["kind"] == "race" and not game.get("off", false)):
		if hud:
			hud.hide_game()
		return
	var player := Game.player
	var outside := player != null and player.world == Game.island
	if game["kind"] == "race" and not outside:
		_finish(false)
		return
	if outside:
		game["left"] = float(game["left"]) - delta
	match game["kind"]:
		"hide":
			_seek(player, outside)
		"race":
			_race(player)
		"catch":
			if float(game["left"]) <= 0.0:
				Events.toast.emit("Time's up! No %s this time." % ItemDB.display_name(game["what"]).to_lower())
				_finish(false)
	_status_check -= delta
	if not game.is_empty() and _status_check <= 0.0 and hud:
		_status_check = 0.25
		hud.show_game(status())


## What the HUD says about the game being played.
func status() -> String:
	var clock := "%d:%02d" % [maxi(0, ceili(float(game.get("left", 0.0)))) / 60, maxi(0, ceili(float(game.get("left", 0.0)))) % 60]
	match game.get("kind", ""):
		"hide":
			return "Hide and seek   Found %d of %d   %s" % [game["found"].size(), game["hiders"].size(), clock]
		"catch":
			return "Catch a %s for %s   %s" % [ItemDB.display_name(game["what"]).to_lower(), NpcData.display_name(game["by"]), clock]
		"race":
			return "Race %s to %s!   %s" % [NpcData.display_name(game["by"]), game["name"], clock]
	return ""


func _seek(player: Player, outside: bool) -> void:
	var found: Array = game["found"]
	for id: String in game["hiders"]:
		if id in found:
			continue
		var hider := Story.npc(id)
		if hider == null:
			found.append(id)
			continue
		if outside and Vector2(hider.position.x - player.position.x, hider.position.z - player.position.z).length() < FIND:
			found.append(id)
			hider.hop()
			Effects.burst("sparkle", hider.position + Vector3(0, 1.4, 0))
			Sfx.play("jingle_ding", -4.0, 1.0, 0.0)
			Events.toast.emit("Found %s! (%d of %d)" % [NpcData.display_name(id), found.size(), game["hiders"].size()])
			if id != game["by"]:
				hider.go_home()
			else:
				hider.stop()
	if found.size() == game["hiders"].size():
		_finish(true)
	elif float(game["left"]) <= 0.0:
		var left: Array[String] = []
		for id: String in game["hiders"]:
			if not id in found and Story.npc(id):
				left.append(NpcData.display_name(id))
				Story.npc(id).hop()
				Story.npc(id).go_home()
		Events.toast.emit("Time's up! %s %s still hiding." % [" and ".join(left), "was" if left.size() == 1 else "were"])
		_finish(false)


func _race(player: Player) -> void:
	var by := Story.npc(game["by"])
	if Vector2(player.position.x - game["at"].x, player.position.z - game["at"].z).length() < FINISH:
		Effects.burst("confetti", player.position + Vector3(0, 1.0, 0))
		Sfx.play("jingle_catch", 0.0, 1.0, 0.0)
		Events.toast.emit("You win!")
		_finish(true)
	elif by == null or by.pastime != "race" or float(game["left"]) <= 0.0:
		if by:
			by.cheer()
			Effects.burst("confetti", by.position + Vector3(0, 1.0, 0))
		Events.toast.emit("%s wins the race!" % NpcData.display_name(game["by"]))
		_finish(false)


func _on_caught(id: String) -> void:
	if game.get("kind", "") == "catch" and game["what"] == id:
		Events.toast.emit("That's the %s! Go and show %s." % [ItemDB.display_name(id).to_lower(), NpcData.display_name(game["by"])])
		_finish(true)


func _finish(won: bool) -> void:
	result = {"by": game["by"], "game": game["kind"], "won": won, "what": game.get("what", ""), "name": game.get("name", "")}
	var by := Story.npc(game["by"])
	if by and Game.player:
		match game["kind"]:
			"hide":
				# Whoever asked comes over to say well done (or where they were).
				var near := Game.player.position + (by.position - Game.player.position).normalized() * 1.2
				result["come_over"] = by.walk_to(near)
			"race":
				result["come_over"] = true
	game = {}
	if _flag:
		_flag.visible = false
	if hud:
		hud.hide_game()
	_next_offer = _rng.randf_range(240.0, 480.0)
