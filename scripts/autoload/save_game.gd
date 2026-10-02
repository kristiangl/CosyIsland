extends Node
## Reads and writes the save file as JSON.
##
## The terrain is regenerated from the island seed, so the save only holds what changes:
## objects, inventory, player position and the clock offset.

const SAVE_PATH := "user://island_save.json"
const VERSION := 1


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func write(data: Dictionary) -> void:
	data["version"] = VERSION
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data))


func read() -> Dictionary:
	if not has_save():
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary and int(parsed.get("version", 0)) == VERSION:
		return parsed
	push_warning("Save file was unreadable or from another version; starting fresh.")
	return {}


func delete() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
