extends GodPower
## 澜·澜之网：每 3.5 秒向敌人最密集的地方抛出大网，把网里的敌人拉到中心、定住，收网时造成伤害
## 被网住的敌人「溺水」3 秒：受到的范围伤害 +20%
## 强化：大网（半径）、双网（多抛几张）、漩涡（收网后留下漩涡）、拖曳（定住更久）
## 质变：九浪（推出巨浪卷走敌人）、安德瓦利之网（网留在地上，经验翻倍）、溺亡者（死在网里的敌人为你作战）
## 素材（可选）：effects/gods/ran_net.png 网（96×96），ran_wave.png 浪（64×32，浪头朝上，横向铺开），ran_whirl.png 漩涡（4 帧 64×64）

const BASE_DAMAGE := 18.0
const BASE_COOLDOWN := 3.5
const THROW_RANGE := 450.0
const NET_RADIUS := 90.0
const NET_FLIGHT := 0.35
const NET_CLOSE := 0.25
const HOLD_TIME := 0.6
const DROWN_TIME := 3.0
const PULL := 8.0              # 收网时把敌人往中心拉的力度
const WHIRL_PULL := 70.0
const ANDVARI_LIFE := 3.0
const ANDVARI_DAMAGE := 0.4
const DROWNED_LIFE := 8.0
const DROWNED_MAX := 6
const WAVE_SPEED := 450.0
const WAVE_RANGE := 500.0
const MAIDENS_EVERY := 12.0
const COUNTER_CHANCE := 0.2

var _nets: Array[Dictionary] = []   # 抛出去的网：from、to、t（0 → 1 飞行，之后收网）
var _waves: Array[Dictionary] = []  # 浪：pos、dir、flown、reach、carried
var _drowned: Array[Einherjar] = []
var _maidens := MAIDENS_EVERY


func net_radius() -> float:
	return NET_RADIUS * (1.0 + stat("ran_size") / 100.0)


func throws() -> int:
	return 1 + int(stat("ran_double"))


func hold_time() -> float:
	return HOLD_TIME + stat("ran_drag")


func tick(delta: float) -> void:
	if _timer <= 0.0:
		if path == "ran_waves":
			_push_waves()
		else:
			_throw_nets()
	_tick_nets(delta)
	_tick_waves(delta)
	if path == "ran_waves" and awakened:
		_maidens -= delta
		if _maidens <= 0.0:
			_maidens = cooldown(MAIDENS_EVERY)
			for i in 9:
				var dir := Vector2.from_angle(TAU * i / 9.0)
				_waves.append({"pos": global_position + dir * 450.0, "dir": -dir, "flown": 0.0, "reach": 390.0, "carried": {}})


# ———— 抛网 ————

func _throw_nets() -> void:
	var taken: Array[Vector2] = []
	for i in throws():
		var at := densest_point(global_position, THROW_RANGE, net_radius(), taken)
		if not at.is_finite():
			break
		taken.append(at)
		_nets.append({"from": global_position, "to": at, "t": 0.0, "closed": false})
	if not taken.is_empty():
		_timer = cooldown(BASE_COOLDOWN)
		Audio.sfx_or("net_throw", "dash", -6.0)


func _tick_nets(delta: float) -> void:
	for net in _nets:
		var before: float = net.t
		net.t += delta / NET_FLIGHT
		if before < 1.0 and net.t >= 1.0:
			_pull(net.to, net_radius())
		if not net.closed and net.t >= 1.0 + NET_CLOSE / NET_FLIGHT:
			net.closed = true
			_close(net.to, net_radius())
	_nets = _nets.filter(func(n: Dictionary) -> bool: return not n.closed or n.t < 1.0 + (NET_CLOSE + 0.3) / NET_FLIGHT)


## 网落地：把网里的敌人往中心拉
func _pull(center: Vector2, radius: float) -> void:
	for enemy in enemies_in_radius(center, radius):
		if not enemy is Boss:
			enemy._knockback += (center - enemy.global_position) * PULL


## 收网：伤害、溺水、定住；然后按质变留下漩涡或金网
func _close(center: Vector2, radius: float) -> void:
	var caught := Enemy.damage_in_radius(get_tree(), center, radius * 0.75, damage(BASE_DAMAGE))
	for enemy in caught:
		_drown(enemy)
		enemy.stun(hold_time())
	FxLayer.burst(center, Color(0.4, 0.7, 1.0), 14, 160.0, 3.0)
	Audio.sfx_or("net_close", "", -4.0)
	if stat("ran_whirl") > 0.0:
		_whirl(center, radius * 1.2)
	if path == "ran_andvari":
		var soak := func(enemy: Enemy) -> void:
			enemy.take_damage(damage(BASE_DAMAGE) * ANDVARI_DAMAGE)
			enemy.add_status("andvari", 1.1)
			if awakened:
				enemy.add_status("gold_net", 1.1)
			_drown(enemy)
		var net := zone(center, radius, ANDVARI_LIFE, 1.0, soak, Color(1.0, 0.85, 0.35) if awakened else Color(0.4, 0.7, 1.0))
		net.texture = art("ran_net")


func _drown(enemy: Enemy) -> void:
	enemy.add_status("drown", DROWN_TIME)
	if has_fusion("andvari") and player.gods.has("loki"):
		player.gods["loki"].ignite(enemy)


