shader_type spatial;
render_mode world_vertex_coords, unshaded, blend_mix, depth_draw_never, cull_back;

// Translucent preview shown while placing something on the grid.

#include "res://shaders/include/world.gdshaderinc"

uniform vec4 colour : source_color = vec4(0.5, 1.0, 0.6, 0.5);

void vertex() {
	VERTEX = curve_world(VERTEX);
}

void fragment() {
	float pulse = 0.85 + 0.15 * sin(TIME * 5.0);
	ALBEDO = mix(COLOR.rgb, colour.rgb, 0.65);
	ALPHA = colour.a * pulse;
}
