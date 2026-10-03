shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

// Particles (CPUParticles3D): camera-facing quads that follow the world curvature, with
// the shape drawn from UV so no textures are needed. Colour and fade come from the
// particle colour (COLOR). See scripts/autoload/effects.gd.

#include "res://shaders/include/particle.gdshaderinc"
