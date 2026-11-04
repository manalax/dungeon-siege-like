shader_type spatial;
// Inverted-hull outline, applied as a MeshInstance3D.material_overlay (F-013 hover highlight).
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float width = 0.04;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = color.rgb;
}
