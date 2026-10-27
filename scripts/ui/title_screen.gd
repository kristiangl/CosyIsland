class_name TitleScreen
extends Control
## The title screen: a short splash, then the main menu. Continue goes back into the
## file played last; each of the three files can be played, or (under its File options)
## exported as a copy to take to another computer, started over or deleted, asking twice
## first; an empty file starts a new island. Import a file brings a copy in. Runs
## started from the command line
## with game options (--new, --slot, --seed, --demo, --screenshot...) skip straight into
## the game, so the tools keep working.
##
##   --title            show the title screen anyway (with --screenshot: the menu)
##   --title=splash     the splash, for a screenshot (--title=island: the live 3D island
##                      the backdrop picture is rendered from)
##   --title=file       the actions for file 1 (--title=options: its file options,
##                      --title=confirm and --title=sure: asking before deleting,
##                      --title=export: a copy of it saved, --title=import: bringing one in)

const GAME_SCENE := "res://scenes/main.tscn"
## Options that mean "go straight into the game".
const DIRECT := ["new", "slot", "seed", "demo", "screenshot", "ui", "at", "view"]
const SPLASH_TIME := 2.2
## Buttons for things that can't be undone.
const DANGER := Color("c4554a")
## Rendered from TitleBackdrop: --title=island --screenshot=... at 1920x1080 (see CLAUDE.md).
const BACKDROP := "res://assets/title/backdrop.jpg"

var _curtain: ColorRect
var _splash: Control
var _menu: Control
var _files: VBoxContainer
var _continue: Button
var _popup_holder: CenterContainer
var _popup: PanelContainer
var _popup_box: VBoxContainer
var _thumbs: CharacterThumbs
var _fade: ColorRect
var _busy := false
var _splash_left := 0.0


