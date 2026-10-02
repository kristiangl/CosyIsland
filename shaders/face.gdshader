shader_type spatial;
render_mode specular_disabled;

// A character's head: skin plus a face drawn with signed distance shapes, so every
// eye, brow, mouth and cheek style is just a number. Works in the head mesh's local
// space (centred on the head, facing +Z), using the front view as a flat face plane.

#include "res://shaders/include/world.gdshaderinc"
#include "res://shaders/include/toon_light.gdshaderinc"

// Off for characters shown outside the island (menus), where world curvature makes no sense.
uniform bool curved = true;

uniform vec3 skin : source_color = vec3(0.97, 0.82, 0.71);
uniform vec3 eye_colour : source_color = vec3(0.35, 0.23, 0.16);
uniform vec3 brow_colour : source_color = vec3(0.35, 0.23, 0.16);
uniform int eye_style = 0;
uniform int brow_style = 1;
uniform int mouth_style = 0;
uniform int cheek_style = 1;
uniform float blink = 0.0;
// Face feature placement (metres in head space).
uniform float eye_x = 0.125;
uniform float eye_y = -0.035;
uniform float mouth_y = -0.13;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (curved) {
		VERTEX += (inverse(MODEL_MATRIX) * vec4(curve_world(world) - world, 0.0)).xyz;
	}
}

float sd_ellipse(vec2 p, vec2 r) {
	// Cheap approximation, good enough for small features.
	float k = length(p / r);
	return (k - 1.0) * min(r.x, r.y);
}

float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// Distance to an arc of a circle centred at c, radius r, between angles a0 and a1.
float sd_arc(vec2 p, vec2 c, float r, float a0, float a1) {
	vec2 d = p - c;
	float ang = atan(d.y, d.x);
	if (ang >= a0 && ang <= a1) {
		return abs(length(d) - r);
	}
	vec2 e0 = c + r * vec2(cos(a0), sin(a0));
	vec2 e1 = c + r * vec2(cos(a1), sin(a1));
	return min(length(p - e0), length(p - e1));
}

// Paints `col` over `base` where distance d < 0, with a soft anti-aliased edge.
vec3 paint(vec3 base, vec3 col, float d, float aa) {
	return mix(base, col, 1.0 - smoothstep(-aa, aa, d));
}

vec3 draw_eye(vec3 base, vec2 p, float aa, float side) {
	vec3 dark = eye_colour * 0.35 + vec3(0.06, 0.04, 0.07);
	vec3 white = vec3(1.0);
	float open = 1.0 - blink;
	if (open < 0.2 || eye_style == 2) {
		// Closed or happy: a curved line.
		float bend = eye_style == 2 ? 1.0 : -0.4;
		float d = sd_arc(p, vec2(0.0, -0.025 * bend), 0.042, bend > 0.0 ? 0.6 : -2.55, bend > 0.0 ? 2.55 : -0.6);
		return paint(base, dark, d - 0.008, aa);
	}
	if (eye_style == 3) {
		// Sleepy: lower half of an oval under a lid line.
		vec2 q = p - vec2(0.0, -0.01);
		float d = max(sd_ellipse(q, vec2(0.045, 0.05 * open)), q.y - 0.004);
		base = paint(base, dark, d, aa);
		base = paint(base, dark, sd_segment(p, vec2(-0.05, -0.006), vec2(0.05, -0.006)) - 0.006, aa);
		return paint(base, white, length(p - vec2(0.014, -0.022)) - 0.01, aa);
	}
	if (eye_style == 6) {
		return paint(base, dark, length(p / vec2(1.0, open)) - 0.026, aa);
	}
	if (eye_style == 7) {
		// Wide: white, coloured iris, pupil, shine.
		base = paint(base, white, sd_ellipse(p, vec2(0.056, 0.064 * open)), aa);
		base = paint(base, eye_colour, sd_ellipse(p - vec2(0.0, -0.006), vec2(0.04, 0.05 * open)), aa);
		base = paint(base, dark, sd_ellipse(p - vec2(0.0, -0.006), vec2(0.022, 0.028 * open)), aa);
		base = paint(base, dark, abs(sd_ellipse(p, vec2(0.056, 0.064 * open))) - 0.004, aa);
		return paint(base, white, length(p - vec2(0.016, 0.02)) - 0.012, aa);
	}
	vec2 r = vec2(0.045, 0.062 * open);
	if (eye_style == 5) {
		// Almond: an oval with its outer corner lifted.
		p.y -= p.x * side * 0.25;
		r = vec2(0.054, 0.04 * open);
	}
	float d = sd_ellipse(p, r);
	base = paint(base, dark, d, aa);
	if (eye_style == 1 || eye_style == 4) {
		// Sparkly: tinted lower half and a second shine.
		float lower = smoothstep(0.0, -0.05, p.y);
		base = mix(base, mix(dark, eye_colour, 0.8), lower * (1.0 - smoothstep(-aa, aa, d + 0.006)));
		base = paint(base, white, length(p - vec2(-0.014, -0.024)) - 0.007, aa);
	}
	if (eye_style == 4) {
		// Lashes on the outer upper edge.
		for (int i = 0; i < 3; i++) {
			float a = 0.7 + float(i) * 0.38;
			vec2 from = vec2(cos(a) * side * r.x, sin(a) * r.y) * 0.95;
			vec2 to = from + vec2(cos(a) * side, sin(a)) * 0.022;
			base = paint(base, dark, sd_segment(p, from, to) - 0.004, aa);
		}
	}
	return paint(base, white, length(p - vec2(0.015, 0.022)) - 0.015, aa);
}

