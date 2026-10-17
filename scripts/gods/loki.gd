extends GodPower
## 洛基·诡火：身边的火焰灼烧靠近的敌人，离开火焰后继续掉血
## 强化：野火蔓延（范围）、余烬（灼烧更久）、银舌（迷惑）、火种（死亡时点燃同伴）
## 质变：狼之父（火焰幼狼）、变形者（火焰分身吸引敌人）、纳吉尔法尔之路（走过的地方起火）
## 素材：effects/will_o_wisp_aura.png（现有）；可选 effects/gods/loki_wolf.png 幼狼（2 帧 32×32，头朝右），
##       loki_decoy.png 火焰分身（4 帧 32×48）、loki_fire_patch.png 火路（4 帧 32×32）

const AURA := preload("res://assets/sprites/effects/will_o_wisp_aura.png")
const AURA_ART_RADIUS := 60.0
const BASE_RADIUS := 80.0
const BASE_DAMAGE := 6.0
const TICK := 0.5
const BURN_TIME := 2.0
const BURN_RATIO := 0.8        # 灼烧每秒伤害 = 火焰伤害 × 这个
const CHARM_TIME := 3.0
const CHARM_BLAST := 70.0      # 觉醒的神格被动：迷惑的敌人死亡时爆炸
const WOLF_SPEED := 300.0
const WOLF_SEEK := 260.0
const WOLF_BITE_EVERY := 0.6
const WOLF_BITE_RADIUS := 40.0
const BREATH_EVERY := 10.0
const BREATH_LENGTH := 220.0
const DECOY_EVERY := 4.0
const DECOY_LIFE := 4.0
const DECOY_LURE := 320.0
const ROAD_EVERY := 0.12
const ROAD_LIFE := 4.0

var _wolf_pos := Vector2.ZERO
var _wolf_bite := 0.0
var _breath := BREATH_EVERY
var _breath_flash := 0.0
var _breath_dir := Vector2.RIGHT
var _decoys: Array[GodZone] = []
var _road_timer := 0.0
var _last_drop := Vector2.INF
var _second := 0.0
var _awaken_kills := 0


func fire_radius() -> float:
	return BASE_RADIUS * (1.0 + stat("loki_radius") / 100.0)


func burn_time() -> float:
	return BURN_TIME + stat("loki_ember")


func _ready() -> void:
	super._ready()
	show_behind_parent = true
	_wolf_pos = global_position


func tick(delta: float) -> void:
	match path:
		"loki_wolf":
			_tick_wolf(delta)
		"loki_road":
			_tick_road(delta)
		_:
			if _timer <= 0.0:
				_timer = TICK
				_scorch(global_position, fire_radius(), 1.0)
				Audio.sfx("fire_burn", -8.0)
			if path == "loki_shifter":
				_tick_decoys()
	_second -= delta
	if _second <= 0.0:
		_second = 1.0
		_every_second()


## 灼烧一圈敌人
func _scorch(center: Vector2, radius: float, mult: float) -> void:
	for enemy in Enemy.damage_in_radius(get_tree(), center, radius, damage(BASE_DAMAGE) * mult):
		ignite(enemy)


func ignite(enemy: Enemy) -> void:
	enemy.burn(damage(BASE_DAMAGE) * BURN_RATIO, burn_time())


## 每秒：银舌迷惑灼烧的敌人；融合技「毒蛇之刑」给灼烧的敌人叠霜冻
func _every_second() -> void:
	var charm_chance := stat("loki_silver") / 100.0
	var venom := has_fusion("venom")
	if charm_chance <= 0.0 and not venom:
		return
	for node in enemies():
		var enemy := node as Enemy
		if not enemy.has_status("burn"):
			continue
		if randf() < charm_chance:
			enemy.charm(CHARM_TIME)
		if venom:
			enemy.add_frost(1)


func on_enemy_died(enemy: Enemy) -> void:
	if enemy.has_status("burn") and stat("loki_spark") > 0.0:
		var near := enemies_in_radius(enemy.global_position, 110.0)
		near.erase(enemy)
		near.shuffle()
		for other in near.slice(0, int(stat("loki_spark"))):
			ignite(other)
			FxLayer.burst(other.global_position, Color(1.0, 0.6, 0.2), 4, 90.0, 2.0)
	if awakened and enemy.has_status("charm"):
		Enemy.damage_in_radius(get_tree(), enemy.global_position, CHARM_BLAST, damage(BASE_DAMAGE) * 4.0)
		FxLayer.burst(enemy.global_position, Color(1.0, 0.45, 0.8), 18, 220.0, 3.5)
	if awakened and path == "loki_road":
		_awaken_kills += 1


# ———— 质变：狼之父 ————

func _tick_wolf(delta: float) -> void:
	var prey := nearest_enemy(global_position, WOLF_SEEK)
	var goal := prey.global_position if prey else global_position + Vector2(-24, 10)
	_wolf_pos = _wolf_pos.move_toward(goal, WOLF_SPEED * (1.3 if awakened else 1.0) * delta)
	_wolf_bite -= delta
	var bite_radius := WOLF_BITE_RADIUS * (1.0 + stat("loki_radius") / 100.0) * (1.6 if awakened else 1.0)
	if prey and _wolf_bite <= 0.0 and _wolf_pos.distance_to(prey.global_position) < bite_radius:
		_wolf_bite = cooldown(WOLF_BITE_EVERY)
		for enemy in Enemy.damage_in_radius(get_tree(), _wolf_pos, bite_radius, damage(BASE_DAMAGE) * 2.5 * (1.5 if awakened else 1.0)):
			ignite(enemy)
			if randf() < stat("loki_silver") / 100.0:
				enemy.charm(CHARM_TIME)
		FxLayer.mark(prey.global_position, randf() * TAU, bite_radius, Color(1.0, 0.55, 0.2), "bite")
		Audio.sfx_or("wolf_bite", "fire_burn", -4.0)
	if awakened:
		_breath -= delta
		_breath_flash = maxf(0.0, _breath_flash - delta)
		if _breath <= 0.0 and prey:
			_breath = cooldown(BREATH_EVERY)
			_breath_flash = 0.4
			_breath_dir = _wolf_pos.direction_to(prey.global_position)
			for node in enemies():
				var enemy := node as Enemy
				var offset := enemy.global_position - _wolf_pos
				if offset.length() < BREATH_LENGTH and absf(_breath_dir.angle_to(offset)) < 0.45:
					enemy.take_damage(damage(BASE_DAMAGE) * 3.0)
					ignite(enemy)
					enemy.charm(CHARM_TIME)
			Audio.sfx_or("wolf_breath", "fire_burn", 2.0)


