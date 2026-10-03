shader_type spatial;
render_mode world_vertex_coords, specular_disabled;

// Terrain surface. Vertex colour alpha picks the material:
// 1.0 ground (red = grass weight, blending grass into sand; green = 0 at the foot of a
// cliff for a little contact shade; blue = 0 along the top of one for a light rim),
// 0.75 grass lip on a cliff
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
// The plaza's paved area in tiles: x, z, width, depth (zero width for none).
uniform vec4 plaza = vec4(0.0);
uniform vec3 paving_light : source_color = vec3(0.94, 0.87, 0.79);
uniform vec3 paving_dark : source_color = vec3(0.80, 0.72, 0.66);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = VERTEX;
	world_normal = NORMAL;
	VERTEX = curve_world(VERTEX);
}

// Chunky stacked stones: staggered rows of blocks with darker joints, a lighter top
// edge on each block and a little tone variation from block to block.
vec3 cliff_colour(vec3 n, vec3 p) {
	vec2 along = normalize(vec2(-n.z, n.x) + vec2(0.0001));
	float u = dot(p.xz, along);
	// Wobble the rows so the stones look piled rather than laid.
	float y = p.y + (value_noise(vec2(u * 2.2, 1.0)) - 0.5) * 0.12;
	float row_h = 0.42;
	float row = floor(y / row_h);
	float v = fract(y / row_h);
	float width = 0.6 + hash21(vec2(row, 3.0)) * 0.35;
	float uu = u / width + hash21(vec2(row, 7.0));
	float block = floor(uu);
	float fu = fract(uu);
	float tone = hash21(vec2(block, row));
	vec3 col = mix(cliff_dark, cliff_light, 0.35 + tone * 0.4);
	col = mix(col, col * 1.12, smoothstep(0.72, 0.8, v));
	float edge_u = min(fu, 1.0 - fu) * width;
	float joint = max(1.0 - smoothstep(0.0, 0.05, v), 1.0 - smoothstep(0.0, 0.035, edge_u + (value_noise(p.xz * 9.0 + p.y) - 0.5) * 0.02));
	return mix(col, cliff_dark * 0.88, joint * 0.6);
}

// 1 inside the plaza's rounded, slightly wobbly outline.
float plaza_mask(vec2 xz) {
	if (plaza.z <= 0.0) {
		return 0.0;
	}
	vec2 centre = plaza.xy + plaza.zw * 0.5;
	float radius = 1.8;
	vec2 q = abs(xz - centre) - (plaza.zw * 0.5 + 0.25 - radius);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	d += (value_noise(xz * 1.3) - 0.5) * 0.3 + (value_noise(xz * 5.0) - 0.5) * 0.06;
	return 1.0 - smoothstep(-0.04, 0.04, d);
}

// Irregular flagstones (a jittered cell pattern) with soft grout between.
vec3 paving_colour(vec2 xz) {
	vec2 p = xz * 1.8;
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash21(i + g), hash21(i + g + 17.3)) * 0.8 + 0.1;
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = i + g;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	vec3 stone = mix(paving_dark, paving_light, 0.55 + hash21(id) * 0.4);
	stone *= 0.97 + value_noise(xz * 7.0) * 0.05;
	return mix(mix(stone, paving_dark * 0.94, 0.7), stone, smoothstep(0.04, 0.11, d2 - d1));
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
		col = mix(col, paving_colour(xz), plaza_mask(xz));
		// Soft shade at the foot of cliffs (vertex green is 0 next to a higher tile), and
		// a narrow light rim along their tops, so drops read from any side.
		col *= mix(0.82, 1.0, smoothstep(0.0, 1.0, COLOR.g));
		col = mix(col * 1.09 + vec3(0.015), col, smoothstep(0.12, 0.3, COLOR.b));
	} else if (kind > 0.625) {
		col = grass_colour(xz);
	} else if (kind > 0.375) {
		col = cliff_colour(world_normal, world_pos);
	} else {
		col = bed_colour * (0.9 + fbm(xz * 0.5) * 0.15);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	EMISSION = cel_ambient(ALBEDO);
}
