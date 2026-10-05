shader_type spatial;
render_mode specular_disabled;

// A generated base body (SkinnedBody) with its clothes painted on. Each vertex carries
// its rest (T-pose) position in UV (x, y) and UV2.x (z), so the top, bottoms and shoes
// are worked out in rest space and stay put while the skin bends.

#include "res://shaders/include/world.gdshaderinc"
#include "res://shaders/include/toon_light.gdshaderinc"
#include "res://shaders/include/patterns.gdshaderinc"

uniform bool curved = true;

uniform vec3 skin : source_color = vec3(0.97, 0.82, 0.71);
// The top: colours, pattern, sleeves (0 none, 1 short, 2 long) and where its hem is
// (0 at the waist, 1 at the knee for dresses).
uniform vec3 top_a : source_color = vec3(0.94, 0.54, 0.48);
uniform vec3 top_b : source_color = vec3(0.97, 0.96, 0.93);
uniform int top_pattern = 0;
uniform int sleeves = 1;
uniform float hem = 0.0;
// Bottoms: 0 none, 1 shorts, 2 knee length, 3 full length.
uniform vec3 bottom_colour : source_color = vec3(0.3, 0.38, 0.6);
uniform int bottoms = 1;
uniform vec3 shoe_colour : source_color = vec3(0.98, 0.97, 0.94);
uniform bool shoes = true;
// The body's layout in rest space (from the base model's joints).
uniform float shoulder_x = 0.19;
uniform float elbow_x = 0.3;
uniform float wrist_x = 0.42;
uniform float arm_y = 0.7;
uniform float neck_y = 0.75;
uniform float hip_y = 0.37;
uniform float knee_y = 0.21;
uniform float ankle_y = 0.1;

// Checking a rig: colour each vertex by the bone that moves it most.
uniform bool show_bones = false;

varying vec3 rest;
// 0 body, 1 arm, 2 tail (see tools/character_import.gd).
varying float part;
varying vec3 bone_colour;

void vertex() {
	rest = vec3(UV, UV2.x);
	part = UV2.y;
	if (show_bones) {
		uint best = BONE_INDICES.x;
		float w = BONE_WEIGHTS.x;
		if (BONE_WEIGHTS.y > w) { best = BONE_INDICES.y; w = BONE_WEIGHTS.y; }
		if (BONE_WEIGHTS.z > w) { best = BONE_INDICES.z; w = BONE_WEIGHTS.z; }
		if (BONE_WEIGHTS.w > w) { best = BONE_INDICES.w; }
		float h = fract(float(best) * 0.618);
		bone_colour = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0) * 0.8 + 0.2;
	}
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (curved) {
		VERTEX += (inverse(MODEL_MATRIX) * vec4(curve_world(world) - world, 0.0)).xyz;
	}
}

void fragment() {
	vec3 col = skin;
	float ax = abs(rest.x);
	bool arm = part > 0.5 && part < 1.5;
	// Tails stay furry.
	bool tail = part > 1.5;
	float waist = hip_y + 0.05;
	float top_end = mix(waist, knee_y + 0.02, hem);
	if (tail) {
	} else if (arm) {
		float sleeve_end = sleeves == 0 ? shoulder_x : (sleeves == 1 ? mix(shoulder_x, elbow_x, 0.55) : wrist_x - 0.01);
		if (ax < sleeve_end) {
			vec2 uv = vec2(ax, atan(rest.y - arm_y, rest.z) * 0.05);
			col = pattern_colour(top_pattern, uv, top_a, top_b);
		}
	} else if (rest.y < neck_y && rest.y > top_end) {
		vec2 uv = vec2(atan(rest.x, rest.z) * 0.18, rest.y);
		col = pattern_colour(top_pattern, uv, top_a, top_b);
	} else if (bottoms > 0 && rest.y <= top_end) {
		float end = bottoms == 1 ? mix(hip_y, knee_y, 0.45) : (bottoms == 2 ? knee_y - 0.01 : ankle_y + 0.015);
		if (rest.y > end) {
			col = bottom_colour;
		}
	}
	if (shoes && rest.y < ankle_y + 0.012 && !arm && !tail) {
		col = shoe_colour;
	}
	ALBEDO = show_bones ? bone_colour : col;
	ROUGHNESS = 1.0;
	EMISSION = cel_ambient(ALBEDO);
}
