shader_type spatial;
render_mode world_vertex_coords, unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// Bubbly foam lapping at river and pond banks. Vertex alpha is 1 at the bank and 0 out
// in the water; UV.x runs along the bank. The edge wobbles and creeps with time.

#include "res://shaders/include/world.gdshaderinc"
#include "res://shaders/include/toon_light.gdshaderinc"

uniform vec3 foam : source_color = vec3(0.98, 0.99, 0.97);

void vertex() {
	VERTEX = curve_world(VERTEX);
	VERTEX.y += sin(TIME * 1.1 + VERTEX.x * 0.4 + VERTEX.z * 0.3) * 0.02;
}

void fragment() {
	float wobble = value_noise(vec2(UV.x * 5.0 - TIME * 0.4, TIME * 0.3)) * 0.5
		+ value_noise(vec2(UV.x * 13.0 + TIME * 0.6, 3.0)) * 0.25;
	float reach = COLOR.a - (1.0 - wobble) * 0.55;
	float body = smoothstep(0.0, 0.06, reach);
	// A few loose bubbles just beyond the edge.
	vec2 cell = vec2(UV.x * 7.0, UV.y * 2.0);
	vec2 g = fract(cell) - 0.5;
	float bubble = (1.0 - smoothstep(0.12, 0.18, length(g))) * step(0.7, hash21(floor(cell)))
		* smoothstep(0.0, 0.4, COLOR.a);
	ALBEDO = foam * (fixed_tints ? fixed_lit : cel_lit);
	ALPHA = clamp(body + bubble * 0.8, 0.0, 1.0) * 0.9;
}
