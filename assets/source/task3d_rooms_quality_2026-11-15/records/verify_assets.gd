extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func collect(node: Node, result: Dictionary) -> void:
	if node is Node3D: result[node.get_path()] = node.transform
	for child in node.get_children(): collect(child, result)
func run() -> void:
	var animated = {"rune_gate":"open", "spike_trap":"spike", "pressure_plate":"press", "lever":"activate"}
	var markers = {"snow_floor":"TileOrigin", "void_causeway":"VoidVolume", "spike_trap":"DamageOrigin", "rune_trap":"BlastOrigin", "pressure_plate":"TriggerOrigin", "lever":"InteractAnchor", "brazier":"FireOrigin"}
	for id in ["rune_gate","snow_floor","void_causeway","spike_trap","rune_trap","pressure_plate","lever","brazier"]:
		var packed = load("res://assets/models/midgard/quality/" + id + ".glb") as PackedScene
		check(packed != null, "Missing model: " + id)
		if not packed: continue
		var model = packed.instantiate()
		root.add_child(model)
		var meshes = model.find_children("*", "MeshInstance3D", true, false)
		check(not meshes.is_empty() and meshes.size() <= 15, "Mesh grouping: " + id)
		var textured := 0
		for node in meshes:
			var mat = node.mesh.surface_get_material(0) as StandardMaterial3D
			check(mat != null, "Missing material: " + id)
			if mat and mat.albedo_texture:
				textured += 1
				check(mat.normal_enabled and mat.normal_texture != null, "Missing PBR normal: " + id)
		check(textured > 0, "No scanned materials: " + id)
		if markers.has(id): check(model.find_child(markers[id],true,false) != null, "Missing anchor: " + id)
		if animated.has(id):
			var players = model.find_children("*", "AnimationPlayer", true, false)
			check(not players.is_empty(), "No player: " + id)
			if not players.is_empty():
				var player: AnimationPlayer = players[0]
				var clip: String = animated[id]
				check(player.has_animation(clip), "No clip: " + id)
				if player.has_animation(clip):
					player.play(clip); player.seek(0,true)
					var before := {}; collect(model,before)
					var seek_time := 1.1 if id == "spike_trap" else 1.7 if id == "lever" else 2.3 if id == "rune_gate" else 1.3
					player.seek(seek_time,true)
					var after := {}; collect(model,after)
					var moved := false
					for path: NodePath in before:
						if not before[path].is_equal_approx(after[path]): moved = true
					check(moved,"Static animation: " + id)
					print("ANIMATION ",id," clip=",clip," moved=",moved)
		print("MODEL ",id," meshes=",meshes.size()," textured=",textured)
		model.free()
	print("QUALITY_ROOM_VERIFICATION failures=", failures)
	quit(int(failures > 0))
