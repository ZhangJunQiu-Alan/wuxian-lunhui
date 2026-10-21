extends GodPower
## 巴德尔·圣光：每 2.5 秒朝敌人最多的方向射出一道贯穿光束；被照到的敌人挂上光痕，带光痕的敌人死亡时爆出一圈光
## 强化：棱光（多射几道）、光辉（长度和宽度）、余晖（地上留光带）、折射（打中光痕敌人时分出小光束）
## 质变：光明之矛（飞过全屏的光矛）、白昼（绕身旋转的光柱）、万物之誓（命中攒护盾，满了伤害翻倍）
## 素材（可选）：effects/gods/baldr_beam.png 光束（64×16，沿光束方向拉伸），baldr_spear.png 光矛（64×16，矛尖朝右）

const BASE_DAMAGE := 22.0
const BASE_COOLDOWN := 2.5
const BEAM_LENGTH := 400.0
const BEAM_WIDTH := 24.0
const BEAM_SHOW := 0.25
const PRISM_SPREAD := 0.25
const LIGHT_TIME := 3.0
const LIGHT_BURST := 50.0
const REFRACT_LENGTH := 180.0
const SPEAR_SPEED := 1600.0
const SPEAR_RANGE := 1200.0
const SPEAR_DAMAGE := 2.5
const SPEAR_COOLDOWN := 1.5
const CROSS_LENGTH := 300.0
const PILLAR_SPIN := 1.2
const PILLAR_LENGTH := 0.6     # 白昼：光柱长度 = 光束长度 × 这个
const PILLAR_BURST := 3.0
const PILLAR_REST := 4.0
const PILLAR_MIN_REST := 1.5
const PILLAR_HIT := 0.25
const PILLAR_DAMAGE := 0.35
const WARD_MAX := 3
const IMMUNE_TIME := 3.0
const IMMUNE_COOLDOWN := 10.0
const FLASH_EVERY := 30.0      # 觉醒的神格被动：每隔多久全屏闪光

var _beams: Array[Dictionary] = []   # 正在显示的光束：a、b、width、life
var _spears: Array[Dictionary] = []
var _pillar_angle := 0.0
var _pillar_hit := {}
var _pillars_active := true
var _pillar_remaining := PILLAR_BURST
var _pillar_glows: Array[GodZone] = []
var _glow_timer := 0.0
var _flash := FLASH_EVERY
var _flash_show := 0.0
var _immune_ready := 0.0


func length() -> float:
	return BEAM_LENGTH * (1.0 + stat("baldr_radiance") / 100.0)


func width() -> float:
	return BEAM_WIDTH * (1.0 + stat("baldr_radiance") / 100.0)


func beams() -> int:
	return 1 + int(stat("baldr_prism"))


func tick(delta: float) -> void:
	match path:
		"baldr_daylight":
			_tick_pillars(delta)
		"baldr_spear":
			_move_spears(delta)
			if _timer <= 0.0:
				var dir := _aim()
				if dir.is_finite():
					_timer = cooldown(BASE_COOLDOWN * SPEAR_COOLDOWN)
					for i in beams():
						_spears.append({"pos": global_position, "dir": dir.rotated((i - (beams() - 1) * 0.5) * PRISM_SPREAD), "flown": 0.0, "hit": {}, "crossed": false, "from": global_position})
					Audio.sfx_or("light_spear", "rune_bolt", 2.0)
		_:
			if _timer <= 0.0:
				var dir := _aim()
				if dir.is_finite():
					_timer = cooldown(BASE_COOLDOWN)
					var mult := 2.0 if path == "baldr_oath" and player.ward >= WARD_MAX else 1.0
					if player.immune_time > 0.0 and path == "baldr_oath":
						mult *= 2.0
					for i in beams():
						var d := dir.rotated((i - (beams() - 1) * 0.5) * PRISM_SPREAD)
						fire_beam(global_position, global_position + d * length(), width(), mult, true)
					Audio.sfx_or("light_beam", "rune_bolt", -2.0)
	for beam in _beams:
		beam.life -= delta
	_beams = _beams.filter(func(b: Dictionary) -> bool: return b.life > 0.0)
	_immune_ready -= delta
	if awakened:
		_flash -= delta
		_flash_show = maxf(0.0, _flash_show - delta)
		if _flash <= 0.0:
			_flash = FLASH_EVERY
			_flash_show = 0.5
			Audio.sfx_or("light_flash", "level_up")
			for enemy in enemies_in_radius(global_position, 900.0):
				enemy.add_status("light", LIGHT_TIME)


