extends "res://scripts/gods/odin.gd"
var timings := {}

func tick(delta: float) -> void:
	var start:=Time.get_ticks_usec()
	super.tick(delta)
	var row: Array=timings.get("tick",[0,0,0])
	var elapsed:=Time.get_ticks_usec()-start
	row[0]+=1
	row[1]+=elapsed
	row[2]=maxi(row[2],elapsed)
	timings["tick"]=row

func detonate(enemy: Enemy, forced: bool = false) -> void:
	var start:=Time.get_ticks_usec()
	super.detonate(enemy, forced)
	var row: Array=timings.get("detonate",[0,0,0])
	var elapsed:=Time.get_ticks_usec()-start
	row[0]+=1
	row[1]+=elapsed
	row[2]=maxi(row[2],elapsed)
	timings["detonate"]=row

func _update_night_membership() -> void:
	var start:=Time.get_ticks_usec()
	super._update_night_membership()
	var row: Array=timings.get("_update_night_membership",[0,0,0])
	var elapsed:=Time.get_ticks_usec()-start
	row[0]+=1
	row[1]+=elapsed
	row[2]=maxi(row[2],elapsed)
	timings["_update_night_membership"]=row

func _move_missiles(delta: float) -> void:
	var start:=Time.get_ticks_usec()
	super._move_missiles(delta)
	var row: Array=timings.get("_move_missiles",[0,0,0])
	var elapsed:=Time.get_ticks_usec()-start
	row[0]+=1
	row[1]+=elapsed
	row[2]=maxi(row[2],elapsed)
	timings["_move_missiles"]=row

func _draw() -> void:
	var start:=Time.get_ticks_usec()
	super._draw()
	var row: Array=timings.get("_draw",[0,0,0])
	var elapsed:=Time.get_ticks_usec()-start
	row[0]+=1
	row[1]+=elapsed
	row[2]=maxi(row[2],elapsed)
	timings["_draw"]=row

func zone(pos: Vector2, radius: float, life: float, tick_every: float, on_tick: Callable, zone_color: Color) -> GodZone:
	var z=load("res://assets/source/taskK_independent_qa_2026-10-20/diagnostics/zone_profile.gd").new()
	z.position=pos
	z.radius=radius
	z.life=life
	z.tick_every=tick_every
	z.on_tick=on_tick
	z.color=zone_color
	game().add_child(z)
	return z
