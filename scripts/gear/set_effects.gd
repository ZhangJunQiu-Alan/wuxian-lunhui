class_name SetEffects
extends Node2D
## 套装效果：穿齐一套 4 件时，开局由 game.gd 挂在玩家身上。规则照 docs/装备系统_已确认.md，数值都在下面的常量里
## 接入点：Enemy.take_damage 调 modify_damage / on_damage_dealt，Player.take_damage 调 on_player_hit，
##         Player.weapon_cooldown 调 weapon_cooldown_mult，HUD 每帧读 hud_state
## 素材：assets/sprites/effects/sets/（帧条的尺寸、帧数、锚点见 assets/source/taskS_sets_2026-11-10/integration.md）

const FX_DIR := "res://assets/sprites/effects/sets/"
## 帧条：文件、每帧尺寸、帧数、fps、锚点
const STRIPS := {
	"thorn_burst": ["thornoath_burst", Vector2(248, 248), 6, 16.0, Vector2(124, 124)],
	"thorn_stab": ["thornoath_stab", Vector2(24, 32), 4, 16.0, Vector2(12, 27)],
	"mengzhi": ["xingtian_mengzhi", Vector2(64, 64), 6, 16.0, Vector2(32, 32)],
	"scale": ["dragonslayer_scale_r2", Vector2(64, 64), 4, 8.0, Vector2(32, 32)],
	"shatter": ["dragonslayer_shatter", Vector2(64, 64), 6, 16.0, Vector2(32, 32)],
	"storm": ["yellowwind_storm_r2", Vector2(96, 112), 6, 12.0, Vector2(48, 62)],
	"storm_start": ["yellowwind_storm_start_r2", Vector2(96, 112), 3, 12.0, Vector2(48, 62)],
	"storm_end": ["yellowwind_storm_end_r2", Vector2(96, 112), 3, 12.0, Vector2(48, 62)],
	"lotus": ["lotus_proc_r2", Vector2(64, 64), 4, 16.0, Vector2(32, 32)],
	"ring": ["valhalla_ring_r2", Vector2(64, 32), 8, 12.0, Vector2(32, 19)],
}

# 荆誓骑士 · 荆棘反刺
const THORN_MULT := 3.0
const THORN_RADIUS := 120.0
const THORN_PUSH := 520.0
const THORN_COOLDOWN := 0.5
const THORN_SEEK := 260.0      # 不知道是谁打的（弹幕、地面火焰）时，反刺这么近以内最近的敌人
# 刑天 · 猛志
const MENGZHI_PER_STACK := 0.08
const MENGZHI_MAX := 5
const MENGZHI_HOLD := 10.0     # 这么久没挨打开始消失
const MENGZHI_DECAY := 1.0     # 之后每隔这么久掉一层
# 夜之伯爵 · 血契
const LIFESTEAL := 0.01
# 涅墨亚狮皮 · 十二伟业
const ELITE_BONUS := 0.35
# 屠龙者 · 龙血
const SCALE_EVERY := 20.0
# 黄风大王 · 三昧神风
const STORM_EVERY := 5.0
const STORM_RANGE := 300.0
const STORM_MAX := 2
# 圣杯骑士 · 无瑕
const FLAWLESS_BONUS := 0.4
# 莲花化身 · 三头八臂
const LOTUS_CHANCE := 0.2
const LOTUS_FX_EVERY := 0.25   # 莲花特效最多这么久放一次，免得满屏都是

static var active: SetEffects  # 本局生效的套装效果，没有就是 null

var set_id := ""
var player: Player
var _back: Node2D    # 画在身体后面的特效
var _front: Node2D   # 画在身体前面的特效
var _thorn_cd := 0.0
var _mengzhi := 0
var _mengzhi_time := 0.0
var _scale_time := SCALE_EVERY
var _scale_fx: Strip
var _storm_time := STORM_EVERY
var _storms: Array[Sandstorm] = []
var _echoing := false
var _lotus_fx_cd := 0.0
var _guardian: Guardian


func _ready() -> void:
	player = get_parent() as Player
	active = self
	_back = Node2D.new()
	player.add_child.call_deferred(_back)
	player.move_child.call_deferred(_back, 0)
	_front = Node2D.new()
	add_child(_front)
	if set_id == "valhalla":
		_guardian = Guardian.new()
		_guardian.player = player
		_guardian.position = player.position + Vector2(-50, 0)
		player.get_parent().add_child.call_deferred(_guardian)


func _exit_tree() -> void:
	if active == self:
		active = null


