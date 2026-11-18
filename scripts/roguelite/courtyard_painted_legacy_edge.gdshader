shader_type spatial;

#include "res://scripts/roguelite/courtyard_painted_coverage.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D albedo_map : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_normal = false;
uniform float normal_strength = 1.0;
uniform float mineral_roughness = 1.0;
uniform float mineral_metallic = 0.0;
varying vec3 v4_world;

void vertex() {
	v4_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (replaced_by_paint(v4_world)) {
		discard;
	}
	ALBEDO = texture(albedo_map, UV).rgb * tint.rgb;
	METALLIC = mineral_metallic;
	ROUGHNESS = mineral_roughness * texture(roughness_map, UV).r;
	if (use_normal) {
		NORMAL_MAP = texture(normal_map, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
}
