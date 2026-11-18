shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_prepass_alpha, blend_mix;

#include "res://scripts/roguelite/courtyard_paint_projection.gdshaderinc"

uniform sampler2D painting : source_color, filter_linear, repeat_disable;

void vertex() {
	carrier_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 pigment = texture(painting, UV);
	if (pigment.a < .004) {
		discard;
	}
	ALBEDO = pigment.rgb;
	ALPHA = pigment.a;
	DEPTH = painted_device_depth(UV, VIEW_MATRIX, PROJECTION_MATRIX, pigment.a < .998 ? .22 : 0.0);
}
