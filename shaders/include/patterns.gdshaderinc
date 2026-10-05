// Clothing patterns, shared by the cloth and skinned body shaders.
// 0 plain, 1 stripes, 2 wide stripes, 3 dots, 4 checks, 5 hearts, 6 stars, 7 flowers, 8 two-tone,
// 9 gingham, 10 tartan, 11 waves, 12 leaves, 13 argyle, 14 cherries, 15 clouds.

float sd_heart(vec2 p) {
	p.x = abs(p.x);
	if (p.y + p.x > 1.0) {
		return sqrt(dot(p - vec2(0.25, 0.75), p - vec2(0.25, 0.75))) - sqrt(2.0) / 4.0;
	}
	vec2 a = p - vec2(0.0, 1.0);
	vec2 b = p - 0.5 * max(p.x + p.y, 0.0);
	return sqrt(min(dot(a, a), dot(b, b))) * sign(p.x - p.y);
}

// Five-pointed star (approximate distance): radius swings between inner and outer.
float sd_star(vec2 p, float r) {
	float seg = 6.2832 / 5.0;
	float t = fract((atan(p.y, p.x) + 1.5708) / seg);
	float f = abs(t - 0.5) * 2.0;
	return length(p) - mix(r * 0.45, r, f * f);
}

// Returns 1 where the pattern shows colour_b.
float pattern_mask(int pattern, vec2 uv, float aa) {
	if (pattern == 1) {
		return step(0.5, fract(uv.y / 0.05));
	}
	if (pattern == 2) {
		return step(0.5, fract(uv.y / 0.11));
	}
	if (pattern == 4) {
		vec2 c = floor(uv / 0.05);
		return mod(c.x + c.y, 2.0);
	}
	if (pattern == 8) {
		return step(uv.y, 0.52);
	}
	if (pattern == 9) {
		// Gingham: crossing bands, darker where they overlap.
		float bx = step(0.5, fract(uv.x / 0.06));
		float by = step(0.5, fract(uv.y / 0.06));
		return (bx + by) * 0.5;
	}
	if (pattern == 10) {
		// Tartan: wide and narrow bands both ways, plus a fine line.
		vec2 f = fract(uv / 0.16);
		vec2 wide = step(vec2(0.55), f);
		vec2 thin = 1.0 - step(vec2(0.04), abs(f - 0.3));
		return clamp((wide.x + wide.y) * 0.35 + max(thin.x, thin.y) * 0.7, 0.0, 1.0);
	}
	if (pattern == 11) {
		float w = uv.y + sin(uv.x * 55.0) * 0.012;
		return 1.0 - smoothstep(0.012 - aa, 0.012 + aa, abs(fract(w / 0.07) - 0.5) * 0.07);
	}
	if (pattern == 13) {
		// Argyle: diamonds in a checker with thin crossing lines.
		vec2 q = vec2(uv.x / 0.08 + uv.y / 0.11, uv.y / 0.11 - uv.x / 0.08);
		vec2 c = floor(q);
		float diamond = mod(c.x + c.y, 2.0) * 0.6;
		vec2 l = abs(fract(vec2(uv.x / 0.08 + uv.y / 0.055, uv.x / 0.08 - uv.y / 0.055)) - 0.5);
		float line = 1.0 - smoothstep(0.03, 0.06, min(l.x, l.y));
		return max(diamond, line);
	}
	// Motif patterns on a staggered grid.
	float cell = pattern == 3 ? 0.055 : (pattern == 15 ? 0.14 : 0.09);
	vec2 g = uv / cell;
	g.x += mod(floor(g.y), 2.0) * 0.5;
	vec2 p = (fract(g) - 0.5) * cell;
	float d;
	if (pattern == 3) {
		d = length(p) - cell * 0.22;
	} else if (pattern == 5) {
		d = sd_heart(vec2(p.x, -p.y + cell * 0.22) / (cell * 0.36)) * cell * 0.36;
	} else if (pattern == 6) {
		d = sd_star(p, cell * 0.3);
	} else if (pattern == 7) {
		float a = atan(p.y, p.x);
		d = length(p) - cell * (0.2 + 0.08 * cos(a * 5.0));
	} else if (pattern == 12) {
		// A leaf on the slant.
		vec2 q = mat2(vec2(0.7, 0.7), vec2(-0.7, 0.7)) * p;
		d = (length(vec2(q.x * 2.2, q.y)) + abs(q.x) * 0.8) - cell * 0.3;
	} else if (pattern == 14) {
		// Cherries: two fruits on a stalk.
		d = min(length(p - vec2(-0.012, -0.012)), length(p - vec2(0.014, -0.016))) - cell * 0.12;
		vec2 s1 = p - vec2(0.0, 0.016);
		d = min(d, max(abs(s1.x + s1.y * 0.4) - 0.0025, abs(s1.y) - 0.018));
	} else if (pattern == 15) {
		// Puffy clouds.
		d = min(min(length(p - vec2(-0.02, 0.0)) - cell * 0.13, length(p - vec2(0.02, 0.0)) - cell * 0.13),
			length(p - vec2(0.0, 0.012)) - cell * 0.16);
		d = max(d, -p.y - cell * 0.1);
	} else {
		return 0.0;
	}
	return 1.0 - smoothstep(-aa, aa, d);
}


// The pattern's colour at uv (metres): colour_b where the pattern shows, flower centres
// in yellow.
vec3 pattern_colour(int pattern, vec2 uv, vec3 colour_a, vec3 colour_b) {
	float aa = max(fwidth(uv.x), fwidth(uv.y)) * 0.8;
	vec3 col = pattern == 0 ? colour_a : mix(colour_a, colour_b, pattern_mask(pattern, uv, aa));
	if (pattern == 7) {
		float cell = 0.09;
		vec2 g = uv / cell;
		g.x += mod(floor(g.y), 2.0) * 0.5;
		vec2 p = (fract(g) - 0.5) * cell;
		col = mix(col, vec3(0.98, 0.84, 0.4), 1.0 - smoothstep(-aa, aa, length(p) - cell * 0.08));
	}
	return col;
}
