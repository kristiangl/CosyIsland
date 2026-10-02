extends Node
## Prints an ASCII map and key locations for an island seed:
##   godot --headless --path . res://tools/island_info.tscn -- --seed=7
## Legend: ~ sea, . sand, 1-3 grass tier, = fresh water, / ramp, # bridge, T tree,
## F fruit tree, P palm, R rock, * flower, @ spawn.


func _ready() -> void:
	var d := IslandGenerator.generate(int(Game.args.get("seed", "7")))
	var marks := {}
	for o in d.objects:
		var c: String = {"tree": "T", "fruit_tree": "F", "palm": "P", "rock": "R", "flower": "*", "bridge": "#"}.get(o["kind"], "?")
		marks[d.idx(o["x"], o["z"])] = c
	marks[d.idx(d.spawn.x, d.spawn.y)] = "@"
	for z in d.height:
		var line := ""
		for x in d.width:
			var i := d.idx(x, z)
			if marks.has(i):
				line += marks[i]
			elif d.ramps.has(i):
				line += "/"
			else:
				line += ["~", ".", str(d.tiers[i]), "="][d.tiles[i]]
		print(line)
	print("fruit=%s flower=%s spawn=%s plaza=%s" % [d.native_fruit, d.native_flower, d.spawn, d.plaza])
	for o in d.objects:
		if o["kind"] in ["bridge", "rock"]:
			print(o)
	print("ramps: ", d.ramps.keys().map(func(i): return Vector2i(i % d.width, i / d.width)))
	get_tree().quit()
