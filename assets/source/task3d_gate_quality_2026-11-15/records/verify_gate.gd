extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var packed = load("res://assets/models/midgard/quality/rune_gate.glb") as PackedScene
	assert(packed)
	var model = packed.instantiate()
	root.add_child(model)
	var meshes = model.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() >= 7 and meshes.size() <= 12)
	var textured = 0
	for mesh in meshes:
		var mat = mesh.mesh.surface_get_material(0) as StandardMaterial3D
		if mat and mat.albedo_texture:
			assert(mat.normal_enabled and mat.normal_texture)
			textured += 1
	var player = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert(player.has_animation("open"))
	var moving = model.find_child("GateMoving", true, false) as Node3D
	assert(moving)
	player.play("open")
	player.seek(0, true)
	var before = moving.position
	player.seek(2.3, true)
	assert(moving.position.y > before.y + 3)
	print("QUALITY_GATE_VERIFIED meshes=",meshes.size()," textured=",textured," animation=open displacement=",moving.position-before)
	model.free()
	quit()
