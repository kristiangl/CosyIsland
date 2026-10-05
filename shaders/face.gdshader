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
// Mii-style adjustments (see Appearance.ADJUST).
uniform float eye_scale = 1.0;
uniform float eye_tilt = 0.0;
// Brows: height above the eye, nudge outwards, tilt.
uniform float brow_y = 0.085;
uniform float brow_x = 0.0;
uniform float brow_tilt = 0.0;
uniform float mouth_scale = 1.0;
uniform float cheek_y = -0.11;
// 0 none, 1 dot, 2 button, 3 curve, 4 pointy, 5 round.
uniform int nose_style = 0;
uniform float nose_y = -0.085;
uniform float nose_scale = 1.0;
// Animal heads: 0 person, 1 cat (tabby forehead, pale muzzle, pink nose, whiskers),
// 2 dog (patches over the eyes and ears with a pale blaze, pale muzzle), 3 rabbit
// (puffy pale cheeks, pink nose, whiskers, buck teeth), 4 ferret (pale face, dark
// mask round the eyes), 5 mouse (pale muzzle under its snout, whiskers), 6 bird (a
// pale face disc with cheek spots in the third colour; its beak is a mesh).
uniform int species = 0;
// Second fur colour for markings (a cat's pale muzzle), and a third for a cat's tabby
// stripes, a ferret's mask or a bird's cheek spots.
uniform vec3 fur_b : source_color = vec3(1.0);
uniform vec3 fur_c : source_color = vec3(1.0);
// A cat's pale blaze from the nose up between the eyes.
uniform bool cat_blaze = false;
uniform vec3 whisker_colour : source_color = vec3(0.85, 0.82, 0.8);
uniform vec3 nose_colour : source_color = vec3(0.9, 0.55, 0.6);

// Generated heads: how far up their face is drawn (so the kind's eye height lands on
// the head's eye line), and how far forward a beak starts, painted beak_colour.
uniform float face_lift = 0.0;
uniform float beak_z = 10.0;
uniform vec3 beak_colour : source_color = vec3(0.9, 0.6, 0.3);

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX - vec3(0.0, face_lift, 0.0);
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
	vec2 q = p - vec2(side * brow_x, brow_y);
	q = mat2(vec2(cos(side * brow_tilt), sin(side * brow_tilt)), vec2(-sin(side * brow_tilt), cos(side * brow_tilt))) * q;
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
	vec2 q = (p - vec2(0.0, mouth_y)) / mouth_scale;
	aa /= mouth_scale;
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

