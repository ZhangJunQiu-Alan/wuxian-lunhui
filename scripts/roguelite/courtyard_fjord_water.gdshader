shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D water_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D aerial_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 parallax;
varying vec3 world;

#include "res://scripts/roguelite/courtyard_painted_coverage.gdshaderinc"

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (replaced_by_paint(world)) {
		discard;
	}
	vec2 p = world.xz - parallax;
	float t = TIME * .009;
	vec2 current = vec2(p.x*.092+p.y*.014, p.y*.117) + vec2(t,-t*.4);
	vec3 floes = texture(water_map, current).rgb;
	vec3 vista = texture(aerial_map, p * vec2(.018, .027) + vec2(.55,.41) + vec2(-t*.14,t*.08)).rgb;
	float fog = smoothstep(-.75, .75, sin(p.x*.13+p.y*.16+t*2.5) * cos(p.y*.18-p.x*.052));
	vec3 deep = mix(vec3(.037,.073,.126), vec3(.102,.186,.285), fog * .53);
	ALBEDO = mix(deep, mix(floes,vista,.38) * vec3(.81,.91,1.12), .84);
}
