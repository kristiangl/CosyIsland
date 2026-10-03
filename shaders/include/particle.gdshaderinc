// Shared body for shaders/particle.gdshader (soft-edged, blended) and
// shaders/particle_glow.gdshader (added on top, for fire and glowing things).
#include "res://shaders/include/world.gdshaderinc"

// 0 soft dot, 1 sparkle (four-point star), 2 leaf, 3 heart, 4 flame, 5 puff (smoke),
// 6 square chip, 7 ring.
uniform int shape = 0;
// Off for effects shown outside the island.
uniform bool curved = true;
// Brightens towards white in the middle, for glowing things (fire, fireflies).
uniform float glow = 0.0;

varying float seed;

void vertex() {
	// Face the camera but keep the particle's own size and spin (INSTANCE_CUSTOM.x).
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 centre = MODEL_MATRIX[3].xyz;
	if (curved) {
		centre = curve_world(centre);
	}
	mat4 m = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(centre, 1.0));
	seed = float(INSTANCE_ID) * 1.7;
	float spin = INSTANCE_CUSTOM.x;
	mat2 r = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin)));
	vec2 v = r * VERTEX.xy;
	MODELVIEW_MATRIX = VIEW_MATRIX * m;
	VERTEX = vec3(v.x * scale.x, v.y * scale.y, 0.0);
}

float heart(vec2 p) {
	p.y += 0.25;
	p.x = abs(p.x);
	float a = atan(p.x, p.y) / 3.14159;
	float r = length(p);
	float h = abs(a);
	float d = (13.0 * h - 22.0 * h * h + 10.0 * h * h * h) / (6.0 - 5.0 * h);
	return 1.0 - smoothstep(d * 0.42 - 0.03, d * 0.42, r);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = 0.0;
	if (shape == 1) {
		float star = min(abs(p.x) * 6.0 + abs(p.y), abs(p.y) * 6.0 + abs(p.x));
		a = 1.0 - smoothstep(0.75, 1.0, star);
		a = max(a, 1.0 - smoothstep(0.0, 0.35, length(p)));
	} else if (shape == 2) {
		// Leaf: a lens shape with a midrib.
		float lens = length(vec2(p.x * 1.9, p.y)) + abs(p.x) * 0.6;
		a = 1.0 - smoothstep(0.85, 0.95, lens);
		a *= 1.0 - 0.35 * (1.0 - smoothstep(0.0, 0.07, abs(p.x)));
	} else if (shape == 3) {
		a = heart(p * 1.1);
	} else if (shape == 4) {
		// Flame: a teardrop pointing up.
		vec2 q = vec2(p.x / (0.75 - 0.35 * p.y), p.y);
		a = 1.0 - smoothstep(0.8, 1.0, length(vec2(q.x, max(q.y, 0.0) * 0.6 + min(q.y, 0.0))));
	} else if (shape == 5) {
		// Smoke puff: a soft, slightly lumpy blob.
		float lump = 0.85 + 0.05 * sin(atan(p.y, p.x) * 3.0 + seed);
		a = (1.0 - smoothstep(lump - 0.35, lump, length(p))) * 0.85;
	} else if (shape == 6) {
		a = 1.0 - smoothstep(0.6, 0.75, max(abs(p.x), abs(p.y)));
	} else if (shape == 7) {
		a = 1.0 - smoothstep(0.08, 0.16, abs(length(p) - 0.75));
	} else {
		a = 1.0 - smoothstep(0.2, 1.0, length(p));
	}
	vec3 col = COLOR.rgb;
	if (glow > 0.0) {
		col = mix(col, vec3(1.0, 0.98, 0.9), glow * (1.0 - smoothstep(0.0, 0.6, length(p))));
	}
	ALBEDO = col;
	ALPHA = a * COLOR.a;
}
