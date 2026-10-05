extends Node
## Background music by the island clock (assets/music): morning pieces from 6am to noon,
## afternoon ones until 6pm, evening ones through the night. The two pieces of each part
## of the day take turns hour by hour, each looping until its hour is up, and one fades
## into the next. On the title screen the clock is the real time.

const TRACKS := {
	"morning": ["res://assets/music/morning_1.mp3", "res://assets/music/morning_2.mp3"],
	"afternoon": ["res://assets/music/afternoon_1.mp3", "res://assets/music/afternoon_2.mp3"],
	"evening": ["res://assets/music/night_1.mp3", "res://assets/music/night_2.mp3"],
}
const FADE_TIME := 4.0
## How loud the music plays, 0 to 1.
const VOLUME := 0.7

var enabled := true
var _players: Array[AudioStreamPlayer] = []
## Which player is fading in (the other fades out).
var _front := 0
var _mix := 1.0
var _track := ""
var _check := 0.0
var _streams: Dictionary = {}


func _ready() -> void:
	# No music in screenshots, tests and other headless runs, or with --mute.
	enabled = DisplayServer.get_name() != "headless" and not Game.args.has("screenshot") and not Game.args.has("mute")
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = linear_to_db(0.0)
		add_child(p)
		_players.append(p)


## Morning, afternoon or evening at this hour.
static func part_of_day(hour: float) -> String:
	if hour >= 6.0 and hour < 12.0:
		return "morning"
	if hour >= 12.0 and hour < 18.0:
		return "afternoon"
	return "evening"


## The piece for this hour: the part of the day's two, turn about by the hour.
static func track_for(hour: float) -> String:
	var pieces: Array = TRACKS[part_of_day(hour)]
	return pieces[int(floor(hour)) % pieces.size()]


func _process(delta: float) -> void:
	if not enabled:
		return
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		var wanted := track_for(GameClock.hour_float())
		if wanted != _track:
			_switch_to(wanted)
	if _mix < 1.0:
		_mix = minf(1.0, _mix + delta / FADE_TIME)
		_apply_mix()
		if _mix >= 1.0:
			_players[1 - _front].stop()


func _switch_to(path: String) -> void:
	_track = path
	if not _streams.has(path):
		var stream: AudioStream = load(path)
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		_streams[path] = stream
	# Whatever's playing fades out on the other player.
	_front = 1 - _front
	var p := _players[_front]
	p.stream = _streams[path]
	p.play()
	_mix = 0.0
	_apply_mix()


func _apply_mix() -> void:
	_players[_front].volume_db = linear_to_db(maxf(_mix * VOLUME, 0.0001))
	_players[1 - _front].volume_db = linear_to_db(maxf((1.0 - _mix) * VOLUME, 0.0001))
