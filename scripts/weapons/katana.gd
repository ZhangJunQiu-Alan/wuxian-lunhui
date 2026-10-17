class_name Katana
extends Node2D
## 太刀：朝面向方向挥出扇形斩击，命中范围内所有敌人
## 画面：一道刀光从扇形一侧扫到另一侧（每刀换方向，素材 4 帧），命中的敌人身上留下刀痕

const SLASH := preload("res://assets/sprites/effects/katana_slash.png")
const SLASH_REACH := 58.0  # 刀光素材从中心到外缘的像素数，按攻击范围缩放
const SLASH_DURATION := 0.24
const HALF_ARC := 1.05  # 扇形半角（弧度），约 60°，整个扇形 120°
const HAMSTRING_TIME := 2.0  # 断筋减速持续的秒数

var damage := 14.0
var cooldown := 1.0
var reach := 110.0
var back_slash := false  # 回身斩：同时斩向身后
var knockback := 260.0
var hamstring := 0.0  # 断筋：砍中的敌人减速这么多（0.2 = 移速 -20%）
var player: Player
var _timer := 0.3
var _slash_count := 0
var _niten := false  # 这一刀是否触发了二刀流
var _slash_time := 0.0
var _slash_dirs: Array[Vector2] = []
var _sweep_sign := 1.0  # 刀光扫动方向，每刀交替


func _ready() -> void:
	player = get_parent() as Player
	z_index = 1  # 刀光画在敌人上面


func _process(delta: float) -> void:
	if _slash_time > 0.0:
		_slash_time -= delta
		queue_redraw()
	_timer -= delta
	if _timer > 0.0:
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	var target := _nearest_in_reach(enemies)
	if target == null:
		return  # 攻击范围内没有敌人就不出刀，冷却保持就绪，敌人一进入范围立刻出刀
	_timer = cooldown * player.weapon_cooldown()
	_slash(enemies, target)


func _slash(enemies: Array[Node], target: Enemy) -> void:
	var aim := global_position.direction_to(target.global_position)
	if aim == Vector2.ZERO:
		aim = player.facing
	# 剑士的被动「二刀流」：每第 4 刀变为双刀斩，前后同时斩击，伤害翻倍
	_slash_count += 1
	_niten = _slash_count % 4 == 0
	_slash_dirs = [aim]
	if back_slash or _niten:
		_slash_dirs.append(-aim)
	_slash_time = SLASH_DURATION
	_sweep_sign = -_sweep_sign
	player.play_attack(aim, 7.0, _timer)
	Audio.sfx("katana_slash")

	var dmg := damage * player.damage_mult * (2.0 if _niten else 1.0)
	for node in enemies:
		var enemy := node as Enemy
		var offset := enemy.global_position - global_position
		if offset.length() > reach + enemy.radius:
			continue
		for dir in _slash_dirs:
			if absf(dir.angle_to(offset)) <= HALF_ARC:
				enemy.take_damage(dmg, offset.normalized() * knockback, _niten)
				if hamstring > 0.0:
					enemy.apply_slow(hamstring, HAMSTRING_TIME)
				FxLayer.mark(enemy.global_position, dir.angle() + PI * 0.5 * _sweep_sign * 0.6, enemy.radius * 2.0 + 30.0, _tint())
				break


## 找攻击范围内最近的敌人，没有就返回 null
func _nearest_in_reach(enemies: Array[Node]) -> Enemy:
	var nearest: Enemy = null
	var best := INF
	for node in enemies:
		var enemy := node as Enemy
		var d := enemy.global_position.distance_to(global_position) - enemy.radius
		if d <= reach and d < best:
			best = d
			nearest = enemy
	return nearest


func _tint() -> Color:
	return Color(1.0, 0.85, 0.45) if _niten else Color(0.8, 0.9, 1.0)  # 二刀流的刀光是金色


func _draw() -> void:
	if _slash_time <= 0.0:
		return
	var frame := mini(3, int((1.0 - _slash_time / SLASH_DURATION) * 4.0))
	var tint := Color(1.0, 0.85, 0.45, 0.85) if _niten else Color(1, 1, 1, 0.85)
	for dir in _slash_dirs:
		# 淡淡的扇形，提示攻击范围
		var fan := PackedVector2Array([Vector2.ZERO])
		for i in 13:
			fan.append(Vector2.from_angle(dir.angle() - HALF_ARC + HALF_ARC * 2.0 * i / 12.0) * reach)
		draw_colored_polygon(fan, Color(_tint(), 0.1 * _slash_time / SLASH_DURATION))
		SpriteVisual.draw_frame(self, SLASH, 4, frame, Vector2.ZERO, Vector2(64, 64), dir.angle(), Vector2(1.0, _sweep_sign) * reach / SLASH_REACH, tint)
