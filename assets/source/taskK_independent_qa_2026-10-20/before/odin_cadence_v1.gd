extends GodPower
## 奥丁·符文飞弹：向最近的敌人发射符文，命中叠符文印记，叠到 3 层时引爆
## 强化：符文增殖（数量）、破甲符文（穿透）、符文共鸣（引爆波及）、回旋符文（折返、分裂）
## 质变：冈格尼尔（贯穿长枪）、渡鸦（俯冲叠印记）、九夜符文（符文阵）
## 素材：effects/rune_missile.png（现有）；可选 effects/gods/odin_spear.png 长枪（64×16，枪尖朝右），
##       odin_raven.png 渡鸦（2 帧 24×24，头朝右），odin_rune_circle.png 符文阵（96×96）

const RANGE := 600.0
const MISSILE := preload("res://assets/sprites/effects/rune_missile.png")
const BASE_DAMAGE := 12.0
const BASE_COOLDOWN := 0.8
const MISSILE_SPEED := 520.0
const RUNE_DETONATE := 3
const DETONATE_DAMAGE := 1.5
const SPEAR_EVERY := 2.5
const SPEAR_SPEED := 1400.0
const SPEAR_RANGE := 900.0
const SPEAR_BOUNCES := 3       # 觉醒·永不落空：连续贯穿几次
const RAVEN_EVERY := 1.2
const RAVEN_SPEED := 620.0
const RAVEN_ORBIT := 70.0
const CIRCLE_RADIUS := 45.0
const CIRCLE_LIFE := 3.0
const NIGHT_HIT_EVERY := 1.0
const SUMMON_EVERY := 100      # 觉醒的神格被动：每击杀这么多个敌人召唤一位英灵

var _missiles: Array[Dictionary] = []  # 飞行中的符文和长枪
var _ravens: Array[Dictionary] = []    # 渡鸦：angle、target、pos、diving、hit
var _circles: Array[GodZone] = []
var _kills := 0
var _charm_tick := 0.0
var _night_hit_at := {}
var _night_spread_at := {}
var _night_membership := {}
var _night_frame := -1
var _night_revision := -1
var _night_circle_count := -1


func tick(delta: float) -> void:
	for history in [_night_hit_at, _night_spread_at]:
		if history.size() > 512:
			for enemy in history.keys():
				if not is_instance_valid(enemy) or _time - history[enemy] >= NIGHT_HIT_EVERY:
					history.erase(enemy)
	match path:
		"odin_gungnir":
			if _timer <= 0.0:
				var target := nearest_enemy(global_position, RANGE)
				if target:
					_timer = cooldown(SPEAR_EVERY)
					_throw_spears(global_position.direction_to(target.global_position))
		"odin_ravens":
			_tick_ravens(delta)
		_:
			_fire_missiles()
	_move_missiles(delta)
	_circles.assign(_circles.filter(func(c) -> bool: return is_instance_valid(c)))
	if has_fusion("blood_brothers"):
		_charm_tick -= delta
		if _charm_tick <= 0.0:
			_charm_tick = 1.0
			for node in enemies():
				if (node as Enemy).has_status("charm"):
					add_rune(node, 1)


func _fire_missiles() -> void:
	if _timer > 0.0:
		return
	var count := 1 + int(stat("odin_count"))
	var targets := enemies_in_radius(global_position, RANGE)
	if targets.is_empty():
		return
	targets.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
	_timer = cooldown(BASE_COOLDOWN)
	Audio.sfx("rune_bolt")
	for i in count:
		var target: Enemy = targets[i % targets.size()]
		_missiles.append(_missile(global_position, global_position.direction_to(target.global_position), MISSILE_SPEED, RANGE, 1 + int(stat("odin_pierce")), false))


func _missile(from: Vector2, dir: Vector2, speed: float, reach: float, pierce: int, spear: bool) -> Dictionary:
	return {"pos": from, "dir": dir, "speed": speed, "reach": reach, "flown": 0.0, "pierce": pierce, "hit": {},
		"back": false, "spear": spear, "bounces": 0}


func _throw_spears(dir: Vector2) -> void:
	Audio.sfx_or("spear_throw", "rune_bolt", 2.0)
	var count := 1 + int(stat("odin_count"))
	for i in count:
		_missiles.append(_missile(global_position, dir.rotated((i - (count - 1) * 0.5) * 0.2), SPEAR_SPEED, SPEAR_RANGE, 9999, true))


