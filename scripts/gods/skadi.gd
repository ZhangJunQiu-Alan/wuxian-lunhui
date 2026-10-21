extends GodPower
## 斯卡蒂·霜猎之箭：每 1.8 秒向最远的敌人射出穿透的冰箭，命中叠霜冻；霜冻叠到 5 层时冻结
## 强化：连珠（多射几支）、寒意（每箭多叠几层）、冰原（箭飞过的地面结冰）、碎冰（冻结的敌人死亡时爆出冰片）
## 质变：狩猎本能（狙击最强的敌人）、雪鞋（边跑边射）、永冬（身边的暴风雪）
## 素材：effects/ice_shard.png（现有，冰片）；可选 effects/gods/skadi_arrow.png 冰箭（32×8，箭头朝右），
##       skadi_blizzard.png 暴风雪（128×128，会旋转），skadi_ice.png 冰面（64×16，沿方向拉伸）

const SHARD := preload("res://assets/sprites/effects/ice_shard.png")
const BASE_DAMAGE := 16.0
const BASE_COOLDOWN := 1.8
const RANGE := 600.0
const ARROW_SPEED := 800.0
const ARROW_PIERCE := 3
const VOLLEY_SPREAD := 0.15
const SNIPE_DAMAGE := 3.0
const SNIPE_COOLDOWN := 1.5
const SNIPE_SPEED := 1400.0
const SNIPE_LENGTH := 1400.0
const STRIDE := 150.0          # 雪鞋：每走这么远射一箭
const BLIZZARD_RADIUS := 110.0
const BLIZZARD_TICK := 0.75
const BLIZZARD_DAMAGE := 0.15
const BLIZZARD_MIN_TICK := 0.45
const BLIZZARD_VISUAL_RADIUS := 128.0
const SKI_TIME := 3.0

var _arrows: Array[Dictionary] = []
var _prey: Enemy               # 狩猎本能标记的猎物
var _walked := 0.0
var _last_pos := Vector2.INF
var _ski := 0.0
var _blizzard_tick := 0.0
var _ice_timer := 0.0
var _winter_ice: Array[GodZone] = []
var _snipe_line := {}          # 觉醒·群山之女：贯穿全屏的一箭（画 0.3 秒）


func frost_per_hit() -> int:
	return 1 + int(stat("skadi_chill"))


func volley() -> int:
	return 1 + int(stat("skadi_volley"))


func awaken() -> void:
	super.awaken()
	player.slow_immune = true  # 神格被动：免疫减速


func tick(delta: float) -> void:
	match path:
		"skadi_hunter":
			_tick_hunter()
		"skadi_snowshoes":
			_tick_snowshoes(delta)
		"skadi_winter":
			_tick_blizzard(delta)
		_:
			if _timer <= 0.0:
				var target := farthest_enemy(global_position, RANGE)
				if target:
					_timer = cooldown(BASE_COOLDOWN)
					_volley(global_position.direction_to(target.global_position), volley())
	_move_arrows(delta)
	if _snipe_line:
		_snipe_line.life -= delta
		if _snipe_line.life <= 0.0:
			_snipe_line = {}


func _volley(dir: Vector2, count: int) -> void:
	Audio.sfx_or("ice_arrow", "arrow_shot", -4.0)
	for i in count:
		_arrows.append(_arrow(dir.rotated((i - (count - 1) * 0.5) * VOLLEY_SPREAD), ARROW_SPEED, ARROW_PIERCE, 1.0, frost_per_hit()))


func _arrow(dir: Vector2, speed: float, pierce: int, mult: float, frost: int) -> Dictionary:
	return {"pos": global_position, "from": global_position, "dir": dir, "speed": speed, "flown": 0.0, "pierce": pierce, "mult": mult, "frost": frost, "hit": {}}


func _move_arrows(delta: float) -> void:
	for a in _arrows:
		var step: float = a.speed * delta
		var from: Vector2 = a.pos
		a.pos += a.dir * step
		a.flown += step
		for enemy in enemies_on_line(from, a.pos, 8.0):
			if a.hit.has(enemy) or a.pierce <= 0:
				continue
			a.hit[enemy] = true
			a.pierce -= 1
			enemy.take_damage(damage(BASE_DAMAGE) * a.mult, a.dir * 80.0)
			enemy.add_frost(a.frost)
		if a.pierce <= 0 or a.flown >= RANGE * 1.2:
			a.done = true
			if stat("skadi_icefield") > 0.0:
				_ice(a.from, a.pos)
	_arrows = _arrows.filter(func(a: Dictionary) -> bool: return not a.get("done", false))


## 冰原：一条结冰的路，踩上去的敌人叠霜冻
func _ice(a: Vector2, b: Vector2) -> void:
	var chill := func(enemy: Enemy) -> void:
		enemy.add_frost(1)
	var ice := line_zone(a, b, 18.0, stat("skadi_icefield"), 0.5, chill, Color(0.75, 0.92, 1.0))
	ice.texture = art("skadi_ice")


## 碎冰：冻结的敌人死亡时爆出冰片
func on_enemy_died(enemy: Enemy) -> void:
	var shards := int(stat("skadi_shatter"))
	if shards <= 0 or not enemy.is_frozen():
		return
	var at := enemy.global_position
	Audio.sfx_or("ice_shatter", "ice_pillar", -6.0)
	var frost_hit := func(other: Enemy, _bolt: Projectile) -> void:
		other.add_frost(1)
	for i in shards:
		shoot(at, Vector2.from_angle(TAU * i / shards + randf() * 0.3), 420.0, damage(BASE_DAMAGE) * 0.5, 1, SHARD, 1, Vector2(16, 16), frost_hit, 0.45)