vec3 draw_brow(vec3 base, vec2 p, float aa, float side) {
	if (brow_style == 0) {
		return base;
	}
	vec2 q = p - vec2(0.0, 0.085);
	if (brow_style == 1) {
		return paint(base, brow_colour, sd_arc(q, vec2(0.0, -0.05), 0.05, 1.1, 2.05) - 0.007, aa);
	}
	if (brow_style == 2) {
		return paint(base, brow_colour, sd_segment(q, vec2(-0.03, 0.0), vec2(0.03, 0.0)) - 0.012, aa);
	}
	if (brow_style == 3) {
		// Worried: inner end raised.
		return paint(base, brow_colour, sd_segment(q, vec2(-0.032 * side, 0.012), vec2(0.03 * side, -0.006)) - 0.007, aa);
	}
	return paint(base, brow_colour, sd_arc(q, vec2(0.0, -0.08), 0.085, 1.15, 2.0) - 0.004, aa);
}

vec3 draw_mouth(vec3 base, vec2 p, float aa) {
	vec3 line = vec3(0.45, 0.22, 0.24);
	vec3 inside = vec3(0.62, 0.24, 0.3);
	vec3 tongue = vec3(0.96, 0.55, 0.58);
	vec2 q = p - vec2(0.0, mouth_y);
	if (mouth_style == 0) {
		return paint(base, line, sd_arc(q, vec2(0.0, 0.018), 0.026, -2.4, -0.74) - 0.0055, aa);
	}
	if (mouth_style == 1 || mouth_style == 5) {
		// Open grin: a half disc.
		float d = max(length(q - vec2(0.0, 0.006)) - 0.032, q.y - 0.006);
		base = paint(base, inside, d, aa);
		base = paint(base, tongue, max(d, length(q - vec2(0.0, -0.03)) - 0.02), aa);
		return base;
	}
	if (mouth_style == 2) {
		// Cat mouth: two little arcs.
		vec2 m = vec2(abs(q.x), q.y);
		return paint(base, line, sd_arc(m, vec2(0.014, 0.006), 0.014, -3.1, -0.2) - 0.005, aa);
	}
	if (mouth_style == 3) {
		return paint(base, inside, sd_ellipse(q, vec2(0.014, 0.018)), aa);
	}
	return paint(base, line, sd_segment(q, vec2(-0.018, 0.0), vec2(0.018, 0.0)) - 0.005, aa);
}

void fragment() {
	vec3 col = skin;
	if (local_pos.z > 0.12) {
		vec2 p = local_pos.xy;
		float aa = max(fwidth(p.x), fwidth(p.y)) * 0.8;
		float side = sign(p.x);
		// Position relative to this side's eye; `side` says which way is outwards.
		vec2 e = vec2(p.x - side * eye_x, p.y - eye_y);
		if (cheek_style == 1 || cheek_style == 3) {
			vec2 c = vec2(abs(p.x) - 0.2, p.y + 0.11);
			col = mix(col, vec3(0.98, 0.6, 0.6), 0.55 * (1.0 - smoothstep(-aa, aa, sd_ellipse(c, vec2(0.05, 0.026)))));
		}
		if (cheek_style >= 2) {
			for (int i = 0; i < 3; i++) {
				vec2 f = vec2(abs(p.x) - 0.17 - float(i) * 0.022, p.y + 0.085 + float(i % 2) * 0.014);
				col = paint(col, skin * 0.72, length(f) - 0.0055, aa);
			}
		}
		col = draw_brow(col, e, aa, side);
		col = draw_eye(col, e, aa, side);
		col = draw_mouth(col, p, aa);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	EMISSION = cel_ambient(ALBEDO);
}
