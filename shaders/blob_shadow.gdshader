shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, world_vertex_coords, shadows_disabled;

// Fish seen through the water: a soft dark shape on the surface.

#include "res://shaders/include/world.gdshaderinc"

uniform vec4 colour : source_color = vec4(0.13, 0.22, 0.3, 0.42);

void vertex() {
	VERTEX = curve_world(VERTEX);
}

void fragment() {
	ALBEDO = colour.rgb;
	ALPHA = colour.a;
}