func _move_missiles(delta: float) -> void:
	for m in _missiles:
		var step: float = m.speed * delta
		var from: Vector2 = m.pos
		m.pos += m.dir * step
		m.flown += step
		var width: float = (14.0 + 6.0 * stat("odin_pierce")) if m.spear else 10.0
		for enemy in enemies_on_line(from, m.pos, width):
			if m.hit.has(enemy) or m.pierce <= 0:
				continue
			m.hit[enemy] = true
			m.pierce -= 1
			enemy.take_damage(damage(BASE_DAMAGE) * (2.0 if m.spear else 1.0), m.dir * 120.0)
			add_rune(enemy, RUNE_DETONATE if m.spear else 1)
		if m.pierce <= 0 or m.flown >= m.reach:
			_missile_end(m)
	_missiles = _missiles.filter(func(m: Dictionary) -> bool: return not m.get("done", false))


## 符文飞到尽头（或穿透用完）：折返、分裂、转向下一个敌人，或者变成符文阵
func _missile_end(m: Dictionary) -> void:
	if m.spear and awakened and m.bounces < SPEAR_BOUNCES:
		var next := nearest_enemy(m.pos, RANGE, m.hit.keys())
		if next:
			m.bounces += 1
			m.dir = m.pos.direction_to(next.global_position)
			m.flown = 0.0
			m.reach = m.pos.distance_to(next.global_position) + 120.0
			m.hit = {}
			return
	if not m.back and stat("odin_return") > 0.0 and m.flown >= m.reach:
		m.back = true
		m.dir = -m.dir
		m.flown = 0.0
		m.hit = {}
		m.pierce = 9999 if m.spear else 1 + int(stat("odin_pierce"))
		if not m.spear and randf() < stat("odin_return") / 100.0:
			var twin := m.duplicate()
			twin.dir = m.dir.rotated(0.3)
			twin.hit = {}
			m.dir = m.dir.rotated(-0.3)
			_missiles.append(twin)
		return
	m.done = true
	if path == "odin_nights":
		_rune_circle(m.pos)


## 叠 n 层符文印记，叠满引爆
func add_rune(enemy: Enemy, n: int) -> void:
	if not is_instance_valid(enemy) or enemy._dead:
		return
	if has_fusion("baldr_dream"):
		enemy.add_status("light", 3.0)
	if has_fusion("blood_brothers"):
		enemy.burn(damage(BASE_DAMAGE) * 0.5, 2.0)
	if enemy.add_stacks("rune", n, 6.0) >= RUNE_DETONATE:
		detonate(enemy)


## 引爆印记：额外伤害；符文共鸣波及周围
func detonate(enemy: Enemy, _forced: bool = false) -> void:
	if not is_instance_valid(enemy) or enemy._dead:
		return
	var at := enemy.global_position
	enemy.clear_stacks("rune")
	enemy.take_damage(damage(BASE_DAMAGE) * DETONATE_DAMAGE)
	Audio.sfx_or("rune_detonate", "", -6.0)
	FxLayer.burst(at, Color(0.8, 0.6, 1.0), 12, 160.0, 3.0)
	var reach := stat("odin_resonance")
	if reach > 0.0:
		FxLayer.ring(at, reach)
		for other in enemies_in_radius(at, reach):
			if other != enemy:
				other.take_damage(damage(BASE_DAMAGE) * 0.6)
				other.add_stacks("rune", 1, 6.0)
	if path == "odin_nights" and awakened:  # 世界树之秘：所有符文阵里的敌人叠 1 层
		_update_night_membership()
		for other in _night_membership:
			if is_instance_valid(other) and not other._dead and _time - _night_spread_at.get(other, -INF) >= NIGHT_HIT_EVERY:
				_night_spread_at[other] = _time
				other.add_stacks("rune", 1, 6.0)


func _update_night_membership() -> void:
	var frame := Engine.get_process_frames()
	if _night_frame == frame and _night_revision == Enemy.spatial_revision and _night_circle_count == _circles.size():
		return
	_night_membership.clear()
	for circle in _circles:
		if is_instance_valid(circle):
			for other in circle.enemies_inside():
				_night_membership[other] = true
	_night_frame = frame
	_night_revision = Enemy.spatial_revision
	_night_circle_count = _circles.size()


# ———— 质变：九夜符文 ————

func _rune_circle(at: Vector2, can_repeat: bool = true) -> void:
	var radius := CIRCLE_RADIUS * (1.0 + 0.15 * stat("odin_pierce")) * (1.4 if awakened else 1.0)
	var life := CIRCLE_LIFE * (1.6 if awakened else 1.0)
	var mark := func(enemy: Enemy) -> void:
		if _time - _night_hit_at.get(enemy, -INF) < NIGHT_HIT_EVERY:
			return
		_night_hit_at[enemy] = _time
		enemy.take_damage(damage(BASE_DAMAGE) * 0.5)
		add_rune(enemy, 1)
	var circle := zone(at, radius, life, 1.0, mark, Color(0.75, 0.55, 1.0))
	circle.texture = art("odin_rune_circle")
	_circles.append(circle)
	if can_repeat and randf() < stat("odin_return") / 100.0:  # 再生出来的符文阵不会再生，不然几率叠满后会越积越多
		get_tree().create_timer(life, false).timeout.connect(func() -> void:
			if is_instance_valid(self):
				_rune_circle(at, false))


