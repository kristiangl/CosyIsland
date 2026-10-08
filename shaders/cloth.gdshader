shader_type spatial;
render_mode specular_disabled;

// Clothes, hair, hats, shoes and skin on characters. One colour (or a pattern of two)
// per material; meshes carry metre-based UVs (around, up) from MeshKit.
// Vertex colour: red = brightness (inner faces are a little darker), green = 0 on trim
// pieces (collars, cuffs, buttons, laces) which take colour_b instead.

#include "res://shaders/include/world.gdshaderinc"
#include "res://shaders/include/toon_light.gdshaderinc"
#include "res://shaders/include/patterns.gdshaderinc"

// Off for characters shown outside the island (menus), where world curvature makes no sense.
uniform bool curved = true;

uniform vec3 colour_a : source_color = vec3(0.94, 0.54, 0.48);
uniform vec3 colour_b : source_color = vec3(0.97, 0.96, 0.93);
// 0 plain, 1 stripes, 2 wide stripes, 3 dots, 4 checks, 5 hearts, 6 stars, 7 flowers, 8 two-tone,
// 9 gingham, 10 tartan, 11 waves, 12 leaves, 13 argyle, 14 cherries, 15 clouds.
uniform int pattern = 0;
uniform float pattern_scale = 1.0;
// Lighter band for hair shine.
uniform float shine = 0.0;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (curved) {
		VERTEX += (inverse(MODEL_MATRIX) * vec4(curve_world(world) - world, 0.0)).xyz;
	}
}

void fragment() {
	vec3 col = pattern_colour(pattern, UV / pattern_scale, colour_a, colour_b);
	if (COLOR.g < 0.5) {
		col = colour_b;
	}
	if (shine > 0.0) {
		// A soft anime-style highlight band across the top of the hair.
		vec3 n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		float band = smoothstep(0.55, 0.62, n.y) * (1.0 - smoothstep(0.75, 0.82, n.y));
		col = mix(col, min(col * 1.25 + vec3(0.06), vec3(1.0)), band * shine);
	}
	ALBEDO = col * COLOR.r;
	ROUGHNESS = 1.0;
	cloud_light = sky_light(VERTEX, INV_VIEW_MATRIX, TIME);
	EMISSION = cel_ambient(ALBEDO);
}
