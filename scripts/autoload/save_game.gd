extends Node
## Reads and writes save files as JSON, one per file slot.
##
## The terrain is regenerated from the island seed, so a save only holds what changes:
## objects, inventory, player position and the clock offset. The title screen picks a
## slot (1 to SLOTS); runs started from the command line with --new, --seed or
## --screenshot use the scratch slot (0) unless given --slot=N, so they never touch a
## real file.
##
## A file can be exported as a copy (a .cosysave, the same JSON) to take to another
## computer, and a copy imported into any file (`export_file`, `import_file`; the title
## screen's File options and Import a file).

const SLOTS := 3
const VERSION := 1
## Where the single save lived before there were slots: it becomes file 1.
const OLD_PATH := "user://island_save.json"

## The slot being played (0 is the scratch slot).
var slot := 0


func _ready() -> void:
	if FileAccess.file_exists(OLD_PATH) and not FileAccess.file_exists(path(1)):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(OLD_PATH), ProjectSettings.globalize_path(path(1)))


static func path(n: int) -> String:
	return "user://scratch_save.json" if n == 0 else "user://save_%d.json" % n


func has_save(n: int = -1) -> bool:
	return FileAccess.file_exists(path(slot if n < 0 else n))


func write(data: Dictionary) -> void:
	data["version"] = VERSION
	data["saved_at"] = int(Time.get_unix_time_from_system())
	var file := FileAccess.open(path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Could not write save: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data))


func read(n: int = -1) -> Dictionary:
	if not has_save(n):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path(slot if n < 0 else n)))
	if parsed is Dictionary and int(parsed.get("version", 0)) == VERSION:
		return parsed
	push_warning("Save file was unreadable or from another version; starting fresh.")
	return {}


func delete(n: int = -1) -> void:
	if has_save(n):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(slot if n < 0 else n)))


## What the title screen shows for a file: {} if it's empty, else the player's and
## island's names, acorns, when it was last saved (unix time), which island day it's up
## to (0 if unknown) and the player's look.
func summary(n: int) -> Dictionary:
	var data := read(n)
	if data.is_empty():
		return {}
	var saved_at := int(data.get("saved_at", 0))
	if saved_at == 0:
		saved_at = int(FileAccess.get_modified_time(path(n)))
	return {
		"player_name": data.get("player_name", ""),
		"island_name": data.get("island_name", ""),
		"acorns": int(data.get("inventory", {}).get("currency", 0)),
		"saved_at": saved_at,
		"days": int(data["day"]) - int(data["started_day"]) + 1 if data.has("day") and data.has("started_day") else 0,
		"look": data.get("player", {}).get("look", {}),
	}


## The file played most recently, or 0 if there are none.
func latest() -> int:
	var best := 0
	var when := -1
	for n in range(1, SLOTS + 1):
		var s := summary(n)
		if not s.is_empty() and int(s["saved_at"]) > when:
			when = int(s["saved_at"])
			best = n
	return best


# --- Moving a file to another computer ---------------------------------------------------

## Copies of a file to take to another computer are plain save files with this ending.
const EXPORT_EXT := "cosysave"
## Where copies go, and where else they're looked for when importing (besides any file
## picked with the system's file dialog).
const EXPORT_FOLDER := "Cosy Island"
## Set to look somewhere else instead (the tests use a folder of their own).
var export_dir_override := ""


## The folder copies are saved to: "Cosy Island" in the player's Documents (or the
## game's own folder if there's no Documents).
func export_dir() -> String:
	if export_dir_override != "":
		return export_dir_override
	var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if docs == "":
		return ProjectSettings.globalize_path("user://exports")
	return docs.path_join(EXPORT_FOLDER)


