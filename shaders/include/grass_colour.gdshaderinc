// Grass palette shared by the terrain and the grass tufts so they blend into each other.

uniform vec3 grass_light : source_color = vec3(0.50, 0.73, 0.31);
uniform vec3 grass_mid : source_color = vec3(0.37, 0.61, 0.27);
uniform vec3 grass_dark : source_color = vec3(0.27, 0.51, 0.27);
uniform vec3 grass_warm : source_color = vec3(0.66, 0.74, 0.32);

vec3 grass_colour(vec2 xz) {
	float patches = fbm(xz * 0.09);
	float detail = value_noise(xz * 0.9);
	vec3 col = mix(grass_dark, grass_mid, smoothstep(0.3, 0.5, patches));
	col = mix(col, grass_light, smoothstep(0.55, 0.72, patches));
	// Sun-bleached warm patches, very large scale.
	col = mix(col, grass_warm, smoothstep(0.62, 0.85, fbm(xz * 0.025 + 31.0)) * 0.3);
	col *= 0.94 + detail * 0.1;
	return col;
}
