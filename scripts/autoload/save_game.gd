extends Node
## Reads and writes save files as JSON, one per file slot.
##
## The terrain is regenerated from the island seed, so a save only holds what changes:
## objects, inventory, player position and the clock offset. The title screen picks a
## slot (1 to SLOTS); runs started from the command line with --new, --seed or
## --screenshot use the scratch slot (0) unless given --slot=N, so they never touch a
## real file.

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