func _ready() -> void:
	var title_arg: String = Game.args.get("title", "none") if Game.args.has("title") else "none"
	if skips_title(Game.args):
		_start_game.call_deferred(-1, false)
		return
	Game.mode = Game.Mode.MENU
	theme = UIStyle.theme()
	set_anchors_preset(PRESET_FULL_RECT)
	# A picture of an island from out at sea (rendered by --title=island), with
	# butterflies flitting about in front of it.
	var picture := TextureRect.new()
	picture.texture = load(BACKDROP)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_preset(PRESET_FULL_RECT)
	add_child(picture)
	add_child(TitleButterflies.new())
	# A cream curtain behind the splash; it lifts to show the island once it's built.
	_curtain = ColorRect.new()
	_curtain.color = UIStyle.CREAM
	_curtain.set_anchors_preset(PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_curtain)
	_thumbs = CharacterThumbs.new()
	add_child(_thumbs)
	_thumbs.thumb_ready.connect(func(_key): _refresh_portraits())
	_build_menu()
	_build_splash()
	_fade = ColorRect.new()
	_fade.color = Color(0.99, 0.96, 0.88, 0.0)
	_fade.set_anchors_preset(PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	if title_arg == "splash" or title_arg == "none":
		_show_splash()
	elif title_arg == "island":
		# The live island the picture is rendered from.
		_curtain.visible = false
		_menu.visible = false
		var backdrop := TitleBackdrop.new()
		add_child(backdrop)
		backdrop.build({})
	else:
		_show_menu()
		if title_arg == "import":
			_import_list()
		elif title_arg in ["file", "options", "confirm", "sure", "export"] and SaveGame.has_save(1):
			match title_arg:
				"export":
					_export(1)
				"file":
					_file_actions(1)
				"options":
					_file_options(1)
				"confirm":
					_confirm_delete(1, false)
				"sure":
					_really_delete(1, false)
	if Game.args.has("screenshot"):
		Game.screenshot(Game.args["screenshot"], int(Game.args.get("frames", "30")))


## Whether these command-line options go straight into the game.
static func skips_title(args: Dictionary) -> bool:
	return not args.has("title") and DIRECT.any(func(k): return args.has(k))


func _process(delta: float) -> void:
	if _splash and _splash.visible and _splash_left > 0.0 and not Game.args.has("screenshot"):
		_splash_left -= delta
		var shown := SPLASH_TIME - _splash_left
		_splash.modulate.a = clampf(minf(shown / 0.5, _splash_left / 0.5), 0.0, 1.0)
		if _splash_left <= 0.0:
			_show_menu()


func _input(event: InputEvent) -> void:
	# Any button skips the splash.
	if _splash and _splash.visible and _splash_left > 0.0 and event.is_pressed() and not event.is_echo() \
			and not Game.args.has("screenshot"):
		get_viewport().set_input_as_handled()
		_splash_left = minf(_splash_left, 0.25)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _popup_holder.visible and not _busy:
		get_viewport().set_input_as_handled()
		_close_popup()


# --- Splash ----------------------------------------------------------------------------

func _build_splash() -> void:
	_splash = CenterContainer.new()
	_splash.set_anchors_preset(PRESET_FULL_RECT)
	_splash.visible = false
	add_child(_splash)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	_splash.add_child(box)
	box.add_child(_Leaf.new())
	box.add_child(_title_label(96))
	var sub := Label.new()
	sub.text = "a little island of your own"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	box.add_child(sub)


func _show_splash() -> void:
	_menu.visible = false
	_splash.visible = true
	_splash.modulate.a = 1.0 if Game.args.has("screenshot") else 0.0
	_splash_left = SPLASH_TIME if not Game.args.has("screenshot") else 999.0


# --- Menu ------------------------------------------------------------------------------

func _build_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.set_anchors_preset(PRESET_CENTER_TOP)
	# Right of centre, leaving the island on the left clear.
	_menu.anchor_left = 0.66
	_menu.anchor_right = 0.66
	_menu.offset_left = -260
	_menu.offset_right = 260
	_menu.offset_top = 36
	_menu.add_theme_constant_override("separation", 10)
	add_child(_menu)
	var title := _title_label(72)
	_menu.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	_menu.add_child(gap)
	_continue = Button.new()
	_continue.custom_minimum_size = Vector2(0, 52)
	_continue.add_theme_font_size_override("font_size", 24)
	_continue.pressed.connect(func(): _start_game(SaveGame.latest(), false))
	_menu.add_child(_continue)
	_files = VBoxContainer.new()
	_files.add_theme_constant_override("separation", 10)
	_menu.add_child(_files)
	var bring := Button.new()
	bring.text = "Import a file"
	bring.custom_minimum_size = Vector2(0, 44)
	bring.pressed.connect(func(): if not _busy: _import_list())
	_menu.add_child(bring)
	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(0, 44)
	quit.pressed.connect(func(): get_tree().quit())
	# (In a browser you just close the tab.)
	quit.visible = not OS.has_feature("web")
	_menu.add_child(quit)
	var hint := Label.new()
	hint.text = "Files are saved as you play."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	_menu.add_child(hint)
	# The popup for a file's actions, and for asking before deleting.
	_popup_holder = CenterContainer.new()
	_popup_holder.set_anchors_preset(PRESET_FULL_RECT)
	_popup_holder.visible = false
	add_child(_popup_holder)
	_popup = PanelContainer.new()
	_popup.custom_minimum_size = Vector2(380, 0)
	_popup_box = VBoxContainer.new()
	_popup_box.add_theme_constant_override("separation", 10)
	_popup.add_child(_popup_box)
	_popup_holder.add_child(_popup)


func _title_label(font_size: int) -> Label:
	var l := Label.new()
	l.text = "Cosy Island"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UIStyle.font(640))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", UIStyle.BROWN)
	l.add_theme_color_override("font_outline_color", UIStyle.CREAM)
	l.add_theme_constant_override("outline_size", font_size / 6)
	return l


