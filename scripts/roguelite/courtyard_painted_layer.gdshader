shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://scripts/roguelite/courtyard_paint_projection.gdshaderinc"

uniform sampler2D painting : source_color, filter_linear, repeat_disable;

void vertex() {
	carrier_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 pigment = texture(painting, UV);
	if (pigment.a < 0.52) {
		discard;
	}
	ALBEDO = pigment.rgb;
	DEPTH = painted_device_depth(UV, VIEW_MATRIX, PROJECTION_MATRIX, 0.0);
}
