// Grass palette shared by the terrain and the grass tufts so they blend into each other.

uniform vec3 grass_light : source_color = vec3(0.72, 0.89, 0.62);
uniform vec3 grass_mid : source_color = vec3(0.66, 0.86, 0.59);
uniform vec3 grass_dark : source_color = vec3(0.60, 0.81, 0.57);
uniform vec3 grass_warm : source_color = vec3(0.78, 0.89, 0.62);

float _seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// Little painted grass marks scattered over the ground: a "v" of two short strokes per
// cell, pointing away from the camera so they read as tufts. Returns -1 (dark mark),
// +1 (light mark) or 0.
float grass_marks(vec2 xz) {
	vec2 p = xz / 0.42;
	vec2 cell = floor(p);
	float h = hash21(cell);
	if (h < 0.45) {
		return 0.0;
	}
	vec2 base = cell + 0.25 + 0.5 * vec2(hash21(cell + 1.7), hash21(cell + 3.1));
	float lean = (hash21(cell + 5.3) - 0.5) * 0.12;
	float d = min(_seg(p, base, base + vec2(-0.11 + lean, -0.28)), _seg(p, base, base + vec2(0.1 + lean, -0.24)));
	d = min(d, _seg(p, base, base + vec2(lean, -0.34)));
	float mark = 1.0 - smoothstep(0.022, 0.05, d);
	return mark * (h > 0.8 ? 1.0 : -1.0);
}

// The season's tint on the grass (Weather): golden in autumn, paler in winter.
global uniform vec3 grass_tint;

vec3 grass_colour(vec2 xz) {
	float patches = fbm(xz * 0.09);
	float detail = value_noise(xz * 0.9);
	vec3 col = mix(grass_dark, grass_mid, smoothstep(0.3, 0.5, patches));
	col = mix(col, grass_light, smoothstep(0.55, 0.72, patches));
	// Sun-bleached warm patches, very large scale.
	col = mix(col, grass_warm, smoothstep(0.62, 0.85, fbm(xz * 0.025 + 31.0)) * 0.2);
	col *= 0.97 + detail * 0.05;
	float mark = grass_marks(xz);
	col *= 1.0 + (mark < 0.0 ? mark * 0.11 : mark * 0.07);
	return col * grass_tint;
}
