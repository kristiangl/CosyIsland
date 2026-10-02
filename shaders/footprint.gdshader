shader_type spatial;
render_mode world_vertex_coords, unshaded, blend_mix, depth_draw_never, cull_disabled;

// Grid squares under an item being placed. The plane is scaled to the footprint and
// `tiles` says how many tiles it covers, so each tile gets a rounded outline.

#include "res://shaders/include/world.gdshaderinc"

uniform vec4 colour : source_color = vec4(0.5, 1.0, 0.6, 0.5);
uniform vec2 tiles = vec2(1.0);

void vertex() {
	VERTEX = curve_world(VERTEX);
}

void fragment() {
	vec2 t = UV * tiles;
	vec2 f = abs(fract(t) - 0.5);
	float edge = max(f.x, f.y);
	float border = smoothstep(0.39, 0.42, edge) * (1.0 - smoothstep(0.47, 0.5, edge));
	float pulse = 0.5 + 0.5 * sin(TIME * 4.0);
	ALBEDO = mix(colour.rgb, vec3(1.0), border * 0.6);
	ALPHA = colour.a * (0.35 + 0.15 * pulse) + border * 0.6;
}
