shader_type sky;

// Painted gradient sky driven by the time of day (DayNight), seen when you look up
// (CameraRig): clouds as thick as the weather says, stars at night with now and then a
// shooting star, and a rainbow after the showers.

global uniform float cloud_cover;
global uniform float night;

uniform vec3 top_colour : source_color = vec3(0.55, 0.77, 0.95);
uniform vec3 horizon_colour : source_color = vec3(0.86, 0.93, 0.96);
uniform vec3 sun_colour : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3 sun_direction = vec3(0.0, 0.5, -1.0);
// The colour clouds take: white by day, grey in the rain, dusky at night.
uniform vec3 cloud_colour : source_color = vec3(1.0, 1.0, 1.0);
uniform float rainbow = 0.0;
// How often shooting stars cross (0 none; set on clear nights).
uniform float meteors = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float clouds_at(vec2 p) {
	float v = noise(p) * 0.5 + noise(p * 2.1 + 3.7) * 0.3 + noise(p * 4.3 + 9.1) * 0.2;
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(horizon_colour, top_colour, pow(up, 0.55));
	float sun = max(dot(dir, normalize(sun_direction)), 0.0);
	col += sun_colour * (pow(sun, 64.0) * 0.6 + pow(sun, 6.0) * 0.12) * (1.0 - cloud_cover * 0.8);

	// Stars, twinkling, where the sky's clear.
	if (night > 0.01 && dir.y > 0.0) {
		vec2 sp = dir.xz / (dir.y + 0.35) * 60.0;
		vec2 cell = floor(sp);
		float h = hash(cell);
		vec2 off = vec2(hash(cell + 1.3), hash(cell + 7.1)) - 0.5;
		float d = length(fract(sp) - 0.5 - off * 0.6);
		float star = step(0.93, h) * (1.0 - smoothstep(0.02, 0.09, d)) * (0.6 + 0.4 * sin(TIME * 3.0 + h * 40.0));
		col += vec3(1.0, 0.97, 0.9) * star * night * (1.0 - cloud_cover) * smoothstep(0.02, 0.2, dir.y);
		// A shooting star now and then: a short bright streak sliding down the sky.
		if (meteors > 0.0) {
			float slot = floor(TIME / 2.5);
			float when = fract(TIME / 2.5);
			if (hash(vec2(slot, 4.2)) < meteors) {
				vec2 start = vec2(hash(vec2(slot, 1.0)) - 0.5, 0.35 + hash(vec2(slot, 2.0)) * 0.35);
				vec2 heading = normalize(vec2(0.6 + hash(vec2(slot, 3.0)), -0.45));
				vec2 head = start + heading * when * 0.5;
				vec2 q = vec2(dir.x, dir.y) - head;
				float along = dot(q, -heading);
				float across = abs(dot(q, vec2(-heading.y, heading.x)));
				float streak = (1.0 - smoothstep(0.0015, 0.004, across)) * step(0.0, along) * (1.0 - smoothstep(0.0, 0.09, along));
				col += vec3(1.0, 0.95, 0.85) * streak * sin(when * 3.14159) * night * 1.5 * step(dir.z, 0.0);
			}
		}
	}

	// A rainbow over the northern sky, round a point below the horizon.
	if (rainbow > 0.0) {
		vec3 centre = normalize(vec3(0.15, -0.2, -1.0));
		float angle = degrees(acos(clamp(dot(dir, centre), -1.0, 1.0)));
		float r = (angle - 38.0) / 5.0;
		if (r > 0.0 && r < 1.0) {
			// Red on the outside through to violet inside, in soft pastels.
			float hue = clamp((0.88 - r) / 0.76, 0.0, 1.0) * 0.75;
			vec3 bow = clamp(abs(fract(vec3(hue) + vec3(1.0, 0.6667, 0.3333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
			bow = mix(vec3(1.0), bow, 0.5);
			float fade = smoothstep(0.0, 0.2, r) * (1.0 - smoothstep(0.8, 1.0, r)) * smoothstep(0.0, 0.08, dir.y);
			col = mix(col, bow, fade * rainbow * 0.45);
		}
	}

	// Clouds drifting overhead, more of them the cloudier it is.
	if (dir.y > 0.0) {
		vec2 cp = dir.xz / (dir.y + 0.12) * 1.6 + vec2(TIME * 0.006, TIME * 0.003);
		float c = clouds_at(cp);
		float edge = mix(0.78, 0.2, cloud_cover);
		float cover = smoothstep(edge, edge + 0.12, c) * smoothstep(0.0, 0.12, dir.y);
		vec3 cloud = cloud_colour * (0.88 + 0.12 * smoothstep(edge, edge + 0.3, c));
		col = mix(col, cloud, cover * 0.92);
	}
	// Soft cloud bank near the horizon.
	float band = smoothstep(0.0, 0.08, up) * (1.0 - smoothstep(0.08, 0.3, up));
	col = mix(col, horizon_colour * 1.05, band * 0.35);
	COLOR = col;
}
