uniform sampler2D painted_depth : filter_nearest, repeat_disable;
uniform vec3 guide_back;
uniform float eye_distance;
uniform float depth_offset = 0.0;
varying vec3 carrier_world;

float painted_device_depth(vec2 uv, mat4 view, mat4 projection, float bias) {
	vec2 code = round(texture(painted_depth, uv).rg * 255.0);
	float distance_from_eye = 7.0 + 23.0 * (256.0 * code.r + code.g) / 65535.0;
	vec3 world = carrier_world + guide_back * (eye_distance - distance_from_eye + depth_offset + bias);
	vec4 clip = projection * (view * vec4(world, 1.0));
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return clip.z / clip.w * 0.5 + 0.5;
#else
	return clip.z / clip.w;
#endif
}
