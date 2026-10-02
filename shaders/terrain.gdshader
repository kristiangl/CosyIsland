shader_type spatial;
render_mode world_vertex_coords, specular_disabled;

// Terrain surface. Vertex colour alpha picks the material:
// 1.0 ground (red = grass weight, blending grass into sand; green = 0 at the foot of a
// cliff for a little contact shade), 0.75 grass lip on a cliff
// top, 0.5 cliff face, 0.25 river or pond bed.

#include "res://shaders/include/world.gdshaderinc"
#include "res://shaders/include/grass_colour.gdshaderinc"
#include "res://shaders/include/toon_light.gdshaderinc"

uniform vec3 sand_light : source_color = vec3(0.98, 0.91, 0.76);
uniform vec3 sand_dark : source_color = vec3(0.95, 0.86, 0.70);
uniform vec3 sand_wet : source_color = vec3(0.86, 0.79, 0.68);
uniform vec3 cliff_light : source_color = vec3(0.78, 0.71, 0.66);
uniform vec3 cliff_dark : source_color = vec3(0.62, 0.55, 0.54);
uniform vec3 bed_colour : source_color = vec3(0.58, 0.74, 0.70);

varying vec3 world_pos;

void vertex() {
	world_pos = VERTEX;
	VERTEX = curve_world(VERTEX);
}

vec3 sand_colour(vec2 xz, float y) {
	float n = fbm(xz * 0.35);
	vec3 col = mix(sand_dark, sand_light, smoothstep(0.3, 0.7, n));
	col *= 0.98 + value_noise(xz * 6.0) * 0.04;
	return mix(sand_wet, col, smoothstep(-0.05, 0.08, y));
}

void fragment() {
	float kind = COLOR.a;
	vec2 xz = world_pos.xz;
	vec3 col;
	if (kind > 0.875) {
		// Grass and sand blend along a wobbly line where the grass weight crosses 0.5.
		float wobble = (value_noise(xz * 1.3) - 0.5) * 0.4 + (value_noise(xz * 4.1) - 0.5) * 0.12;
		float grass = smoothstep(0.47, 0.53, COLOR.r + wobble);
		col = mix(sand_colour(xz, world_pos.y), grass_colour(xz), grass);
		// Soft shade at the foot of cliffs (vertex green is 0 next to a higher tile).
		col *= mix(0.86, 1.0, smoothstep(0.0, 1.0, COLOR.g));
	} else if (kind > 0.625) {
		col = grass_colour(xz);
	} else if (kind > 0.375) {
		// Soft horizontal strata, wobbled so they look hand drawn.
		float wobble = fbm(vec2(xz.x + xz.y, world_pos.y) * 0.8) * 0.35;
		float strata = smoothstep(0.45, 0.55, fract(world_pos.y * 1.6 + wobble));
		col = mix(cliff_dark, cliff_light, strata * 0.5 + 0.3);
	} else {
		col = bed_colour * (0.9 + fbm(xz * 0.5) * 0.15);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	EMISSION = cel_ambient(ALBEDO);
}
