extends SceneTree
## Converts KayKit models (CC0, www.kaylousberg.com) into the game's own meshes:
## vertex-coloured ArrayMeshes for the shared prop material, so they get the cel
## lighting, outlines, wind sway and world curve like everything else.
##
##   /opt/godot/godot --headless --path . --script res://tools/kaykit_import.gd -- --src=/path/to/KayKit [--only=name,name]
##
## What gets imported is listed in tools/kaykit.json. Each model names its glTF file
## (relative to --src) and is saved as res://assets/kaykit/<name>.res, with:
##   scale    to game units (1 = a tile), or fit: [width, height] to fit inside
##   sway     "foliage" (green parts sway, more towards the top) or "none"
##   palette  a set from the file's "palettes": colours are moved onto the game's own
##            ramps by kind (green, brown, grey...), darkest to lightest
##   recolour {"#from": "#to"} for single colours
##   smooth   true to round off hard edges (normals shared where vertices meet), so
##            canopies and bushes shade like soft puffs under the cel lighting
## KayKit models colour each face from a small palette texture, so sampling the
## texture at each vertex's UV gives its colour without needing the texture at all.

const LIST := "res://tools/kaykit.json"
const OUT_DIR := "res://assets/kaykit/"


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var src: String = args.get("src", "")
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	var list: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LIST))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var done := 0
	for name: String in list["models"]:
		if not only.is_empty() and not name in only:
			continue
		var entry: Dictionary = list["models"][name]
		var palette: Dictionary = list.get("palettes", {}).get(entry.get("palette", ""), {})
		var mesh := import_model(src.path_join(entry["src"]), entry, palette)
		if mesh == null:
			push_error("Couldn't import " + name)
			continue
		ResourceSaver.save(mesh, OUT_DIR + name + ".res", ResourceSaver.FLAG_COMPRESS)
		done += 1
	print("Imported %d models" % done)
	if list.has("animations") and (only.is_empty() or "animations" in only):
		var library := import_animations(src, list["animations"])
		ResourceSaver.save(library, OUT_DIR + "rig_medium.res", ResourceSaver.FLAG_COMPRESS)
		print("Imported %d animations" % library.get_animation_list().size())
	quit()


## KayKit's Rig_Medium animations, for RigPose: just the listed clips ({file: [names]},
## files relative to --src) and just the bones RigPose reads, each track named after
## its bone. The skeleton's rest pose goes in the library's "bones" meta:
## {bone: [parent bone or "", rest Transform3D]}.
static func import_animations(src: String, files: Dictionary) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	var bones := {}
	var keep := {}
	for file: String in files:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		doc.append_from_file(src.path_join(file), state)
		var scene := doc.generate_scene(state)
		var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
		if bones.is_empty():
			for pair: Array in RigPose.MAP:
				var b := skeleton.find_bone(pair[1])
				while b >= 0:
					keep[skeleton.get_bone_name(b)] = true
					b = skeleton.get_bone_parent(b)
			for child: String in RigPose.CHILD.values():
				if child != "":
					keep[child] = true
			keep[RigPose.SLOT] = true
			for name: String in keep:
				var b := skeleton.find_bone(name)
				var parent := skeleton.get_bone_parent(b)
				bones[name] = [skeleton.get_bone_name(parent) if parent >= 0 else "", skeleton.get_bone_rest(b)]
		var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var source := player.get_animation_library("")
		for clip: String in files[file]:
			var from := source.get_animation(clip)
			var anim := Animation.new()
			anim.length = from.length
			anim.loop_mode = from.loop_mode
			for t in from.get_track_count():
				var bone := String(from.track_get_path(t).get_concatenated_subnames())
				var kind := from.track_get_type(t)
				if not keep.has(bone) or not kind in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D]:
					continue
				if kind == Animation.TYPE_POSITION_3D and bone != "hips":
					continue
				var to := anim.add_track(kind)
				anim.track_set_path(to, NodePath(bone))
				for k in from.track_get_key_count(t):
					anim.track_insert_key(to, from.track_get_key_time(t, k), from.track_get_key_value(t, k))
			library.add_animation(clip, anim)
		scene.free()
	library.set_meta("bones", bones)
	return library