# ———— 质变：变形者 ————

func _tick_decoys() -> void:
	_decoys.assign(_decoys.filter(func(d) -> bool: return is_instance_valid(d)))
	var limit := 3 if awakened else 1
	if _decoys.size() < limit and _time >= float(get_meta("next_decoy", 0.0)):
		set_meta("next_decoy", _time + cooldown(1.5 if awakened else DECOY_EVERY))
		_spawn_decoy()
	for decoy in _decoys:
		for enemy in enemies_in_radius(decoy.global_position, DECOY_LURE):
			enemy.lure = decoy


func _spawn_decoy() -> void:
	var at := global_position
	var burn_tick := func(enemy: Enemy) -> void:
		enemy.take_damage(damage(BASE_DAMAGE) * 0.8)
		ignite(enemy)
	var decoy := zone(at, fire_radius() * 0.8, DECOY_LIFE, TICK, burn_tick, Color(1.0, 0.5, 0.2))
	decoy.on_end = func() -> void:
		if not is_instance_valid(self):
			return
		if stat("loki_spark") > 0.0:
			_scorch(at, 90.0, 2.0)
			FxLayer.burst(at, Color(1.0, 0.55, 0.2), 20, 220.0, 3.5)
		if awakened:
			for enemy in enemies_in_radius(at, 120.0):
				enemy.charm(CHARM_TIME)
	_decoys.append(decoy)
	Audio.sfx_or("decoy_spawn", "fire_burn")
	FxLayer.burst(at, Color(1.0, 0.55, 0.2), 12, 140.0, 3.0)


# ———— 质变：纳吉尔法尔之路 ————

func _tick_road(delta: float) -> void:
	_road_timer -= delta
	if _road_timer > 0.0 or global_position.distance_to(_last_drop) < 14.0:
		return
	_road_timer = ROAD_EVERY
	_last_drop = global_position
	var growth := 1.0 + 0.05 * int(_awaken_kills / 50.0)
	var radius := fire_radius() * 0.45 * growth
	var life := (ROAD_LIFE + stat("loki_ember")) * (1.5 if awakened else 1.0)
	var burn_tick := func(enemy: Enemy) -> void:
		enemy.take_damage(damage(BASE_DAMAGE) * 0.7)
		ignite(enemy)
	var patch := zone(global_position, radius, life, TICK, burn_tick, Color(1.0, 0.45, 0.15))
	patch.texture = art("loki_fire_patch")


func _draw() -> void:
	match path:
		"loki_wolf":
			_draw_wolf()
		"loki_road":
			pass
		_:
			var r := fire_radius()
			draw_circle(Vector2.ZERO, r, Color(0.3, 1.0, 0.75, 0.06))
			SpriteVisual.draw_frame(self, AURA, 4, int(_time * 8.0), Vector2.ZERO, Vector2(64, 64), 0.0, Vector2.ONE * r / AURA_ART_RADIUS)
	var decoy_art := art("loki_decoy")
	_decoys.assign(_decoys.filter(func(d) -> bool: return is_instance_valid(d)))
	for decoy in _decoys:
		var p := to_local(decoy.global_position)
		if decoy_art:
			SpriteVisual.draw_frame(self, decoy_art, 4, int(_time * 8.0), p, Vector2(16, 44), 0.0, Vector2.ONE, Color(1, 1, 1, 0.85))
		else:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -36), p + Vector2(10, -10), p + Vector2(8, 4), p + Vector2(-8, 4), p + Vector2(-10, -10)]), Color(1.0, 0.5, 0.2, 0.55 + 0.15 * sin(_time * 10.0)))


func _draw_wolf() -> void:
	var p := to_local(_wolf_pos)
	var scale := 1.6 if awakened else 1.0
	var face := -1.0 if _wolf_pos.x > global_position.x + 4.0 and nearest_enemy(global_position, WOLF_SEEK) == null else 1.0
	var wolf := art("loki_wolf")
	if wolf:
		SpriteVisual.draw_frame(self, wolf, 2, int(_time * 8.0), p, Vector2(16, 24), 0.0, Vector2(face, 1.0) * scale)
	else:
		draw_circle(p, 9.0 * scale, Color(1.0, 0.5, 0.15, 0.85))
		draw_circle(p + Vector2(7 * face, -5) * scale, 5.0 * scale, Color(1.0, 0.7, 0.3, 0.9))
	draw_circle(p, 14.0 * scale, Color(1.0, 0.55, 0.2, 0.15))
	if _breath_flash > 0.0:
		var cone := PackedVector2Array([p])
		for i in 9:
			cone.append(p + _breath_dir.rotated(-0.45 + 0.9 * i / 8.0) * BREATH_LENGTH)
		draw_colored_polygon(cone, Color(1.0, 0.5, 0.2, _breath_flash))
