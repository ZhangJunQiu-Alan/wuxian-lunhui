from pathlib import Path
import re,json
r=Path(__file__).parent/'runtime'
(r/'tools/n_perf_stats.gd').write_text('''extends RefCounted
static var rows := {}
static func record(id: String, start: int) -> void:
 var elapsed := Time.get_ticks_usec()-start
 var row: Array=rows.get(id,[0,0,0])
 row[0]+=1
 row[1]+=elapsed
 row[2]=maxi(row[2],elapsed)
 rows[id]=row
''')
specs={
'scripts/game.gd':{'_physics_process':('_delta',False)},
'scripts/world/map_layer.gd':{'push_out':('pos, margin',True)},
'scripts/gods/thor.gd':{'_tick_static':('delta',False)},
'scripts/entities/enemy.gd':{'_physics_process':('delta',False),'_separation':('',True),'update_spatial_index':('',False),'_tick_statuses':('delta',False),'take_damage':('amount, knockback, crit',False),'query_radius':('center, reach',True),'query_line':('a, b, width',True),'add_stacks':('id, n, duration',True)},
'scripts/gods/odin.gd':{'detonate':('enemy, _forced',False),'_update_night_membership':('',False),'_move_missiles':('delta',False),'tick':('delta',False)},
'scripts/gods/god_zone.gd':{'_process':('delta',False),'enemies_inside':('',True)},
'scripts/core/audio.gd':{'_play_sfx':('sound, volume_db, pitch',False)},
'scripts/effects/fx_layer.gd':{'damage_number':('pos, amount, crit',False),'burst':('pos, color, count, speed, size',False),'_process':('delta',False),'_draw':('',False)},
}
for path,methods in specs.items():
 p=r/path; s=p.read_text()
 for name,(args,returns) in methods.items():
  pattern=re.compile(r'^(static )?func '+re.escape(name)+r'\((.*)\) -> ([^:]+):$',re.M)
  m=pattern.search(s); assert m,(path,name)
  static=m[1] or ''; signature=m[2]; typ=m[3]; ident=path.split('/')[-1]+'.'+name
  wrapper=f'{static}func {name}({signature}) -> {typ}:\n\tvar n_start := Time.get_ticks_usec()\n'
  call=f'_n_base_{name}({args})'
  wrapper+=f'\tvar n_result = {call}\n' if returns else f'\t{call}\n'
  wrapper+=f'\tpreload("res://tools/n_perf_stats.gd").record("{ident}", n_start)\n'
  if returns: wrapper+='\treturn n_result\n'
  wrapper+=f'\n\n{static}func _n_base_{name}({signature}) -> {typ}:'
  s=s[:m.start()]+wrapper+s[m.end():]
 p.write_text(s)
p=r/'tools/acceptance_vigrid_soak.gd'; s=p.read_text();s=s.replace('func _flush() -> void:', 'func _flush() -> void:\n\t_report["instrumentation"] = preload("res://tools/n_perf_stats.gd").rows')
p.write_text(s)
print('instrumented',list(specs))
