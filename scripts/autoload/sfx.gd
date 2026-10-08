extends Node
## Sound effects (assets/sfx, built by tools/make_sfx.sh) and the island's ambience.
##
## play(name) picks one of a sound's takes (name_1, name_2... or just name) at random and
## nudges its pitch so repeats don't sound mechanical; play_at() fades it with distance
## from the player. voice() babbles a letter of what a character says, pitched to suit
## them. The ambience round the player follows the place and the weather: birds by day,
## crickets on dry nights, waves near the sea, a stream by the rivers and ponds, rain and
## wind from Weather, and only the rain on the roof indoors. Silent headless, in
## screenshots and with --mute; "Sounds" in the phone's Options turns it all off.

const DIR := "res://assets/sfx/"
const SETTINGS := "user://settings.cfg"
## One-shots playing at once at most.
const VOICES := 16
## Ambience layers: name -> loop file.
const LAYERS := {"rain": "rain_loop", "wind": "wind_loop", "waves": "waves_loop", "stream": "stream_loop",
	"crickets": "crickets_loop"}
## How loud each layer gets at full strength (dB).
const LAYER_DB := {"rain": -6.0, "wind": -10.0, "waves": -8.0, "stream": -12.0, "crickets": -14.0}
## Voice pitch by animal kind, nudged per character so no two sound quite alike.
const SPECIES_PITCH := {"cat": 1.3, "dog": 1.05, "rabbit": 1.45, "ferret": 1.25, "mouse": 1.7, "bird": 1.55}
## Footstep sounds by surface: [sound, pitch, volume dB].
const STEPS := {"grass": ["step_grass", 1.0, 0.0], "stone": ["step_stone", 1.05, -1.0], "wood": ["step_wood", 1.0, -1.0],
	"snow": ["step_snow", 1.0, 0.0], "sand": ["step_snow", 0.72, -3.0], "carpet": ["step_carpet", 1.0, 0.0]}

var enabled := true
## Turned off in the options (kept in user://settings.cfg, for every save file).
var muted := false:
	set(value):
		muted = value
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS)
		cfg.set_value("sound", "sfx_off", value)
		cfg.save(SETTINGS)
		if value:
			for p in _pool:
				p.stop()
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _layers: Dictionary = {}
var _targets: Dictionary = {}
var _check := 0.0
var _bird_wait := 3.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	enabled = DisplayServer.get_name() != "headless" and not Game.args.has("screenshot") and not Game.args.has("mute")
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		muted = bool(cfg.get_value("sound", "sfx_off", false))
	_rng.randomize()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for layer: String in LAYERS:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_layers[layer] = p
		_targets[layer] = 0.0
	if enabled:
		get_viewport().gui_focus_changed.connect(_on_focus_changed)


## A sound's takes, loaded the first time it's asked for.
func takes(sound: String) -> Array:
	if not _streams.has(sound):
		var found: Array = []
		if ResourceLoader.exists(DIR + sound + ".ogg"):
			found.append(load(DIR + sound + ".ogg"))
		for n in range(1, 10):
			var path := "%s%s_%d.ogg" % [DIR, sound, n]
			if not ResourceLoader.exists(path):
				break
			found.append(load(path))
		_streams[sound] = found
	return _streams[sound]


## Plays a sound once (a random take, a little higher or lower each time by `vary`).
func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0, vary: float = 0.06) -> void:
	if not enabled or muted:
		return
	var found := takes(sound)
	if found.is_empty():
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = found[_rng.randi() % found.size()]
	if sound.begins_with("jingle"):
		Music.duck(p.stream.get_length() + 0.3)
	p.volume_db = volume_db
	p.pitch_scale = pitch * _rng.randf_range(1.0 - vary, 1.0 + vary)
	p.play()


