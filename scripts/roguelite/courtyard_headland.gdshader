shader_type spatial;

uniform sampler2D snowfield : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D limestone : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D basalt_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D limestone_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D basalt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D slab_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D basalt_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world;

#include "res://scripts/roguelite/courtyard_painted_coverage.gdshaderinc"

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float random_cell(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float grain(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(random_cell(cell), random_cell(cell + vec2(1, 0)), f.x),
		mix(random_cell(cell + vec2(0, 1)), random_cell(cell + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	if (replaced_by_paint(world)) {
		discard;
	}
	vec2 p = world.xz;
	float broad = grain(p * 0.43);
	float grit = grain(p * 4.9);
	float curve = sin((p.x + 1.2) * 0.48) * 1.12 + 0.43;
	curve = mix(curve, -1.65, smoothstep(-13.0, -6.8, p.x) * (1.0 - smoothstep(-5.7, -2.8, p.x)));
	curve = mix(curve, 1.24, smoothstep(6.1, 10.3, p.x));
	float road = abs(p.y - curve) - mix(1.02, 1.51, broad);
	float forecourt = (length((p - vec2(-21.2, 0.15)) / vec2(4.03, 2.65)) - 1.0) * 2.4;
	float arena = (length((p - vec2(.41, -.15)) / vec2(6.45, 5.75)) - 1.0) * 4.2;
	float edge = min(min(road, forecourt), arena) + (grit - .5) * .15;
	float paved = 1.0 - smoothstep(-.11, .09, edge);
	float packed_edge = smoothstep(-.15, .01, edge) * (1.0 - smoothstep(.13, .36, edge));
	float wind = grain(p * .63 + vec2(32.9, -16.1));
	float flurry = smoothstep(.64, .89, wind * .82 + grit * .22);
	vec2 stone_uv = p * vec2(.389, .414);
	vec2 snow_uv = p * .46 + vec2(.07,.12);
	vec3 ice_snow = texture(snowfield, snow_uv).rgb * vec3(.79, .78, .83);
	ice_snow *= mix(.53, 1.03, broad);
	vec3 stone = texture(limestone, stone_uv).rgb * vec3(.78, .80, .88);
	stone *= mix(.66, 1.05, broad);
	vec3 flat_surface = mix(ice_snow, stone, paved);
	flat_surface = mix(flat_surface, ice_snow * vec3(.75,.82,.92), packed_edge * .44);
	flat_surface = mix(flat_surface, ice_snow, flurry * (.46 + packed_edge * .43));
	float treeline = smoothstep(.16,1.89,edge) *
		smoothstep(.23,.78,grain(p*vec2(.72,.51)+vec2(4.2,-2.5)));
	flat_surface *= mix(vec3(1.0),vec3(.40,.47,.62),treeline*.85);
	vec2 cliff_uv = vec2(world.x * .42 + world.z * .51, world.y * .55);
	vec3 basalt = texture(basalt_map, cliff_uv).rgb * vec3(.71,.83,1.03);
	float cracks = grain(vec2(p.x*4.9+p.y*3.6,world.y*.77));
	float strata = grain(vec2(p.x*.75 + p.y*1.1,world.y*4.1));
	basalt *= mix(.52, 1.24, cracks) * mix(.82, 1.06, strata);
	float fractures = smoothstep(.59, .80, grain(vec2(p.x*2.8+p.y*3.1,world.y*.74)));
	float cap = smoothstep(-mix(.22,.46,fractures),.001, world.y);
	basalt = mix(basalt, ice_snow * .62, cap*.83);
	float top = smoothstep(-.026,-.001,world.y);
	ALBEDO = mix(basalt, flat_surface, top);
	vec3 cliff_detail = texture(basalt_normal, cliff_uv).rgb;
	vec3 flat_detail = mix(texture(snow_normal, snow_uv).rgb, texture(limestone_normal, stone_uv).rgb, paved);
	NORMAL_MAP = mix(cliff_detail, flat_detail, top);
	NORMAL_MAP_DEPTH = .50;
	ROUGHNESS = mix(texture(basalt_roughness,cliff_uv).r,
		mix(texture(snow_roughness,snow_uv).r,texture(slab_roughness,stone_uv).r,paved),top);
}