## One glTF file as a single-surface mesh, scaled, centred and standing on y = 0.
static func import_model(path: String, entry: Dictionary, palette: Dictionary) -> ArrayMesh:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	var texture := Image.new()
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var images: Array = json.get("images", [])
	if not images.is_empty():
		texture.load(path.get_base_dir().path_join(images[0]["uri"]))
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var nodes := state.get_nodes()
	var meshes := state.get_meshes()
	for i in nodes.size():
		var node: GLTFNode = nodes[i]
		if node.mesh < 0:
			continue
		# The node's transform all the way up.
		var xform := Transform3D.IDENTITY
		var at := i
		while at >= 0:
			xform = nodes[at].xform * xform
			at = nodes[at].parent
		var imesh: ImporterMesh = meshes[node.mesh].mesh
		for s in imesh.get_surface_count():
			var arrays := imesh.get_surface_arrays(s)
			var tint := Color.WHITE
			var mat := imesh.get_surface_material(s)
			if mat is BaseMaterial3D:
				tint = mat.albedo_color
			var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var nor: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uv = arrays[Mesh.ARRAY_TEX_UV]
			var idx = arrays[Mesh.ARRAY_INDEX]
			var base := verts.size()
			for v in pos.size():
				verts.append(xform * pos[v])
				normals.append((xform.basis * nor[v]).normalized())
				var c := tint
				if uv != null and not texture.is_empty():
					var u: Vector2 = uv[v]
					var px := clampi(int(fposmod(u.x, 1.0) * texture.get_width()), 0, texture.get_width() - 1)
					var py := clampi(int(fposmod(u.y, 1.0) * texture.get_height()), 0, texture.get_height() - 1)
					c = texture.get_pixel(px, py) * tint
				colours.append(Color(c.r, c.g, c.b, 0.0))
			if idx == null:
				for v in pos.size():
					indices.append(base + v)
			else:
				for v: int in idx:
					indices.append(base + v)
	if verts.is_empty():
		return null
	_repaint(colours, palette, entry.get("recolour", {}))
	# Scale, then stand it on the ground, centred.
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for p in verts:
		lo = lo.min(p)
		hi = hi.max(p)
	var scale := float(entry.get("scale", 1.0))
	if entry.has("fit"):
		var fit: Array = entry["fit"]
		var size := hi - lo
		scale = minf(float(fit[0]) / maxf(size.x, size.z), float(fit[1]) / size.y)
	var shift := Vector3(-(lo.x + hi.x) * 0.5, -lo.y, -(lo.z + hi.z) * 0.5)
	var height := maxf(hi.y - lo.y, 0.001)
	for v in verts.size():
		var up := clampf((verts[v].y - lo.y) / height, 0.0, 1.0)
		verts[v] = (verts[v] + shift) * scale
		if entry.get("sway", "none") == "foliage":
			# Leaves sway, more at the top; trunks only a little.
			colours[v].a = up if _kind(colours[v]) == "green" else up * 0.25
	if entry.get("smooth", false):
		_smooth(verts, normals, colours)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Broad colour families, for moving a model's colours onto the game's palette.
static func _kind(c: Color) -> String:
	if c.s < 0.18:
		return "grey"
	var hue := c.h * 360.0
	if hue >= 65.0 and hue < 170.0:
		return "green"
	if hue < 50.0 or hue >= 330.0:
		return "brown" if c.v < 0.85 or c.s > 0.45 else "warm"
	if hue < 65.0:
		return "yellow"
	return "blue"


## Moves each colour family onto its ramp, keeping the order of light and dark:
## the darkest shade of a family in the model lands on the ramp's first colour.
static func _repaint(colours: PackedColorArray, palette: Dictionary, recolour: Dictionary) -> void:
	var swaps := {}
	for from: String in recolour:
		swaps[Color(from).to_html(false)] = Color(recolour[from])
	var lows := {}
	var highs := {}
	for c in colours:
		var k := _kind(c)
		lows[k] = minf(lows.get(k, 1.0), c.get_luminance())
		highs[k] = maxf(highs.get(k, 0.0), c.get_luminance())
	for i in colours.size():
		var c := colours[i]
		var key := c.to_html(false)
		if swaps.has(key):
			colours[i] = Color(swaps[key], c.a)
			continue
		var k := _kind(c)
		if not palette.has(k):
			continue
		var ramp: Array = palette[k]
		var t := 0.5
		if highs[k] - lows[k] > 0.01:
			t = (c.get_luminance() - lows[k]) / (highs[k] - lows[k])
		var f := t * (ramp.size() - 1)
		var j := mini(int(f), ramp.size() - 2)
		var out := Color(ramp[j]).lerp(Color(ramp[j + 1]), f - j)
		colours[i] = Color(out, c.a)


## Averages the normals of vertices at the same spot and of the same colour family,
## so faceted shapes shade smoothly but leaves stay sharp against the trunk.
static func _smooth(verts: PackedVector3Array, normals: PackedVector3Array, colours: PackedColorArray) -> void:
	var sums := {}
	var keys := []
	keys.resize(verts.size())
	for v in verts.size():
		var p := (verts[v] * 1000.0).round()
		var key := "%d,%d,%d,%s" % [p.x, p.y, p.z, _kind(colours[v])]
		keys[v] = key
		sums[key] = sums.get(key, Vector3.ZERO) + normals[v]
	for v in verts.size():
		var n: Vector3 = sums[keys[v]]
		if n.length() > 0.001:
			normals[v] = n.normalized()
