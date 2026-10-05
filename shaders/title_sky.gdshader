shader_type canvas_item;

// The title screen's backdrop: a soft morning sky with drifting clouds, the sun low over
// a calm sea, and a little island on the horizon. Colours are sRGB.

uniform vec3 sky_top : source_color = vec3(0.67, 0.85, 0.93);
uniform vec3 sky_low : source_color = vec3(0.99, 0.93, 0.82);
uniform vec3 sea_far : source_color = vec3(0.55, 0.80, 0.86);
uniform vec3 sea_near : source_color = vec3(0.36, 0.67, 0.80);
uniform vec3 sun_colour : source_color = vec3(1.0, 0.92, 0.70);
uniform vec3 grass : source_color = vec3(0.56, 0.78, 0.47);
uniform vec3 sand : source_color = vec3(0.96, 0.88, 0.70);
uniform vec2 screen = vec2(1280.0, 720.0);

const float HORIZON = 0.66;

float cloud(vec2 p, vec2 c, float s) {
	float d = length((p - c) / vec2(1.0, 0.55)) - 0.07 * s;
	d = min(d, length((p - c - vec2(0.06, 0.012) * s) / vec2(1.0, 0.6)) - 0.055 * s);
	d = min(d, length((p - c + vec2(0.065, -0.01) * s) / vec2(1.0, 0.6)) - 0.05 * s);
	return d;
}

void fragment() {
	float aspect = screen.x / screen.y;
	vec2 uv = UV;
	vec2 p = vec2(uv.x * aspect, uv.y);
	vec3 col;
	if (uv.y < HORIZON) {
		float t = uv.y / HORIZON;
		col = mix(sky_top, sky_low, smoothstep(0.0, 1.0, t));
		// The sun, low and hazy.
		vec2 sun = vec2(aspect * 0.72, HORIZON - 0.13);
		float r = length(p - sun);
		col = mix(col, sun_colour, 0.35 * (1.0 - smoothstep(0.0, 0.32, r)));
		col = mix(col, sun_colour, 1.0 - smoothstep(0.075, 0.08, r));
		// Clouds drifting by.
		for (int i = 0; i < 4; i++) {
			float fi = float(i);
			float speed = 0.006 + fi * 0.002;
			float x = mod(fi * 0.53 * aspect + TIME * speed, aspect + 0.6) - 0.3;
			vec2 c = vec2(x, 0.12 + fi * 0.09);
			float d = cloud(p, c, 1.0 + 0.3 * sin(fi * 2.1));
			col = mix(col, vec3(1.0, 0.99, 0.96), (1.0 - smoothstep(-0.004, 0.004, d)) * 0.9);
		}
	} else {
		float t = (uv.y - HORIZON) / (1.0 - HORIZON);
		col = mix(sea_far, sea_near, t);
		// Glints that ripple sideways.
		float wave = sin(p.x * 34.0 / (0.3 + t) + TIME * 0.9 + sin(uv.y * 90.0) * 1.5);
		float rows = step(0.6, fract(uv.y * (40.0 - t * 18.0)));
		col = mix(col, vec3(1.0), smoothstep(0.86, 0.98, wave) * rows * (0.25 + 0.2 * (1.0 - t)));
		// The sun's path on the water.
		float path = 1.0 - smoothstep(0.0, 0.07 + t * 0.12, abs(p.x - aspect * 0.72));
		col = mix(col, sun_colour, path * rows * 0.35 * (1.0 - t));
	}
	// A little island on the horizon, with a palm.
	vec2 isl = vec2(aspect * 0.24, HORIZON + 0.004);
	vec2 q = (p - isl) / vec2(0.26, 0.07);
	if (p.y < isl.y && length(q) < 1.0) {
		col = length(q) > 0.86 || p.y > isl.y - 0.012 ? sand : grass;
	}
	vec2 trunk = p - isl - vec2(0.07, -0.065);
	float lean = trunk.x + trunk.y * 0.25;
	if (abs(lean) < 0.006 && trunk.y > -0.07 && trunk.y < 0.0) {
		col = vec3(0.55, 0.42, 0.32);
	}
	// Fronds drooping either way from the top of the trunk.
	vec2 crown = p - isl - vec2(0.0875, -0.135);
	const vec2 FRONDS[6] = vec2[](vec2(-1.0, 0.35), vec2(-0.8, -0.25), vec2(-0.2, -0.75),
		vec2(0.35, -0.7), vec2(0.85, -0.2), vec2(1.0, 0.4));
	for (int i = 0; i < 6; i++) {
		vec2 dir = normalize(FRONDS[i]);
		float along = dot(crown, dir);
		float droop = along * along * 3.0;
		vec2 bent = crown - vec2(0.0, droop);
		along = dot(bent, dir);
		float off = length(bent - dir * along);
		float len = 0.075;
		if (length(crown) < 0.1 && along > 0.0 && along < len && off < 0.014 * sin(along / len * 3.1416) + 0.002) {
			col = vec3(0.42, 0.68, 0.40);
		}
	}
	COLOR = vec4(col, 1.0);
}
