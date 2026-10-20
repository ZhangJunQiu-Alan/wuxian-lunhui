class_name GodPower
extends Node2D
## 神明的神术基类：每位信仰的神一个节点，挂在玩家身上
## 强化卡的数值累加到 stats 里（卡牌 id -> 数值总和），质变设置 path，觉醒设置 awakened
## 敌人死亡、玩家受伤、玩家闪现时，所有神术都会收到通知（on_enemy_died / on_player_hurt / on_dash）
##
## 素材（可选）：assets/sprites/effects/gods/<名字>.png，见 art()。没有素材时用程序画的图形

const ART_DIR := "res://assets/sprites/effects/gods/"

static var fusions := {}  # 本局已获得的融合技 id -> true，每局开始时清空
static var _art_cache := {}

var god_id := ""
var player: Player
var path := ""         # 选过的质变 id，例如 thor_cloud
var awakened := false
var stats := {}        # 强化卡 id -> 累计数值
var color := Color.WHITE
var _timer := 0.4
var _time := 0.0


static func create(id: String) -> GodPower:
	var power: GodPower = load("res://scripts/gods/%s.gd" % id).new()
	power.god_id = id
	power.color = Gods.ALL[id].color
	return power


static func has_fusion(id: String) -> bool:
	return fusions.has(id)


## 读取 assets/sprites/effects/gods/<file>.png，没有就返回 null
static func art(file: String) -> Texture2D:
	if not _art_cache.has(file):
		var path := ART_DIR + file + ".png"
		_art_cache[file] = load(path) if ResourceLoader.exists(path) else null
	return _art_cache[file]


func _ready() -> void:
	player = get_parent() as Player
	add_to_group("god_powers")


func _process(delta: float) -> void:
	_time += delta
	_timer -= delta
	tick(delta)
	queue_redraw()


## 子类每帧的逻辑
func tick(_delta: float) -> void:
	pass


func stat(id: String) -> float:
	return stats.get(id, 0.0)


## 选了一张强化卡
func upgrade(id: String, v: float, _rarity: int) -> void:
	stats[id] = stat(id) + v


func set_path(id: String) -> void:
	path = id
	_timer = 0.3
	FxLayer.burst(player.global_position, color, 40, 260.0, 4.0)


func awaken() -> void:
	awakened = true
	FxLayer.burst(player.global_position, color, 70, 340.0, 5.0)
	player.shake(8.0, 0.3)


func on_enemy_died(_enemy: Enemy) -> void:
	pass


func on_player_hurt() -> void:
	pass


func on_dash() -> void:
	pass


## 神术冷却：受「冷却缩短」影响，不受只管基础武器的「急速」影响
func cooldown(base: float) -> float:
	return base * player.cooldown_mult * player.god_cooldown_mult


## 当前伤害（已乘全局伤害加成）
func damage(base: float) -> float:
	return base * player.damage_mult


func game() -> Node:
	return get_tree().current_scene


func enemies() -> Array[Node]:
	return get_tree().get_nodes_in_group("enemies")


func nearest_enemy(from: Vector2, max_dist: float, exclude: Array = []) -> Enemy:
	var best: Enemy = null
	var best_d := max_dist * max_dist
	for enemy in Enemy.query_radius(from, max_dist):
		if exclude.has(enemy):
			continue
		var d := enemy.global_position.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = enemy
	return best


func farthest_enemy(from: Vector2, max_dist: float) -> Enemy:
	var best: Enemy = null
	var best_d := -1.0
	for enemy in Enemy.query_radius(from, max_dist):
		var d := enemy.global_position.distance_squared_to(from)
		if d < max_dist * max_dist and d > best_d:
			best_d = d
			best = enemy
	return best


## 血量最高的敌人（精英、Boss 优先）
func strongest_enemy(from: Vector2, max_dist: float) -> Enemy:
	var best: Enemy = null
	for enemy in Enemy.query_radius(from, max_dist):
		if enemy.global_position.distance_squared_to(from) < max_dist * max_dist and (best == null or enemy.hp > best.hp):
			best = enemy
	return best


## 范围 max_dist 内敌人最密集的地方：随机挑一些敌人，数它们 radius 内有几个同伴
func densest_point(from: Vector2, max_dist: float, radius: float, exclude_near: Array[Vector2] = []) -> Vector2:
	var candidates: Array[Enemy] = []
	for node in enemies():
		var enemy := node as Enemy
		if enemy.global_position.distance_to(from) < max_dist:
			candidates.append(enemy)
	if candidates.is_empty():
		return Vector2.INF
	candidates.shuffle()
	var best := Vector2.INF
	var best_count := -1
	for enemy: Enemy in candidates.slice(0, 24):
		var pos := enemy.global_position
		if exclude_near.any(func(p: Vector2) -> bool: return p.distance_to(pos) < radius):
			continue
		var count := 0
		for other in candidates:
			if other.global_position.distance_to(pos) < radius:
				count += 1
		if count > best_count:
			best_count = count
			best = pos
	return best


