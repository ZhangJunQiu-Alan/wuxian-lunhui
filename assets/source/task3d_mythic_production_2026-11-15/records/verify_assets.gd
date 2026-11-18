extends SceneTree
var failures:=0
var motions:=0
func _initialize() -> void:
	run.call_deferred()
func check(value: bool,message: String) -> void:
	if not value:
		failures+=1
		push_error(message)
func poses(skeleton: Skeleton3D) -> Array[Transform3D]:
	var result: Array[Transform3D]=[]
	for i in skeleton.get_bone_count():result.append(skeleton.get_bone_pose(i))
	return result
func run() -> void:
	var file=FileAccess.open("res://assets/source/task3d_mythic_production_2026-11-15/manifest.json",FileAccess.READ)
	var manifest=JSON.parse_string(file.get_as_text())
	for entry in manifest.models:
		var id: String=entry.id
		var packed=load("res://"+entry.glb) as PackedScene
		check(packed!=null,"Missing scene "+id)
		if not packed:continue
		var model=packed.instantiate();root.add_child(model)
		var meshes=model.find_children("*","MeshInstance3D",true,false)
		check(not meshes.is_empty(),"No meshes "+id)
		for mesh in meshes:
			check(mesh.mesh!=null,"Empty mesh "+id)
			for i in mesh.mesh.get_surface_count():check(mesh.mesh.surface_get_material(i)!=null,"Missing material "+id)
		if entry.get("skins",0)>0:
			var skeletons=model.find_children("*","Skeleton3D",true,false)
			check(skeletons.size()==1,"Skeleton count "+id)
			if not skeletons.is_empty():
				var skeleton: Skeleton3D=skeletons[0]
				check(skeleton.get_bone_count()>=13,"Too few bones "+id)
				var skinned:=0
				for mesh in meshes:
					if mesh.skin:
						skinned+=1
						check(mesh.skin.get_bind_count()>10,"Missing skin binds "+id)
				check(skinned>0,"No skinned mesh "+id)
				var players=model.find_children("*","AnimationPlayer",true,false)
				check(not players.is_empty(),"No animations "+id)
				if not players.is_empty():
					var player: AnimationPlayer=players[0]
					for clip in entry.animations:
						check(player.has_animation(clip),"Missing clip "+id+" "+clip)
						if not player.has_animation(clip):continue
						player.play(clip);player.seek(0,true);var before=poses(skeleton)
						player.seek(player.get_animation(clip).length*.40,true);var after=poses(skeleton)
						var changed:=false
						for i in before.size():
							if not before[i].is_equal_approx(after[i]):changed=true
						check(changed,"Static skeleton clip "+id+" "+clip)
						if changed:motions+=1
						print("CLIP ",id," ",clip," moved=",changed)
		print("MODEL ",id," meshes=",meshes.size())
		model.free()
	print("PRODUCTION_VERIFICATION models=",manifest.models.size()," motion_clips=",motions," failures=",failures)
	quit(int(failures>0))