## 朝敌人最多的方向；附近没有敌人返回 INF
func _aim() -> Vector2:
	var dir := densest_direction(global_position, length(), width())
	if not dir.is_finite():
		var target := nearest_enemy(global_position, length())
		if target:
			dir = global_position.direction_to(target.global_position)
	return dir


## 射一道光束，返回照到的敌人。main 为 false 时是折射出来的小光束（不再折射）
func fire_beam(a: Vector2, b: Vector2, beam_width: float, mult: float, main: bool) -> Array[Enemy]:
	var hit := enemies_on_line(a, b, beam_width)
	for enemy in hit:
		var lit := enemy.has_status("light")
		enemy.take_damage(damage(BASE_DAMAGE) * mult * (1.0 if main else 0.5) * enemy.area_mult())
		_after_hit(enemy)
		if main and lit and randf() < stat("baldr_refract") / 100.0:
			var other := nearest_enemy(enemy.global_position, REFRACT_LENGTH, [enemy])
			if other:
				var dir := enemy.global_position.direction_to(other.global_position)
				fire_beam(enemy.global_position, enemy.global_position + dir * REFRACT_LENGTH, beam_width * 0.5, mult, false)
	_beams.append({"a": a, "b": b, "width": beam_width, "life": BEAM_SHOW})
	if main and stat("baldr_afterglow") > 0.0:
		_afterglow(a, b, beam_width)
	return hit