// Fur markings over the whole head, before the face is drawn on top.
vec3 markings(vec3 col, vec3 p) {
	if (species == 1) {
		// Cat: a pale muzzle and chin, and tabby stripes on the forehead and cheeks.
		if (p.z > 0.1) {
			float muzzle = sd_ellipse(p.xy - vec2(0.0, -0.13), vec2(0.15, 0.085));
			col = mix(col, fur_b, 1.0 - smoothstep(-0.012, 0.012, muzzle));
			if (cat_blaze) {
				// Narrow between the eyes, widening down to the muzzle.
				float b = sd_segment(p.xy, vec2(0.0, -0.1), vec2(0.0, 0.13)) - (0.022 + clamp(0.02 - p.y, 0.0, 0.12) * 0.45);
				col = mix(col, fur_b, 1.0 - smoothstep(-0.01, 0.01, b));
			}
		}
		float stripes = 0.0;
		for (int i = -1; i <= 1; i++) {
			float x = float(i) * 0.065;
			stripes = max(stripes, 1.0 - smoothstep(0.008, 0.016, sd_segment(p.xy, vec2(x, 0.12), vec2(x * 1.25, 0.3)) - (i == 0 ? 0.004 : 0.0)));
		}
		stripes *= smoothstep(0.0, 0.15, p.z);
		for (int i = 0; i < 2; i++) {
			float y = -0.02 - float(i) * 0.045;
			float d = sd_segment(vec2(abs(p.x), p.y), vec2(0.27, y), vec2(0.36, y + 0.02));
			stripes = max(stripes, (1.0 - smoothstep(0.007, 0.014, d)) * step(0.05, p.z));
		}
		col = mix(col, fur_c, stripes * 0.8);
	} else if (species == 2) {
		// Dog: coloured patches over the eyes and ears either side of a pale blaze.
		float blaze = 0.045 + clamp(-p.y, 0.0, 0.2) * 0.35;
		float patch = smoothstep(-0.11, -0.09, p.y + sin(p.x * 18.0) * 0.012);
		if (p.z > -0.05) {
			patch *= smoothstep(blaze - 0.008, blaze + 0.008, abs(p.x));
		}
		col = mix(col, fur_b, patch);
	} else if (species == 3 && p.z > 0.1) {
		// Rabbit: two puffy cheeks either side of the nose, and a pale chin.
		float puff = sd_ellipse(vec2(abs(p.x) - 0.05, p.y + 0.15), vec2(0.075, 0.055));
		puff = min(puff, sd_ellipse(p.xy - vec2(0.0, -0.2), vec2(0.06, 0.04)));
		col = mix(col, fur_b, 1.0 - smoothstep(-0.01, 0.01, puff));
	} else if (species == 4 && p.z > 0.05) {
		// Ferret: a pale face, a dark mask round the eyes running down the nose, and pale
		// brows above it.
		float face = sd_ellipse(p.xy - vec2(0.0, -0.09), vec2(0.2, 0.13));
		col = mix(col, fur_b, 1.0 - smoothstep(-0.012, 0.012, face));
		float mask = sd_ellipse(vec2(abs(p.x) - 0.13, p.y + 0.03), vec2(0.105, 0.06));
		mask = min(mask, sd_segment(p.xy, vec2(0.0, -0.01), vec2(0.0, -0.1)) - 0.025);
		col = mix(col, fur_c, 1.0 - smoothstep(-0.01, 0.01, mask));
		float brow = sd_ellipse(vec2(abs(p.x) - 0.12, p.y - 0.065), vec2(0.06, 0.028));
		col = mix(col, fur_b, 1.0 - smoothstep(-0.01, 0.01, brow));
	} else if (species == 5 && p.z > 0.1) {
		// Mouse: a pale muzzle round the base of the snout.
		float muzzle = sd_ellipse(p.xy - vec2(0.0, -0.13), vec2(0.13, 0.08));
		col = mix(col, fur_b, 1.0 - smoothstep(-0.012, 0.012, muzzle));
	} else if (species == 6 && p.z > 0.0) {
		// Bird: a pale face round the eyes and beak, with round cheek spots.
		float face = sd_ellipse(p.xy - vec2(0.0, -0.05), vec2(0.27, 0.19));
		col = mix(col, fur_b, 1.0 - smoothstep(-0.015, 0.015, face));
		float spot = length(vec2(abs(p.x) - 0.2, p.y + 0.12)) - 0.04;
		col = mix(col, fur_c, 1.0 - smoothstep(-0.008, 0.008, spot));
	}
	return col;
}

// A rabbit's two front teeth, just under the mouth.
vec3 buck_teeth(vec3 base, vec2 p, float aa) {
	vec2 q = p - vec2(0.0, mouth_y - 0.024);
	float d = sd_segment(q, vec2(0.0, 0.008), vec2(0.0, -0.006)) - 0.015;
	base = paint(base, vec3(0.42, 0.3, 0.28), d - 0.004, aa);
	base = paint(base, vec3(1.0), d, aa);
	return paint(base, vec3(0.75, 0.7, 0.7), sd_segment(q, vec2(0.0, 0.012), vec2(0.0, -0.016)) - 0.0018, aa);
}

vec3 animal_nose(vec3 base, vec2 p, float aa) {
	vec2 q = p - vec2(0.0, mouth_y + 0.045);
	// A small rounded triangle pointing down.
	float d = max(abs(q.x) * 0.87 - q.y * 0.5, q.y - 0.01) - 0.016;
	base = paint(base, nose_colour, d, aa);
	return paint(base, vec3(1.0), length(q - vec2(-0.008, 0.008)) - 0.005, aa);
}

