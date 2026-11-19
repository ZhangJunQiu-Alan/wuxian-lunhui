// 石碑卡的插画：只在拱形窗里显示，按窗口比例裁掉插画下部（插画的主体在上部）。
shader_type canvas_item;

uniform sampler2D window_mask : filter_linear;
uniform vec4 window_rect = vec4(0.1, 0.064, 0.8, 0.518);  // 窗口在整张卡里的位置（UV）
uniform float visible_height = 0.74;  // 窗口显示插画高度的多少
uniform float crop_top = 0.03;
uniform float brightness = 1.0;

void fragment() {
	vec2 art_uv = vec2(UV.x, crop_top + UV.y * visible_height);
	vec4 c = texture(TEXTURE, art_uv);
	float mask = texture(window_mask, window_rect.xy + UV * window_rect.zw).r;
	COLOR = vec4(c.rgb * brightness, c.a * mask);
}
