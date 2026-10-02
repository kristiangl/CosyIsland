shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

// Full-screen ink lines for the cel-shaded look. Finds silhouettes (jumps in depth) and
// creases (sudden changes in depth slope, such as the top edge of a cliff), then darkens
// the colour underneath so lines take on the tint of what they outline.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 line_tint : source_color = vec3(0.36, 0.26, 0.36);
uniform float line_strength = 0.85;
uniform float silhouette_threshold = 0.035;
uniform float crease_threshold = 0.02;
uniform float thickness = 1.0;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_proj) {
	float raw = texture(depth_tex, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv * 2.0 - 1.0, raw * 2.0 - 1.0);
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, raw);
#endif
	vec4 view = inv_proj * vec4(ndc, 1.0);
	return -view.z / view.w;
}

void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE;
	float c = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float l = linear_depth(SCREEN_UV - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float r = linear_depth(SCREEN_UV + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float u = linear_depth(SCREEN_UV - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float d = linear_depth(SCREEN_UV + vec2(0.0, px.y), INV_PROJECTION_MATRIX);

	// Silhouettes: a neighbour much further away than this pixel (only draw on the near side).
	float far_jump = max(max(l, r), max(u, d)) - c;
	float silhouette = step(silhouette_threshold * c, far_jump);
	// Creases: the second derivative of depth.
	float crease_x = abs(l + r - 2.0 * c);
	float crease_y = abs(u + d - 2.0 * c);
	float crease = step(crease_threshold * c, max(crease_x, crease_y)) * (1.0 - step(0.2 * c, max(crease_x, crease_y)));
	float line = max(silhouette, crease * 0.75);
	// Fade lines out in the far distance so the horizon stays soft.
	line *= 1.0 - smoothstep(60.0, 110.0, c);

	// Only the lines are drawn, so see-through things rendered earlier (the placement
	// preview, effects) aren't painted over.
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	ALBEDO = col * line_tint;
	ALPHA = line * line_strength;
}
