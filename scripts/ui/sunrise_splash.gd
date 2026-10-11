class_name SunriseSplash
extends Control
## A little sunrise over the sea, shown when the island moves on to another day (time
## travel, waking up, or the clock passing five in the morning): the sky warms, a smiling
## sun comes up behind an island with a palm tree, birds fly over and the date says hello.
## It covers the screen (`covered`) while the island catches up with the new day.

signal covered
signal done

const FADE_IN := 0.35
const RISE := 2.3
const HOLD := 0.7
const FADE_OUT := 0.45

const NIGHT_TOP := Color("3a3b6e")
const NIGHT_LOW := Color("c47a9c")
const DAY_TOP := Color("8fcbe8")
const DAY_LOW := Color("ffdca3")
const SEA_DAWN := Color("6c66a6")
const SEA_DAY := Color("5fb3d1")
const SEA_DEEP_DAWN := Color("434779")
const SEA_DEEP_DAY := Color("3f8fbd")
const SUN := Color("ffcf5e")
const SUN_LIGHT := Color("fff1b8")
const ISLAND_DAWN := Color("4a3f63")
const ISLAND_DAY := Color("6fae63")

var playing := false
## Stops the clock this many seconds in (for screenshots); below 0 it runs.
var hold_at := -1.0
var _t := 0.0
var _covered := false
var _title: Label
var _date: Label
## Stars and clouds, placed once (fractions of the screen).
var _stars: PackedVector3Array = []
var _clouds: PackedVector3Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 512
	for i in 34:
		_stars.append(Vector3(rng.randf(), rng.randf_range(0.02, 0.5), rng.randf_range(1.2, 2.6)))
	for i in 3:
		_clouds.append(Vector3(rng.randf_range(0.1, 0.9), rng.randf_range(0.14, 0.3), rng.randf_range(0.8, 1.2)))
	_title = _label(64, UIStyle.BROWN, 16)
	_date = _label(30, UIStyle.BROWN_LIGHT, 10)


func _label(font_size: int, colour: Color, outline: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UIStyle.font(700))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", UIStyle.CREAM)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## Starts it: `covered` once the screen's hidden, `done` when it's gone again. A press of
## A or B once it's covering the screen hurries it along.
func play(title: String, date: String) -> void:
	_title.text = title
	_date.text = date
	_t = 0.0
	_covered = false
	playing = true
	visible = true
	modulate.a = 0.0


## Starts it already covering the screen (waking up from the dark of sleep).
func play_from_dark(title: String, date: String) -> void:
	_t = FADE_IN
	_title.text = title
	_date.text = date
	_covered = false
	playing = true
	visible = true
	modulate.a = 1.0


func _process(delta: float) -> void:
	if not playing:
		return
	_t = hold_at if hold_at >= 0.0 else _t + delta
	var total := FADE_IN + RISE + HOLD + FADE_OUT
	modulate.a = clampf(_t / FADE_IN, 0.0, 1.0) if _t < FADE_IN else clampf((total - _t) / FADE_OUT, 0.0, 1.0)
	if not _covered and _t >= FADE_IN:
		_covered = true
		covered.emit()
	var p := _progress()
	var words := clampf((p - 0.55) / 0.3, 0.0, 1.0)
	_title.modulate.a = words
	_date.modulate.a = clampf((p - 0.7) / 0.3, 0.0, 1.0)
	_title.size.x = size.x
	_date.size.x = size.x
	_title.position = Vector2(0, size.y * 0.07 + (1.0 - _ease(words)) * 18.0)
	_date.position = Vector2(0, _title.position.y + _title.size.y - 6)
	queue_redraw()
	if _t >= total:
		playing = false
		visible = false
		done.emit()