func _show_menu() -> void:
	_splash.visible = false
	_splash_left = 0.0
	_menu.visible = true
	if Game.args.has("screenshot"):
		_curtain.visible = false
	else:
		create_tween().tween_property(_curtain, "modulate:a", 0.0, 0.8)
	_refresh_files()


## Rebuilds the file cards from what's saved, and focuses the obvious choice.
func _refresh_files() -> void:
	for child in _files.get_children():
		child.queue_free()
	var latest := SaveGame.latest()
	_continue.visible = latest > 0
	if latest > 0:
		var s := SaveGame.summary(latest)
		_continue.text = "Continue on %s Island" % _island_of(s)
	var cards: Array[Button] = []
	for n in range(1, SaveGame.SLOTS + 1):
		var card := FileCard.new(n, SaveGame.summary(n), _thumbs)
		card.pressed.connect(_on_file_pressed.bind(n))
		_files.add_child(card)
		cards.append(card)
	if latest > 0:
		_continue.grab_focus.call_deferred()
	else:
		cards[0].grab_focus.call_deferred()


func _refresh_portraits() -> void:
	for card in _files.get_children():
		card.queue_redraw()


static func _island_of(s: Dictionary) -> String:
	var name: String = s.get("island_name", "")
	return name if name != "" else "your"


func _on_file_pressed(n: int) -> void:
	if _busy:
		return
	if SaveGame.has_save(n):
		_file_actions(n)
	else:
		_start_game(n, true)


# --- Popups ----------------------------------------------------------------------------

func _open_popup(heading: String, note: String, options: Array) -> void:
	for child in _popup_box.get_children():
		_popup_box.remove_child(child)
		child.queue_free()
	var h := Label.new()
	h.text = heading
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_size_override("font_size", 26)
	_popup_box.add_child(h)
	if note != "":
		var l := Label.new()
		l.text = note
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(330, 0)
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
		_popup_box.add_child(l)
	var first: Button = null
	for opt: Array in options:
		var b := Button.new()
		b.text = opt[0]
		b.custom_minimum_size = Vector2(0, 46)
		b.pressed.connect(opt[1])
		if opt.size() > 2 and opt[2] == "danger":
			# Things that can't be undone are in red.
			for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
				b.add_theme_color_override(state, DANGER)
		_popup_box.add_child(b)
		if first == null:
			first = b
	_popup_holder.visible = true
	_popup.reset_size()
	_menu.modulate.a = 0.45
	_set_menu_focus(false)
	first.grab_focus.call_deferred()


func _close_popup() -> void:
	_popup_holder.visible = false
	_menu.modulate.a = 1.0
	_set_menu_focus(true)
	_refresh_files()


func _set_menu_focus(on: bool) -> void:
	for b in [_continue] + _files.get_children():
		(b as Control).focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	for child in _menu.get_children():
		if child is Button:
			child.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE


func _file_actions(n: int) -> void:
	var s := SaveGame.summary(n)
	_open_popup("File %d: %s Island" % [n, _island_of(s)], FileCard.details(s), [
		["Play", func(): _start_game(n, false)],
		["File options", func(): _file_options(n)],
		["Back", _close_popup],
	])


## Starting over and deleting, tucked away from Play so they're not pressed by accident.
func _file_options(n: int) -> void:
	var s := SaveGame.summary(n)
	_open_popup("File %d options" % n, "%s Island" % _island_of(s), [
		["Back", func(): _file_actions(n)],
		["Export a copy", func(): _export(n)],
		["Start over", func(): _confirm_delete(n, true), "danger"],
		["Delete this file", func(): _confirm_delete(n, false), "danger"],
	])


