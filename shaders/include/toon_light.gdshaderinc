// Soft two-tone lighting with a warm rim, in the spirit of hand-painted animation.
// Shadowed sides fall back to the (cool, sky-coloured) ambient light set by DayNight,
// which gives the blue-violet shadows instead of grey ones.

uniform float light_softness = 0.22;
uniform float rim_strength = 0.18;

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(-0.04, light_softness, ndl) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	SPECULAR_LIGHT += LIGHT_COLOR / PI * rim * rim_strength * lit;
}