func _input(event: InputEvent) -> void:
	if not playing:
		return
	# Nothing behind it takes a press while it's up (the phone's buttons, say).
	get_viewport().set_input_as_handled()
	var press := event.is_action_pressed("use") or event.is_action_pressed("ui_accept") \
		or event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel")
	if press and _covered and _t < FADE_IN + RISE + HOLD - 0.15:
		# On to the fade out.
		_t = FADE_IN + RISE + HOLD - 0.15


## How far up the sun is, 0..1: slow to start, quicker, then settling.
func _progress() -> float:
	return smoothstep(0.0, 1.0, clampf((_t - FADE_IN * 0.5) / RISE, 0.0, 1.0))


static func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var p := _progress()
	var warm := smoothstep(0.0, 1.0, p)
	var horizon := h * 0.64
	# Sky.
	var top := NIGHT_TOP.lerp(DAY_TOP, warm)
	var low := NIGHT_LOW.lerp(DAY_LOW, warm)
	draw_polygon([Vector2(0, 0), Vector2(w, 0), Vector2(w, horizon), Vector2(0, horizon)], [top, top, low, low])
	# Stars, going out as it gets light.
	var star_a := clampf(1.0 - p * 2.2, 0.0, 1.0)
	if star_a > 0.0:
		for s in _stars:
			var twinkle := 0.6 + 0.4 * sin(_t * 3.0 + s.x * 40.0)
			draw_circle(Vector2(s.x * w, s.y * horizon), s.z, Color(1, 1, 0.9, star_a * twinkle))
	# The sun, with a glow and rays turning slowly round it.
	var r := h * 0.1
	var sun := Vector2(w * 0.5, lerpf(horizon + r * 1.3, h * 0.37, p))
	for i in 4:
		draw_circle(sun, r * (1.5 + i * 0.45), Color(SUN_LIGHT, 0.07 * warm + 0.03))
	var rays := clampf((p - 0.25) / 0.5, 0.0, 1.0)
	if rays > 0.0:
		for i in 12:
			var a := _t * 0.25 + i * TAU / 12.0
			var reach := r * (1.45 + 0.12 * sin(_t * 2.0 + i))
			var side := Vector2.from_angle(a + PI * 0.5) * r * 0.16
			var dir := Vector2.from_angle(a)
			draw_colored_polygon([sun + dir * r * 1.15 + side, sun + dir * reach, sun + dir * r * 1.15 - side], Color(SUN, 0.75 * rays))
	draw_circle(sun, r, SUN)
	draw_circle(sun + Vector2(-r * 0.28, -r * 0.3), r * 0.42, Color(SUN_LIGHT, 0.55))
	# A sleepy happy face: closed eyes and rosy cheeks.
	var face := Color("8a5a3c")
	for side in [-1.0, 1.0]:
		var eye := sun + Vector2(side * r * 0.36, -r * 0.02)
		draw_arc(eye, r * 0.14, PI * 1.1, PI * 1.9, 8, face, maxf(2.0, r * 0.06), true)
		draw_circle(sun + Vector2(side * r * 0.56, r * 0.24), r * 0.13, Color("f29a8a", 0.7))
	draw_arc(sun + Vector2(0, r * 0.18), r * 0.16, PI * 0.15, PI * 0.85, 8, face, maxf(2.0, r * 0.06), true)
	# Clouds drifting by.
	for c in _clouds:
		var at := Vector2(fposmod(c.x + _t * 0.012 * c.z, 1.2) * w - w * 0.1, c.y * h)
		_cloud(at, h * 0.045 * c.z, Color("fff6ea").lerp(Color("f6c2c8"), 1.0 - warm))
	# The sea covers the bottom of the sun until it's up.
	var sea := SEA_DAWN.lerp(SEA_DAY, warm)
	var deep := SEA_DEEP_DAWN.lerp(SEA_DEEP_DAY, warm)
	draw_polygon([Vector2(0, horizon), Vector2(w, horizon), Vector2(w, h), Vector2(0, h)], [sea, sea, deep, deep])
	# The sun's path on the water.
	for i in 9:
		var y := horizon + 10.0 + i * (h - horizon) * 0.1
		var half := r * (0.9 - i * 0.07) * (0.8 + 0.2 * sin(_t * 4.0 + i * 1.7))
		draw_line(Vector2(sun.x - half, y), Vector2(sun.x + half, y), Color(SUN_LIGHT, 0.5 * (0.35 + warm * 0.65) * (1.0 - i * 0.08)), 5.0, true)
	# Little waves.
	for i in 7:
		var y := horizon + (h - horizon) * (0.22 + 0.11 * i)
		var x := fposmod(i * 0.37 + _t * 0.03 * (1 + i % 2), 1.0) * w
		draw_line(Vector2(x - 22, y), Vector2(x + 22, y), Color(1, 1, 1, 0.25), 4.0, true)
	_island(Vector2(w * 0.24, horizon), h * 0.09, ISLAND_DAWN.lerp(ISLAND_DAY, warm))
	_island(Vector2(w * 0.8, horizon), h * 0.045, ISLAND_DAWN.lerp(ISLAND_DAY, warm).darkened(0.08))
	# Birds flying over once it's light.
	if p > 0.3:
		for i in 3:
			var fly := (_t - FADE_IN) * 0.07 + i * 0.05
			var at := Vector2((0.15 + fly) * w + i * 34.0, h * (0.2 + 0.04 * i) + sin(_t * 2.0 + i) * 6.0)
			var flap := sin(_t * 9.0 + i * 2.0) * 0.5
			var span := h * 0.018
			draw_polyline([at + Vector2(-span, -span * (0.4 + flap)), at, at + Vector2(span, -span * (0.4 + flap))], Color("5a4a5e", clampf((p - 0.3) * 3.0, 0.0, 1.0)), 3.0, true)