## Folders a copy might have been put in on this computer: the export folder, then
## Documents itself, Downloads and the Desktop.
func import_dirs() -> PackedStringArray:
	var dirs := PackedStringArray([export_dir()])
	if export_dir_override == "":
		for kind: int in [OS.SYSTEM_DIR_DOCUMENTS, OS.SYSTEM_DIR_DOWNLOADS, OS.SYSTEM_DIR_DESKTOP]:
			var d := OS.get_system_dir(kind)
			if d != "" and not d in dirs:
				dirs.append(d)
	return dirs


## Saves a copy of file `n` in the export folder, named after the island, the player and
## the date. Returns the copy's full path, or "" if it couldn't be written.
func export_file(n: int) -> String:
	var data := read(n)
	if data.is_empty():
		return ""
	var dir := export_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var stem := export_stem(n)
	var to := dir.path_join("%s.%s" % [stem, EXPORT_EXT])
	var tries := 2
	while FileAccess.file_exists(to):
		to = dir.path_join("%s (%d).%s" % [stem, tries, EXPORT_EXT])
		tries += 1
	return to if export_to(n, to) == OK else ""


## A copy's name, without its ending: the island, the player and the date.
func export_stem(n: int) -> String:
	var data := read(n)
	var island: String = data.get("island_name", "")
	var who: String = data.get("player_name", "")
	var stem := "%s Island" % (island if island != "" else "My")
	if who != "":
		stem += " - " + who
	return safe_name(stem + " - " + Time.get_date_string_from_system())


## In a browser: hands the browser a copy of file `n` to save to its downloads. The
## name it's given, or "" if there's nothing to give.
func download_file(n: int) -> String:
	var data := read(n)
	if data.is_empty() or not OS.has_feature("web"):
		return ""
	var name := "%s.%s" % [export_stem(n), EXPORT_EXT]
	JavaScriptBridge.download_buffer(JSON.stringify(data).to_utf8_buffer(), name, "application/octet-stream")
	return name


## Writes a copy of file `n` to `to` (a full path).
func export_to(n: int, to: String) -> Error:
	var data := read(n)
	if data.is_empty():
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(to, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	return OK


## A file name without the characters some systems won't have in one.
static func safe_name(text: String) -> String:
	for bad: String in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		text = text.replace(bad, "")
	return text.strip_edges()


## What's in a copy at `from`: {"data": the save} if it can be imported, else
## {"error": why not}.
func check_import(from: String) -> Dictionary:
	if not FileAccess.file_exists(from):
		return {"error": "That file isn't there any more."}
	# (Parsed quietly: a file that isn't JSON at all just isn't a save.)
	var json := JSON.new()
	var parsed = json.data if json.parse(FileAccess.get_file_as_string(from)) == OK else null
	if not parsed is Dictionary or not parsed.has("seed") or not parsed.has("player") or not parsed.has("world"):
		return {"error": "That doesn't look like a Cosy Island file."}
	if int(parsed.get("version", 0)) != VERSION:
		return {"error": "That file's from a different version of the game."}
	return {"data": parsed}


## Puts the copy at `from` into file `n`, replacing whatever's there. "" if it worked,
## else why not.
func import_file(from: String, n: int) -> String:
	var checked := check_import(from)
	if checked.has("error"):
		return checked["error"]
	var file := FileAccess.open(path(n), FileAccess.WRITE)
	if file == null:
		return "Couldn't write file %d." % n
	file.store_string(JSON.stringify(checked["data"]))
	return ""


## Copies found on this computer (`import_dirs`), newest first: [{"path", "name", "when"}].
func copies_found(limit: int = 6) -> Array:
	var found: Array = []
	for dir: String in import_dirs():
		var access := DirAccess.open(dir)
		if access == null:
			continue
		for name: String in access.get_files():
			if name.get_extension().to_lower() == EXPORT_EXT:
				var full := dir.path_join(name)
				found.append({"path": full, "name": name.get_basename(), "when": FileAccess.get_modified_time(full)})
	found.sort_custom(func(a, b): return a["when"] > b["when"])
	return found.slice(0, limit)
