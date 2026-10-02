shader_type spatial;
render_mode specular_disabled;

// Clothes, hair, hats, shoes and skin on characters. One colour (or a pattern of two)
// per material; meshes carry metre-based UVs (around, up) from MeshKit.
// Vertex colour: red = brightness (inner faces are a little darker), green = 0 on trim
// pieces (collars, cuffs, buttons, laces) which take colour_b instead.

#include "res://shaders/include/world.gdshaderinc"
#include "res://shaders/include/toon_light.gdshaderinc"

// Off for characters shown outside the island (menus), where world curvature makes no sense.
uniform bool curved = true;

uniform vec3 colour_a : source_color = vec3(0.94, 0.54, 0.48);
uniform vec3 colour_b : source_color = vec3(0.97, 0.96, 0.93);
// 0 plain, 1 stripes, 2 wide stripes, 3 dots, 4 checks, 5 hearts, 6 stars, 7 flowers, 8 two-tone.
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

float sd_heart(vec2 p) {
	p.x = abs(p.x);
	if (p.y + p.x > 1.0) {
		return sqrt(dot(p - vec2(0.25, 0.75), p - vec2(0.25, 0.75))) - sqrt(2.0) / 4.0;
	}
	vec2 a = p - vec2(0.0, 1.0);
	vec2 b = p - 0.5 * max(p.x + p.y, 0.0);
	return sqrt(min(dot(a, a), dot(b, b))) * sign(p.x - p.y);
}

// Five-pointed star (approximate distance): radius swings between inner and outer.
float sd_star(vec2 p, float r) {
	float seg = 6.2832 / 5.0;
	float t = fract((atan(p.y, p.x) + 1.5708) / seg);
	float f = abs(t - 0.5) * 2.0;
	return length(p) - mix(r * 0.45, r, f * f);
}

// Returns 1 where the pattern shows colour_b.
float pattern_mask(vec2 uv, float aa) {
	if (pattern == 1) {
		return step(0.5, fract(uv.y / 0.05));
	}
	if (pattern == 2) {
		return step(0.5, fract(uv.y / 0.11));
	}
	if (pattern == 4) {
		vec2 c = floor(uv / 0.05);
		return mod(c.x + c.y, 2.0);
	}
	if (pattern == 8) {
		return step(uv.y, 0.52);
	}
	// Motif patterns on a staggered grid.
	float cell = pattern == 3 ? 0.055 : 0.09;
	vec2 g = uv / cell;
	g.x += mod(floor(g.y), 2.0) * 0.5;
	vec2 p = (fract(g) - 0.5) * cell;
	float d;
	if (pattern == 3) {
		d = length(p) - cell * 0.22;
	} else if (pattern == 5) {
		d = sd_heart(vec2(p.x, -p.y + cell * 0.22) / (cell * 0.36)) * cell * 0.36;
	} else if (pattern == 6) {
		d = sd_star(p, cell * 0.3);
	} else if (pattern == 7) {
		float a = atan(p.y, p.x);
		d = length(p) - cell * (0.2 + 0.08 * cos(a * 5.0));
	} else {
		return 0.0;
	}
	return 1.0 - smoothstep(-aa, aa, d);
}

void fragment() {
	vec2 uv = UV / pattern_scale;
	float aa = max(fwidth(uv.x), fwidth(uv.y)) * 0.8;
	vec3 col = pattern == 0 ? colour_a : mix(colour_a, colour_b, pattern_mask(uv, aa));
	if (pattern == 7) {
		// Flower centres.
		float cell = 0.09;
		vec2 g = uv / cell;
		g.x += mod(floor(g.y), 2.0) * 0.5;
		vec2 p = (fract(g) - 0.5) * cell;
		col = mix(col, vec3(0.98, 0.84, 0.4), 1.0 - smoothstep(-aa, aa, length(p) - cell * 0.08));
	}
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
	EMISSION = cel_ambient(ALBEDO);
}
