class_name Palette
extends RefCounted
## Repaints vertex-coloured models by colour family: each family a model uses (its
## wood, its upholstery, its accents...) is moved onto a ramp of the game's own
## colours, keeping the model's light and dark. Used for the colourways of KayKit
## furniture series.


## The family a colour belongs to: "white", "grey", "red", "wood", "orange", "yellow",
## "green", "blue" or "purple".
static func family(c: Color) -> String:
	if c.s < 0.15:
		return "white" if c.v > 0.85 else "grey"
	var hue := c.h * 360.0
	if hue < 12.0 or hue >= 330.0:
		return "red"
	if hue < 45.0:
		return "orange" if c.s > 0.66 or c.v > 0.85 else "wood"
	if hue < 70.0:
		return "yellow"
	if hue < 175.0:
		return "green"
	if hue < 260.0:
		return "blue"
	return "purple"


## Moves each family named in `paint` ({family: ["hex", ...], darkest first}) onto its
## ramp: the darkest shade of that family in the model lands on the first colour, the
## lightest on the last. Alpha (wind sway) is kept.
static func repaint(colours: PackedColorArray, paint: Dictionary) -> void:
	if paint.is_empty():
		return
	var lows := {}
	var highs := {}
	var kinds := PackedStringArray()
	kinds.resize(colours.size())
	for i in colours.size():
		var k := family(colours[i])
		kinds[i] = k
		var l := colours[i].get_luminance()
		lows[k] = minf(lows.get(k, 1.0), l)
		highs[k] = maxf(highs.get(k, 0.0), l)
	for i in colours.size():
		var k := kinds[i]
		if not paint.has(k):
			continue
		var ramp: Array = paint[k]
		var t := 0.5
		if highs[k] - lows[k] > 0.01:
			t = (colours[i].get_luminance() - lows[k]) / (highs[k] - lows[k])
		var f := t * (ramp.size() - 1)
		var j := mini(int(f), ramp.size() - 2)
		var out := Color(ramp[j]).lerp(Color(ramp[mini(j + 1, ramp.size() - 1)]), f - j)
		colours[i] = Color(out, colours[i].a)
