shader_type spatial;
render_mode unshaded, blend_mix;

void fragment() {
	float soft = 1.0 - smoothstep(0.04, 0.53, length(UV - vec2(0.5)));
	ALBEDO = vec3(0.028, 0.041, 0.067);
	ALPHA = soft * 0.68;
}