vec3 whiskers(vec3 base, vec2 p, float aa) {
	vec2 q = vec2(abs(p.x), p.y);
	for (int i = 0; i < 3; i++) {
		float y = mouth_y + 0.035 - float(i) * 0.02;
		float d = sd_segment(q, vec2(0.13, y), vec2(0.27, y + 0.03 - float(i) * 0.028));
		base = paint(base, whisker_colour, d - 0.003, aa);
	}
	return base;
}

// A person's nose: a few simple shapes in a darker skin tone.
vec3 draw_nose(vec3 base, vec2 p, float aa) {
	if (nose_style == 0) {
		return base;
	}
	vec2 q = (p - vec2(0.0, nose_y)) / nose_scale;
	aa /= nose_scale;
	vec3 shade = skin * vec3(0.8, 0.68, 0.66);
	if (nose_style == 1) {
		return paint(base, shade, sd_ellipse(q, vec2(0.012, 0.009)), aa);
	}
	if (nose_style == 2) {
		base = paint(base, mix(skin, shade, 0.55), sd_ellipse(q, vec2(0.03, 0.022)), aa);
		return paint(base, mix(skin, vec3(1.0), 0.5), length(q - vec2(-0.01, 0.007)) - 0.007, aa);
	}
	if (nose_style == 3) {
		return paint(base, shade, sd_arc(q, vec2(-0.004, 0.0), 0.02, -1.6, 1.4) - 0.004, aa);
	}
	if (nose_style == 4) {
		float d = max(abs(q.x) * 0.9 + q.y * 0.45, -q.y - 0.014) - 0.012;
		return paint(base, shade, abs(d) - 0.0035, aa);
	}
	base = paint(base, mix(skin, shade, 0.5), sd_ellipse(q, vec2(0.04, 0.03)), aa);
	return paint(base, shade, length(vec2(abs(q.x) - 0.014, q.y + 0.008)) - 0.006, aa);
}

void fragment() {
	vec3 col = markings(skin, local_pos);
	if (local_pos.z > beak_z) {
		col = beak_colour;
	}
	if (local_pos.z > 0.12) {
		vec2 p = local_pos.xy;
		float aa = max(fwidth(p.x), fwidth(p.y)) * 0.8;
		float side = sign(p.x);
		// Position relative to this side's eye; `side` says which way is outwards.
		vec2 e = vec2(p.x - side * eye_x, p.y - eye_y);
		// Eyes tilt their outer corners up or down and scale about their centre.
		float t = side * eye_tilt;
		vec2 eye = mat2(vec2(cos(t), sin(t)), vec2(-sin(t), cos(t))) * e / eye_scale;
		if (cheek_style == 1 || cheek_style == 3) {
			vec2 c = vec2(abs(p.x) - 0.2, p.y - cheek_y);
			col = mix(col, vec3(0.98, 0.6, 0.6), 0.55 * (1.0 - smoothstep(-aa, aa, sd_ellipse(c, vec2(0.05, 0.026)))));
		}
		if (cheek_style >= 2) {
			for (int i = 0; i < 3; i++) {
				vec2 f = vec2(abs(p.x) - 0.17 - float(i) * 0.022, p.y - cheek_y - 0.025 + float(i % 2) * 0.014);
				col = paint(col, skin * 0.72, length(f) - 0.0055, aa);
			}
		}
		col = draw_brow(col, e, aa, side);
		col = draw_eye(col, eye, aa / eye_scale, side);
		if (species == 0) {
			col = draw_nose(col, p, aa);
		}
		if (species != 6) {
			col = draw_mouth(col, p, aa);
		}
		if (species == 3) {
			col = buck_teeth(col, p, aa);
		}
		if (species == 1 || species == 3 || species == 5) {
			col = whiskers(col, p, aa);
		}
		if (species == 1 || species == 3) {
			col = animal_nose(col, p, aa);
		}
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	EMISSION = cel_ambient(ALBEDO);
}