func _process(delta: float) -> void:
	_thorn_cd = maxf(0.0, _thorn_cd - delta)
	_lotus_fx_cd = maxf(0.0, _lotus_fx_cd - delta)
	if player.is_dead:
		return
	match set_id:
		"xingtian":
			if _mengzhi > 0:
				_mengzhi_time -= delta
				if _mengzhi_time <= 0.0:
					_mengzhi -= 1
					_mengzhi_time = MENGZHI_DECAY
		"dragonslayer":
			if _scale_time > 0.0:
				_scale_time -= delta
				if _scale_time <= 0.0:
					_scale_fx = _body_fx("scale", _front, true)
					Audio.sfx("pickup_xp", -8.0)
		"yellowwind":
			_storm_time -= delta
			_storms = _storms.filter(func(storm: Sandstorm) -> bool: return is_instance_valid(storm) and not storm.ending)
			if _storm_time <= 0.0:
				_storm_time = STORM_EVERY
				if _storms.size() < STORM_MAX:
					var storm := Sandstorm.new()
					storm.player = player
					storm.position = Game.clamp_to_map(player.position + Vector2.from_angle(randf() * TAU) * randf() * STORM_RANGE, 40.0)
					player.get_parent().add_child(storm)
					_storms.append(storm)


# ---------------------------------------------------------------- 打别人

## 敌人受到伤害之前：返回套装加成之后的伤害（十二伟业、无瑕）
func modify_damage(enemy: Enemy, amount: float) -> float:
	match set_id:
		"nemean":
			if enemy.is_elite or enemy is Boss:
				amount *= 1.0 + ELITE_BONUS
		"grail":
			if player.hp >= player.max_hp:
				amount *= 1.0 + FLAWLESS_BONUS
	return amount


## 敌人受到伤害之后。dealt 是实际扣掉的血，incoming 是这次攻击原本的伤害（加成、暴击之前），quiet = 持续伤害
func on_damage_dealt(enemy: Enemy, dealt: float, incoming: float, knockback: Vector2, quiet: bool) -> void:
	match set_id:
		"nightcount":
			if not player.is_dead:
				player.heal(dealt * LIFESTEAL)
		"lotus":
			# 持续伤害、追加的那一下自己、大招期间都不触发
			if quiet or _echoing or is_instance_valid(player.active_ultimate) or randf() >= LOTUS_CHANCE:
				return
			_echo.call_deferred(enemy, incoming, knockback * 0.5)
			if _lotus_fx_cd <= 0.0:
				_lotus_fx_cd = LOTUS_FX_EVERY
				_body_fx("lotus", _back)


func _echo(enemy: Enemy, amount: float, knockback: Vector2) -> void:
	if not is_instance_valid(enemy) or enemy._dead:
		return
	_echoing = true
	enemy.take_damage(amount, knockback)
	_echoing = false


# ---------------------------------------------------------------- 挨打

## 玩家要掉血之前：返回套装处理之后的伤害，0 表示这一下被完全挡掉了。source 是打人的敌人（不知道就是 null）
func on_player_hit(amount: float, source: Node2D) -> float:
	match set_id:
		"dragonslayer":
			# 和守护符文一样只挡普通伤害；吞噬这种按最大生命算的致命判定仍然要躲
			if _scale_time <= 0.0 and amount < player.max_hp:
				_scale_time = SCALE_EVERY
				if is_instance_valid(_scale_fx):
					_scale_fx.queue_free()
				_body_fx("shatter", _front)
				Audio.sfx("pickup_xp", -4.0)
				FxLayer.floating_text(player.global_position + Vector2(0, -98), tr("龙鳞抵挡"), Color(0.5, 0.85, 0.6))
				return 0.0
		"xingtian":
			if amount < player.max_hp:
				amount *= 1.0 - MENGZHI_PER_STACK * _mengzhi
			_mengzhi = mini(MENGZHI_MAX, _mengzhi + 1)
			_mengzhi_time = MENGZHI_HOLD
			_body_fx("mengzhi", _back)
		"thornoath":
			if _thorn_cd <= 0.0:
				_thorn_cd = THORN_COOLDOWN
				_thorns(amount, source)
	return amount


