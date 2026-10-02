shader_type spatial;
render_mode world_vertex_coords, unshaded, blend_mix, depth_draw_never, cull_back;

// The item being placed: its own colours, lightly tinted green (fits) or red (doesn't),
// slightly see-through and gently pulsing.

#include "res://shaders/include/world.gdshaderinc"

uniform vec4 colour : source_color = vec4(0.5, 1.0, 0.6, 0.5);

void vertex() {
	VERTEX = curve_world(VERTEX);
}

void fragment() {
	float pulse = 0.5 + 0.5 * sin(TIME * 4.0);
	ALBEDO = mix(COLOR.rgb, colour.rgb, 0.25 + 0.1 * pulse);
	ALPHA = 0.78;
}
