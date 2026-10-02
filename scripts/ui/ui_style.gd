class_name UIStyle
extends RefCounted
## Shared look for the interface: soft cream panels with rounded corners and brown text.

const CREAM := Color("fbf3dc")
const CREAM_DARK := Color("efe2bf")
const BROWN := Color("6b4f3a")
const BROWN_LIGHT := Color("a08670")
const ACCENT := Color("f0b65a")
const GREEN := Color("7cbf6a")


static func panel(colour: Color = CREAM, radius: int = 26) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = colour
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0.25, 0.18, 0.1, 0.18)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


## Fredoka (SIL Open Font License, see assets/fonts/OFL.txt), semi-bold.
static func font(weight: int = 560) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Fredoka.ttf")
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): weight}
	return fv


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 20
	t.set_color("font_color", "Label", BROWN)
	t.set_color("font_color", "Button", BROWN)
	t.set_color("font_hover_color", "Button", BROWN)
	t.set_color("font_focus_color", "Button", BROWN)
	t.set_color("font_pressed_color", "Button", BROWN)
	var normal := panel(CREAM_DARK, 18)
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	normal.shadow_size = 0
	var focus := normal.duplicate()
	focus.bg_color = ACCENT
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", focus)
	t.set_stylebox("pressed", "Button", focus)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("panel", "PanelContainer", panel())
	return t