## 荆棘反刺：反刺攻击者（受到的伤害 ×3 + 武器伤害），再把身边一圈敌人推开
func _thorns(taken: float, source: Node2D) -> void:
	var at := player.global_position
	var target := source as Enemy
	if not is_instance_valid(target) or target._dead:
		target = null
		var best := THORN_SEEK
		for enemy in Enemy.query_radius(at, THORN_SEEK):
			var d := enemy.global_position.distance_to(at) - enemy.radius
			if not enemy._dead and d < best:
				best = d
				target = enemy
	_world_fx("thorn_burst", player.position, -1)
	Audio.sfx("katana_slash", -6.0)
	if target:
		_world_fx("thorn_stab", target.position + Vector2(0, target.radius * 0.6), 1)
		target.take_damage(minf(taken, player.max_hp) * THORN_MULT + player.weapon_damage(), at.direction_to(target.global_position) * 200.0)
	for enemy in Enemy.query_radius(at, THORN_RADIUS):
		if not enemy._dead:
			enemy.take_damage(0.0, at.direction_to(enemy.global_position) * THORN_PUSH)


# ---------------------------------------------------------------- 其他接入点

## 基础武器冷却的倍率（狂暴：每损失 1% 生命，出手速度 +1%）
func weapon_cooldown_mult() -> float:
	if set_id != "bearskin":
		return 1.0
	return 1.0 / (1.0 + clampf(1.0 - player.hp / player.max_hp, 0.0, 1.0))


## 血条旁边的套装图标怎么画：text 是图标上的小字（层数、秒数），lit = false 时图标变灰
func hud_state() -> Dictionary:
	var state := {"set": set_id, "text": "", "lit": true}
	match set_id:
		"xingtian":
			state.text = str(_mengzhi) if _mengzhi > 0 else ""
			state.lit = _mengzhi > 0
		"dragonslayer":
			state.lit = _scale_time <= 0.0
			state.text = "" if state.lit else str(ceili(_scale_time))
		"grail":
			state.lit = player.hp >= player.max_hp
		"bearskin":
			var bonus := roundi(100.0 * clampf(1.0 - player.hp / player.max_hp, 0.0, 1.0))
			state.text = "+%d%%" % bonus if bonus > 0 else ""
	return state


# ---------------------------------------------------------------- 特效

## 贴在身体上的特效（和角色帧同一个中心、同一个缩放）
func _body_fx(id: String, layer: Node2D, loop: bool = false) -> Strip:
	var fx := Strip.create(id, loop)
	var sprite: Node2D = player._sprite
	if sprite:
		fx.position = sprite.position
		fx.scale = sprite.scale.abs()
	layer.add_child(fx)
	return fx


## 落在地上的特效（按 1× 画，和判定范围对得上）
func _world_fx(id: String, at: Vector2, z: int) -> void:
	var fx := Strip.create(id, false)
	fx.position = at
	fx.z_index = z
	player.get_parent().add_child(fx)


## 播放一条横向帧条：播完自己消失，loop = true 时一直循环
class Strip extends Node2D:
	var texture: Texture2D
	var frame_size := Vector2(64, 64)
	var frames := 1
	var fps := 12.0
	var anchor := Vector2.ZERO
	var loop := false
	var time := 0.0

	static func create(id: String, looping: bool) -> Strip:
		var info: Array = SetEffects.STRIPS[id]
		var fx := Strip.new()
		fx.texture = load(SetEffects.FX_DIR + str(info[0]) + ".png")
		fx.frame_size = info[1]
		fx.frames = info[2]
		fx.fps = info[3]
		fx.anchor = info[4]
		fx.loop = looping
		fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return fx

	func _process(delta: float) -> void:
		time += delta
		if not loop and time * fps >= frames:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var frame := int(time * fps) % frames
		draw_texture_rect_region(texture, Rect2(-anchor, frame_size), Rect2(Vector2(frame * frame_size.x, 0), frame_size))


## 三昧神风的沙尘暴：卷起 → 游走 4 秒 → 散开。卷进去的敌人每 0.5 秒受到武器伤害的一半并减速
class Sandstorm extends Node2D:
	const DURATION := 4.0
	const RADIUS := 48.0
	const TICK := 0.5
	const DAMAGE := 0.5
	const SLOW := 0.3
	const WANDER_SPEED := 36.0

	var player: Player
	var ending := false
	var _life := DURATION
	var _tick := 0.0
	var _heading := randf() * TAU
	var _fx: Strip

	func _ready() -> void:
		z_index = -1  # 在角色和敌人脚下
		_fx = Strip.create("storm_start", false)
		add_child(_fx)

	func _process(delta: float) -> void:
		if ending:
			if not is_instance_valid(_fx):
				queue_free()
			return
		if not is_instance_valid(_fx):  # 卷起播完，换成循环
			_fx = Strip.create("storm", true)
			add_child(_fx)
		_life -= delta
		_heading += randf_range(-1.5, 1.5) * delta
		position = Game.clamp_to_map(position + Vector2.from_angle(_heading) * WANDER_SPEED * delta, RADIUS)
		_tick -= delta
		if _tick <= 0.0 and is_instance_valid(player):
			_tick = TICK
			for enemy in Enemy.query_radius(global_position, RADIUS):
				if not enemy._dead:
					enemy.apply_slow(SLOW, TICK + 0.1)
					enemy.take_dot(player.weapon_damage() * DAMAGE)
		if _life <= 0.0:
			ending = true
			_fx.queue_free()
			_fx = Strip.create("storm_end", false)
			add_child(_fx)