## Plays a sound from somewhere in the world: quieter the further it is from the player,
## and not at all from another island or room.
func play_at(sound: String, at: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var player := Game.player
	if player == null:
		return
	var d := Vector2(at.x - player.position.x, at.z - player.position.z).length()
	if d > 16.0:
		return
	play(sound, volume_db - d * 1.2, pitch)


## Plays a sound after `seconds` (thunder after the flash, say).
func play_later(sound: String, seconds: float, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	await get_tree().create_timer(seconds).timeout
	play(sound, volume_db, pitch, 0.1)


## A character's babble for one letter of what they're saying: vowels sound like
## themselves, other letters like a vowel near them, all at the speaker's pitch.
func voice(speaker: String, letter: String) -> void:
	var l := letter.to_lower()
	if l == "" or not l.unicode_at(0) in range(97, 123):
		return
	var vowels: Array[String] = ["a", "e", "i", "o", "u"]
	var vowel: String = l if l in vowels else vowels[l.unicode_at(0) % 5]
	play("voice_" + vowel, -6.0, voice_pitch(speaker), 0.07)


## How high a character's voice is.
static func voice_pitch(speaker: String) -> float:
	var def := NpcData.get_character(speaker)
	var species = def.get("species", {})
	var kind: String = species.get("kind", "") if species is Dictionary else ""
	var base: float = SPECIES_PITCH.get(kind, 1.2) * (0.9 + float(absi(hash(speaker)) % 21) / 100.0)
	return float(def.get("voice", base))


## A footstep on whatever's underfoot (World.step_surface).
func step(surface: String, running: bool) -> void:
	var s: Array = STEPS.get(surface, STEPS["grass"])
	play(s[0], s[2] + (1.5 if running else 0.0), s[1], 0.1)


func _on_focus_changed(control: Control) -> void:
	if control is BaseButton and Game.mode == Game.Mode.MENU:
		play("ui_move", -4.0, 1.0, 0.03)


func _input(event: InputEvent) -> void:
	if not enabled or Game.mode != Game.Mode.MENU or event.is_echo():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is BaseButton and event.is_action_pressed("ui_accept"):
		play("ui_select", -3.0, 1.0, 0.03)
	elif event.is_action_pressed("ui_cancel"):
		play("ui_back", -3.0, 1.0, 0.03)


# --- Ambience --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not enabled:
		return
	_check -= delta
	if _check <= 0.0:
		_check = 0.3
		_aim()
	for layer: String in _layers:
		var p: AudioStreamPlayer = _layers[layer]
		var want: float = 0.0 if muted else _targets[layer]
		var now := db_to_linear(p.volume_db) if p.playing else 0.0
		var level := move_toward(now, want, delta * 0.5)
		if level > 0.001:
			if not p.playing:
				p.stream = _loop(LAYERS[layer])
				p.play()
			p.volume_db = linear_to_db(level) + LAYER_DB[layer]
		elif p.playing:
			p.stop()
	_birds(delta)


func _loop(sound: String) -> AudioStream:
	var found := takes(sound)
	if found.is_empty():
		return null
	var s: AudioStream = found[0]
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	return s


## Works out how loud each layer should be where the player is now.
func _aim() -> void:
	var w := Game.world
	var player := Game.player
	for layer: String in _targets:
		_targets[layer] = 0.0
	if w == null or player == null or Game.player.get_parent() == null:
		return
	var outdoors := not w.interior
	_targets["rain"] = clampf(Weather.rain + Weather.storm * 0.3, 0.0, 1.0) * (1.0 if outdoors else 0.35)
	if not outdoors:
		return
	_targets["wind"] = clampf(0.15 + (Weather.wind - 1.0) * 0.55, 0.0, 1.0)
	var night := DayNight.glow_at(GameClock.hour_float())
	var dry := Weather.rain < 0.1 and Weather.snow < 0.1
	_targets["crickets"] = night * (1.0 if dry and Weather.season != "winter" else 0.0) * 0.8
	# Near the sea and the rivers: how close is the nearest?
	var here := player.tile()
	var sea := 99.0
	var fresh := 99.0
	for dz in range(-8, 9):
		for dx in range(-8, 9):
			var t := w.data.tile(here.x + dx, here.y + dz)
			var d := Vector2(dx, dz).length()
			if t == IslandData.Tile.OCEAN:
				sea = minf(sea, d)
			elif t == IslandData.Tile.WATER:
				fresh = minf(fresh, d)
	_targets["waves"] = clampf(1.0 - (sea - 2.0) / 7.0, 0.0, 1.0)
	_targets["stream"] = clampf(1.0 - (fresh - 1.0) / 4.0, 0.0, 1.0)


## Birds sing now and then on dry days outdoors, most of all in the early morning.
func _birds(delta: float) -> void:
	_bird_wait -= delta
	if _bird_wait > 0.0:
		return
	var hour := GameClock.hour_float()
	var dawn := hour >= 5.0 and hour < 9.0
	_bird_wait = _rng.randf_range(1.0, 3.5) if dawn else _rng.randf_range(3.0, 9.0)
	var w := Game.world
	if w == null or w.interior or hour < 5.0 or hour > 18.5 or Weather.rain > 0.1 or Weather.snow > 0.1:
		return
	play("bird_%d" % _rng.randi_range(1, 4), _rng.randf_range(-16.0, -9.0), _rng.randf_range(0.85, 1.2), 0.0)
