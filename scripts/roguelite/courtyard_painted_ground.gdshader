shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_mix;

#include "res://scripts/roguelite/courtyard_paint_projection.gdshaderinc"

uniform sampler2D painting : source_color, filter_linear, repeat_disable;
uniform bool backing_plate = false;
uniform bool threshold_plate = false;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	carrier_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 pigment = texture(painting, UV);
	if (pigment.a < 0.0039) {
		discard;
	}
	ALBEDO = pigment.rgb;
	ALPHA = pigment.a * opacity;
	// Fully replaced pixels act as the backing plate. They fill gaps without
	// competing with the feet or with the antialiased edges of depth-writing art.
	DEPTH = threshold_plate || (backing_plate && pigment.a > 0.998)
		? 0.00001
		: painted_device_depth(UV, VIEW_MATRIX, PROJECTION_MATRIX, backing_plate ? .075 : 0.0);
}
