extends GodPower
## 弗蕾亚·女武神之羽：羽刃环绕身边切割敌人；被羽刃击中的敌人被「拣选」，死亡时可能掉下回复生命的金羽
## 强化：羽翼丰满（数量）、展翼（半径和转速）、金羽（掉落几率）、羽盾（挡子弹）
## 质变：鹰羽披风（羽刃射出再飞回）、布里辛嘉曼（金色光环）、战猫车（战猫扑击）
## 素材：effects/feather_blade.png（现有）；可选 effects/gods/freyja_cat.png 战猫（2 帧 24×24，头朝右），
##       freyja_chariot.png 猫车（96×48，朝右），freyja_ring.png 光环（128×128，中间透明）

const FEATHER := preload("res://assets/sprites/effects/feather_blade.png")
const ORBIT_RADIUS := 85.0
const SPIN := 3.0
const BASE_DAMAGE := 10.0
const HIT_SIZE := 10.0
const HIT_COOLDOWN := 0.5
const CHOSEN_TIME := 4.0
const FEATHER_CHANCE := 0.02
const HAWK_EVERY := 2.0
const HAWK_REACH := 2.6        # 鹰羽披风：射出去的距离 = 环绕半径 × 这个
const HAWK_TIME := 1.0         # 一次往返的时间
const RING_TICK := 0.4
const RING_SLOW := 0.3
const CAT_POUNCE_EVERY := 0.8
const CAT_POUNCE_TIME := 0.15
const CHARIOT_EVERY := 15.0
const CHARIOT_TIME := 0.8
const CHARIOT_WIDTH := 50.0
const TEAR_HEAL := 0.15
const SORTIE_EVERY := 3.0      # 融合技「华纳双子」：每隔多久一片羽刃离身追击

var _angle := 0.0
var _last_hit := {}            # 敌人 -> 上次被羽刃打到的时间
var _hawk_phase := -1.0        # 鹰羽披风：0 → 1 往返中，-1 = 在身边
var _hawk_split := {}          # 觉醒·弗尔克范格：这一轮已经分裂过的羽刃序号
var _ring_tick := 0.0
var _cats: Array[Dictionary] = []
var _chariot := -1.0           # 猫车冲锋进度 0 → 1，-1 = 没在冲
var _chariot_from := Vector2.ZERO
var _chariot_hit := {}
var _sortie := {}              # 华纳双子：离身追击的羽刃 pos、target、back
var _sortie_timer := SORTIE_EVERY


func count() -> int:
	return 2 + int(stat("freyja_count"))


func orbit_radius() -> float:
	return ORBIT_RADIUS * (1.0 + stat("freyja_wings") / 100.0)


func awaken() -> void:
	super.awaken()
	player.revives += 1  # 神格被动：战死者的一半归弗尔克范格


func tick(delta: float) -> void:
	_angle = fmod(_angle + SPIN * (1.0 + stat("freyja_wings") / 100.0) * delta, TAU)
	match path:
		"freyja_hawk":
			_tick_hawk(delta)
		"freyja_brisingamen":
			_tick_ring(delta)
		"freyja_cats":
			_tick_cats(delta)
		_:
			for i in count():
				_cut_at(global_position + blade_offset(i), 1.0)
			_block_shots(_blade_points(), HIT_SIZE + 8.0)
	if has_fusion("vanir_twins"):
		_tick_sortie(delta)
	if _last_hit.size() > 300:
		for enemy in _last_hit.keys():
			if not is_instance_valid(enemy) or _time - _last_hit[enemy] > HIT_COOLDOWN:
				_last_hit.erase(enemy)


func blade_offset(i: int) -> Vector2:
	return Vector2.from_angle(_angle + TAU * i / count()) * orbit_radius()


func _blade_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	var flying := path == "freyja_hawk" and _hawk_phase >= 0.0
	for i in count():
		points.append(global_position + (_hawk_offset(i) if flying else blade_offset(i)))
	return points


## 在 pos 处切割碰到的敌人（同一个敌人有冷却），返回切到的敌人
func _cut_at(pos: Vector2, mult: float, cd: float = HIT_COOLDOWN) -> Array[Enemy]:
	var cut: Array[Enemy] = []
	for enemy in enemies_in_radius(pos, HIT_SIZE):
		if _time - _last_hit.get(enemy, -INF) < cd:
			continue
		_last_hit[enemy] = _time
		enemy.take_damage(damage(BASE_DAMAGE) * mult, (enemy.global_position - global_position).normalized() * 120.0)
		choose(enemy)
		cut.append(enemy)
	if not cut.is_empty():
		Audio.sfx("feather_hit", -6.0)
	return cut


func choose(enemy: Enemy) -> void:
	enemy.add_status("chosen", CHOSEN_TIME)


