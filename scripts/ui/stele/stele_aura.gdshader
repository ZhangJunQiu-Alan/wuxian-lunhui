// 史诗、传说卡背后的光晕；传说再加缓慢转动的光芒。
shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_color : source_color = vec4(1.0);
uniform float strength = 0.0;
uniform float rays = 0.0;
uniform float aspect = 0.6;  // 宽 / 高

void fragment() {
	vec2 p = (UV - vec2(0.5, 0.45)) * vec2(aspect, 1.0) * 2.0;
	float d = length(p);
	float halo = smoothstep(0.95, 0.15, d) * strength;
	float angle = atan(p.y, p.x);
	float beam = pow(0.5 + 0.5 * sin(angle * 9.0 + TIME * 0.5), 8.0) * smoothstep(1.0, 0.25, d) * rays;
	float breath = 0.85 + 0.15 * sin(TIME * 1.7);
	COLOR = vec4(glow_color.rgb * (halo * 0.45 + beam * 0.35) * breath, 1.0);
}