# ———— 质变：渡鸦 ————

func _tick_ravens(delta: float) -> void:
	var want := 2 + int(stat("odin_count")) + (2 if awakened else 0)
	while _ravens.size() < want:
		_ravens.append({"angle": randf() * TAU, "pos": global_position, "diving": false, "target": null, "hit": {}})
	var reach := 16.0 + 6.0 * stat("odin_pierce")
	for r in _ravens:
		r.angle += delta * 2.5
		if not r.diving:
			r.pos = r.pos.lerp(global_position + Vector2.from_angle(r.angle) * RAVEN_ORBIT, minf(1.0, delta * 8.0))
			continue
		var target: Enemy = r.target if is_instance_valid(r.target) else null
		if target == null or target._dead:
			r.diving = false
			continue
		var from: Vector2 = r.pos
		r.pos = r.pos.move_toward(target.global_position, RAVEN_SPEED * delta)
		if stat("odin_pierce") > 0.0:
			for enemy in enemies_on_line(from, r.pos, reach):
				if enemy != target and not r.hit.has(enemy):
					r.hit[enemy] = true
					enemy.take_damage(damage(BASE_DAMAGE) * 0.5)
					add_rune(enemy, 1)
		if r.pos.distance_to(target.global_position) < target.radius + 6.0:
			target.set_meta("raven_hit", _time)
			target.take_damage(damage(BASE_DAMAGE) * 1.2)
			add_rune(target, 2)
			r.diving = randf() < stat("odin_return") / 100.0
			r.hit = {}
			if r.diving:
				r.target = _raven_target()
				r.diving = r.target != null
	if _timer <= 0.0:
		for r in _ravens:
			if not r.diving:
				r.target = _raven_target()
				if r.target:
					Audio.sfx_or("raven_dive", "", -6.0)
					r.diving = true
					_timer = cooldown(RAVEN_EVERY) / maxf(1.0, _ravens.size() * 0.5)
				break


## 渡鸦的目标：印记最多的敌人，一样多时挑最近的
func _raven_target() -> Enemy:
	var best: Enemy = null
	var best_score := -INF
	for enemy in enemies_in_radius(global_position, 450.0):
		var score := enemy.stack_count("rune") * 1000.0 - enemy.global_position.distance_to(global_position)
		if score > best_score:
			best_score = score
			best = enemy
	return best


func on_enemy_died(enemy: Enemy) -> void:
	if enemy is Boss:
		return
	if awakened:
		_kills += 1
		if _kills % SUMMON_EVERY == 0:
			summon_einherjar(20.0, 1.0)
		if path == "odin_ravens" and enemy.is_elite and _time - float(enemy.get_meta("raven_hit", -99.0)) < 1.0:
			summon_einherjar(15.0, 1.0)
	if has_fusion("valhalla") and enemy.is_elite:
		summon_einherjar(15.0, 1.0, Color(1.0, 0.9, 0.7))


func _draw() -> void:
	var spear := art("odin_spear")
	for m in _missiles:
		var p := to_local(m.pos)
		if m.spear:
			if spear:
				SpriteVisual.draw_frame(self, spear, 1, 0, p, Vector2(56, 8), m.dir.angle())
			else:
				draw_line(p - m.dir * 48.0, p, Color(0.85, 0.75, 1.0), 3.0)
				draw_line(p - m.dir * 10.0, p + m.dir * 6.0, Color(1, 1, 1), 4.0)
		else:
			SpriteVisual.draw_frame(self, MISSILE, 4, int(_time * 12.0), p, Vector2(21, 15), m.dir.angle())
	var raven := art("odin_raven")
	for r in _ravens:
		var p := to_local(r.pos)
		var facing := -1.0 if (r.diving and is_instance_valid(r.target) and r.target.global_position.x < r.pos.x) else 1.0
		if raven:
			SpriteVisual.draw_frame(self, raven, 2, int(_time * 8.0), p, Vector2(12, 12), 0.0, Vector2(facing, 1.0))
		else:
			var flap := 4.0 * sin(_time * 14.0)
			draw_colored_polygon(PackedVector2Array([p + Vector2(8 * facing, 0), p + Vector2(-6 * facing, -6 - flap), p + Vector2(-3 * facing, 0), p + Vector2(-6 * facing, 6 + flap)]), Color(0.12, 0.1, 0.18))
