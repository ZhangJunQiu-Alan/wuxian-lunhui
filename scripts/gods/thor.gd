extends GodPower
## 托尔·落雷：每 2 秒向附近的敌人劈下一道雷，被劈中的敌人感电
## 强化：风暴（多劈几道）、雷域（范围）、麻痹（定住）、回响（原地再劈）
## 质变：妙尔尼尔（掷锤，一路落雷）、雷暴云（头顶雷云持续劈小雷）、静电场（叠感电，电网互相电击）
## 素材（可选）：effects/gods/thor_hammer.png 战锤（32×32，锤头朝右），thor_cloud.png 雷云（128×64）

const RANGE := 450.0
const BASE_RADIUS := 50.0
const BASE_DAMAGE := 20.0
const BASE_COOLDOWN := 2.0
const PARALYZE_TIME := 0.6
const ECHO_DELAY := 0.5
const HAMMER_EVERY := 3.0
const HAMMER_RANGE := 380.0
const HAMMER_SPEED := 700.0
const HAMMER_STEP := 60.0     # 战锤每飞这么远落一道雷
const HAMMER_SPREAD := 0.35   # 多把战锤之间的夹角
const RETURN_BLAST := 140.0   # 觉醒：战锤回手时的雷爆半径
const CLOUD_RATE := 3.0       # 雷云每秒劈几道小雷
const CLOUD_DAMAGE := 0.4
const CLOUD_RANGE := 300.0
const LINK_RANGE := 150.0     # 静电场：感电敌人之间多远会连成电网
const STATIC_TICK := 1.0
const STATIC_DAMAGE := 0.12   # 电网每秒伤害 = 落雷伤害 × 这个 × 感电层数 × (1 + 0.5 × 相连数)
const SHOCK_STACKS := 5
const COUNTER_CHANCE := 0.3   # 觉醒的神格被动：受伤时反劈

var _hammers: Array[Dictionary] = []  # 飞行中的战锤：pos、dir、back（在往回飞）、flown、next_drop、hit
var _cloud_acc := 0.0
var _static_tick := 0.0
var _links: Array[Dictionary] = []    # 电网的连线（画 0.25 秒）：a、b、life
var _utgard_tick := 0.0
var _exploding := false


func upgrade(id: String, v: float, rarity: int) -> void:
	super.upgrade(id, v, rarity)
	if id == "thor_storm" and rarity == 2:  # 史诗风暴：额外范围 +10%
		stats["thor_field"] = stat("thor_field") + 10.0


func strikes() -> int:
	return 1 + int(stat("thor_storm"))


func blast_radius() -> float:
	return BASE_RADIUS * (1.0 + stat("thor_field") / 100.0)


func tick(delta: float) -> void:
	match path:
		"thor_mjolnir":
			_tick_hammers(delta)
		"thor_cloud":
			_tick_cloud(delta)
		_:
			_tick_bolts()
			if path == "thor_static":
				_tick_static(delta)
	for link in _links:
		link.life -= delta
	_links = _links.filter(func(l: Dictionary) -> bool: return l.life > 0.0)
	if has_fusion("utgard") and player.gods.has("loki"):
		_tick_utgard(delta)


# ———— 落雷（基础形态，静电场也用它叠感电）————

func _tick_bolts() -> void:
	if _timer > 0.0:
		return
	var candidates := enemies_in_radius(global_position, RANGE)
	if candidates.is_empty():
		return
	_timer = cooldown(BASE_COOLDOWN)
	candidates.shuffle()
	for i in mini(strikes(), candidates.size()):
		strike(candidates[i].global_position)


## 劈一道雷。mult 是伤害倍率，small 是雷暴云的小雷
func strike(pos: Vector2, mult: float = 1.0, small: bool = false, is_echo: bool = false) -> void:
	var radius := blast_radius() * (0.7 if small else 1.0)
	if path == "thor_static":
		LightningFx.spawn(game(), pos + Vector2(randf_range(-40.0, 40.0), -420.0), pos, radius)
		Audio.sfx("lightning", -6.0)
		for enemy in enemies_in_radius(pos, radius):
			enemy.add_stacks("shock", 2, 4.0)
			if enemy.stack_count("shock") > SHOCK_STACKS:
				enemy.stacks["shock"] = SHOCK_STACKS
			_after_hit(enemy)
	else:
		for enemy in lightning(pos, radius, damage(BASE_DAMAGE) * mult):
			_after_hit(enemy)
	if not is_echo and randf() < stat("thor_echo") / 100.0:
		get_tree().create_timer(ECHO_DELAY, false).timeout.connect(func() -> void:
			if is_instance_valid(self):
				strike(pos, mult, small, true))


