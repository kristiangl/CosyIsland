shader_type spatial;
render_mode specular_disabled;

// Floors and walls inside homes: a procedural pattern in two colours over UV (metres).
// Walls run UV.x along the wall and UV.y up from the floor; floors use (x, z).

#include "res://shaders/include/world.gdshaderinc"
#include "res://shaders/include/toon_light.gdshaderinc"

// 0 plain, 1 planks, 2 stripes, 3 woven mat, 4 canvas, 5 tiles, 6 dots
uniform int pattern = 0;
uniform vec4 colour_a : source_color = vec4(0.92, 0.87, 0.76, 1.0);
uniform vec4 colour_b : source_color = vec4(0.8, 0.72, 0.6, 1.0);
// Floors: the room's size in tiles, to darken the corners where floor meets wall.
uniform vec2 room_size = vec2(0.0);
// Walls: darken towards the floor.
uniform bool is_wall = false;

vec3 plain(vec2 p) {
	return colour_a.rgb * (0.97 + 0.05 * fbm(p * 1.7));
}

vec3 planks(vec2 p) {
	float width = 0.25;
	float row = floor(p.y / width);
	float along = p.x + hash21(vec2(row, 3.1)) * 3.0;
	float board = floor(along / 1.6);
	vec2 f = vec2(fract(along / 1.6) * 1.6, fract(p.y / width) * width);
	vec3 c = mix(colour_a.rgb, colour_b.rgb, hash21(vec2(row, board)) * 0.55);
	c *= 0.97 + 0.05 * sin(p.x * 7.0 + value_noise(p * vec2(1.5, 14.0)) * 5.0);
	float gap = max(1.0 - step(0.014, f.y), 1.0 - step(0.014, f.x));
	return mix(c, colour_b.rgb * 0.72, gap);
}

vec3 stripes(vec2 p) {
	float s = fract(p.x / 0.3);
	vec3 c = s < 0.5 ? colour_a.rgb : mix(colour_a.rgb, colour_b.rgb, 0.55);
	float line = 1.0 - smoothstep(0.0, 0.03, abs(s - 0.5));
	return mix(c, colour_b.rgb, line * 0.8);
}

vec3 woven(vec2 p) {
	vec2 cell = floor(p / 0.3);
	vec2 f = fract(p / 0.3);
	bool across = mod(cell.x + cell.y, 2.0) < 1.0;
	// Strands run across or along in alternating squares, shaded at their edges.
	float t = across ? f.y : f.x;
	float strand = fract(t * 3.0);
	vec3 c = mix(colour_a.rgb, colour_b.rgb, across ? 0.12 : 0.32);
	c *= 0.95 + 0.05 * sin(strand * 3.14159);
	return c;
}

vec3 canvas(vec2 p) {
	vec3 c = colour_a.rgb * (0.96 + 0.04 * value_noise(p * vec2(40.0, 3.0)));
	// Seams every metre with a row of stitches beside them.
	float s = abs(fract(p.x + 0.5) - 0.5);
	float seam = 1.0 - smoothstep(0.01, 0.025, s);
	float stitch = (1.0 - smoothstep(0.004, 0.012, abs(s - 0.05))) * step(0.5, fract(p.y * 8.0));
	return mix(c, colour_b.rgb, max(seam, stitch * 0.7));
}

vec3 tiles(vec2 p) {
	vec2 f = fract(p / 0.5);
	vec2 cell = floor(p / 0.5);
	vec3 c = mix(colour_a.rgb, colour_a.rgb * 0.95, hash21(cell));
	float grout = max(1.0 - smoothstep(0.015, 0.035, min(f.x, 1.0 - f.x)), 1.0 - smoothstep(0.015, 0.035, min(f.y, 1.0 - f.y)));
	return mix(c, colour_b.rgb, grout);
}

vec3 dots(vec2 p) {
	vec2 q = p / 0.25;
	q.x += mod(floor(q.y), 2.0) * 0.5;
	float d = length(fract(q) - 0.5);
	return mix(colour_a.rgb, colour_b.rgb, 1.0 - smoothstep(0.16, 0.19, d));
}

void fragment() {
	vec2 p = UV;
	vec3 c;
	if (pattern == 1) {
		c = planks(p);
	} else if (pattern == 2) {
		c = stripes(p);
	} else if (pattern == 3) {
		c = woven(p);
	} else if (pattern == 4) {
		c = canvas(p);
	} else if (pattern == 5) {
		c = tiles(p);
	} else if (pattern == 6) {
		c = dots(p);
	} else {
		c = plain(p);
	}
	// Soft painted shading where surfaces meet.
	if (is_wall) {
		c *= mix(0.86, 1.0, smoothstep(0.0, 0.6, p.y));
	} else if (room_size.x > 0.0) {
		float edge = min(min(p.x, room_size.x - p.x), p.y);
		c *= mix(0.86, 1.0, smoothstep(0.0, 0.7, edge));
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	EMISSION = cel_ambient(ALBEDO);
}
