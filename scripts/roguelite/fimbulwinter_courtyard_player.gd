extends Player

var perimeter: Array[Vector3] = []


func weapon_dash(direction: Vector2, distance: float) -> Vector2:
	var end := Game.clamp_to_map(position + direction * distance, RADIUS)
	# Preserve continuous wall collision, including the narrow exit causeway.
	dash_through_obstacles = true
	for anchor in perimeter:
		var center := Vector2(anchor.x, anchor.y)
		if Geometry2D.get_closest_point_to_segment(center, position, end).distance_to(center) < anchor.z + RADIUS:
			dash_through_obstacles = false
			break
	var landing := super.weapon_dash(direction, distance)
	dash_through_obstacles = false
	return landing
