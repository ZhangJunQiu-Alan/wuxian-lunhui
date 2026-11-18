shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV;
	float time = TIME;
	float rim = smoothstep(0.0, .026, p.x) * smoothstep(0.0, .026, 1.0 - p.x);
	float open = smoothstep(1.0 - reveal - .12, 1.0 - reveal + .025, p.y);
	float flow = p.x + sin(p.y * 7.1 - time * 1.15 + p.x * 2.4) * .029
		+ sin(p.y * 16.4 - time * 1.9 + p.x * 6.6) * .008;
	float veils = pow(.5 + .5 * sin(flow * 39.0 - time * .78 + sin(flow * 18.0) * 1.4), 3.2);
	float wisps = pow(.5 + .5 * sin(flow * 101.0 + time * 1.2 + sin(p.x * 23.0) * 2.0), 6.0);
	float fall = .55 + .45 * sin(p.y * 11.8 - time * 4.0 + flow * 17.0);
	float threshold = smoothstep(.71, 1.0, p.y);
	float glow = .15 + veils * (.35 + fall * .22) + wisps * (.12 + fall * .13) + threshold * .45;
	vec3 pigment = mix(vec3(.065, .24, .47), vec3(.35, .82, 1.0), min(glow, 1.0));
	ALBEDO = pigment * (.73 + glow * .56);
	EMISSION = pigment * glow * .32;
	ALPHA = rim * open * reveal * (.60 + glow * .29);
}