func on_dash() -> void:
	if awakened and path == "skadi_snowshoes":
		_ski = SKI_TIME


# ———— 质变：狩猎本能 ————

func _tick_hunter() -> void:
	if not is_instance_valid(_prey) or _prey._dead or _prey.global_position.distance_to(global_position) > 750.0:
		_prey = strongest_enemy(global_position, 700.0)
	if _timer > 0.0 or _prey == null:
		return
	_timer = cooldown(BASE_COOLDOWN * SNIPE_COOLDOWN)
	var dir := global_position.direction_to(_prey.global_position)
	Audio.sfx_or("ice_snipe", "arrow_shot", 2.0)
	if awakened:  # 群山之女：一箭贯穿整个屏幕
		var end := global_position + dir * SNIPE_LENGTH
		for enemy in enemies_on_line(global_position, end, 14.0):
			enemy.take_damage(damage(BASE_DAMAGE) * SNIPE_DAMAGE)
			enemy.add_frost(Enemy.FROST_FREEZE)
		_snipe_line = {"a": global_position, "b": end, "life": 0.3}
	else:
		_arrows.append(_arrow(dir, SNIPE_SPEED, 9999, SNIPE_DAMAGE, Enemy.FROST_FREEZE))
	if stat("skadi_volley") > 0.0:
		var near := nearest_enemy(global_position, RANGE)
		if near:
			_volley(global_position.direction_to(near.global_position), int(stat("skadi_volley")))


# ———— 质变：雪鞋 ————

func _tick_snowshoes(delta: float) -> void:
	_ski = maxf(0.0, _ski - delta)
	if _last_pos.is_finite():
		_walked += global_position.distance_to(_last_pos)
	_last_pos = global_position
	var stride := STRIDE * cooldown(1.0)
	if _walked < stride:
		return
	var target := farthest_enemy(global_position, RANGE)
	if target:
		while _walked >= stride:
			_walked -= stride
			_volley(global_position.direction_to(target.global_position), volley() * (2 if _ski > 0.0 else 1))
	else:
		_walked = minf(_walked, stride)


# ———— 质变：永冬 ————

func blizzard_radius() -> float:
	return 700.0 if awakened else BLIZZARD_RADIUS * (1.0 + 0.15 * stat("skadi_volley"))


func _tick_blizzard(delta: float) -> void:
	_blizzard_tick -= delta
	if _blizzard_tick <= 0.0:
		_blizzard_tick = maxf(BLIZZARD_MIN_TICK, BLIZZARD_TICK * cooldown(1.0))
		for enemy in enemies_in_radius(global_position, blizzard_radius()):
			enemy.take_damage(damage(BASE_DAMAGE) * BLIZZARD_DAMAGE)
			enemy.add_frost(1)
	if stat("skadi_icefield") > 0.0:
		_ice_timer -= delta
		if _ice_timer <= 0.0:
			_ice_timer = 0.4
			_winter_ice.assign(_winter_ice.filter(func(ice): return is_instance_valid(ice) and not ice.is_queued_for_deletion()))
			for ice in _winter_ice:
				if ice.global_position.distance_to(global_position) < 30.0:
					ice._age = 0.0
					return
			var chill := func(enemy: Enemy) -> void:
				enemy.add_frost(1)
			_winter_ice.append(zone(global_position, 30.0, stat("skadi_icefield"), 0.5, chill, Color(0.75, 0.92, 1.0)))


func _draw() -> void:
	var arrow := art("skadi_arrow")
	for a in _arrows:
		var p := to_local(a.pos)
		if arrow:
			SpriteVisual.draw_frame(self, arrow, 1, 0, p, Vector2(28, 4), a.dir.angle(), Vector2.ONE * (1.5 if a.mult > 1.0 else 1.0))
		else:
			draw_line(p - a.dir * 18.0, p, Color(0.8, 0.95, 1.0), 2.0 if a.mult <= 1.0 else 4.0)
			draw_circle(p, 2.5, Color(1, 1, 1))
	if is_instance_valid(_prey) and path == "skadi_hunter":
		var p := to_local(_prey.global_position)
		var r := _prey.radius + 10.0
		draw_arc(p, r, 0.0, TAU, 24, Color(0.75, 0.92, 1.0, 0.7), 1.5)
		for i in 4:
			var d := Vector2.from_angle(PI / 2 * i)
			draw_line(p + d * (r - 4.0), p + d * (r + 6.0), Color(0.75, 0.92, 1.0, 0.9), 2.0)
	if _snipe_line:
		draw_line(to_local(_snipe_line.a), to_local(_snipe_line.b), Color(0.85, 0.97, 1.0, _snipe_line.life / 0.3), 6.0)
	if path == "skadi_winter":
		var r := minf(blizzard_radius(), BLIZZARD_VISUAL_RADIUS)
		var tex := art("skadi_blizzard")
		if tex:
			draw_set_transform(Vector2.ZERO, _time * 0.8)
			draw_texture_rect(tex, Rect2(-Vector2.ONE * r, Vector2.ONE * r * 2.0), false, Color(1, 1, 1, 0.28))
			draw_set_transform(Vector2.ZERO)
		else:
			draw_circle(Vector2.ZERO, r, Color(0.8, 0.92, 1.0, 0.07))
			for i in 10:
				var angle := _time * 1.5 + TAU * i / 10.0
				var d := r * (0.4 + 0.55 * fmod(i * 0.37 + _time * 0.2, 1.0))
				draw_circle(Vector2.from_angle(angle) * d, 2.0, Color(1, 1, 1, 0.7))
