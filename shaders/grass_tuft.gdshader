shader_type spatial;
// Tufts write no depth so the outline pass ignores them (no speckled lines on lawns).
render_mode world_vertex_coords, cull_disabled, specular_disabled, depth_draw_never;

// Little grass clumps scattered over the grass tiles. They take their colour from the
// same noise as the terrain, brightening towards the tips (vertex colour red).

#include "res://shaders/include/world.gdshaderinc"
#include "res://shaders/include/grass_colour.gdshaderinc"
#include "res://shaders/include/toon_light.gdshaderinc"

varying vec3 world_pos;
varying float tip;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	tip = COLOR.r;
	VERTEX += wind_offset(root, VERTEX.y - root.y, 2.5, TIME);
	world_pos = VERTEX;
	VERTEX = curve_world(VERTEX);
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec3 col = grass_colour(world_pos.xz);
	col = mix(col * 0.88, col * 1.14 + vec3(0.03, 0.04, 0.0), tip);
	col = wet(col);
	// Under snow only the tips poke through.
	col = mix(col, snow_colour(world_pos.xz), snow_cover * (1.0 - tip * 0.5));
	ALBEDO = col;
	ROUGHNESS = 1.0;
	cloud_light = sky_light(VERTEX, INV_VIEW_MATRIX, TIME);
	EMISSION = cel_ambient(ALBEDO);
	// Light both sides of the blades like the ground beneath them.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
