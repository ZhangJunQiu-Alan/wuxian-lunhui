extends "res://tools/test_vigrid.gd"

var _records := []

func _run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): _output=arg.trim_prefix("--output=")
 var save=root.get_node("Save")
 if save.path==save.DEFAULT_PATH or _output.is_empty(): quit(2); return
 save.reset()
 save.cleared_levels.assign(["midgard","helheim"])
 save.selected_level="vigrid"
 _boss_db=load("res://scripts/data/boss_db.gd")
 AudioServer.set_bus_mute(0,true)
 _begin("circle-tick target cache versus original cadence and resonance")
 for awake in [false,true]:
  var before=await _measure("before",awake)
  var after=await _measure("after",awake)
  for i in before.states.size(): _check(before.states[i]==after.states[i],"ordered HP/runes/positions after staggered ticks, moves, death and spread: awake=%s step=%d"%[awake,i])
  _records.append({"awake":awake,"before_us":before.us,"after_us":after.us})
 _pass()
 await _test_cleanup()
 DirAccess.make_dir_recursive_absolute(_output)
 var file=FileAccess.open(_output.path_join("night_targets.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":_checks,"failures":_failures,"log":_log,"records":_records},"\t"))
 file.close()
 print("NIGHT_TARGET_RESULT ",_checks," checks ",_failures," failures ",JSON.stringify(_records))
 OS.delay_msec(200)
 quit(1 if _failures else 0)

func _measure(version: String, awake: bool) -> Dictionary:
 await _new_game()
 var source="res://assets/source/taskN_performance_2026-10-21/before/odin.gd" if version=="before" else "res://scripts/gods/odin.gd"
 var power=load(source).new()
 _player.add_child(power)
 _player.gods.odin=power
 power.god_id="odin"
 power.path="odin_nights"
 power.awakened=awake
 power.stats.odin_resonance=140.0
 var enemy_script=load("res://scripts/entities/enemy.gd")
 enemy_script.crit_chance=0.0
 var enemies:=[]
 for i in 120:
  var enemy=_game.spawn_enemy("dead",Vector2(i%12-6,i/12-5)*19.0)
  enemy.hp=1000000.0
  enemy.max_hp=enemy.hp
  enemies.append(enemy)
 seed(78)
 for i in 24: power._rune_circle(Vector2(i%6-3,i/6-2)*24.0,false)
 var states:=[]
 var total:=0
 for step in 10:
  power._time=step*0.25
  if step==2:
   enemies[0].position=Vector2(900,900)
   enemies[1].position+=Vector2(24,0)
  if step==4: _game.despawn_enemy(enemies[2])
  if step==6:
   enemies[0].position=Vector2(40,30)
   enemies[1].radius=96.0
   enemies[1].update_spatial_index()
  var start:=Time.get_ticks_usec()
  for i in power._circles.size():
   if i%3==step%3: power._circles[i]._process(0.25)
  power.detonate(enemies[15])
  total+=Time.get_ticks_usec()-start
  var row:=[]
  for enemy in enemies: row.append([enemy.hp,enemy.stack_count("rune"),enemy.position])
  states.append(row)
 return {"us":total,"states":states}
