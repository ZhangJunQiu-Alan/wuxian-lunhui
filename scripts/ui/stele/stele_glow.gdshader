// 石碑卡的品质光：刻纹按品质上色发光；高品质有沿刻纹上行的光带、逐个亮起的符文、扫过石面的高光。
// TEXTURE 是刻纹蒙版；TIME 不受游戏暂停影响，选卡时游戏是暂停的。
shader_type canvas_item;
render_mode blend_add;

uniform sampler2D runes_mask : filter_linear;
uniform sampler2D stone : filter_linear;  // 石碑底图，用它的 alpha 限定高光范围
uniform vec4 glow_color : source_color = vec4(1.0);
uniform float strength = 0.4;   // 刻纹常亮的强度
uniform float pulse = 0.0;      // 呼吸
uniform float sweep = 0.0;      // 沿刻纹上行的光带
uniform float runes = 0.0;      // 符文亮起
uniform float shimmer = 0.0;    // 石面高光
uniform float phase = 0.0;      // 每张卡错开一点

void fragment() {
	float t = TIME + phase;
	float inlay = texture(TEXTURE, UV).r;
	float breath = 1.0 + pulse * 0.35 * sin(t * 2.1);
	float band_y = fract(t * 0.21) * 1.5 - 0.25;
	float band = exp(-pow((1.0 - UV.y - band_y) * 7.0, 2.0));
	float glow = inlay * (strength * breath + sweep * band * 1.6);
	float rune = texture(runes_mask, UV).r * runes * smoothstep(0.2, 1.0, 0.5 + 0.5 * sin(t * 2.6 - UV.y * 16.0));
	float stone_a = texture(stone, UV).a;
	float diag = UV.x * 0.6 + UV.y * 0.4;
	float sh = shimmer * stone_a * exp(-pow((diag - (fract(t * 0.16) * 2.0 - 0.5)) * 9.0, 2.0)) * 0.22;
	vec3 c = glow_color.rgb * (glow + rune * 1.8) + mix(glow_color.rgb, vec3(1.0), 0.6) * sh;
	COLOR = vec4(c, 1.0);
}
