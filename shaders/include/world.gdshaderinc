// Shared world helpers: the "rolling log" curvature, wind and cheap value noise.
// Every world shader runs its vertices through curve_world so the island bends away
// from the camera like a gently rolling hill.

global uniform vec3 curve_origin;
global uniform float curve_amount;
global uniform float wind_strength;
// Weather: how wet the ground is, and how much snow lies on it (0 to 1).
global uniform float wetness;
global uniform float snow_cover;

vec3 curve_world(vec3 p) {
	float dz = p.z - curve_origin.z;
	p.y -= dz * dz * curve_amount;
	return p;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		v += value_noise(p) * amp;
		p = p * 2.03 + vec2(17.1, 9.7);
		amp *= 0.5;
	}
	return v / 0.875;
}

// Sideways sway for things rooted at their origin. height = metres above the root, t = TIME.
vec3 wind_offset(vec3 root, float height, float weight, float t) {
	float phase = t * 1.4 + root.x * 0.37 + root.z * 0.23;
	float gust = 0.6 + 0.4 * sin(t * 0.31 + root.x * 0.05);
	float sway = sin(phase) * gust * height * weight * 0.035 * wind_strength;
	return vec3(sway, 0.0, sway * 0.4);
}

// Snow lying on the ground, a little blue in the hollows.
vec3 snow_colour(vec2 xz) {
	return vec3(0.95, 0.97, 1.0) * (0.95 + value_noise(xz * 1.7) * 0.06);
}

// Wet ground: darker and a little cooler.
vec3 wet(vec3 col) {
	return mix(col, col * vec3(0.76, 0.8, 0.86), wetness * 0.85);
}
