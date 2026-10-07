shader_type spatial;
render_mode world_vertex_coords, specular_disabled;

// Paths laid with the landscaping app, and the stairs they make on slopes.
// COLOR.r is the kind (World.PATH_KINDS order, as index / 8), COLOR.g which of the eight
// neighbouring tiles have a path too (as bits / 255: N 1, E 2, S 4, W 8, NE 16, SE 32,
// SW 64, NW 128), COLOR.b 1 on flat path and stair treads, 0.5 on stair risers and sides.
// UV is the position across the tile (x east, y south), for rounding the outer corners.

#include "res://shaders/include/world.gdshaderinc"
#include "res://shaders/include/toon_light.gdshaderinc"

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = VERTEX;
	world_normal = NORMAL;
	VERTEX = curve_world(VERTEX);
}

bool has(int mask, int bit) {
	return (mask & bit) != 0;
}

// Irregular cobbles: a jittered cell pattern, returning the cell's tone (x) and how far
// in from its edge we are (y).
vec2 cells(vec2 p) {
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
	return vec2(hash21(id), d2 - d1);
}

vec3 stone(vec2 xz) {
	vec2 c = cells(xz * 2.6);
	vec3 col = mix(vec3(0.66, 0.65, 0.66), vec3(0.86, 0.85, 0.84), 0.35 + c.x * 0.55);
	col *= 0.97 + value_noise(xz * 9.0) * 0.05;
	return mix(vec3(0.56, 0.55, 0.56), col, smoothstep(0.04, 0.12, c.y));
}

// Bricks in a running bond along x.
vec3 brick(vec2 xz) {
	float row = floor(xz.y / 0.25);
	float u = xz.x / 0.5 + mod(row, 2.0) * 0.5;
	float id = floor(u);
	vec2 f = vec2(fract(u) * 0.5, fract(xz.y / 0.25) * 0.25);
	float tone = hash21(vec2(id, row));
	vec3 col = mix(vec3(0.72, 0.38, 0.30), vec3(0.86, 0.52, 0.40), tone);
	col *= 0.96 + value_noise(xz * 14.0) * 0.06;
	float edge = min(min(f.x, 0.5 - f.x), min(f.y, 0.25 - f.y));
	return mix(vec3(0.88, 0.82, 0.74), col, smoothstep(0.012, 0.03, edge));
}

// Planks running along z, their ends staggered.
vec3 wood(vec2 xz) {
	float plank = floor(xz.x / 0.25);
	float v = xz.y / 1.5 + hash21(vec2(plank, 2.0));
	float id = floor(v);
	float fx = fract(xz.x / 0.25) * 0.25;
	float fz = fract(v) * 1.5;
	float tone = hash21(vec2(plank, id));
	vec3 col = mix(vec3(0.66, 0.48, 0.33), vec3(0.80, 0.62, 0.43), tone);
	col *= 0.94 + sin(xz.y * 22.0 + value_noise(vec2(plank, xz.y * 3.0)) * 4.0) * 0.03;
	float seam = min(min(fx, 0.25 - fx), min(fz, 1.5 - fz) * 0.4);
	return mix(vec3(0.42, 0.30, 0.22), col, smoothstep(0.008, 0.022, seam));
}

// Square terracotta tiles with pale grout.
vec3 terracotta(vec2 xz) {
	vec2 g = xz / 0.5;
	vec2 id = floor(g);
	vec2 f = fract(g) * 0.5;
	float tone = hash21(id);
	vec3 col = mix(vec3(0.82, 0.50, 0.36), vec3(0.92, 0.62, 0.45), tone);
	col *= 0.97 + value_noise(xz * 10.0) * 0.05;
	float edge = min(min(f.x, 0.5 - f.x), min(f.y, 0.5 - f.y));
	return mix(vec3(0.93, 0.86, 0.76), col, smoothstep(0.014, 0.03, edge));
}

vec3 sand(vec2 xz) {
	vec3 col = mix(vec3(0.93, 0.83, 0.64), vec3(0.98, 0.90, 0.74), fbm(xz * 0.8));
	return col * (0.97 + value_noise(xz * 18.0) * 0.05);
}

vec3 dirt(vec2 xz) {
	vec3 col = mix(vec3(0.62, 0.48, 0.36), vec3(0.72, 0.57, 0.43), fbm(xz * 1.1));
	col *= 0.95 + value_noise(xz * 16.0) * 0.08;
	// A few pebbles.
	vec2 c = cells(xz * 5.0);
	return mix(col, vec3(0.80, 0.74, 0.68), step(0.8, c.x) * smoothstep(0.1, 0.2, c.y) * 0.6);
}

vec3 path_colour(int kind, vec2 xz) {
	if (kind == 0) {
		return stone(xz);
	} else if (kind == 1) {
		return brick(xz);
	} else if (kind == 2) {
		return wood(xz);
	} else if (kind == 3) {
		return terracotta(xz);
	} else if (kind == 4) {
		return sand(xz);
	}
	return dirt(xz);
}

void fragment() {
	int kind = int(round(COLOR.r * 8.0));
	int mask = int(round(COLOR.g * 255.0));
	bool soft = kind >= 4;
	vec2 uv = UV;
	vec2 xz = world_pos.xz;
	float shade = 1.0;
	if (COLOR.b > 0.75) {
		// Round the corners with no path round them, and fray sand and dirt edges.
		float r = 0.36;
		float fray = soft ? 0.03 + value_noise(xz * 7.0) * 0.07 : 0.0;
		vec2 q = uv;
		bool n = has(mask, 1);
		bool e = has(mask, 2);
		bool s = has(mask, 4);
		bool w = has(mask, 8);
		float d = 1.0;
		if (!n) d = min(d, q.y);
		if (!s) d = min(d, 1.0 - q.y);
		if (!w) d = min(d, q.x);
		if (!e) d = min(d, 1.0 - q.x);
		vec2 corner = vec2(-1.0);
		if (!n && !w && q.x < r && q.y < r) corner = vec2(r, r);
		if (!n && !e && q.x > 1.0 - r && q.y < r) corner = vec2(1.0 - r, r);
		if (!s && !e && q.x > 1.0 - r && q.y > 1.0 - r) corner = vec2(1.0 - r, 1.0 - r);
		if (!s && !w && q.x < r && q.y > 1.0 - r) corner = vec2(r, 1.0 - r);
		if (corner.x >= 0.0) {
			d = r - length(q - corner);
		}
		if (d < fray) {
			discard;
		}
		// A slightly darker rim along the path's edge.
		shade = mix(0.9, 1.0, smoothstep(fray, fray + 0.06, d));
	} else {
		shade = 0.7;
	}
	vec2 p = abs(world_normal.y) > 0.5 ? xz : vec2(xz.x + xz.y, world_pos.y * 2.0);
	ALBEDO = path_colour(kind, p) * shade;
	ROUGHNESS = 1.0;
	EMISSION = cel_ambient(ALBEDO);
}
