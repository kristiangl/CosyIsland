shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;

// Glowing particles (fire, embers, fireflies, sparkles): like particle.gdshader but added
// on top of what's behind, so they light up.

#include "res://shaders/include/particle.gdshaderinc"
