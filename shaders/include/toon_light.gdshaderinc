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

uniform float light_softness = 0.04;
// Moves the light/shadow line round towards the dark side (characters use this so
// faces stay mostly lit).
uniform float light_wrap = 0.0;

vec3 cel_ambient(vec3 albedo) {
	return albedo * cel_shadow;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(-light_wrap, -light_wrap + light_softness, ndl);
	if (LIGHT_IS_DIRECTIONAL) {
		lit *= smoothstep(0.35, 0.65, ATTENUATION);
		DIFFUSE_LIGHT += pow(max(cel_lit - cel_shadow, vec3(0.0)), vec3(2.2)) * lit;
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit * ATTENUATION;
	}
}
