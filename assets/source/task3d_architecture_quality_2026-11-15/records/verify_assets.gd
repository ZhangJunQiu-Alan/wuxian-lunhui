extends SceneTree
var failures:=0
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures+=1
		push_error(message)
func run() -> void:
	var anchors={"ruined_wall":"SnapLeft","timber_pillar":"BeamAnchor","stone_stairs":"UpperAnchor","barricade":"CoverAnchor","supply_chest":"LootOrigin","runestone":"BlessingOrigin"}
	for id in ["rune_gate","snow_floor","void_causeway","spike_trap","rune_trap","pressure_plate","lever","brazier","ruined_wall","timber_pillar","stone_stairs","barricade","supply_chest","runestone"]:
		var packed=load("res://assets/models/midgard/quality/"+id+".glb") as PackedScene
		check(packed!=null,"Missing model "+id)
		if not packed: continue
		var model=packed.instantiate(); root.add_child(model)
		var meshes=model.find_children("*","MeshInstance3D",true,false)
		check(not meshes.is_empty() and meshes.size()<=15,"Mesh count "+id)
		var textured:=0
		for mesh in meshes:
			var mat=mesh.mesh.surface_get_material(0) as StandardMaterial3D
			check(mat!=null,"Missing material "+id)
			if mat and mat.albedo_texture:
				textured+=1
				check(mat.normal_enabled and mat.normal_texture!=null,"Missing normal "+id)
		check(textured>0,"Missing PBR "+id)
		if anchors.has(id): check(model.find_child(anchors[id],true,false)!=null,"Missing anchor "+id)
		if id=="supply_chest":
			var players=model.find_children("*","AnimationPlayer",true,false)
			check(not players.is_empty(),"Missing chest animation player")
			if not players.is_empty():
				var player: AnimationPlayer=players[0]
				check(player.has_animation("open"),"Missing chest open")
				if player.has_animation("open"):
					var lid=model.find_child("HingedLid",true,false) as Node3D
					check(lid!=null,"Missing hinge")
					if lid:
						player.play("open"); player.seek(0,true)
						var before=lid.transform
						player.seek(2.3,true)
						var angle=before.basis.get_rotation_quaternion().angle_to(lid.basis.get_rotation_quaternion())
						check(angle>1.5,"Chest lid does not open enough")
						check(before.origin.is_equal_approx(lid.position),"Chest hinge drift")
						check(lid.get_child_count()>=2,"Missing lid parts")
						player.seek(0,true)
						check(before.is_equal_approx(lid.transform),"Chest cannot return to closed")
						print("CHEST_ANIMATION open_angle=",angle," hinge_fixed=true reset=true")
		print("MODEL ",id," meshes=",meshes.size()," textured=",textured)
		model.free()
	print("ARCHITECTURE_VERIFICATION failures=",failures)
	quit(int(failures>0))
