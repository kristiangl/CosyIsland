class_name UIIcons
extends RefCounted
## Small hand-drawn icons for tabs and phone apps, drawn with canvas primitives so they
## stay crisp at any size. draw(canvas, id, centre, size, colour).


static func draw(c: CanvasItem, id: String, o: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.5, s * 0.07)
	var light := col.lightened(0.55)
	match id:
		"you":
			c.draw_circle(o + Vector2(0, -s * 0.12), s * 0.22, col)
			_arc(c, o + Vector2(0, s * 0.42), s * 0.36, PI, TAU, col, s * 0.2, true)
		"skin":
			var pts := PackedVector2Array()
			for i in 17:
				var a := PI * 0.5 + (i / 16.0 - 0.5) * PI * 1.25
				pts.append(o + Vector2(cos(a), sin(a)) * s * 0.3 + Vector2(0, s * 0.05))
			pts.append(o + Vector2(0, -s * 0.42))
			c.draw_colored_polygon(pts, col)
		"hair":
			c.draw_circle(o + Vector2(0, s * 0.08), s * 0.3, light)
			_arc(c, o + Vector2(0, s * 0.06), s * 0.36, PI, TAU, col, s * 0.3, true)
			c.draw_rect(Rect2(o + Vector2(-s * 0.36, s * 0.0), Vector2(s * 0.12, s * 0.28)), col)
			c.draw_rect(Rect2(o + Vector2(s * 0.24, s * 0.0), Vector2(s * 0.12, s * 0.28)), col)
		"eyes":
			for sx: float in [-1.0, 1.0]:
				_ellipse(c, o + Vector2(sx * s * 0.18, 0), Vector2(s * 0.11, s * 0.16), col)
				c.draw_circle(o + Vector2(sx * s * 0.18 + s * 0.035, -s * 0.06), s * 0.04, Color.WHITE)
		"brows":
			for sx: float in [-1.0, 1.0]:
				_arc(c, o + Vector2(sx * s * 0.2, s * 0.12), s * 0.18, PI * 1.2, PI * 1.8, col, w * 1.6)
		"nose":
			c.draw_polyline(PackedVector2Array([o + Vector2(0, -s * 0.3), o + Vector2(-s * 0.14, s * 0.15), o + Vector2(s * 0.08, s * 0.2)]), col, w * 1.3)
		"mouth":
			_arc(c, o + Vector2(0, -s * 0.12), s * 0.3, PI * 0.15, PI * 0.85, col, w * 1.6)
		"cheeks":
			for sx: float in [-1.0, 1.0]:
				_ellipse(c, o + Vector2(sx * s * 0.2, 0), Vector2(s * 0.16, s * 0.1), Color(0.95, 0.55, 0.55))
		"top":
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(-s * 0.18, -s * 0.34), o + Vector2(-s * 0.42, -s * 0.18),
				o + Vector2(-s * 0.32, s * 0.0), o + Vector2(-s * 0.22, -s * 0.06), o + Vector2(-s * 0.22, s * 0.36),
				o + Vector2(s * 0.22, s * 0.36), o + Vector2(s * 0.22, -s * 0.06), o + Vector2(s * 0.32, s * 0.0),
				o + Vector2(s * 0.42, -s * 0.18), o + Vector2(s * 0.18, -s * 0.34), o + Vector2(0, -s * 0.24)]), col)
		"bottom":
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(-s * 0.28, -s * 0.32), o + Vector2(s * 0.28, -s * 0.32),
				o + Vector2(s * 0.34, s * 0.34), o + Vector2(s * 0.06, s * 0.34), o + Vector2(0, -s * 0.05),
				o + Vector2(-s * 0.06, s * 0.34), o + Vector2(-s * 0.34, s * 0.34)]), col)
		"shoes":
			_ellipse(c, o + Vector2(s * 0.04, s * 0.1), Vector2(s * 0.38, s * 0.18), col)
			c.draw_rect(Rect2(o + Vector2(-s * 0.34, -s * 0.28), Vector2(s * 0.26, s * 0.38)), col)
			c.draw_line(o + Vector2(-s * 0.36, s * 0.26), o + Vector2(s * 0.42, s * 0.26), light, w)
		"hat":
			_arc(c, o + Vector2(0, s * 0.12), s * 0.3, PI, TAU, col, s * 0.3, true)
			_ellipse(c, o + Vector2(s * 0.12, s * 0.14), Vector2(s * 0.4, s * 0.09), col.darkened(0.15))
		"glasses":
			for sx: float in [-1.0, 1.0]:
				c.draw_arc(o + Vector2(sx * s * 0.22, 0), s * 0.16, 0, TAU, 20, col, w * 1.3, true)
			c.draw_line(o + Vector2(-s * 0.06, -s * 0.02), o + Vector2(s * 0.06, -s * 0.02), col, w * 1.3)
		"clock":
			c.draw_circle(o, s * 0.4, col)
			c.draw_circle(o, s * 0.32, light)
			c.draw_line(o, o + Vector2(0, -s * 0.22), col, w * 1.3)
			c.draw_line(o, o + Vector2(s * 0.16, s * 0.04), col, w * 1.3)
		"save":
			c.draw_rect(Rect2(o - Vector2(s * 0.34, s * 0.34), Vector2(s * 0.68, s * 0.68)), col)
			c.draw_rect(Rect2(o + Vector2(-s * 0.2, -s * 0.34), Vector2(s * 0.4, s * 0.24)), light)
			c.draw_rect(Rect2(o + Vector2(-s * 0.22, s * 0.06), Vector2(s * 0.44, s * 0.22)), light)
		"map":
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(-s * 0.4, -s * 0.28), o + Vector2(-s * 0.13, -s * 0.36),
				o + Vector2(s * 0.13, -s * 0.28), o + Vector2(s * 0.4, -s * 0.36), o + Vector2(s * 0.4, s * 0.28),
				o + Vector2(s * 0.13, s * 0.36), o + Vector2(-s * 0.13, s * 0.28), o + Vector2(-s * 0.4, s * 0.36)]), col)
			c.draw_line(o + Vector2(-s * 0.13, -s * 0.36), o + Vector2(-s * 0.13, s * 0.28), light, w)
			c.draw_line(o + Vector2(s * 0.13, -s * 0.28), o + Vector2(s * 0.13, s * 0.36), light, w)
		"wardrobe":
			c.draw_rect(Rect2(o - Vector2(s * 0.3, s * 0.38), Vector2(s * 0.6, s * 0.76)), col)
			c.draw_line(o + Vector2(0, -s * 0.38), o + Vector2(0, s * 0.38), light, w)
			c.draw_circle(o + Vector2(-s * 0.07, 0), s * 0.035, light)
			c.draw_circle(o + Vector2(s * 0.07, 0), s * 0.035, light)
		"door":
			c.draw_rect(Rect2(o - Vector2(s * 0.26, s * 0.38), Vector2(s * 0.52, s * 0.76)), col)
			c.draw_circle(o + Vector2(s * 0.13, s * 0.04), s * 0.05, light)
		"back":
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(-s * 0.32, 0), o + Vector2(0, -s * 0.28), o + Vector2(0, s * 0.28)]), col)
			c.draw_rect(Rect2(o + Vector2(-s * 0.02, -s * 0.1), Vector2(s * 0.34, s * 0.2)), col)
		"moon":
			c.draw_circle(o, s * 0.34, col)
			c.draw_circle(o + Vector2(s * 0.14, -s * 0.1), s * 0.28, light)
		"journal":
			# A little book with a ribbon and a stamp.
			c.draw_rect(Rect2(o + Vector2(-s * 0.32, -s * 0.36), Vector2(s * 0.64, s * 0.72)), col)
			c.draw_rect(Rect2(o + Vector2(-s * 0.24, -s * 0.36), Vector2(s * 0.05, s * 0.72)), light)
			c.draw_circle(o + Vector2(s * 0.06, -s * 0.04), s * 0.15, light)
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(s * 0.16, s * 0.36), o + Vector2(s * 0.26, s * 0.36),
				o + Vector2(s * 0.26, s * 0.5), o + Vector2(s * 0.21, s * 0.44), o + Vector2(s * 0.16, s * 0.5)]), Color(0.86, 0.36, 0.34))
		"leaf":
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(-s * 0.32, s * 0.32), o + Vector2(-s * 0.2, -s * 0.12),
				o + Vector2(s * 0.08, -s * 0.32), o + Vector2(s * 0.36, -s * 0.36), o + Vector2(s * 0.28, -s * 0.04),
				o + Vector2(s * 0.08, s * 0.22)]), col)
			c.draw_line(o + Vector2(-s * 0.32, s * 0.32), o + Vector2(s * 0.24, -s * 0.24), light, w)
		_:
			c.draw_circle(o, s * 0.3, col)


static func _ellipse(c: CanvasItem, o: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(o + Vector2(cos(a) * r.x, sin(a) * r.y))
	c.draw_colored_polygon(pts, col)


## An arc from angle a0 to a1; filled turns it into a pie-like dome.
static func _arc(c: CanvasItem, o: Vector2, r: float, a0: float, a1: float, col: Color, width: float, filled: bool = false) -> void:
	if filled:
		var pts := PackedVector2Array([o])
		for i in 17:
			var a := lerpf(a0, a1, i / 16.0)
			pts.append(o + Vector2(cos(a), sin(a)) * r)
		c.draw_colored_polygon(pts, col)
	else:
		c.draw_arc(o, r, a0, a1, 16, col, width, true)
