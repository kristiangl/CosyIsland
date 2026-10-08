shader_type canvas_item;

// A grassy border round the screen while a landscaping tool is out: a strip of turf
// with blades along its inner edge, swaying a little, and a few small flowers, so it's
// clear you're landscaping. Colours are sRGB.

uniform vec2 screen = vec2(1280.0, 720.0);
uniform vec3 grass : source_color = vec3(0.55, 0.78, 0.42);
uniform vec3 grass_dark : source_color = vec3(0.38, 0.63, 0.32);
uniform vec3 tip : source_color = vec3(0.74, 0.89, 0.53);
// The solid strip and how far the blades reach past it, in pixels.
uniform float width = 15.0;
uniform float blade = 15.0;

float hash(float n) {
	return fract(sin(n * 12.9898 + 4.1) * 43758.5453);
}

// How far inside the grass a point is (positive inside) for one edge of the screen:
// `along` runs along the edge, `dist` is how far in from it.
float turf(float along, float dist, float seed) {
	float spacing = 8.0;
	float lift = clamp((dist - width) / blade, 0.0, 1.0);
	float a = along + sin(TIME * 1.6 + along * 0.013 + seed) * 2.5 * lift;
	float cell = floor(a / spacing) + seed * 97.0;
	// Each blade leans a little its own way, and some are short.
	float f = fract(a / spacing);
	float lean = (hash(cell + 0.5) - 0.5) * 0.5;
	float len = blade * (0.3 + 0.7 * hash(cell));
	float tri = 1.0 - clamp(abs(f - 0.5 - lean * lift) * 2.0, 0.0, 1.0);
	return width + len * pow(tri, 2.2) - dist;
}

// A little flower now and then along the turf: returns colour and coverage.
vec4 flower(float along, float dist, float seed) {
	float spacing = 86.0;
	float cell = floor(along / spacing);
	float h = hash(cell * 1.7 + seed * 13.0);
	if (h > 0.55) {
		return vec4(0.0);
	}
	vec2 centre = vec2((cell + 0.25 + h) * spacing, width * 0.55);
	vec2 d = vec2(along, dist) - centre;
	float r = length(d);
	float petals = 4.2 + 1.1 * cos(atan(d.y, d.x) * 5.0 + seed);
	vec3 colours[3] = vec3[](vec3(1.0, 0.98, 0.95), vec3(0.98, 0.72, 0.8), vec3(1.0, 0.86, 0.45));
	vec3 c = colours[int(hash(cell + seed) * 2.99)];
	c = mix(c, vec3(0.98, 0.8, 0.3), 1.0 - smoothstep(1.4, 2.2, r));
	return vec4(c, 1.0 - smoothstep(petals - 0.8, petals, r));
}

void fragment() {
	vec2 p = UV * screen;
	vec4 sides[4] = vec4[](
		vec4(p.x, p.y, 0.0, 0.0),
		vec4(p.x, screen.y - p.y, 1.3, 0.0),
		vec4(p.y, p.x, 2.6, 0.0),
		vec4(p.y, screen.x - p.x, 3.9, 0.0));
	float best = -1e6;
	vec4 side = sides[0];
	for (int i = 0; i < 4; i++) {
		float g = turf(sides[i].x, sides[i].y, sides[i].z);
		if (g > best) {
			best = g;
			side = sides[i];
		}
	}
	vec4 col = vec4(0.0);
	if (best > 0.0) {
		// Darker at the screen's edge, lighter up the blades to their tips.
		float up = clamp((side.y - width * 0.3) / (width + blade * 0.6), 0.0, 1.0);
		vec3 c = mix(grass_dark, grass, smoothstep(0.0, 0.5, up));
		c = mix(c, tip, smoothstep(0.55, 1.0, up));
		// A darker rim round each blade.
		c = mix(c, grass_dark, (1.0 - smoothstep(0.0, 1.6, best)) * 0.7);
		col = vec4(c, 1.0);
		vec4 bloom = flower(side.x, side.y, side.z);
		col.rgb = mix(col.rgb, bloom.rgb, bloom.a);
	} else {
		// A soft shadow just inside the grass.
		col = vec4(grass_dark * 0.6, (1.0 - smoothstep(0.0, 7.0, -best)) * 0.18);
	}
	COLOR = col;
}
