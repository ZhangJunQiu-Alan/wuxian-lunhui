// 3D 角色的墨意着色：低饱和、两级柔和明暗、轮廓处轻微墨色加深、细纸纹。不做全身粗黑描边。
// 和手绘场景一样不吃场景灯光（场景是画出来的），明暗用固定的主光方向自己算。
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_texture = true;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 flash : source_color = vec4(1.0, 0.62, 0.58, 0.0);  // 受击时混入的颜色，a 为强度
uniform float desaturate : hint_range(0.0, 1.0) = 0.22;
uniform vec3 paper_tint : source_color = vec3(0.89, 0.93, 1.0);  // 与像素时期的 #e3edff 冷调一致
uniform float edge_ink : hint_range(0.0, 1.0) = 0.38;
uniform float grain : hint_range(0.0, 0.3) = 0.05;
uniform vec3 key_dir = vec3(-0.47, 0.45, 0.76);  // 指向主光（世界坐标），由脚本按太阳方向设置
uniform vec3 light_color : source_color = vec3(1.0, 0.96, 0.9);
uniform vec3 shade_color : source_color = vec3(0.46, 0.52, 0.66);  // 冷灰蓝的墨色暗部
uniform float exposure = 1.0;

varying vec3 local_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	local_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - NODE_POSITION_WORLD;  // 世界单位
}

void fragment() {
	vec3 c = base_color.rgb;
	if (use_texture) {
		c *= texture(albedo_tex, UV).rgb;
	}
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(lum), desaturate) * paper_tint;
	float g = noise(local_pos * 45.0) * 0.6 + noise(local_pos * 130.0) * 0.4;
	c *= 1.0 + (g - 0.5) * grain * 2.0;
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);  // 双面材质的背面法线 Godot 已自动翻转
	float edge = smoothstep(0.62, 0.97, rim) * (0.55 + 0.45 * noise(local_pos * 16.0));
	c = mix(c, c * 0.32 + vec3(0.035, 0.045, 0.075), edge * edge_ink);
	vec3 l = normalize((VIEW_MATRIX * vec4(key_dir, 0.0)).xyz);
	float wrap = clamp((dot(NORMAL, l) + 0.3) / 1.3, 0.0, 1.0);
	// 两级柔和的明暗：像水墨的两遍染色，而不是连续的渐变
	float band = smoothstep(0.28, 0.40, wrap) * 0.55 + smoothstep(0.60, 0.72, wrap) * 0.45;
	c *= mix(shade_color, light_color, band) * exposure;
	ALBEDO = mix(c, flash.rgb, flash.a);
}