func _cloud(at: Vector2, s: float, colour: Color) -> void:
	draw_circle(at + Vector2(-s * 1.1, s * 0.25), s * 0.7, colour)
	draw_circle(at + Vector2(s * 1.1, s * 0.3), s * 0.65, colour)
	draw_circle(at + Vector2(-s * 0.3, -s * 0.15), s, colour)
	draw_circle(at + Vector2(s * 0.45, -s * 0.05), s * 0.85, colour)
	draw_rect(Rect2(at + Vector2(-s * 1.1, s * 0.1), Vector2(s * 2.2, s * 0.85)), colour)


## A round little island on the horizon; the big one has a palm tree.
func _island(at: Vector2, s: float, colour: Color) -> void:
	var pts: PackedVector2Array = []
	for i in 17:
		var a := PI + i * PI / 16.0
		pts.append(at + Vector2(cos(a) * s * 2.2, sin(a) * s))
	draw_colored_polygon(pts, colour)
	if s < 30.0:
		return
	var trunk_col := colour.darkened(0.25)
	var base := at + Vector2(s * 0.5, -s * 0.85)
	var crown := base + Vector2(s * 0.35, -s * 1.5)
	var trunk: PackedVector2Array = []
	for i in 7:
		var f := i / 6.0
		trunk.append(base.lerp(crown, f) + Vector2(sin(f * PI) * -s * 0.18, 0))
	draw_polyline(trunk, trunk_col, s * 0.16, true)
	var leaf := colour.lightened(0.05)
	for i in 5:
		var a := -PI * 0.95 + i * PI * 0.22 + sin(_t * 1.5 + i) * 0.04
		var tip := crown + Vector2.from_angle(a) * s * 1.0 + Vector2(0, s * 0.35 * absf(cos(a)))
		var mid := crown.lerp(tip, 0.5) + Vector2.from_angle(a - PI * 0.5) * s * 0.18
		draw_colored_polygon([crown, mid, tip, crown.lerp(tip, 0.55)], leaf)
	draw_circle(crown, s * 0.13, trunk_col)