## 敌人最多的方向（从 from 出发、长 length 宽 width 的一条里有几个敌人）
func densest_direction(from: Vector2, length: float, width: float) -> Vector2:
	var best := Vector2.INF
	var best_count := 0
	for i in 16:
		var dir := Vector2.from_angle(TAU * i / 16.0)
		var count := 0
		for node in enemies():
			var enemy := node as Enemy
			if _in_line(enemy, from, from + dir * length, width):
				count += 1
		if count > best_count:
			best_count = count
			best = dir
	return best


static func _in_line(enemy: Enemy, a: Vector2, b: Vector2, width: float) -> bool:
	var p := Geometry2D.get_closest_point_to_segment(enemy.global_position, a, b)
	return p.distance_to(enemy.global_position) <= width * 0.5 + enemy.radius


## 一条线段（宽 width）上的所有敌人
func enemies_on_line(a: Vector2, b: Vector2, width: float) -> Array[Enemy]:
	return Enemy.query_line(a, b, width)


func enemies_in_radius(center: Vector2, radius: float) -> Array[Enemy]:
	return Enemy.query_radius(center, radius)


## 在地上放一块持续生效的区域（光带、冰面、火路、麦田……），见 GodZone
func zone(pos: Vector2, radius: float, life: float, tick_every: float, on_tick: Callable, zone_color: Color) -> GodZone:
	var z := GodZone.new()
	z.position = pos
	z.radius = radius
	z.life = life
	z.tick_every = tick_every
	z.on_tick = on_tick
	z.color = zone_color
	game().add_child(z)
	return z


func line_zone(a: Vector2, b: Vector2, width: float, life: float, tick_every: float, on_tick: Callable, zone_color: Color) -> GodZone:
	var z := zone(a, width * 0.5, life, tick_every, on_tick, zone_color)
	z.to = b - a
	return z


## 掉一个回复生命的拾取物（金羽、苹果、金泪）
func drop_heal(pos: Vector2, heal: float, kind: String) -> void:
	var pickup := HealPickup.new()
	pickup.position = pos
	pickup.player = player
	pickup.heal = heal
	pickup.kind = kind
	game().add_child.call_deferred(pickup)


## 召唤一位英灵（奥丁的被动、渡鸦、融合技），也用来做澜的溺亡者
func summon_einherjar(life: float, power: float, tint: Color = Color.WHITE) -> Einherjar:
	var ally := Einherjar.new()
	ally.player = player
	ally.power = power * game().enemy_hp_scale()
	ally.life = life
	ally.modulate = tint
	ally.position = player.global_position + Vector2.from_angle(randf() * TAU) * 40.0
	game().add_child.call_deferred(ally)
	return ally


## 额外掉一颗经验宝石（弗雷的丰收、澜的安德瓦利之网）。value 有小数时按几率进位
func drop_xp(pos: Vector2, value: float) -> void:
	var amount := int(value) + (1 if randf() < value - int(value) else 0)
	if amount <= 0:
		return
	var gem := XpGem.new()
	gem.value = amount
	gem.player = player
	gem.position = pos + Vector2(randf_range(-6, 6), randf_range(-6, 6))
	game().add_child.call_deferred(gem)


## 一道落雷（托尔和融合技共用）：从天上劈到 pos，范围伤害，返回被劈到的敌人
func lightning(pos: Vector2, radius: float, amount: float) -> Array[Enemy]:
	LightningFx.spawn(game(), pos + Vector2(randf_range(-40.0, 40.0), -420.0), pos, radius)
	Audio.sfx("lightning", -3.0)
	var hit := Enemy.damage_in_radius(get_tree(), pos, radius, amount, 120.0)
	for enemy in hit:
		enemy.add_status("shock", 3.0)
	return hit


## 朝某个方向发射一支飞弹，命中时调用 on_hit(enemy, bolt)
func shoot(from: Vector2, dir: Vector2, speed: float, amount: float, pierce: int, texture: Texture2D, frames: int,
		anchor: Vector2, on_hit: Callable = Callable(), lifetime: float = 2.0) -> Projectile:
	var p := Projectile.new()
	p.global_position = from
	p.direction = dir
	p.speed = speed
	p.damage = amount
	p.pierce = pierce
	p.texture = texture
	p.frames = frames
	p.anchor = anchor
	p.color = color
	p.lifetime = lifetime
	p.on_hit = on_hit
	game().add_child.call_deferred(p)  # 可能是在子弹命中（物理回调）里发射的，不能立刻加碰撞体
	return p
