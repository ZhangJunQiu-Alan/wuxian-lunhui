extends GodPower
## 弗雷·自战之剑：飞剑自动追砍敌人，砍完一个飞向下一个；被它杀死的敌人掉落的经验 +50%，偶尔掉下苹果
## 强化：双生剑（数量）、剑之舞（速度）、丰饶（经验）、苹果（掉落几率）
## 质变：古林博斯帝（金鬃野猪冲锋）、丰收之地（麦田回血减速）、阳光之剑（飞过的地方留下灼热光痕）
## 素材（可选）：effects/gods/freyr_sword.png 飞剑（32×12，剑尖朝右），freyr_boar.png 野猪（2 帧 40×28，头朝右），
##       freyr_field.png 麦田（128×128）

const BASE_DAMAGE := 14.0
const SWORD_SPEED := 520.0
const SEEK := 500.0
const HIT_COOLDOWN := 0.3
const HARVEST_XP := 0.5
const APPLE_CHANCE := 0.02
const BOAR_EVERY := 4.0
const BOAR_SPEED := 700.0
const BOAR_RANGE := 450.0
const BOAR_WIDTH := 36.0
const STAMPEDE_EVERY := 15.0
const FIELD_HITS := 10
const FIELD_RADIUS := 90.0
const FIELD_LIFE := 8.0
const FIELD_HEAL := 0.02       # 站在麦田里每秒回复最大生命的 2%
const TRAIL_EVERY := 0.08
const TRAIL_LIFE := 1.5
const REGROWTH_EVERY := 60.0   # 觉醒的神格被动：每分钟回复 15% 生命

var _swords: Array[Dictionary] = []
var _hit := {}
var _boars: Array[Dictionary] = []
var _stampede := STAMPEDE_EVERY
var _field_hits := 0
var _fields: Array[GodZone] = []
var _apple_timer := 3.0
var _regrowth := REGROWTH_EVERY


func swords() -> int:
	return 1 + int(stat("freyr_twin")) + (2 if awakened and path == "freyr_sun" else 0)


func speed_mult() -> float:
	return 1.0 + stat("freyr_dance") / 100.0


func tick(delta: float) -> void:
	if path == "freyr_boar":
		_tick_boars(delta)
	else:
		_tick_swords(delta)
	if path == "freyr_field":
		_tick_fields(delta)
	if awakened:
		_regrowth -= delta
		if _regrowth <= 0.0:
			_regrowth = REGROWTH_EVERY
			player.heal(player.max_hp * 0.15)
			FxLayer.burst(global_position, Color(0.6, 1.0, 0.5), 20, 160.0, 3.0)


# ———— 飞剑 ————

func _tick_swords(delta: float) -> void:
	while _swords.size() < swords():
		_swords.append({"pos": global_position, "target": null, "dir": Vector2.RIGHT, "trail": 0.0, "last": global_position})
	var taken: Array = []
	for s in _swords:
		var target: Enemy = s.target if is_instance_valid(s.target) else null
		if target == null or target._dead or target.global_position.distance_to(global_position) > SEEK:
			target = nearest_enemy(global_position, SEEK, taken)
			s.target = target
		var goal: Vector2 = target.global_position if target else global_position + Vector2(0, -36)
		if target:
			taken.append(target)
		var to: Vector2 = goal - s.pos
		if to.length() > 1.0:
			s.dir = s.dir.lerp(to.normalized(), minf(1.0, delta * 10.0)).normalized()
		s.pos += s.dir * minf(to.length(), SWORD_SPEED * speed_mult() * delta)
		if target and s.pos.distance_to(target.global_position) < target.radius + 8.0 and _time - _hit.get(target, -INF) > HIT_COOLDOWN:
			_hit[target] = _time
			strike(target, 1.0, s.dir * 100.0)
			s.target = null
		if path == "freyr_sun" and target:  # 只在追砍时留下光痕，回到身边待命时不留
			s.trail -= delta
			if s.trail <= 0.0:
				s.trail = TRAIL_EVERY
				_sun_trail(s.last, s.pos)
				s.last = s.pos
	if _hit.size() > 300:
		for enemy in _hit.keys():
			if not is_instance_valid(enemy):
				_hit.erase(enemy)


## 飞剑（或野猪）打中一个敌人；打死了就算丰收
func strike(enemy: Enemy, mult: float, knock: Vector2) -> void:
	if not is_instance_valid(enemy) or enemy._dead or enemy.is_queued_for_deletion():
		return
	var xp := enemy.xp_value
	var at := enemy.global_position
	enemy.take_damage(damage(BASE_DAMAGE) * mult, knock)
	FxLayer.mark(at, knock.angle(), enemy.radius * 2.0 + 12.0, Color(0.75, 1.0, 0.55))
	Audio.sfx_or("sword_hit", "feather_hit", -8.0)
	if has_fusion("vanir_twins"):
		enemy.add_status("chosen", 4.0)
	if path == "freyr_field":
		_field_hits += 1
		if _field_hits >= FIELD_HITS:
			_field_hits = 0
			_field(at, FIELD_RADIUS, FIELD_LIFE)
	if enemy._dead:
		harvest(at, xp)


