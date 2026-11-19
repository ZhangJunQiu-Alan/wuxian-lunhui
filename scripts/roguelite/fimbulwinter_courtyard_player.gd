extends Player

signal foot_moved(from: Vector2, to: Vector2)

var perimeter: Array[Vector3] = []


func _physics_process(delta: float) -> void:
	var previous := position
	super._physics_process(delta)
	if position != previous:
		foot_moved.emit(previous, position)


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


## 中庭用 3D 剑士，倒地动作比像素版长；留够时间让它倒下再出结算
func death_duration() -> float:
	return maxf(super.death_duration(), 1.6)
