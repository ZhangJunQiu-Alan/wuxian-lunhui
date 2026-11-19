shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_prepass_alpha, blend_mix;

uniform sampler2D painted_fire : source_color, filter_linear_mipmap, repeat_disable;
uniform float phase = 0.0;

void fragment() {
	float time = TIME + phase;
	vec2 original_uv = (UV * vec2(400.0, 310.0) - vec2(64.0, 0.0)) / vec2(272.0, 256.0);
	float plume = (1.0 - smoothstep(0.13, 0.41, original_uv.y)) *
		(1.0 - smoothstep(0.15, 0.28, abs(original_uv.x - 0.5)));
	vec2 p = UV + plume * vec2(
		sin(time * 8.3 - original_uv.y * 21.0) * 0.023 + sin(time * 5.4 + original_uv.y * 35.0) * 0.009,
		sin(time * 6.8 - original_uv.y * 16.0) * 0.015
	) * vec2(272.0 / 400.0, 256.0 / 310.0);
	vec4 paint = texture(painted_fire, p);
	float flicker = sin(time * 7.8 - original_uv.y * 21.0) * 0.10 + sin(time * 13.2) * 0.037;
	ALBEDO = paint.rgb * (1.0 + plume * flicker);
	ALPHA = paint.a;
}
