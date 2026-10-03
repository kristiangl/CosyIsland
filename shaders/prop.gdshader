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

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	VERTEX += wind_offset(root, VERTEX.y - root.y, COLOR.a, TIME) * sway_scale;
	if (curved) {
		VERTEX = curve_world(VERTEX);
	}
}

void fragment() {
	ALBEDO = mix(COLOR.rgb, tint.rgb, tint_mix);
	ALBEDO = mix(ALBEDO, vec3(0.25, 0.3, 0.52), night_sky * night);
	ROUGHNESS = 1.0;
	// Glow lifts the colour towards full brightness, more the darker the light is.
	EMISSION = cel_ambient(ALBEDO) + ALBEDO * glow * night_glow * max(vec3(0.0), vec3(1.25) - cel_lit);
}
