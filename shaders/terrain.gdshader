shader_type spatial;
render_mode world_vertex_coords, specular_disabled;

// Terrain surface. Vertex colour alpha picks the material:
// 1.0 grass, 0.75 sand, 0.5 cliff face, 0.25 river or pond bed.

#include "res://shaders/include/world.gdshaderinc"
#include "res://shaders/include/grass_colour.gdshaderinc"
#include "res://shaders/include/toon_light.gdshaderinc"

uniform vec3 sand_light : source_color = vec3(0.98, 0.91, 0.76);
uniform vec3 sand_dark : source_color = vec3(0.95, 0.86, 0.70);
uniform vec3 sand_wet : source_color = vec3(0.86, 0.79, 0.68);
uniform vec3 cliff_light : source_color = vec3(0.84, 0.70, 0.60);
uniform vec3 cliff_dark : source_color = vec3(0.73, 0.59, 0.53);
uniform vec3 bed_colour : source_color = vec3(0.58, 0.74, 0.70);

varying vec3 world_pos;

void vertex() {
	world_pos = VERTEX;
	VERTEX = curve_world(VERTEX);
}

void fragment() {
	float kind = COLOR.a;
	vec2 xz = world_pos.xz;
	vec3 col;
	if (kind > 0.875) {
		col = grass_colour(xz);
	} else if (kind > 0.625) {
		float n = fbm(xz * 0.35);
		col = mix(sand_dark, sand_light, smoothstep(0.3, 0.7, n));
		col *= 0.97 + value_noise(xz * 6.0) * 0.06;
		col = mix(sand_wet, col, smoothstep(-0.05, 0.08, world_pos.y));
	} else if (kind > 0.375) {
		// Soft horizontal strata, wobbled so they look hand drawn.
		float wobble = fbm(vec2(xz.x + xz.y, world_pos.y) * 0.8) * 0.35;
		float strata = smoothstep(0.35, 0.65, fract(world_pos.y * 1.6 + wobble));
		col = mix(cliff_dark, cliff_light, strata * 0.6 + 0.25);
		col *= 0.92 + value_noise(xz * 3.0 + world_pos.y) * 0.12;
	} else {
		col = bed_colour * (0.85 + fbm(xz * 0.5) * 0.25);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	EMISSION = cel_ambient(ALBEDO);
}
