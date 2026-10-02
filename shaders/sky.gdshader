shader_type sky;

// Painted gradient sky driven by the time of day (see DayNight).

uniform vec3 top_colour : source_color = vec3(0.55, 0.77, 0.95);
uniform vec3 horizon_colour : source_color = vec3(0.86, 0.93, 0.96);
uniform vec3 sun_colour : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3 sun_direction = vec3(0.0, 0.5, -1.0);

void sky() {
	float up = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 col = mix(horizon_colour, top_colour, pow(up, 0.55));
	float sun = max(dot(normalize(EYEDIR), normalize(sun_direction)), 0.0);
	col += sun_colour * (pow(sun, 64.0) * 0.6 + pow(sun, 6.0) * 0.12);
	// Soft cloud bank near the horizon.
	float band = smoothstep(0.0, 0.08, up) * (1.0 - smoothstep(0.08, 0.3, up));
	col = mix(col, horizon_colour * 1.05, band * 0.35);
	COLOR = col;
}