## Asks once...
func _confirm_delete(n: int, then_new: bool) -> void:
	var s := SaveGame.summary(n)
	var who: String = s.get("player_name", "")
	_open_popup("Start over?" if then_new else "Delete this file?",
		"%s Island%s will be gone for good." % [_island_of(s), (" and everything %s has made" % who) if who != "" else ""], [
		["Keep it", func(): _file_options(n)],
		["Start a new island" if then_new else "Delete it", func(): _really_delete(n, then_new), "danger"],
	])


## ...and once more, just to be sure.
func _really_delete(n: int, then_new: bool) -> void:
	_open_popup("Are you really sure?", "There's no getting it back afterwards.", [
		["No, keep it", func(): _file_options(n)],
		["Yes, start over" if then_new else "Yes, delete it", func():
			SaveGame.delete(n)
			if then_new:
				_start_game(n, true)
			else:
				_close_popup(), "danger"],
	])


# --- Moving files between computers ------------------------------------------------------

## Whether this computer has its own file dialog (PC and Mac do).
static func _native_files() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)


## Saves a copy of file `n` in Documents/Cosy Island, to take to another computer (in a
## browser, to its downloads).
func _export(n: int) -> void:
	if OS.has_feature("web"):
		var name := SaveGame.download_file(n)
		_open_popup("Copy saved", "Your browser has saved it as \"%s\" (usually in Downloads).\n\nTo carry on somewhere else, choose Import a file on the title screen there and pick it." % name,
			[["OK", _close_popup]])
		return
	var to := SaveGame.export_file(n)
	if to == "":
		_open_popup("Couldn't export", "Something went wrong saving the copy. Is the Documents folder full or locked?",
			[["Back", func(): _file_options(n)]])
		return
	var options: Array = [["OK", _close_popup]]
	if OS.has_feature("pc"):
		options.append(["Show it in its folder", func(): OS.shell_show_in_file_manager(to)])
	if _native_files():
		options.append(["Save another copy somewhere else", func(): _export_elsewhere(n)])
	_open_popup("Copy saved", "It's in %s, called \"%s\".\n\nPut it on the other computer (in Documents, Downloads or the Desktop), then choose Import a file on the title screen there."
		% [to.get_base_dir(), to.get_file()], options)


## A copy of file `n` wherever the player chooses, with the system's save dialog.
func _export_elsewhere(n: int) -> void:
	var island: String = SaveGame.summary(n).get("island_name", "")
	var name := SaveGame.safe_name("%s Island.%s" % [island if island != "" else "My", SaveGame.EXPORT_EXT])
	DisplayServer.file_dialog_show("Save a copy of file %d" % n, SaveGame.export_dir(), name, false,
		DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray(["*.%s ; Cosy Island files" % SaveGame.EXPORT_EXT]),
		func(ok: bool, paths: PackedStringArray, _filter: int):
			if ok and not paths.is_empty():
				_exported_elsewhere.call_deferred(n, paths[0]))


func _exported_elsewhere(n: int, to: String) -> void:
	if to.get_extension().to_lower() != SaveGame.EXPORT_EXT:
		to += "." + SaveGame.EXPORT_EXT
	if SaveGame.export_to(n, to) == OK:
		_open_popup("Copy saved", "It's at %s." % to, [["OK", _close_popup]])
	else:
		_open_popup("Couldn't export", "Something went wrong saving the copy there.", [["Back", func(): _file_options(n)]])


## The copies found on this computer to bring in, newest first (in a browser, its own
## file picker).
func _import_list() -> void:
	if OS.has_feature("web"):
		_open_popup("Import a file", "Pick a .%s file you saved from Cosy Island." % SaveGame.EXPORT_EXT, [
			["Choose a file...", _import_from_browser],
			["Back", _close_popup],
		])
		return
	var found := SaveGame.copies_found()
	var options: Array = []
	for copy: Dictionary in found:
		options.append([copy["name"], func(): _import_from(copy["path"])])
	if _native_files():
		options.append(["Choose a file...", _import_picker])
	options.append(["Back", _close_popup])
	var where := "Documents, Downloads or the Desktop"
	_open_popup("Import a file",
		"Pick a copy to bring in." if not found.is_empty() else "No copies found yet. Put a .%s file in %s and it'll show up here." % [SaveGame.EXPORT_EXT, where],
		options)


