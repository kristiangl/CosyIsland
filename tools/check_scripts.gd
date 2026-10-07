extends Node
## Loads every .gd file so parse errors show up in one go (see tools/check_scripts.sh).


func _ready() -> void:
	var count := 0
	for dir in ["res://scripts", "res://tests", "res://tools"]:
		count += _load_all(dir)
	print("%d scripts loaded" % count)
	get_tree().quit()


func _load_all(path: String) -> int:
	var count := 0
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".gd"):
			var script := load(path.path_join(file)) as GDScript
			# A script that failed to parse can't be instanced (the error may only show
			# as a failed load, so say so plainly).
			if script == null or not script.can_instantiate():
				print("SCRIPT ERROR: %s didn't load" % path.path_join(file))
			count += 1
	for sub in DirAccess.get_directories_at(path):
		count += _load_all(path.path_join(sub))
	return count
