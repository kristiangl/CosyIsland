class_name MeshKit
extends RefCounted
## Small toolkit for building low-poly meshes out of primitives in code.
##
## Colours are given in sRGB and stored linear in the vertex colours. Vertex colour
## alpha carries the wind sway weight (see shaders/prop.gdshader). Triangles are wound
## automatically from the supplied normals, so callers never think about winding.

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colours := PackedColorArray()
var indices := PackedInt32Array()

## Applied to everything added; push and pop it to build nested parts.
var xform := Transform3D.IDENTITY


static func lin(c: Color, sway: float = 0.0) -> Color:
	var l := c.srgb_to_linear()
	return Color(l.r, l.g, l.b, sway)


func vertex(p: Vector3, n: Vector3, c: Color) -> int:
	verts.append(xform * p)
	normals.append((xform.basis * n).normalized())
	colours.append(c)
	return verts.size() - 1


## Adds a triangle of existing vertices, flipped if needed so its front faces along `facing`.
func tri(a: int, b: int, c: int, facing: Vector3) -> void:
	var face := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	# Godot treats clockwise triangles as front-facing, so the cross product points inward.
	if face.dot(facing) > 0.0:
		indices.append_array([a, c, b])
	else:
		indices.append_array([a, b, c])


func quad(a: int, b: int, c: int, d: int, facing: Vector3) -> void:
	tri(a, b, c, facing)
	tri(a, c, d, facing)


## Flat-shaded quad from four positions.
func flat_quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, c: Color) -> void:
	var a := vertex(p0, n, c)
	var b := vertex(p1, n, c)
	var cc := vertex(p2, n, c)
	var d := vertex(p3, n, c)
	quad(a, b, cc, d, xform.basis * n)


## Ellipsoid. `shade` darkens the underside for a soft painted gradient.
func sphere(centre: Vector3, radius: Vector3, c: Color, rings: int = 6, segments: int = 10,
		shade: float = 0.0, wobble: float = 0.0, wobble_seed: int = 0) -> void:
	var start := verts.size()
	for i in rings + 1:
		var phi := PI * i / rings
		for j in segments + 1:
			var theta := TAU * j / segments
			var unit := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var r := radius
			if wobble > 0.0 and i > 0 and i < rings:
				var k := wobble_seed * 31 + i * 7 + (j % segments) * 13
				r *= 1.0 + (fposmod(sin(k * 12.9898) * 43758.5453, 1.0) - 0.5) * wobble
			var n := Vector3(unit.x / radius.x, unit.y / radius.y, unit.z / radius.z).normalized()
			var col := c
			if shade > 0.0:
				var f := 1.0 - shade * (0.5 - unit.y * 0.5)
				col = Color(c.r * f, c.g * f, c.b * f, c.a)
			vertex(centre + unit * r, n, col)
	var row := segments + 1
	for i in rings:
		for j in segments:
			var a := start + i * row + j
			var b := a + row
			var outward := (verts[a] + verts[b + 1]) * 0.5 - xform * centre
			if i == 0:
				tri(a, b, b + 1, outward)
			elif i == rings - 1:
				tri(a, b, a + 1, outward)
			else:
				quad(a, b, b + 1, a + 1, outward)


## Tapered tube between two points, with optional caps.
func cylinder(base: Vector3, top: Vector3, r_base: float, r_top: float, c: Color,
		segments: int = 8, caps: bool = true, c_top: Color = Color(0, 0, 0, -1)) -> void:
	var axis := (top - base).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := axis.cross(side)
	var top_col := c if c_top.a < 0.0 else c_top
	var start := verts.size()
	var slope := (r_base - r_top) / maxf((top - base).length(), 0.001)
	for j in segments + 1:
		var a := TAU * j / segments
		var dir := side * cos(a) + fwd * sin(a)
		var n := (dir + axis * slope).normalized()
		vertex(base + dir * r_base, n, c)
		vertex(top + dir * r_top, n, top_col)
	for j in segments:
		var i := start + j * 2
		var dir := (verts[i] + verts[i + 2]) * 0.5 - xform * base
		quad(i, i + 1, i + 3, i + 2, dir)
	if caps:
		_disc(top, axis, r_top, top_col, segments, side, fwd)
		if r_base > 0.0:
			_disc(base, -axis, r_base, c, segments, side, fwd)


func _disc(centre: Vector3, n: Vector3, r: float, c: Color, segments: int, side: Vector3, fwd: Vector3) -> void:
	if r <= 0.0:
		return
	var mid := vertex(centre, n, c)
	var first := verts.size()
	for j in segments + 1:
		var a := TAU * j / segments
		vertex(centre + (side * cos(a) + fwd * sin(a)) * r, n, c)
	for j in segments:
		tri(mid, first + j, first + j + 1, xform.basis * n)


func cone(base: Vector3, tip: Vector3, r: float, c: Color, segments: int = 8) -> void:
	cylinder(base, tip, r, 0.0, c, segments, true)


## Axis-aligned box (in the current transform), flat shaded.
func box(centre: Vector3, size: Vector3, c: Color, c_top: Color = Color(0, 0, 0, -1)) -> void:
	var h := size * 0.5
	var top := c if c_top.a < 0.0 else c_top
	var p := func(x: float, y: float, z: float) -> Vector3: return centre + Vector3(h.x * x, h.y * y, h.z * z)
	flat_quad(p.call(-1, 1, -1), p.call(1, 1, -1), p.call(1, 1, 1), p.call(-1, 1, 1), Vector3.UP, top)
	flat_quad(p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1), p.call(-1, -1, 1), Vector3.DOWN, c)
	flat_quad(p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1), Vector3.BACK, c)
	flat_quad(p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(-1, 1, -1), Vector3.FORWARD, c)
	flat_quad(p.call(1, -1, -1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(1, 1, -1), Vector3.RIGHT, c)
	flat_quad(p.call(-1, -1, -1), p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1), Vector3.LEFT, c)


## Rounded box: a box with a squashed sphere fused on top, good for cushions and roofs.
func rounded_box(centre: Vector3, size: Vector3, c: Color, roundness: float = 0.3) -> void:
	box(centre - Vector3(0, size.y * roundness * 0.25, 0), size * Vector3(1, 1.0 - roundness * 0.5, 1), c)
	sphere(centre + Vector3(0, size.y * (0.5 - roundness * 0.5), 0), size * Vector3(0.5, roundness, 0.5), c, 4, 12)


## Two-sided flat leaf/petal: a diamond lying along `dir`, tilted up by `lift`.
func leaf(base: Vector3, dir: Vector3, length: float, width: float, c: Color, droop: float = 0.0) -> void:
	dir = dir.normalized()
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(dir).normalized()
	if up.y < 0.0:
		up = -up
	var mid := base + dir * length * 0.45 - up * droop * 0.4
	var tip := base + dir * length - up * droop
	for facing in [up, -up]:
		var a := vertex(base, facing, c)
		var b := vertex(mid + side * width * 0.5, facing, c)
		var t := vertex(tip, facing, c)
		var d := vertex(mid - side * width * 0.5, facing, c)
		quad(a, b, t, d, xform.basis * facing)


func is_empty() -> bool:
	return indices.is_empty()


func commit(existing: ArrayMesh = null) -> ArrayMesh:
	var mesh := existing if existing else ArrayMesh.new()
	if indices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
