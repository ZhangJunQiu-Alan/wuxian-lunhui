from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[4]
changes={}
def replace(path,old,new):
 p=ROOT/path;s=p.read_text();assert s.count(old)==1,(path,s.count(old),old[:80]);p.write_text(s.replace(old,new));changes.setdefault(path,[]).append({'old':old,'new':new})
replace('scripts/ultimates/dimension_slash.gd', '''				draw_line(cut.from, cut.to, Color(0, 0, 0, 0.9), 6.0)
				draw_line(cut.from, cut.to, Color(0.8, 0.85, 1.0), 1.5)''', '''				var dir: Vector2 = cut.to - cut.from
				if not CombatFx.draw(self, "dimension_cut", 0.0, (cut.from + cut.to) * 0.5, dir.angle(), Vector2(dir.length() / 87.0, 0.45)):
					draw_line(cut.from, cut.to, Color(0, 0, 0, 0.9), 6.0)
					draw_line(cut.from, cut.to, Color(0.8, 0.85, 1.0), 1.5)''')
replace('scripts/ultimates/dimension_slash.gd', '''		draw_line(cut.from, cut.to, Color(0.55, 0.65, 1.0, 0.8 * (1.0 - t)), width)
		draw_line(cut.from, cut.to, Color(1, 1, 1, 1.0 - t), width * 0.3)''', '''		var dir: Vector2 = cut.to - cut.from
		if not CombatFx.draw(self, "dimension_cut", _time - BURST_AT, (cut.from + cut.to) * 0.5, dir.angle(), Vector2(dir.length() / 87.0, width / 27.0), Color(1, 1, 1, 1.0 - t)):
			draw_line(cut.from, cut.to, Color(0.55, 0.65, 1.0, 0.8 * (1.0 - t)), width)
			draw_line(cut.from, cut.to, Color(1, 1, 1, 1.0 - t), width * 0.3)''')
replace('scripts/ultimates/wild_west_show.gd', '''	draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 32, Color(COLOR, 0.5 * fade), 2.0)''', '''	if not CombatFx.draw(self, "west_aura", _time, Vector2.ZERO, 0.0, Vector2.ONE * 34.0 / 46.573, Color(1, 1, 1, fade)):
		draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 32, Color(COLOR, 0.5 * fade), 2.0)
	if _time >= 0.25 and CombatFx.texture("west_star") != null:
		return''')
replace('scripts/ultimates/wild_west_show.gd','''		var star := PackedVector2Array()''','''		if CombatFx.draw(self, "west_star", _time, p, 0.0, Vector2.ONE * 0.45, Color(1, 1, 1, fade)):
			continue
		var star := PackedVector2Array()''')
replace('scripts/ultimates/enter_formation.gd','''		draw_line(trail.from, trail.to, Color(0.1, 0.0, 0.0, 0.7 * a), 8.0)
		draw_line(trail.from, trail.to, Color(COLOR, a), 2.0)''','''		var dir: Vector2 = trail.to - trail.from
		if not CombatFx.draw(self, "formation_slash", 0.35 - trail.life, (trail.from + trail.to) * 0.5, dir.angle(), Vector2(dir.length() / 56.0, 1.0), Color(1, 1, 1, a)):
			draw_line(trail.from, trail.to, Color(0.1, 0.0, 0.0, 0.7 * a), 8.0)
			draw_line(trail.from, trail.to, Color(COLOR, a), 2.0)''')
replace('scripts/ultimates/enter_formation.gd','''			# 骑兵剪影：马身 + 骑手 + 前伸的长枪''','''			if CombatFx.draw(self, "formation_cavalry", _cavalry_t + i * 0.07 + k * 0.13, p + Vector2(0, 6), 0.0, Vector2.ONE, Color(1, 1, 1, alpha)):
				continue
			# 骑兵剪影：马身 + 骑手 + 前伸的长枪''')
replace('scripts/ultimates/stonehenge.gd','''		draw_circle(Vector2.ZERO, RADIUS, Color(MAGIC_COLOR, (0.06 + 0.04 * pulse) * fade))''','''		if not CombatFx.draw(self, "stonehenge_circle", 0.0, Vector2.ZERO, 0.0, Vector2.ONE * RADIUS / 62.0, Color(1, 1, 1, (0.25 + 0.12 * pulse) * fade), RADIUS):
			draw_circle(Vector2.ZERO, RADIUS, Color(MAGIC_COLOR, (0.06 + 0.04 * pulse) * fade))''')
replace('scripts/ultimates/stonehenge.gd','''		draw_rect(Rect2(base + drop + Vector2(-9, -30), Vector2(18, 44)), color)
		draw_rect(Rect2(base + drop + Vector2(-9, -30), Vector2(18, 44)), Color(0.25, 0.26, 0.3, fade), false, 2.0)''','''		if not CombatFx.draw(self, "stonehenge_stone", 0.0, base + drop + Vector2(0, 14), 0.0, Vector2.ONE * 0.75, Color(1, 1, 1, fade)):
			draw_rect(Rect2(base + drop + Vector2(-9, -30), Vector2(18, 44)), color)
			draw_rect(Rect2(base + drop + Vector2(-9, -30), Vector2(18, 44)), Color(0.25, 0.26, 0.3, fade), false, 2.0)''')
