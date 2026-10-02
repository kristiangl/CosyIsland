shader_type spatial;
render_mode world_vertex_coords, specular_disabled;

// Props, characters and furniture. Colours come from the mesh's vertex colours.
// Vertex colour alpha is how much that part sways in the wind (0 rigid, 1 leafy).

#include "res://shaders/include/world.gdshaderinc"
#include "res://shaders/include/toon_light.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_mix = 0.0;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	VERTEX += wind_offset(root, VERTEX.y - root.y, COLOR.a, TIME);
	VERTEX = curve_world(VERTEX);
}

void fragment() {
	ALBEDO = mix(COLOR.rgb, tint.rgb, tint_mix);
	ROUGHNESS = 1.0;
	EMISSION = cel_ambient(ALBEDO);
}
