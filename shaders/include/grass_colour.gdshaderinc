// Grass palette shared by the terrain and the grass tufts so they blend into each other.

uniform vec3 grass_light : source_color = vec3(0.72, 0.89, 0.62);
uniform vec3 grass_mid : source_color = vec3(0.66, 0.86, 0.59);
uniform vec3 grass_dark : source_color = vec3(0.60, 0.81, 0.57);
uniform vec3 grass_warm : source_color = vec3(0.78, 0.89, 0.62);

vec3 grass_colour(vec2 xz) {
	float patches = fbm(xz * 0.09);
	float detail = value_noise(xz * 0.9);
	vec3 col = mix(grass_dark, grass_mid, smoothstep(0.3, 0.5, patches));
	col = mix(col, grass_light, smoothstep(0.55, 0.72, patches));
	// Sun-bleached warm patches, very large scale.
	col = mix(col, grass_warm, smoothstep(0.62, 0.85, fbm(xz * 0.025 + 31.0)) * 0.2);
	col *= 0.97 + detail * 0.05;
	return col;
}
