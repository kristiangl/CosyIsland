shader_type spatial;
render_mode world_vertex_coords, specular_disabled;

// Stylised water for the sea, rivers and ponds.
// Vertex colour red = distance from the shore (0 at the shore, 1 far out),
// green = height of the ground underneath + 0.5 (0 means deep).

#include "res://shaders/include/world.gdshaderinc"
#include "res://shaders/include/toon_light.gdshaderinc"

uniform vec3 shallow : source_color = vec3(0.60, 0.90, 0.88);
uniform vec3 deep : source_color = vec3(0.40, 0.70, 0.88);
uniform vec3 foam : source_color = vec3(0.97, 0.98, 0.95);
uniform float ripple_scale = 1.0;
uniform vec2 flow = vec2(0.0, 0.0);
uniform float shore_waves = 1.0;
// Foam where rivers and ponds meet their banks (vertex red = 0 there).
uniform float bank_foam = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = VERTEX;
	VERTEX = curve_world(VERTEX);
	VERTEX.y += sin(TIME * 1.1 + world_pos.x * 0.4 + world_pos.z * 0.3) * 0.02;
}

void fragment() {
	float shore = COLOR.r;
	vec2 uv = world_pos.xz * ripple_scale - flow * TIME;
	vec3 col = mix(shallow, deep, smoothstep(0.0, 0.85, shore));

	// Painted ripple highlights drifting across the surface.
	float r = fbm(uv * 0.5 + vec2(TIME * 0.05, TIME * 0.03));
	float glints = smoothstep(0.7, 0.73, r) * (1.0 - smoothstep(0.73, 0.77, r));
	col = mix(col, mix(col, foam, 0.18), glints * smoothstep(0.05, 0.4, shore) * (1.0 - smoothstep(0.5, 0.9, shore)));

	// Lapping foam bands near the shore.
	float band = sin(shore * 40.0 - TIME * 1.6 + fbm(world_pos.xz * 0.3) * 4.0);
	float waves = smoothstep(0.75, 0.95, band) * (1.0 - smoothstep(0.03, 0.12, shore)) * shore_waves;
	float depth = 0.5 - COLOR.g;
	float edge = 1.0 - smoothstep(0.02, 0.09, depth);
	edge = max(edge, (1.0 - smoothstep(0.0, 0.03, shore)) * bank_foam);
	col = mix(col, foam, clamp(waves * 0.8 + edge, 0.0, 1.0));

	ALBEDO = col;
	ROUGHNESS = 0.6;
	EMISSION = cel_ambient(ALBEDO);
}
