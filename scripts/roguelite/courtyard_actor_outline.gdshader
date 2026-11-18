shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix, shadows_disabled;

uniform sampler2D body_texture : source_color, filter_nearest, repeat_disable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec4 frame_region = vec4(0.0,0.0,1.0,1.0);
uniform bool flipped = false;

float frame_alpha(vec2 at) {
	vec2 valid = step(vec2(0.0),at)*step(at,vec2(1.0));
	return texture(body_texture, frame_region.xy + at * frame_region.zw).a * valid.x * valid.y;
}

void fragment() {
	vec2 at = flipped ? vec2(1.0-UV.x,UV.y) : UV;
	vec2 px = 1.0 / (vec2(textureSize(body_texture,0)) * frame_region.zw);
	float body = frame_alpha(at);
	float left = frame_alpha(at - vec2(px.x,0));
	float right = frame_alpha(at + vec2(px.x,0));
	float top = frame_alpha(at - vec2(0,px.y));
	float bottom = frame_alpha(at + vec2(0,px.y));
	bool occluded = FRAGCOORD.z + .000065 < texture(scene_depth,SCREEN_UV).r;
	if (occluded) {
		if (body < .34) {
			discard;
		}
		float interior = min(min(left,right),min(top,bottom));
		ALBEDO = mix(vec3(.22,.42,.66),vec3(.63,.85,1.0),1.0-interior);
		ALPHA = mix(.44,.90,1.0-interior);
	} else {
		float edge = max(max(left,right),max(top,bottom));
		if (body >= .34 || edge < .34) {
			discard;
		}
		ALBEDO = vec3(.57,.76,.91);
		ALPHA = .24 * edge;
	}
}
