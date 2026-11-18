uniform bool has_painted_cover = false;
uniform sampler2D painted_cover : filter_linear, repeat_disable;
uniform vec2 painted_extent = vec2(36.0, 24.0);
uniform vec3 painted_center;
uniform vec3 painted_right;
uniform vec3 painted_up;

bool replaced_by_paint(vec3 world_position) {
	if (!has_painted_cover) {
		return false;
	}
	vec3 point = world_position - painted_center;
	vec2 uv = vec2(0.5 + dot(point, painted_right) / painted_extent.x, 0.5 - dot(point, painted_up) / painted_extent.y);
	if (any(lessThanEqual(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) {
		return false;
	}
	return texture(painted_cover, uv).a > 0.998;
}