func _after_hit(enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or enemy._dead:
		return
	enemy.add_status("light", LIGHT_TIME)
	if has_fusion("baldr_dream") and enemy.stack_count("rune") > 0 and player.gods.has("odin"):
		player.gods["odin"].detonate(enemy)
	if has_fusion("mistletoe") and player.gods.has("loki"):
		player.gods["loki"].ignite(enemy)
	if path == "baldr_oath" and player.ward < WARD_MAX:
		player.ward += 1
		if player.ward >= WARD_MAX and awakened and _immune_ready <= 0.0:
			_immune_ready = IMMUNE_COOLDOWN
			player.immune_time = IMMUNE_TIME
			FxLayer.burst(global_position, Color(1.0, 0.95, 0.7), 30, 220.0, 4.0)


func _afterglow(a: Vector2, b: Vector2, beam_width: float) -> GodZone:
	var glow := func(enemy: Enemy) -> void:
		enemy.take_damage(damage(BASE_DAMAGE) * 0.3)
		enemy.add_status("light", LIGHT_TIME)
	var strip := line_zone(a, b, beam_width, stat("baldr_afterglow"), 0.5, glow, Color(1.0, 0.92, 0.6))
	strip.texture = art("baldr_glow")
	return strip


func on_enemy_died(enemy: Enemy) -> void:
	if not enemy.has_status("light"):
		return
	_light_burst.call_deferred(enemy.global_position)  # 延迟一帧：连锁爆开时不会一次递归太深
	if has_fusion("mistletoe") and enemy.has_status("burn"):
		var target := nearest_enemy(enemy.global_position, 500.0, [enemy])
		if target:
			shoot(enemy.global_position, enemy.global_position.direction_to(target.global_position), 900.0, damage(BASE_DAMAGE) * 2.0, 9999, null, 1, Vector2.ZERO, Callable(), 1.2)


func _light_burst(at: Vector2) -> void:
	Enemy.damage_in_radius(get_tree(), at, LIGHT_BURST, damage(BASE_DAMAGE) * 0.5)
	Audio.sfx_or("light_burst", "", -10.0)
	FxLayer.burst(at, Color(1.0, 0.95, 0.7), 10, 140.0, 3.0)


# ———— 质变：光明之矛 ————

func _move_spears(delta: float) -> void:
	for s in _spears:
		var step := SPEAR_SPEED * delta
		var from: Vector2 = s.pos
		s.pos += s.dir * step
		s.flown += step
		for enemy in enemies_on_line(from, s.pos, width() * 0.6):
			if s.hit.has(enemy):
				continue
			s.hit[enemy] = true
			enemy.take_damage(damage(BASE_DAMAGE) * SPEAR_DAMAGE)
			_after_hit(enemy)
			if awakened and not s.crossed:  # 神之光矛：十字光
				s.crossed = true
				var at := enemy.global_position
				for d in [s.dir, s.dir.orthogonal()]:
					fire_beam(at - d * CROSS_LENGTH, at + d * CROSS_LENGTH, width(), 1.5, false)
		if s.flown >= SPEAR_RANGE:
			s.done = true
			if stat("baldr_afterglow") > 0.0:
				_afterglow(s.from, s.pos, width() * 0.6)
	_spears = _spears.filter(func(s: Dictionary) -> bool: return not s.get("done", false))


# ———— 质变：白昼 ————

func pillars() -> int:
	return beams() + (2 if awakened else 0)


func _tick_pillars(delta: float) -> void:
	_pillar_angle = fmod(_pillar_angle + PILLAR_SPIN * delta, TAU)
	_pillar_remaining -= delta
	while _pillar_remaining <= 0.0:
		_pillars_active = not _pillars_active
		if _pillars_active:
			_pillar_remaining += PILLAR_BURST
			Audio.sfx_or("light_beam", "rune_bolt", -5.0)
		else:
			_pillar_remaining += maxf(PILLAR_MIN_REST, cooldown(PILLAR_REST))
			for glow in _pillar_glows:
				if is_instance_valid(glow):
					glow.on_tick = Callable()
					glow.set_process(false)
					glow.queue_free()
			_pillar_glows.clear()
			_pillar_hit.clear()
			_glow_timer = 0.0
	if not _pillars_active:
		return
	_pillar_glows.assign(_pillar_glows.filter(func(glow): return is_instance_valid(glow) and not glow.is_queued_for_deletion()))
	var reach := length() * PILLAR_LENGTH
	_glow_timer -= delta
	var leave_glow := _glow_timer <= 0.0 and stat("baldr_afterglow") > 0.0
	if leave_glow:
		_glow_timer = 0.3
	for i in pillars():
		var tip := global_position + Vector2.from_angle(_pillar_angle + TAU * i / pillars()) * reach
		for enemy in enemies_on_line(global_position, tip, width()):
			if _time - _pillar_hit.get(enemy, -INF) < PILLAR_HIT:
				continue
			_pillar_hit[enemy] = _time
			enemy.take_damage(damage(BASE_DAMAGE) * PILLAR_DAMAGE * enemy.area_mult())
			_after_hit(enemy)
		if leave_glow:
			_pillar_glows.append(_afterglow(global_position.lerp(tip, 0.4), tip, width() * 0.7))
	if _pillar_hit.size() > 300:
		for enemy in _pillar_hit.keys():
			if not is_instance_valid(enemy):
				_pillar_hit.erase(enemy)


func _draw() -> void:
	for beam in _beams:
		_draw_beam(to_local(beam.a), to_local(beam.b), beam.width, beam.life / BEAM_SHOW)
	if path == "baldr_daylight" and _pillars_active:
		var reach := length() * PILLAR_LENGTH
		for i in pillars():
			var tip := Vector2.from_angle(_pillar_angle + TAU * i / pillars()) * reach
			_draw_beam(Vector2.ZERO, tip, width(), 0.75)
	var spear := art("baldr_spear")
	for s in _spears:
		var p := to_local(s.pos)
		if spear:
			SpriteVisual.draw_frame(self, spear, 1, 0, p, Vector2(56, 8), s.dir.angle())
		else:
			_draw_beam(p - s.dir * 60.0, p, width() * 0.6, 1.0)
	if path == "baldr_oath":
		for i in player.ward:
			draw_arc(Vector2.ZERO, 22.0 + i * 5.0, 0.0, TAU, 32, Color(1.0, 0.92, 0.6, 0.6), 2.0)
	if player.immune_time > 0.0:
		draw_circle(Vector2.ZERO, 30.0, Color(1.0, 0.95, 0.7, 0.2 + 0.1 * sin(_time * 12.0)))
	if _flash_show > 0.0:
		draw_circle(Vector2.ZERO, 900.0 * (1.0 - _flash_show / 0.5), Color(1.0, 0.97, 0.85, _flash_show * 0.5))


func _draw_beam(a: Vector2, b: Vector2, beam_width: float, alpha: float) -> void:
	var tex := art("baldr_beam")
	if tex:
		draw_set_transform(a, (b - a).angle())
		draw_texture_rect(tex, Rect2(0, -beam_width * 0.5, a.distance_to(b), beam_width), false, Color(1, 1, 1, alpha))
		draw_set_transform(Vector2.ZERO)
		return
	draw_line(a, b, Color(1.0, 0.9, 0.55, 0.35 * alpha), beam_width)
	draw_line(a, b, Color(1.0, 0.97, 0.85, 0.8 * alpha), beam_width * 0.35)