func _import_picker() -> void:
	DisplayServer.file_dialog_show("Import a Cosy Island file", SaveGame.export_dir(), "", false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		PackedStringArray(["*.%s ; Cosy Island files" % SaveGame.EXPORT_EXT, "*.json ; Save files"]),
		func(ok: bool, paths: PackedStringArray, _filter: int):
			if ok and not paths.is_empty():
				_import_from.call_deferred(paths[0]))


## Kept so the browser can call back once a file's picked.
var _browser_pick: JavaScriptObject


## The browser's file picker; the file it gives back is kept in user:// to import.
func _import_from_browser() -> void:
	_browser_pick = JavaScriptBridge.create_callback(func(args: Array):
		var file := FileAccess.open(BROWSER_IMPORT, FileAccess.WRITE)
		file.store_string(String(args[1]))
		file.close()
		_import_from.call_deferred(BROWSER_IMPORT))
	JavaScriptBridge.eval("""
		window.cosyPickFile = function(done) {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = '.cosysave,.json';
			input.onchange = function() {
				var picked = input.files[0];
				if (picked) { picked.text().then(function(text) { done(picked.name, text); }); }
			};
			input.click();
		};
	""", true)
	JavaScriptBridge.get_interface("window").cosyPickFile(_browser_pick)


const BROWSER_IMPORT := "user://browser_import.cosysave"


## Checks the copy at `from`, then asks which file it should go in.
func _import_from(from: String) -> void:
	var checked := SaveGame.check_import(from)
	if checked.has("error"):
		_open_popup("Can't import that", checked["error"], [["Back", _import_list]])
		return
	var data: Dictionary = checked["data"]
	var island: String = _island_of(data)
	var options: Array = []
	for n in range(1, SaveGame.SLOTS + 1):
		var s := SaveGame.summary(n)
		var label := "File %d: empty" % n if s.is_empty() else "File %d: replace %s Island" % [n, _island_of(s)]
		options.append([label, func(): _import_into(from, n), "danger" if not s.is_empty() else ""])
	options.append(["Back", _import_list])
	var who: String = data.get("player_name", "")
	_open_popup("Which file should it go in?", "%s Island%s" % [island.capitalize(), (", %s's" % who) if who != "" else ""], options)


## Puts the copy in file `n`, asking first if that means replacing an island.
func _import_into(from: String, n: int, sure := false) -> void:
	var s := SaveGame.summary(n)
	if not s.is_empty() and not sure:
		_open_popup("Replace %s Island?" % _island_of(s), "It'll be gone for good, and the imported island takes its place in file %d." % n, [
			["Keep it", func(): _import_from(from)],
			["Replace it", func(): _import_into(from, n, true), "danger"],
		])
		return
	var problem := SaveGame.import_file(from, n)
	if problem != "":
		_open_popup("Can't import that", problem, [["Back", _import_list]])
		return
	_open_popup("Imported!", "%s Island is in file %d." % [_island_of(SaveGame.summary(n)).capitalize(), n], [
		["Play it", func(): _start_game(n, false)],
		["OK", _close_popup],
	])


# --- Into the game ---------------------------------------------------------------------

## Opens file `n` (-1 keeps the slot the command line chose), as a new island if `fresh`.
func _start_game(n: int, fresh: bool) -> void:
	if _busy:
		return
	_busy = true
	if n >= 0:
		SaveGame.slot = n
		Game.args["slot"] = str(n)
	if fresh:
		Game.args["new"] = ""
	if _fade:
		var tween := create_tween()
		tween.tween_property(_fade, "color:a", 1.0, 0.35)
		await tween.finished
	Game.mode = Game.Mode.PLAY
	get_tree().change_scene_to_file(GAME_SCENE)


