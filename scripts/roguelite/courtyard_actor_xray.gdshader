// 3D 角色被墙、柱子挡住时，透出一层冷蓝剪影；没被挡住的地方不画。
// 只把「前面隔着明显距离的东西」算作遮挡，所以自己的手臂挡住身体不会触发。
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_back, blend_mix, shadows_disabled;

uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform float gap = 0.45;  // 世界单位

float view_depth(vec2 uv, float depth, mat4 inv_projection) {
	vec4 p = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return -p.z / p.w;
}

void fragment() {
	float scene = view_depth(SCREEN_UV, texture(scene_depth, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	float self_depth = view_depth(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX);
	if (scene > self_depth - gap) {
		discard;
	}
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = mix(vec3(0.22, 0.42, 0.66), vec3(0.63, 0.85, 1.0), rim);
	ALPHA = mix(0.34, 0.86, rim);
}
