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
// How strongly the drifting ripple pattern shows.
uniform float ripple_strength = 0.45;

varying vec3 world_pos;
// Raindrops landing (Weather), 0 to 1.
global uniform float rain;

void vertex() {
	world_pos = VERTEX;
	VERTEX = curve_world(VERTEX);
	VERTEX.y += sin(TIME * 1.1 + world_pos.x * 0.4 + world_pos.z * 0.3) * 0.02;
}

// Animated cell edges: soft light lines like sunlight rippling on water.
float ripples(vec2 p, float t) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			float h = hash21(cell + o);
			vec2 pt = o + 0.5 + 0.38 * vec2(sin(t * 0.7 + h * 6.28), cos(t * 0.6 + h * 9.1));
			float d = length(pt - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return 1.0 - smoothstep(0.015, 0.05, d2 - d1);
}

void fragment() {
	float shore = COLOR.r;
	vec2 uv = world_pos.xz * ripple_scale - flow * TIME;
	vec3 col = mix(shallow, deep, smoothstep(0.0, 0.85, shore));

	// Darker and lighter drifting patches so the surface isn't flat.
	col *= 0.95 + fbm(uv * 0.25 + vec2(TIME * 0.02, 0.0)) * 0.1;
	// Ripple lines, stretched along the flow for rivers, fading out in deep water.
	vec2 rp = uv * 0.8;
	if (length(flow) > 0.0) {
		rp.y *= 0.45;
	}
	// Warp the cells so the lines wobble like real ripples.
	rp += vec2(fbm(rp * 0.6 + TIME * 0.05), fbm(rp * 0.6 + 7.3 - TIME * 0.04)) * 0.9;
	// Patchy: lines only show in drifting clusters.
	float patches = smoothstep(0.35, 0.6, fbm(uv * 0.18 + vec2(TIME * 0.03, -TIME * 0.02)));
	float lines = ripples(rp, TIME) * patches;
	float fade = 1.0 - smoothstep(0.5, 1.0, shore) * 0.6;
	col = mix(col, mix(col, foam, 0.65), lines * ripple_strength * fade);

	// Lapping foam bands near the shore.
	float band = sin(shore * 40.0 - TIME * 1.6 + fbm(world_pos.xz * 0.3) * 4.0);
	float waves = smoothstep(0.75, 0.95, band) * (1.0 - smoothstep(0.03, 0.12, shore)) * shore_waves;
	float depth = 0.5 - COLOR.g;
	float edge = (1.0 - smoothstep(0.02, 0.09, depth)) * shore_waves;
	col = mix(col, foam, clamp(waves * 0.8 + edge, 0.0, 1.0));
	if (rain > 0.0) {
		// Rings spreading where drops land: one per cell, each at its own moment.
		vec2 rc = world_pos.xz * 2.2;
		vec2 id = floor(rc);
		vec2 f = fract(rc) - 0.5 - (vec2(hash21(id), hash21(id + 3.1)) - 0.5) * 0.5;
		float age = fract(TIME * 1.3 + hash21(id + 9.7));
		float ring = 1.0 - smoothstep(0.0, 0.05, abs(length(f) - age * 0.45));
		float shown = step(hash21(id + floor(TIME * 1.3 + hash21(id + 9.7))), rain);
		col = mix(col, foam, ring * (1.0 - age) * shown * 0.7);
	}

	ALBEDO = col;
	ROUGHNESS = 0.6;
	cloud_light = sky_light(VERTEX, INV_VIEW_MATRIX, TIME);
	EMISSION = cel_ambient(ALBEDO);
}