func harvest(at: Vector2, xp: int) -> void:
	drop_xp(at, xp * (HARVEST_XP + stat("freyr_bounty") / 100.0))
	if randf() < APPLE_CHANCE + stat("freyr_apple") / 100.0:
		drop_heal(at, 8.0 + player.max_hp * 0.04, "apple")


func on_enemy_died(enemy: Enemy) -> void:
	if path == "freyr_field" and enemy.has_status("harvest") and not enemy is Boss:
		harvest(enemy.global_position, enemy.xp_value)


# ———— 质变：古林博斯帝 ————

func _tick_boars(delta: float) -> void:
	if _timer <= 0.0:
		var dir := densest_direction(global_position, BOAR_RANGE, BOAR_WIDTH * 2.0)
		if dir.is_finite():
			_timer = cooldown(BOAR_EVERY)
			var count := swords()
			for i in count:
				_charge(global_position, dir.rotated((i - (count - 1) * 0.5) * 0.35), BOAR_RANGE * speed_mult())
			Audio.sfx_or("boar_charge", "dash", -2.0)
	if awakened:
		_stampede -= delta
		if _stampede <= 0.0:
			_stampede = cooldown(STAMPEDE_EVERY)
			for i in 6:
				_charge(global_position + Vector2(-700.0, (i - 2.5) * 110.0), Vector2.RIGHT, 1400.0)
	for b in _boars:
		var step := BOAR_SPEED * speed_mult() * delta
		var from: Vector2 = b.pos
		b.pos += b.dir * step
		b.flown += step
		for enemy in enemies_on_line(from, b.pos, BOAR_WIDTH):
			if not b.hit.has(enemy):
				b.hit[enemy] = true
				var side: Vector2 = b.dir.orthogonal() * signf(b.dir.orthogonal().dot(enemy.global_position - b.pos) + 0.01)
				strike(enemy, 2.0, side * 400.0)
		if b.flown >= b.reach:
			b.done = true
	_boars = _boars.filter(func(b: Dictionary) -> bool: return not b.get("done", false))


func _charge(from: Vector2, dir: Vector2, reach: float) -> void:
	_boars.append({"pos": from, "dir": dir, "flown": 0.0, "reach": reach, "hit": {}})


# ———— 质变：丰收之地 ————

func _field(at: Vector2, radius: float, life: float) -> GodZone:
	var slow_down := func(enemy: Enemy) -> void:
		enemy.apply_slow(0.3, 0.6)
		enemy.add_status("harvest", 0.6)
	var field := zone(at, radius, life, 0.5, slow_down, Color(0.85, 0.8, 0.35))
	field.texture = art("freyr_field")
	_fields.append(field)
	return field


func _tick_fields(delta: float) -> void:
	_fields.assign(_fields.filter(func(f) -> bool: return is_instance_valid(f)))
	if awakened and not _fields.any(func(f: GodZone) -> bool: return f.follow == player):
		var spring := _field(global_position, FIELD_RADIUS * 1.2, INF)
		spring.follow = player
	for field in _fields:
		if field.contains(global_position):
			player.heal(player.max_hp * FIELD_HEAL * delta)
			break
	_apple_timer -= delta
	if _apple_timer <= 0.0:
		_apple_timer = 3.0
		for field in _fields:
			if randf() < 0.25 + stat("freyr_apple") / 100.0 * 4.0:
				drop_heal(field.global_position + Vector2.from_angle(randf() * TAU) * randf() * field.radius, 8.0 + player.max_hp * 0.04, "apple")


# ———— 质变：阳光之剑 ————

func _sun_trail(a: Vector2, b: Vector2) -> void:
	if a.distance_to(b) < 4.0:
		return
	var scorch := func(enemy: Enemy) -> void:
		enemy.burn(damage(BASE_DAMAGE) * 0.5, 2.0)
	line_zone(a, b, 16.0, TRAIL_LIFE * (2.0 if awakened else 1.0), 0.5, scorch, Color(1.0, 0.85, 0.35))


func _draw() -> void:
	var sword := art("freyr_sword")
	for s in _swords:
		var p := to_local(s.pos)
		if sword:
			SpriteVisual.draw_frame(self, sword, 1, 0, p, Vector2(16, 6), s.dir.angle())
		else:
			draw_line(p - s.dir * 12.0, p + s.dir * 10.0, Color(0.9, 1.0, 0.75), 3.0)
			draw_line(p - s.dir * 12.0, p - s.dir * 6.0, Color(0.7, 0.55, 0.25), 5.0)
		draw_circle(p, 9.0, Color(0.7, 1.0, 0.5, 0.18))
	var boar := art("freyr_boar")
	for b in _boars:
		var p := to_local(b.pos)
		var face := Vector2(-1.0 if b.dir.x < 0.0 else 1.0, 1.0)
		if boar:
			SpriteVisual.draw_frame(self, boar, 2, int(_time * 12.0), p, Vector2(20, 20), 0.0, face)
		else:
			draw_circle(p, 13.0, Color(0.95, 0.8, 0.3))
			draw_circle(p + b.dir * 12.0, 7.0, Color(1.0, 0.88, 0.45))
		draw_line(p - b.dir * 40.0, p - b.dir * 14.0, Color(1.0, 0.9, 0.5, 0.35), 10.0)
