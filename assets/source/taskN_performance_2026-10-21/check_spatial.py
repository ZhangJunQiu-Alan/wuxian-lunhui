from pathlib import Path
p=Path('tools/test_spatial_queries.gd')
p.write_text('''extends SceneTree

var _checks := 0
var _failures: Array[String] = []
var _root: Node2D

func _initialize() -> void:
 call_deferred("_run")

func _check(ok: bool, label: String) -> void:
 _checks += 1
 if not ok: _failures.append(label)

func _reference(rect: Rect2) -> Array[Enemy]:
 var result: Array[Enemy] = []
 var first := Vector2i((rect.position / Enemy.GRID_CELL).floor())
 var last := Vector2i((rect.end / Enemy.GRID_CELL).floor())
 if (last.x-first.x+1)*(last.y-first.y+1)>Enemy._indexed_enemies.size():
  for enemy: Enemy in Enemy._indexed_enemies: result.append(enemy)
  return result
 for x in range(first.x,last.x+1):
  for y in range(first.y,last.y+1):
   for enemy: Enemy in Enemy._grid.get(Vector2i(x,y),[]): result.append(enemy)
 return result

func _radius(at: Vector2, reach: float) -> Array[Enemy]:
 var result: Array[Enemy] = []
 var pad := Vector2.ONE*(reach+Enemy._max_radius)
 for enemy in _reference(Rect2(at-pad,pad*2)):
  if enemy.global_position.distance_squared_to(at)<=pow(reach+enemy.radius,2): result.append(enemy)
 return result

func _line(a: Vector2,b: Vector2,width: float) -> Array[Enemy]:
 var result: Array[Enemy] = []
 var half := width*0.5
 for enemy in _reference(Rect2(a.min(b),(b-a).abs()).grow(half+Enemy._max_radius)):
  var point := Geometry2D.get_closest_point_to_segment(enemy.global_position,a,b)
  if point.distance_squared_to(enemy.global_position)<=pow(half+enemy.radius,2): result.append(enemy)
 return result

func _run() -> void:
 var output := ""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
 if output.is_empty(): quit(2); return
 _root=Node2D.new()
 _root.position=Vector2(173,-297)
 root.add_child(_root)
 current_scene=_root
 var enemies: Array[Enemy] = []
 for i in 80:
  var enemy := Enemy.new()
  enemy.radius=[6.0,12.0,28.0,96.0][i%4]
  enemy.position=Vector2((i%10-5)*48,(i/10-4)*41)
  _root.add_child(enemy)
  enemy.set_physics_process(false)
  enemies.append(enemy)
 await process_frame
 for stage in 4:
  if stage==1:
   enemies[0].position+=Vector2(43,41)
   enemies[1].position+=Vector2(300,-900)
   _root.position+=Vector2(19,27)
  elif stage==2:
   enemies[2]._dead=true
   enemies[2].remove_from_group("enemies")
   enemies[2].update_spatial_index()
   enemies[3].radius=160
   enemies[3].update_spatial_index()
  elif stage==3:
   enemies[4].queue_free()
  await process_frame
  for x in [-600.0,-48.0,0.0,48.0,600.0]:
   for reach in [0.0,10.0,48.0,100.0,600.0,1200.0]:
    var at := Vector2(x,-300)
    _check(Enemy.query_radius(at,reach)==_radius(at,reach),"ordered radius stage%d x%s r%s"%[stage,x,reach])
    for end in [at,at+Vector2(300,0),at+Vector2(-250,170)]:
     _check(Enemy.query_line(at,end,reach)==_line(at,end,reach),"ordered line stage%d x%s w%s end%s"%[stage,x,reach,end])
 var timings := {}
 for method in ["reference","candidate"]:
  var start := Time.get_ticks_usec()
  for i in 5000:
   var rect := Rect2(Vector2(i%17-8,i%23-11)*30,Vector2.ONE*(300 if i%2 else 50))
   if method=="reference": _reference(rect)
   else: Enemy._candidates(rect)
  timings[method+"_us"]=Time.get_ticks_usec()-start
 _root.queue_free()
 await process_frame
 _check(Enemy._indexed_enemies.is_empty() and Enemy._grid.is_empty(),"spatial index empty after exit")
 DirAccess.make_dir_recursive_absolute(output)
 var file := FileAccess.open(output.path_join("spatial.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":_checks,"failures":_failures,"microbenchmark":timings},"\\t"))
 file.close()
 print("SPATIAL_RESULT ",_checks," checks ",_failures.size()," failures ",JSON.stringify(timings))
 quit(0 if _failures.is_empty() else 1)
''')
print(p)
