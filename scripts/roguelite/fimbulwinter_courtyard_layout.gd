extends RefCounted

const EAST_SHIFT := 580.0
const DEPTH_RAMP := Vector4(-540, -180, 380, 805)
const COVERS := [
	{"id": "broken-stele", "foot": Vector2(-252, -286), "radius": 50.0, "width": 1.52, "height": 2.11},
	{"id": "split-stone", "foot": Vector2(654, 378), "radius": 49.0, "width": 1.53, "height": 1.91},
	{"id": "frozen-well", "foot": Vector2(1002, -271), "radius": 79.0, "width": 2.10, "height": 1.53},
]
const RING := Vector2(384, -101)
const RING_RADIUS := 276.0


static func expand(point: Vector2) -> Vector2:
	var east := clampf((point.x + 590.0) / 1370.0, 0.0, 1.0)
	var depth := smoothstep(DEPTH_RAMP.x, DEPTH_RAMP.y, point.x) * (1.0 - smoothstep(DEPTH_RAMP.z, DEPTH_RAMP.w, point.x))
	return Vector2(point.x + EAST_SHIFT * east, point.y * (1.0 + .30 * depth))


static func boundary_anchors(ruins: Node3D) -> Array[Vector3]:
	var anchors: Array[Vector3] = []
	var previous := Vector2.ZERO
	for node: Node3D in ruins.find_children("Collider_*", "Node3D", true, false):
		var index := int(str(node.name).get_slice("_", 1))
		if index >= 247 and index <= 252:
			continue # Two obsolete scree clusters inside the old arena.
		var point := expand(Vector2(node.global_position.x, node.global_position.z) * 100.0)
		var radius := node.global_basis.get_scale().x * 100.0
		if index < 112 and index != 0 and index != 55 and previous.distance_to(point) > radius * 1.8:
			var middle := previous.lerp(point, .5)
			anchors.append(Vector3(middle.x, middle.y, radius))
		anchors.append(Vector3(point.x, point.y, radius))
		previous = point
	return anchors