replace('scripts/ultimates/stonehenge.gd','''			draw_line(base + Vector2(0, -32), next + Vector2(0, -32), Color(0.48, 0.49, 0.55, fade), 9.0)''','''			if not CombatFx.draw(self, "stonehenge_lintel", 0.0, (base + next) * 0.5 + Vector2(0, -32), (next - base).angle(), Vector2(base.distance_to(next) / 60.0, 9.0 / 14.0), Color(1, 1, 1, fade)):
				draw_line(base + Vector2(0, -32), next + Vector2(0, -32), Color(0.48, 0.49, 0.55, fade), 9.0)''')
replace('scripts/weapons/twin_blades.gd','const SLASH_DURATION := 0.1','const SLASH_DURATION := 0.25')
replace('scripts/weapons/twin_blades.gd','''	draw_arc(Vector2.ZERO, reach * 0.9, a - HALF_ARC, a + HALF_ARC, 16, Color(1.0, 0.45, 0.45, alpha), 3.0)''','''	if CombatFx.draw(self, "blades_slash", SLASH_DURATION - _slash_time, Vector2.ZERO, a, Vector2.ONE * reach * 0.9 / 30.5, Color.WHITE, reach, HALF_ARC, _aim.angle()):
		return
	draw_arc(Vector2.ZERO, reach * 0.9, a - HALF_ARC, a + HALF_ARC, 16, Color(1.0, 0.45, 0.45, alpha), 3.0)''')
replace('scripts/weapons/arcane_nova.gd','''		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(COLOR, 0.9 * alpha), 6.0 * (1.0 - k) + 2.0)
		draw_circle(Vector2.ZERO, r, Color(COLOR, 0.08 * alpha))''','''		if CombatFx.draw(self, "arcane_nova", wave.t, Vector2.ZERO, 0.0, Vector2.ONE * r / 62.514, Color(1, 1, 1, alpha), r):
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(COLOR, 0.35 * alpha), 1.0)
		else:
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(COLOR, 0.9 * alpha), 6.0 * (1.0 - k) + 2.0)
			draw_circle(Vector2.ZERO, r, Color(COLOR, 0.08 * alpha))''')
replace('scripts/effects/fx_layer.gd','''	instance._marks.append({"pos": pos, "angle": angle, "length": length, "kind": kind, "color": color, "life": MARK_LIFE})''','''	var duration := 0.25 if kind in ["claw", "bite", "death"] else MARK_LIFE
	instance._marks.append({"pos": pos, "angle": angle, "length": length, "kind": kind, "color": color, "life": duration, "duration": duration})


static func death(pos: Vector2, color: Color, elite: bool = false) -> bool:
	if instance == null or CombatFx.texture("death_shards") == null:
		return false
	mark(pos, randf() * TAU, 88.0 if elite else 56.0, color.lightened(0.3), "death")
	return true''')
replace('scripts/effects/fx_layer.gd','''	var k: float = 1.0 - m.life / MARK_LIFE           # 0 → 1''','''	var duration: float = m.get("duration", MARK_LIFE)
	var id: String = {"claw": "hit_claw", "bite": "hit_bite", "death": "death_shards"}.get(m.kind, "")
	if id != "":
		var width := 50.0 if m.kind == "bite" else 28.0
		if CombatFx.draw(self, id, duration - m.life, m.pos, m.angle, Vector2.ONE * m.length / width, m.color):
			return
	var k: float = 1.0 - m.life / duration           # 0 → 1''')
replace('scripts/entities/enemy.gd','''	FxLayer.burst(global_position, color, 30 if is_elite else 8, 220.0 if is_elite else 150.0)''','''	if not FxLayer.death(global_position, color, is_elite):
		FxLayer.burst(global_position, color, 30 if is_elite else 8, 220.0 if is_elite else 150.0)''')
replace('scripts/gods/loki.gd','''	if _breath_flash > 0.0:
		var cone := PackedVector2Array([p])''','''	if _breath_flash > 0.0:
		var fade := minf(1.0, _breath_flash / 0.15)
		if CombatFx.draw(self, "loki_wolf_breath", 0.4 - _breath_flash, p, _breath_dir.angle(), Vector2.ONE * BREATH_LENGTH / 88.0, Color(1, 1, 1, fade), BREATH_LENGTH, 0.45):
			return
		var cone := PackedVector2Array([p])''')
(ROOT/'assets/source/taskJ1_dimension_2026-10-19/integration_2026-10-19/changes.json').write_text(json.dumps(changes,ensure_ascii=False,indent=2)+'\n')
print('Targeted J changes written in',len(changes),'existing scripts, plus CombatFx.')