## A file on the title screen: the player's face, their name and island, acorns and
## when it was last played; or an empty file, to start a new island.
class FileCard:
	extends Button
	var slot: int
	var info: Dictionary
	var thumbs: CharacterThumbs

	func _init(n: int, summary: Dictionary, thumb_source: CharacterThumbs) -> void:
		slot = n
		info = summary
		thumbs = thumb_source
		custom_minimum_size = Vector2(0, 92)
		focus_mode = Control.FOCUS_ALL
		for state in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(grab_focus)

	static func details(s: Dictionary) -> String:
		if s.is_empty():
			return ""
		var parts: Array[String] = []
		if int(s.get("days", 0)) > 0:
			parts.append("Day %d" % int(s["days"]))
		parts.append("%d acorns" % int(s.get("acorns", 0)))
		if int(s.get("saved_at", 0)) > 0:
			parts.append("played " + _when(int(s["saved_at"])))
		return "  ·  ".join(parts)

	## "today, 3:12pm", "yesterday", or a date.
	static func _when(unix: int) -> String:
		var bias: int = Time.get_time_zone_from_system().get("bias", 0) * 60
		var then := Time.get_datetime_dict_from_unix_time(unix + bias)
		var now_unix := int(Time.get_unix_time_from_system()) + bias
		var days := now_unix / 86400 - (unix + bias) / 86400
		var hour: int = then["hour"] % 12
		var clock := "%d:%02d%s" % [12 if hour == 0 else hour, then["minute"], "am" if then["hour"] < 12 else "pm"]
		if days == 0:
			return "today, " + clock
		if days == 1:
			return "yesterday, " + clock
		const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
		return "%d %s" % [then["day"], MONTHS[then["month"] - 1]]

	func _draw() -> void:
		var sb := UIStyle.panel(UIStyle.CREAM if not info.is_empty() else UIStyle.CREAM.darkened(0.04), 22)
		if has_focus():
			sb.border_color = UIStyle.ACCENT
			sb.set_border_width_all(4)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var font := get_theme_default_font()
		var tag := Rect2(Vector2(16, 16), Vector2(60, 60))
		var round := StyleBoxFlat.new()
		round.set_corner_radius_all(30)
		round.bg_color = Color("cfe6e0") if not info.is_empty() else UIStyle.CREAM_DARK
		draw_style_box(round, tag)
		if info.is_empty():
			UIIcons.draw(self, "leaf", tag.get_center(), 34, UIStyle.BROWN_LIGHT)
			draw_string(font, Vector2(92, 42), "File %d" % slot, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIStyle.BROWN)
			draw_string(font, Vector2(92, 70), "Empty: start a new island", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UIStyle.BROWN_LIGHT)
			return
		var face: Texture2D = thumbs.get_thumb(info["look"], "face") if info.has("look") and thumbs else null
		if face:
			draw_texture_rect(face, tag.grow(-2), false)
		else:
			UIIcons.draw(self, "you", tag.get_center(), 34, UIStyle.BROWN)
		var who: String = info.get("player_name", "")
		var island: String = info.get("island_name", "")
		var heading := "%s of %s Island" % [who, island] if who != "" and island != "" else "File %d" % slot
		draw_string(font, Vector2(92, 42), heading, HORIZONTAL_ALIGNMENT_LEFT, size.x - 110, 22, UIStyle.BROWN)
		draw_string(font, Vector2(92, 70), "File %d  ·  " % slot + details(info), HORIZONTAL_ALIGNMENT_LEFT, size.x - 110, 16, UIStyle.BROWN_LIGHT)


## The leaf over the title on the splash.
class _Leaf:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(0, 110)

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		draw_circle(c, 50, Color("cfe6c4"))
		UIIcons.draw(self, "leaf", c, 70, Color("6faa5c"))
