shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, world_vertex_coords, shadows_disabled;

// Fish seen through the water (CreatureModels.shadow): a soft dark pointed oval that
// wiggles as it swims, more towards the tail. Vertex alpha softens the outline; UV.x is
// 0 at the tail and 1 at the nose, UV.y the fish's length.

#include "res://shaders/include/world.gdshaderinc"

uniform vec4 colour : source_color = vec4(0.13, 0.22, 0.3, 0.42);

void vertex() {
	// Side to side across the fish (its local z), a wave running from nose to tail.
	vec3 across = normalize(MODEL_MATRIX[2].xyz);
	vec3 root = MODEL_MATRIX[3].xyz;
	float phase = root.x * 0.9 + root.z * 0.7;
	float tailness = pow(1.0 - UV.x, 1.6);
	VERTEX += across * sin(TIME * 7.0 - UV.x * 4.0 + phase) * UV.y * 0.09 * tailness;
	VERTEX = curve_world(VERTEX);
}

void fragment() {
	ALBEDO = colour.rgb;
	ALPHA = colour.a * smoothstep(0.0, 0.55, COLOR.a);
}