func _whirl(center: Vector2, radius: float) -> void:
	var keep_wet := func(enemy: Enemy) -> void:
		_drown(enemy)
	var whirl := zone(center, radius, stat("ran_whirl"), 0.5, keep_wet, Color(0.35, 0.65, 1.0))
	whirl.pull = WHIRL_PULL
	whirl.texture = art("ran_whirl")


func on_enemy_died(enemy: Enemy) -> void:
	if enemy is Boss:
		return
	if path == "ran_andvari" and enemy.has_status("andvari"):
		drop_xp(enemy.global_position, enemy.xp_value)
		if awakened and randf() < 0.03:
			_gold(enemy.global_position)
	if has_fusion("andvari") and enemy.has_status("drown") and enemy.has_status("burn") and randf() < 0.05:
		_gold(enemy.global_position)
	if path == "ran_drowned" and enemy.has_status("drown"):
		_drowned.assign(_drowned.filter(func(a) -> bool: return is_instance_valid(a)))
		if _drowned.size() < (DROWNED_MAX * 2 if awakened else DROWNED_MAX):
			var ally := summon_einherjar(INF if awakened else DROWNED_LIFE, 0.6, Color(0.55, 0.8, 1.0, 0.85))
			ally.position = enemy.global_position
			_drowned.append(ally)


## 安德瓦利的黄金：掉 1 点奖励点
func _gold(at: Vector2) -> void:
	game().add_reward_points(1)
	FxLayer.floating_text(at + Vector2(0, -20), tr("奖励点 +%d") % 1, Color(1.0, 0.85, 0.4))


func on_player_hurt() -> void:
	if not awakened or randf() >= COUNTER_CHANCE:
		return
	var attacker := nearest_enemy(global_position, 120.0)
	if attacker:
		_drown(attacker)
		attacker.stun(1.0)
		_nets.append({"from": global_position, "to": attacker.global_position, "t": 0.8, "closed": true})


# ———— 质变：九浪 ————

func _push_waves() -> void:
	var dir := densest_direction(global_position, WAVE_RANGE, net_radius())
	if not dir.is_finite():
		return
	_timer = cooldown(BASE_COOLDOWN)
	for i in throws():
		_waves.append({"pos": global_position, "dir": dir.rotated((i - (throws() - 1) * 0.5) * 0.5), "flown": 0.0, "reach": WAVE_RANGE, "carried": {}})
	Audio.sfx_or("wave_push", "dash", -2.0)


func _tick_waves(delta: float) -> void:
	var half := net_radius() * 0.8
	for w in _waves:
		var step := WAVE_SPEED * delta
		w.pos += w.dir * step
		w.flown += step
		var side: Vector2 = w.dir.orthogonal()
		for enemy in enemies_on_line(w.pos - side * half, w.pos + side * half, 30.0):
			if not enemy is Boss and not w.carried.has(enemy):
				w.carried[enemy] = (enemy.global_position - w.pos).dot(side)
		for enemy in w.carried.keys():
			if is_instance_valid(enemy) and not enemy._dead:
				enemy.global_position = w.pos + w.dir * 10.0 + side * float(w.carried[enemy])
		if w.flown >= w.reach:
			w.done = true
			_crash(w.pos, half)
	_waves = _waves.filter(func(w: Dictionary) -> bool: return not w.get("done", false))


func _crash(at: Vector2, half: float) -> void:
	for enemy in Enemy.damage_in_radius(get_tree(), at, half * 1.2, damage(BASE_DAMAGE) * 2.0):
		_drown(enemy)
		enemy.stun(hold_time())
	FxLayer.burst(at, Color(0.5, 0.8, 1.0), 24, 240.0, 4.0)
	Audio.sfx_or("wave_crash", "boss_slam", -6.0)
	player.shake(3.0, 0.12)
	if stat("ran_whirl") > 0.0:
		_whirl(at, half * 1.3)


func _draw() -> void:
	var net_art := art("ran_net")
	for net in _nets:
		var k := minf(1.0, net.t)
		var at := to_local(net.from.lerp(net.to, k)) + Vector2(0, -60.0 * sin(k * PI))  # 抛物线
		var r := net_radius() * (0.3 + 0.7 * k)
		if net.t > 1.0:
			at = to_local(net.to)
			r = net_radius() * lerpf(1.0, 0.6, clampf((net.t - 1.0) * NET_FLIGHT / NET_CLOSE, 0.0, 1.0))
		if net_art:
			draw_texture_rect(net_art, Rect2(at - Vector2.ONE * r, Vector2.ONE * r * 2.0), false, Color(1, 1, 1, 0.85))
		else:
			draw_arc(at, r, 0.0, TAU, 32, Color(0.75, 0.9, 1.0, 0.8), 2.0)
			for i in 4:
				var d := Vector2.from_angle(PI * i / 4.0) * r
				draw_line(at - d, at + d, Color(0.75, 0.9, 1.0, 0.5), 1.0)
	var wave_art := art("ran_wave")
	var half := net_radius() * 0.8
	for w in _waves:
		var p := to_local(w.pos)
		var side: Vector2 = w.dir.orthogonal()
		if wave_art:
			draw_set_transform(p, w.dir.angle() + PI / 2)
			draw_texture_rect(wave_art, Rect2(-half, -16, half * 2.0, 32), false)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_line(p - side * half, p + side * half, Color(0.4, 0.7, 1.0, 0.7), 14.0)
			draw_line(p - side * half + w.dir * 6.0, p + side * half + w.dir * 6.0, Color(0.9, 0.97, 1.0, 0.85), 4.0)
