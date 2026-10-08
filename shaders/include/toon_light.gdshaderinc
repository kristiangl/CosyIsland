// Cel shading with exact palette control. Every lit shader sets
//     EMISSION = cel_ambient(ALBEDO);
// in fragment(), and the sun adds the rest up to cel_lit. A surface in shadow shows
// albedo * cel_shadow, a sunlit one albedo * cel_lit, with one crisp step between.
// Both tints are sRGB multipliers set by DayNight.
//
// Renderer detail (Compatibility): ALBEDO and EMISSION are treated as sRGB, and a
// shadow-casting sun is drawn in a separate additive pass that blends in sRGB space.
// So the base pass gives sRGB albedo * cel_shadow, and the sun pass must add
// sRGB albedo * (cel_lit - cel_shadow), which in linear terms is
// albedo_linear * (cel_lit - cel_shadow)^2.2. Checked with tools/calibrate.tscn.
// The sun must keep shadows enabled for this to hold.

global uniform vec3 cel_lit;
global uniform vec3 cel_shadow;
// Weather (see Weather and DayNight): how much of the sky is cloud. Cloud shadows drift
// across everything the sun lights.
global uniform float cloud_cover;

uniform float light_softness = 0.04;
// Moves the light/shadow line round towards the dark side (characters use this so
// faces stay mostly lit).
uniform float light_wrap = 0.0;
// Icons are lit with these fixed daytime tints instead of the time-of-day globals.
uniform bool fixed_tints = false;
uniform vec3 fixed_lit = vec3(1.0, 0.99, 0.96);
uniform vec3 fixed_shadow = vec3(0.8, 0.77, 0.93);

// Set in fragment() by every lit shader (`cloud_light = sky_light(VERTEX, INV_VIEW_MATRIX, TIME);`
// just before EMISSION), read by light().
varying float cloud_light;

// 1 in sunshine, less under a passing cloud's shadow at a world position.
float cloud_shade(vec3 wp, float t) {
	if (cloud_cover <= 0.01) {
		return 1.0;
	}
	vec2 p = wp.xz * 0.035 + vec2(t * 0.011, t * 0.005);
	float n = value_noise(p) * 0.6 + value_noise(p * 2.3 + vec2(7.0, 3.0)) * 0.4;
	float edge = mix(0.85, 0.12, cloud_cover);
	return mix(1.0, 0.18, smoothstep(edge - 0.05, edge + 0.05, n));
}

// cloud_shade for a fragment's view-space position.
float sky_light(vec3 view_pos, mat4 inv_view, float t) {
	return cloud_shade((inv_view * vec4(view_pos, 1.0)).xyz, t);
}

vec3 cel_ambient(vec3 albedo) {
	return albedo * (fixed_tints ? fixed_shadow : cel_shadow);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(-light_wrap, -light_wrap + light_softness, ndl);
	if (LIGHT_IS_DIRECTIONAL) {
		lit *= smoothstep(0.35, 0.65, ATTENUATION);
		if (!fixed_tints) {
			lit *= cloud_light;
		}
		vec3 lit_tint = fixed_tints ? fixed_lit : cel_lit;
		vec3 shadow_tint = fixed_tints ? fixed_shadow : cel_shadow;
		DIFFUSE_LIGHT += pow(max(lit_tint - shadow_tint, vec3(0.0)), vec3(2.2)) * lit;
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit * ATTENUATION;
	}
}
