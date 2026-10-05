shader_type canvas_item;

// A sandy, wavy border round the screen while on a tour island: a strip of beach with a
// line of foam on its inner edge and a little sea-tinted glow inside that, so it's clear
// you're somewhere else. Colours are sRGB.

uniform vec2 screen = vec2(1280.0, 720.0);
uniform vec3 sand : source_color = vec3(0.95, 0.86, 0.66);
uniform vec3 sand_dark : source_color = vec3(0.86, 0.74, 0.54);
uniform vec3 foam : source_color = vec3(1.0, 1.0, 0.98);
uniform vec3 sea : source_color = vec3(0.45, 0.78, 0.84);
// Strip width and how far it wanders in and out, in pixels.
uniform float width = 22.0;
uniform float wave = 7.0;

float edge(float along, float dist, float seed) {
	float wobble = sin(along * 0.018 + seed) * 0.6 + sin(along * 0.047 + seed * 2.3 + TIME * 0.4) * 0.4;
	return dist - (width + wobble * wave);
}

void fragment() {
	vec2 p = UV * screen;
	// Distance inside each edge's wavy line; the smallest wins, rounded off at corners.
	float top = edge(p.x, p.y, 0.0);
	float bottom = edge(p.x, screen.y - p.y, 1.7);
	float left = edge(p.y, p.x, 3.1);
	float right = edge(p.y, screen.x - p.x, 4.6);
	float k = 30.0;
	float h = -log(exp(-top / k) + exp(-bottom / k) + exp(-left / k) + exp(-right / k)) * k;
	vec4 col = vec4(0.0);
	if (h < 0.0) {
		// Sand, darker towards the edge of the screen, with a few speckles.
		float grain = fract(sin(dot(floor(p / 3.0), vec2(12.9898, 78.233))) * 43758.5453);
		vec3 c = mix(sand, sand_dark, clamp(-h / (width * 1.6), 0.0, 1.0));
		c = mix(c, sand_dark, step(0.93, grain) * 0.5);
		col = vec4(c, 1.0);
	}
	// Foam along the inner edge, washing in and out.
	float swash = 2.5 + sin(TIME * 1.3 + (p.x + p.y) * 0.01) * 1.5;
	float f = 1.0 - smoothstep(swash, swash + 2.5, abs(h - 1.0));
	col = mix(col, vec4(foam, 1.0), f * 0.95);
	// Shallow sea glow just inside.
	if (h > 0.0) {
		float glow = (1.0 - smoothstep(0.0, 26.0, h)) * 0.35;
		col = mix(col, vec4(sea, glow), step(col.a, 0.01) * 1.0);
		col.a = max(col.a, glow * (1.0 - f));
		if (f < 0.5) {
			col.rgb = sea;
		}
	}
	COLOR = col;
}