## 羽盾：羽刃附近飞来的子弹有几率被挡下（每颗子弹只判定一次）
func _block_shots(points: Array[Vector2], reach: float) -> void:
	var chance := stat("freyja_aegis") / 100.0
	if chance <= 0.0:
		return
	for node in get_tree().get_nodes_in_group("enemy_projectiles"):
		var shot := node as Node2D
		if shot.has_meta("aegis"):
			continue
		for p in points:
			if p.distance_to(shot.global_position) < reach:
				shot.set_meta("aegis", true)
				if randf() < chance:
					FxLayer.burst(shot.global_position, Color(1.0, 0.85, 0.4), 6, 100.0, 2.5)
					shot.queue_free()
				break


func on_enemy_died(enemy: Enemy) -> void:
	if enemy.has_status("chosen") and randf() < FEATHER_CHANCE + stat("freyja_gold") / 100.0:
		drop_heal(enemy.global_position, 6.0 + player.max_hp * 0.03, "feather")


func on_player_hurt() -> void:
	if awakened and path == "freyja_brisingamen":
		drop_heal(global_position + Vector2.from_angle(randf() * TAU) * 50.0, player.max_hp * TEAR_HEAL, "tear")


# ———— 质变：鹰羽披风 ————

func _tick_hawk(delta: float) -> void:
	if _hawk_phase < 0.0:
		for i in count():
			_cut_at(global_position + blade_offset(i), 1.0)
		if _timer <= 0.0 and nearest_enemy(global_position, orbit_radius() * HAWK_REACH) != null:
			_timer = cooldown(HAWK_EVERY)
			_hawk_phase = 0.0
			_hawk_split = {}
			Audio.sfx_or("feather_launch", "feather_hit")
		return
	_hawk_phase += delta / HAWK_TIME
	if _hawk_phase >= 1.0:
		_hawk_phase = -1.0
		return
	var points := _blade_points()
	for i in points.size():
		var cut := _cut_at(points[i], 1.0, 0.25)
		if awakened and not cut.is_empty() and not _hawk_split.has(i):
			_hawk_split[i] = true
			var dir := global_position.direction_to(points[i])
			for k in 3:
				shoot(points[i], dir.rotated((k - 1) * 0.5), 520.0, damage(BASE_DAMAGE) * 0.5, 1, FEATHER, 1, Vector2(8, 8), choose_hit, 0.5)
	_block_shots(points, HIT_SIZE + 8.0)


func choose_hit(enemy: Enemy, _bolt: Projectile) -> void:
	choose(enemy)


## 鹰羽披风射出去时的位置（覆盖 blade_offset）
func _hawk_offset(i: int) -> Vector2:
	var dir := Vector2.from_angle(_angle * 0.3 + TAU * i / count())
	var reach := orbit_radius() * lerpf(1.0, HAWK_REACH, sin(_hawk_phase * PI))
	return dir * reach


# ———— 质变：布里辛嘉曼 ————

func ring_width() -> float:
	return 12.0 + 6.0 * count()


func _tick_ring(delta: float) -> void:
	_ring_tick -= delta
	var r := orbit_radius()
	var half := ring_width() * 0.5
	if _ring_tick <= 0.0:
		_ring_tick = RING_TICK
		var healed := 0
		for node in enemies():
			var enemy := node as Enemy
			var d := enemy.global_position.distance_to(global_position)
			if absf(d - r) > half + enemy.radius:
				continue
			enemy.take_damage(damage(BASE_DAMAGE) * 0.8)
			enemy.apply_slow(RING_SLOW, 0.5)
			choose(enemy)
			if healed < 4:
				healed += 1
				player.heal(0.25)
	var chance := stat("freyja_aegis") / 100.0
	if chance > 0.0:
		for node in get_tree().get_nodes_in_group("enemy_projectiles"):
			var shot := node as Node2D
			if not shot.has_meta("aegis") and absf(shot.global_position.distance_to(global_position) - r) < half:
				shot.set_meta("aegis", true)
				if randf() < chance:
					FxLayer.burst(shot.global_position, Color(1.0, 0.85, 0.4), 6, 100.0, 2.5)
					shot.queue_free()


# ———— 质变：战猫车 ————

func _tick_cats(delta: float) -> void:
	while _cats.size() < count():
		_cats.append({"pos": global_position, "target": null, "t": -1.0, "cd": randf() * CAT_POUNCE_EVERY, "from": Vector2.ZERO})
	var patrol := orbit_radius() * 0.9
	var cat_points: Array[Vector2] = []
	for i in _cats.size():
		var cat: Dictionary = _cats[i]
		cat.cd -= delta
		if cat.t >= 0.0:
			cat.t += delta / CAT_POUNCE_TIME
			var target: Enemy = cat.target if is_instance_valid(cat.target) else null
			if target:
				cat.pos = cat.from.lerp(target.global_position, minf(1.0, cat.t))
			if cat.t >= 1.0:
				cat.t = -1.0
				if target and not target._dead:
					target.take_damage(damage(BASE_DAMAGE) * 1.6, cat.from.direction_to(target.global_position) * 160.0)
					choose(target)
					FxLayer.mark(target.global_position, randf() * TAU, target.radius * 2.0 + 10.0, Color(1.0, 0.85, 0.4), "claw")
		else:
			var home := global_position + Vector2.from_angle(_angle * 0.4 + TAU * i / _cats.size()) * patrol
			cat.pos = cat.pos.move_toward(home, 320.0 * delta)
			if cat.cd <= 0.0:
				var prey := nearest_enemy(cat.pos, patrol + 80.0)
				if prey:
					cat.cd = cooldown(CAT_POUNCE_EVERY)
					cat.target = prey
					cat.from = cat.pos
					cat.t = 0.0
					Audio.sfx_or("cat_pounce", "feather_hit", -4.0)
		cat_points.append(cat.pos)
	_block_shots(cat_points, 18.0)
	if awakened:
		_tick_chariot(delta)