## 被雷劈到之后：麻痹，以及和别的神的融合技
func _after_hit(enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or enemy._dead:
		return
	if randf() < stat("thor_paralyze") / 100.0:
		enemy.stun(PARALYZE_TIME)
	if has_fusion("father_son") and enemy.stack_count("rune") > 0 and player.gods.has("odin"):
		player.gods["odin"].detonate(enemy, true)
	if has_fusion("utgard") and enemy.has_status("burn"):
		Enemy.damage_in_radius(get_tree(), enemy.global_position, 70.0, damage(BASE_DAMAGE) * 0.6)
		FxLayer.burst(enemy.global_position, Color(1.0, 0.55, 0.2), 14, 180.0, 3.5)
	if has_fusion("shatter_thunder") and enemy.is_frozen():
		var at := enemy.global_position
		for other in enemies_in_radius(at, 80.0):
			other.take_damage(damage(BASE_DAMAGE) * 0.8)
			other.add_frost(2)
		FxLayer.burst(at, Color(0.75, 0.9, 1.0), 16, 200.0, 3.5)
	if has_fusion("serpent_fishing") and enemy.has_status("drown"):
		for node in enemies():
			var other := node as Enemy
			if other != enemy and other.has_status("drown"):
				other.take_damage(damage(BASE_DAMAGE) * 0.5)
				LightningFx.spawn(game(), enemy.global_position, other.global_position, 0.0)


# ———— 质变 A：妙尔尼尔 ————

func _tick_hammers(delta: float) -> void:
	if _timer <= 0.0:
		var target := nearest_enemy(global_position, 500.0)
		if target:
			_timer = cooldown(HAMMER_EVERY)
			_throw_hammers(global_position.direction_to(target.global_position), strikes() + (2 if awakened else 0))
	for h in _hammers:
		var step := HAMMER_SPEED * delta
		if h.back:
			var home := global_position
			h.pos = h.pos.move_toward(home, step)
			if h.pos.distance_to(home) < 12.0:
				h.done = true
				_hammer_returned()
		else:
			h.pos += h.dir * step
			if h.flown + step >= HAMMER_RANGE:
				h.back = true
				h.hit = {}
		h.flown += step
		if h.flown >= h.next_drop:
			h.next_drop += HAMMER_STEP
			strike(h.pos, 0.6, true, true)
		for enemy in enemies_in_radius(h.pos, 16.0):
			if not h.hit.has(enemy):
				h.hit[enemy] = true
				enemy.take_damage(damage(BASE_DAMAGE) * 0.8, h.dir * 160.0)
				_after_hit(enemy)
	_hammers = _hammers.filter(func(h: Dictionary) -> bool: return not h.get("done", false))


func _throw_hammers(dir: Vector2, count: int) -> void:
	Audio.sfx_or("hammer_throw", "dash", -4.0)
	for i in count:
		var angle := (i - (count - 1) * 0.5) * HAMMER_SPREAD
		_hammers.append({"pos": global_position, "dir": dir.rotated(angle), "back": false, "flown": 0.0, "next_drop": HAMMER_STEP, "hit": {}})


func _hammer_returned() -> void:
	Audio.sfx_or("hammer_catch", "", -6.0)
	if awakened:
		for enemy in lightning(global_position, RETURN_BLAST, damage(BASE_DAMAGE) * 2.0):
			_after_hit(enemy)
		player.shake(4.0, 0.15)
	if randf() < stat("thor_echo") / 100.0:
		var target := nearest_enemy(global_position, 500.0)
		if target:
			_throw_hammers(global_position.direction_to(target.global_position), 1)


# ———— 质变 B：雷暴云 ————

func _tick_cloud(delta: float) -> void:
	var rate := (CLOUD_RATE + strikes() - 1) * (2.0 if awakened else 1.0)
	_cloud_acc += rate * delta / cooldown(1.0)
	var reach := 700.0 if awakened else CLOUD_RANGE * (1.0 + stat("thor_field") / 100.0)
	while _cloud_acc >= 1.0:
		_cloud_acc -= 1.0
		var candidates := enemies_in_radius(global_position, reach)
		if candidates.is_empty():
			_cloud_acc = 0.0
			return
		strike(candidates.pick_random().global_position, CLOUD_DAMAGE, true)


# ———— 质变 C：静电场 ————

func _tick_static(delta: float) -> void:
	_static_tick -= delta
	if _static_tick > 0.0:
		return
	_static_tick = STATIC_TICK
	var shocked: Array[Enemy] = []
	for node in enemies():
		var enemy := node as Enemy
		if enemy.stack_count("shock") > 0:
			shocked.append(enemy)
	var reach := link_range()
	if not shocked.is_empty():
		Audio.sfx_or("static_zap", "", -8.0)
	var counts := {}
	for enemy in shocked:
		var linked := 0
		for other in Enemy.query_radius(enemy.global_position, reach):
			if other != enemy and other.stack_count("shock") > 0 and other.global_position.distance_squared_to(enemy.global_position) < reach * reach:
				linked += 1
				if linked <= 4 and enemy.get_instance_id() < other.get_instance_id() and _links.size() < 80:
					_links.append({"a": enemy.global_position, "b": other.global_position, "life": 0.25})
		counts[enemy] = mini(linked, 4)
	for enemy in shocked:
		if enemy._dead:
			continue
		var dmg := damage(BASE_DAMAGE) * STATIC_DAMAGE * enemy.stack_count("shock") * (1.0 + 0.5 * int(counts[enemy]))
		var times := 2 if randf() < stat("thor_echo") / 100.0 else 1
		for i in times:
			enemy.take_dot(dmg)
		_after_hit(enemy)


func link_range() -> float:
	return LINK_RANGE * (1.0 + stat("thor_field") / 100.0)


## 觉醒·雷神之域：感电的敌人死亡时，引爆电网上所有相连的敌人
func on_enemy_died(enemy: Enemy) -> void:
	if not (awakened and path == "thor_static") or _exploding or enemy.stack_count("shock") <= 0:
		return
	_exploding = true
	var chain: Array[Enemy] = []
	var frontier: Array[Vector2] = [enemy.global_position]
	var reach := link_range()
	while not frontier.is_empty() and chain.size() < 40:
		var from: Vector2 = frontier.pop_back()
		for other in Enemy.query_radius(from, reach):
			if other.stack_count("shock") > 0 and not chain.has(other) and other.global_position.distance_squared_to(from) < reach * reach:
				chain.append(other)
				frontier.append(other.global_position)
				_links.append({"a": from, "b": other.global_position, "life": 0.3})
				if chain.size() >= 40:
					break
	for other in chain:
		if is_instance_valid(other):
			other.take_damage(damage(BASE_DAMAGE) * 1.5)
	_exploding = false


func on_player_hurt() -> void:
	if awakened and randf() < COUNTER_CHANCE:
		var target := nearest_enemy(global_position, 300.0)
		if target:
			strike(target.global_position, 1.0, false, true)


# ———— 融合技 ————

## 乌特加尔德之旅：诡火范围内的敌人每秒被小雷击中一次
func _tick_utgard(delta: float) -> void:
	_utgard_tick -= delta
	if _utgard_tick > 0.0:
		return
	_utgard_tick = 1.0
	var loki: GodPower = player.gods["loki"]
	var targets := enemies_in_radius(loki.global_position, loki.fire_radius())
	targets.shuffle()
	for enemy in targets.slice(0, 6):
		LightningFx.spawn(game(), enemy.global_position + Vector2(0, -200), enemy.global_position, 0.0)
		enemy.take_damage(damage(BASE_DAMAGE) * 0.3)


## 假新娘：闪现后隐身 2 秒，敌人追向原地的幻影；隐身结束时降下巨雷
func on_dash() -> void:
	if not has_fusion("false_bride"):
		return
	var decoy := Node2D.new()
	decoy.global_position = global_position
	game().add_child(decoy)
	for node in enemies():
		(node as Enemy).lure = decoy
	player.modulate.a = 0.35
	get_tree().create_timer(2.0, false).timeout.connect(func() -> void:
		decoy.queue_free()
		if not is_instance_valid(self):
			return
		player.modulate.a = 1.0
		for enemy in lightning(global_position, 160.0, damage(BASE_DAMAGE) * 5.0):
			_after_hit(enemy)
		player.shake(8.0, 0.25))


func _draw() -> void:
	for link in _links:
		var a := to_local(link.a)
		var b := to_local(link.b)
		var mid := (a + b) * 0.5 + (b - a).orthogonal().normalized() * randf_range(-8.0, 8.0)
		draw_polyline(PackedVector2Array([a, mid, b]), Color(0.6, 0.85, 1.0, 0.8 * link.life / 0.25), 2.0)
	if path == "thor_cloud":
		_draw_cloud()
	var hammer := art("thor_hammer")
	for h in _hammers:
		var p := to_local(h.pos)
		var spin := _time * 18.0
		if hammer:
			SpriteVisual.draw_frame(self, hammer, 1, 0, p, Vector2(16, 16), spin)
		else:
			draw_set_transform(p, spin)
			draw_rect(Rect2(-9, -6, 12, 12), Color(0.7, 0.75, 0.85))
			draw_line(Vector2(3, 0), Vector2(12, 0), Color(0.5, 0.35, 0.2), 3.0)
			draw_set_transform(Vector2.ZERO)
		draw_circle(p, 10.0, Color(color, 0.25))


func _draw_cloud() -> void:
	var scale := 3.0 if awakened else 1.0
	var at := Vector2(0, -95.0 - (60.0 if awakened else 0.0))
	var cloud := art("thor_cloud")
	if cloud:
		SpriteVisual.draw_frame(self, cloud, 1, 0, at, Vector2(64, 32), 0.0, Vector2.ONE * scale, Color(1, 1, 1, 0.85))
		return
	for i in 5:
		var x := (i - 2) * 16.0 * scale
		var r := (14.0 + 6.0 * sin(_time * 2.0 + i)) * scale
		draw_circle(at + Vector2(x, absf(i - 2) * 4.0 * scale), r, Color(0.32, 0.36, 0.45, 0.75))
	if int(_time * 10.0) % 7 == 0:
		draw_circle(at, 18.0 * scale, Color(0.7, 0.85, 1.0, 0.25))
