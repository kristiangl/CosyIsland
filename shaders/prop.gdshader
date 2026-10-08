shader_type spatial;
render_mode world_vertex_coords, specular_disabled;

// Props, characters and furniture. Colours come from the mesh's vertex colours.
// Vertex colour alpha is how much that part sways in the wind (0 rigid, 1 leafy).
// Glowing parts (mushroom gills, stars) use a copy with `glow` set and light up at night.

#include "res://shaders/include/world.gdshaderinc"
#include "res://shaders/include/toon_light.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_mix = 0.0;
// Off for things shown outside the island (icons, menus).
uniform bool curved = true;
uniform float glow = 0.0;
// More sway for short things like flowers.
uniform float sway_scale = 1.0;
global uniform float night_glow;
// Window glass uses a copy with this set: it shows the night sky after dark.
uniform float night_sky = 0.0;
global uniform float night;
// Trees and bushes (Models.foliage_material) turn with the seasons (Weather):
// x autumn colours, y spring blossom on some trees. 1 for trees, 0.5 for bushes (which
// don't blossom).
uniform float seasonal = 0.0;
global uniform vec4 foliage;
// Snow settles on top of things outdoors (not held tools or icons).
uniform bool weathered = true;

varying vec3 root_pos;
varying float up_facing;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	root_pos = root;
	up_facing = NORMAL.y;
	VERTEX += wind_offset(root, VERTEX.y - root.y, COLOR.a, TIME) * sway_scale;
	if (curved) {
		VERTEX = curve_world(VERTEX);
	}
}

void fragment() {
	ALBEDO = mix(COLOR.rgb, tint.rgb, tint_mix);
	if (seasonal > 0.0 && curved && !fixed_tints) {
		// Green leaves turn: each tree its own warm colour in autumn, and some trees
		// blossom pink in spring.
		vec3 c = ALBEDO;
		float green = clamp((c.g - max(c.r, c.b)) * 6.0, 0.0, 1.0);
		float h = hash21(floor(root_pos.xz * 0.7) + 0.37);
		float luma = dot(c, vec3(0.3, 0.59, 0.11));
		vec3 warm = h < 0.3 ? vec3(0.95, 0.56, 0.27) : (h < 0.62 ? vec3(0.96, 0.77, 0.32) : vec3(0.86, 0.38, 0.29));
		c = mix(c, warm * (0.6 + luma * 0.7), green * foliage.x * (0.7 + h * 0.3));
		float bloom = step(h, 0.45) * foliage.y * step(0.75, seasonal);
		c = mix(c, vec3(0.99, 0.8, 0.88) * (0.82 + luma * 0.35), green * bloom);
		ALBEDO = c;
	}
	if (weathered && curved && !fixed_tints && snow_cover > 0.0) {
		ALBEDO = mix(ALBEDO, snow_colour(root_pos.xz), snow_cover * smoothstep(0.55, 0.85, up_facing));
	}
	ALBEDO = mix(ALBEDO, vec3(0.25, 0.3, 0.52), night_sky * night);
	ROUGHNESS = 1.0;
	// Glow lifts the colour towards full brightness, more the darker the light is.
	cloud_light = sky_light(VERTEX, INV_VIEW_MATRIX, TIME);
	EMISSION = cel_ambient(ALBEDO) + ALBEDO * glow * night_glow * max(vec3(0.0), vec3(1.25) - cel_lit);
}