func _tick_chariot(delta: float) -> void:
	if _chariot < 0.0:
		if _timer <= 0.0:
			_timer = cooldown(CHARIOT_EVERY)
			_chariot = 0.0
			_chariot_from = global_position + Vector2(-700.0, 0.0)
			_chariot_hit = {}
			Audio.sfx_or("chariot_charge", "dash", 2.0)
		return
	_chariot += delta / CHARIOT_TIME
	var at := _chariot_from + Vector2(1400.0 * minf(1.0, _chariot), 0.0)
	for enemy in enemies_in_radius(at, CHARIOT_WIDTH):
		if not _chariot_hit.has(enemy):
			_chariot_hit[enemy] = true
			enemy.take_damage(damage(BASE_DAMAGE) * 4.0, Vector2(0, signf(enemy.global_position.y - at.y + 0.1)) * 500.0)
			choose(enemy)
	if _chariot >= 1.0:
		_chariot = -1.0


# ———— 融合技：华纳双子 ————

func _tick_sortie(delta: float) -> void:
	if _sortie.is_empty():
		_sortie_timer -= delta
		var prey := nearest_enemy(global_position, 400.0)
		if _sortie_timer <= 0.0 and prey:
			_sortie_timer = SORTIE_EVERY
			_sortie = {"pos": global_position, "target": prey, "back": false}
		return
	var target: Enemy = _sortie.target if is_instance_valid(_sortie.target) else null
	var goal: Vector2 = global_position if _sortie.back or target == null else target.global_position
	_sortie.pos = _sortie.pos.move_toward(goal, 600.0 * delta)
	if not _sortie.back and _sortie.pos.distance_to(goal) < 10.0:
		_sortie.back = true
		if target:
			target.take_damage(damage(BASE_DAMAGE) * 2.0)
			choose(target)
	elif _sortie.back and _sortie.pos.distance_to(global_position) < 12.0:
		_sortie = {}


func _draw() -> void:
	match path:
		"freyja_brisingamen":
			var ring := art("freyja_ring")
			var r := orbit_radius()
			if ring:
				draw_texture_rect(ring, Rect2(-Vector2.ONE * (r + ring_width() * 0.5), Vector2.ONE * (r + ring_width() * 0.5) * 2.0), false, Color(1, 1, 1, 0.8))
			else:
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1.0, 0.82, 0.35, 0.35), ring_width())
				draw_arc(Vector2.ZERO, r, _angle, _angle + 1.2, 16, Color(1.0, 0.95, 0.7, 0.5), ring_width() * 0.4)
		"freyja_cats":
			_draw_cats()
		_:
			for i in count():
				var p := _hawk_offset(i) if path == "freyja_hawk" and _hawk_phase >= 0.0 else blade_offset(i)
				SpriteVisual.draw_frame(self, FEATHER, 1, 0, p, Vector2(16, 16), p.angle() + PI / 2)
	if not _sortie.is_empty():
		var p := to_local(_sortie.pos)
		SpriteVisual.draw_frame(self, FEATHER, 1, 0, p, Vector2(16, 16), _time * 12.0, Vector2.ONE * 1.3)


func _draw_cats() -> void:
	var cat_art := art("freyja_cat")
	for cat in _cats:
		var p := to_local(cat.pos)
		var face := 1.0 if not is_instance_valid(cat.target) or cat.target.global_position.x >= cat.pos.x else -1.0
		if cat_art:
			SpriteVisual.draw_frame(self, cat_art, 2, int(_time * 8.0), p, Vector2(12, 18), 0.0, Vector2(face, 1.0))
		else:
			draw_circle(p, 7.0, Color(0.95, 0.8, 0.45))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -5), p + Vector2(-2, -11), p + Vector2(0, -5)]), Color(0.95, 0.8, 0.45))
			draw_colored_polygon(PackedVector2Array([p + Vector2(5, -5), p + Vector2(2, -11), p + Vector2(0, -5)]), Color(0.95, 0.8, 0.45))
	if _chariot >= 0.0:
		var at := to_local(_chariot_from + Vector2(1400.0 * minf(1.0, _chariot), 0.0))
		var chariot := art("freyja_chariot")
		if chariot:
			SpriteVisual.draw_frame(self, chariot, 1, 0, at, Vector2(48, 32))
		else:
			draw_rect(Rect2(at - Vector2(30, 14), Vector2(60, 28)), Color(1.0, 0.85, 0.4, 0.9))
			draw_line(at - Vector2(140, 0), at - Vector2(30, 0), Color(1.0, 0.9, 0.6, 0.4), 18.0)
