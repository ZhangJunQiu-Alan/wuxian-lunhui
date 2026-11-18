shader_type spatial;

uniform sampler2D flagstones : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise_at(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(grain(cell), grain(cell + vec2(1.0, 0.0)), blend.x),
		mix(grain(cell + vec2(0.0, 1.0)), grain(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

void fragment() {
	vec2 point = world.xz;
	vec3 stone = texture(flagstones, UV).rgb * vec3(0.83, 0.90, 1.00);
	float coarse = noise_at(point * 1.65);
	float fine = noise_at(point * 15.0);
	float drift = (coarse - 0.4) * 0.92 + (fine - 0.50) * 0.22;
	float passage = smoothstep(4.1, 8.3, abs(world.x));
	float edge = max(abs(world.z) - mix(6.23, 2.45, passage), max(-world.x - 26.5, world.x - 14.3));
	float height = smoothstep(-0.66, -0.06, world.y);
	float frost = smoothstep(-0.40, 0.60, edge + drift) * height;
	vec3 snow = vec3(0.22, 0.28, 0.36) * (0.82 + 0.18 * coarse + 0.14 * fine);
	ALBEDO = mix(stone * mix(0.28, 1.0, height), snow, frost * 0.85);
	ROUGHNESS = mix(0.80, 0.96, frost);
}
