shader_type spatial;

uniform sampler2D stone_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool carved = false;
varying vec3 world_at;
varying vec3 world_normal;

#include "res://scripts/roguelite/courtyard_painted_coverage.gdshaderinc"

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	if (replaced_by_paint(world_at)) {
		discard;
	}
	vec3 axis = pow(abs(normalize(world_normal)), vec3(4.0));
	axis /= max(.001, axis.x + axis.y + axis.z);
	vec3 p = world_at * (carved ? .63 : .47);
	vec3 texel = texture(stone_map,p.zy).rgb*axis.x + texture(stone_map,p.xz).rgb*axis.y
		+ texture(stone_map,p.xy).rgb*axis.z;
	vec3 variation = carved ? vec3(1.13,1.14,1.16) : vec3(.87,.93,1.04);
	ALBEDO = texel * variation;
	NORMAL_MAP = texture(stone_normal,UV).rgb;
	NORMAL_MAP_DEPTH = .57;
	ROUGHNESS = texture(stone_roughness,UV).r;
}