## 英灵分身：一直跟在玩家身边，追砍玩家身边 220 像素内的敌人，每一下是玩家武器伤害的一半，出手和玩家的武器一样快
## 不会受伤（敌人根本不把它当目标）
class Guardian extends Node2D:
	const IDLE := preload("res://assets/sprites/allies/valhalla_guardian_idle.png")
	const ATTACK := preload("res://assets/sprites/allies/valhalla_guardian_attack.png")
	const FRAME := Vector2(64, 64)
	const FOOT := Vector2(32, 55)
	const SEEK := 220.0
	const DAMAGE := 0.5
	const SPEED := 300.0
	const FOLLOW := 56.0
	const REACH := 34.0
	const SWING_RADIUS := 46.0
	const ATTACK_FRAMES := 6
	const ATTACK_FPS := 16.0

	var player: Player
	var _time := 0.0
	var _swing_cd := 0.0
	var _swing_t := -1.0   # 出手动作播到哪了，小于 0 表示没在出手
	var _hit_done := true
	var _dir := Vector2.RIGHT
	var _ring: Strip

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		scale = Vector2.ONE * Player.SPRITE_HEIGHT / FRAME.y * SpriteVisual.ACTOR_SCALE  # 和玩家的身体帧一样大
		_ring = Strip.create("ring", true)
		_ring.show_behind_parent = true
		add_child(_ring)
		FxLayer.burst(global_position, Color(0.85, 0.88, 0.92), 24, 200.0)

	func _process(delta: float) -> void:
		if not is_instance_valid(player):
			queue_free()
			return
		_time += delta
		_swing_cd -= delta
		var foe := _nearest_enemy()
		var goal := player.global_position + Vector2.from_angle(_time * 0.6 + PI) * FOLLOW
		if foe:
			goal = foe.global_position + foe.global_position.direction_to(global_position) * (REACH * 0.6 + foe.radius * 0.5)
		position = Game.clamp_to_map(position.move_toward(goal, SPEED * delta), 12.0)
		if foe and _swing_t < 0.0 and _swing_cd <= 0.0 and global_position.distance_to(foe.global_position) < REACH + foe.radius:
			_swing_cd = maxf(0.25, player.weapon_interval())
			_swing_t = 0.0
			_hit_done = false
			_dir = global_position.direction_to(foe.global_position)
		if _swing_t >= 0.0:
			_swing_t += delta
			if not _hit_done and _swing_t * ATTACK_FPS >= 3.0:  # 第 4 帧是挥到最前面的那一下
				_hit_done = true
				var at := global_position + _dir * 24.0
				Enemy.damage_in_radius(get_tree(), at, SWING_RADIUS, player.weapon_damage() * DAMAGE, 120.0)
				FxLayer.mark(at, _dir.angle(), 52.0, Color(0.86, 0.9, 0.95))
			if _swing_t * ATTACK_FPS >= ATTACK_FRAMES:
				_swing_t = -1.0
		elif foe == null and player.facing.x != 0.0:
			_dir = Vector2(signf(player.facing.x), 0)
		queue_redraw()

	func _nearest_enemy() -> Enemy:
		var best: Enemy = null
		var best_d := INF
		for enemy in Enemy.query_radius(player.global_position, SEEK):
			if enemy._dead:
				continue
			var d := enemy.global_position.distance_squared_to(global_position)
			if d < best_d:
				best_d = d
				best = enemy
		return best

	func _draw() -> void:
		var strip := IDLE
		var frame := int(_time * 8.0) % 4
		if _swing_t >= 0.0:
			strip = ATTACK
			frame = mini(ATTACK_FRAMES - 1, int(_swing_t * ATTACK_FPS))
		var flip := _dir.x < 0.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
		draw_texture_rect_region(strip, Rect2(-FOOT, FRAME), Rect2(Vector2(frame * FRAME.x, 0), FRAME))
		draw_set_transform(Vector2.ZERO)
