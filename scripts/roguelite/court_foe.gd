class_name CourtFoe
extends Enemy
## 冻石庭院的尸鬼和冰霜精魂（3D 模型由 courtyard_enemy_3d.gd 跟着播动作）。和像素关卡的敌人分开写，2026-11-21 按用户选的方案：
## - 尸鬼：远了向前垫步突刺，贴身就横扫；平时挨一刀踉跄 0.3 s，出招时霸体；连挨 3 刀跪地 1 s，这期间受到的伤害 +50%。
## - 精魂：被近身就往后飘开 2 m（之后 5 秒内不再飘，追得上）；冰锥（地上有瞄准线，出手前 0.15 s 锁定方向）和脚下冰刺轮流放。
## - 只有招式打中才掉血，身体碰到不算。
## 出招的时长、出手时刻、距离由 3D 模型按动作量好后填进 moves（Enemy3D.configure）。

signal spike_cast(at: Vector2, radius: float, delay: float, damage: float)  # 冰刺：庭院画预警圈，delay 秒后冒出来结算伤害

const HP := {"draugr": 80.0, "ice_spirit": 40.0}  # 太刀一刀 22：尸鬼 4 刀、精魂 2 刀
const LUNGE := 60.0  # 突刺时向前垫步 0.6 米
const LUNGE_STOP := 110.0  # 垫步不会冲到离玩家比这更近
const SWEEP_RANGE := 130.0  # 玩家贴到这个距离内就横扫，不刺
const STAGGER_TIME := 0.3
const POISE := 3  # 连挨几刀跪地
const POISE_RESET := 2.0  # 这么久没挨刀，连击数清零
const KNEEL_TIME := 1.0
const KNEEL_BONUS := 0.5
const DRIFT_TRIGGER := 200.0  # 玩家近到 2 m 内，精魂往后飘
const DRIFT_DISTANCE := 200.0
const DRIFT_TIME := 0.7
const DRIFT_COOLDOWN := 5.0  # 用户 2026-11-21：飘完 5 秒内不再飘
const AIM_LOCK := 0.15  # 冰锥出手前这么久锁定方向
const SPIKE_DELAY := 0.8
const SPIKE_RADIUS := 52.0
const SPELL_GAP := 1.9  # 精魂两次施法之间
const BOLT_SPEED := 1.2  # 冰锥比普通冰棱快 1.2 倍（用户 2026-11-21）

## 招式：time 总时长、strike 出手时刻（秒）；thrust 另有 reach 矛尖距离、lunge 垫步的起止时刻；sweep 有 radius、arc（半角）
var moves := {
	"thrust": {"time": 0.92, "strike": 0.57, "reach": 191.0, "lunge": Vector2(0.36, 0.57), "rest": 1.0},
	"sweep": {"time": 1.12, "strike": 0.56, "radius": 152.0, "arc": 1.2, "rest": 1.1},
	"bolt": {"time": 0.95, "strike": 0.6, "rest": SPELL_GAP},
	"spike": {"time": 0.9, "strike": 0.55, "rest": SPELL_GAP},
}
var action := ""  # 正在出的招：thrust / sweep（尸鬼），bolt / spike（精魂）
var action_time := 0.0
var aim := Vector2.RIGHT
var kneeling := false
var stagger := 0.0  # 踉跄或跪地的剩余时间
var drift := 0.0  # 正在往后飘的剩余时间
var _struck := false
var _lunge := 0.0
var _poise := 0
var _poise_time := 0.0
var _drift_cd := 0.0
var _drift_dir := Vector2.ZERO
var _next_spell := "bolt"
var _spell_cd := randf_range(0.6, 1.4)


func setup(id: String, hp_scale: float, elite: bool = false, damage_scale: float = 1.0) -> void:
	super.setup(id, hp_scale, elite, damage_scale)
	max_hp = HP.get(id, max_hp) * hp_scale
	hp = max_hp
	_attack_cd = randf_range(0.3, 0.9)


func reach() -> float:
	return moves.thrust.reach + LUNGE


## 出招进度 0 → 1（到出手那一刻为 1），3D 模型拿来亮冰光、画瞄准线
func charge() -> float:
	if action == "":
		return 0.0
	return clampf(action_time / moves[action].strike, 0.0, 1.0)


func aim_locked() -> bool:
	return action == "bolt" and action_time >= moves.bolt.strike - AIM_LOCK


func _physics_process(delta: float) -> void:
	_flash_time = maxf(0.0, _flash_time - delta)
	_squash_time = maxf(0.0, _squash_time - delta)
	_tick_statuses(delta)
	if _dead or not is_instance_valid(target):
		return
	if _frozen_time > 0.0:
		_frozen_time -= delta
		return
	if has_status("charm"):
		_charmed_move(delta)
		return
	_hit_slow_time -= delta
	if _hit_slow_time <= 0.0:
		_hit_slow = 0.0
	_poise_time -= delta
	if _poise_time <= 0.0:
		_poise = 0
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	var dir := to_target / dist if dist > 0.01 else aim
	var velocity := Vector2.ZERO
	if stagger > 0.0:
		stagger -= delta
		if stagger <= 0.0:
			kneeling = false
	elif type_id == "draugr":
		velocity = _lancer(dir, dist, delta)
	else:
		velocity = _caster(dir, dist, delta)
	position += velocity * delta + _knockback * delta + _separation()
	_knockback *= exp(-KNOCKBACK_DECAY * delta)
	position = MapLayer.push_out(Game.clamp_to_map(position, radius), radius)


# ———— 尸鬼 ————

func _lancer(dir: Vector2, dist: float, delta: float) -> Vector2:
	_attack_cd -= delta
	if action != "":
		return _advance(delta)
	if _attack_cd <= 0.0:
		if dist < SWEEP_RANGE:
			_begin("sweep", dir)
			return Vector2.ZERO
		if dist < reach() * 0.97:
			_lunge = clampf(dist - LUNGE_STOP, 0.0, LUNGE)
			_begin("thrust", dir)
			return Vector2.ZERO
	if dist > reach() * 0.9:  # 端着矛走到垫步一刺刚好够得着的地方
		return dir * speed * move_mult()
	return Vector2.ZERO


func _begin(id: String, dir: Vector2) -> void:
	action = id
	action_time = 0.0
	aim = dir
	_struck = false


func _advance(delta: float) -> Vector2:
	var move: Dictionary = moves[action]
	var before := action_time
	action_time += delta
	var velocity := Vector2.ZERO
	if action == "thrust" and delta > 0.0:  # 垫步：先快后慢地往前送 0.6 m
		var window: Vector2 = move.lunge
		var a := _ease_out(inverse_lerp(window.x, window.y, clampf(before, window.x, window.y)))
		var b := _ease_out(inverse_lerp(window.x, window.y, clampf(action_time, window.x, window.y)))
		velocity = aim * _lunge * (b - a) / delta
	if action == "bolt" and not aim_locked() and is_instance_valid(target):
		aim = global_position.direction_to(target.global_position)
	if not _struck and action_time >= move.strike:
		_struck = true
		_strike_move()
	if action_time >= move.time:
		if type_id == "draugr":
			_attack_cd = move.rest * randf_range(0.85, 1.15)
		else:
			_spell_cd = move.rest * randf_range(0.85, 1.15)
		action = ""
	return velocity


static func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


func _strike_move() -> void:
	if not is_instance_valid(target):
		return
	var at := target.global_position
	match action:
		"thrust":  # 玩家在矛杆这条线上（从身前到矛尖）就挨这一下；方向在起手时锁定，躲开就没事
			var tip: Vector2 = global_position + aim * moves.thrust.reach
			if Geometry2D.get_closest_point_to_segment(at, global_position, tip).distance_to(at) <= Player.RADIUS + 8.0:
				target.take_damage(contact_damage, self)
		"sweep":  # 身前一大片扇形
			var offset := at - global_position
			if offset.length() <= moves.sweep.radius + Player.RADIUS and absf(aim.angle_to(offset)) <= moves.sweep.arc:
				target.take_damage(contact_damage, self)
		"bolt":
			var shot := EnemyProjectile.spawn(get_parent(), global_position, aim, projectile_damage)
			shot.speed = (projectile_speed if projectile_speed > 0.0 else shot.speed) * BOLT_SPEED
			Audio.sfx("ice_shot", -4.0)
		"spike":
			spike_cast.emit(at, SPIKE_RADIUS, SPIKE_DELAY, projectile_damage)
			Audio.sfx("ice_shot", -8.0)


## 挨刀：尸鬼平时踉跄（打断走路，不打断出招），连挨 3 刀跪地；跪着时伤害 +50%
func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, crit: bool = false) -> void:
	if _dead:
		return
	if kneeling and amount > 0.0:
		amount *= 1.0 + KNEEL_BONUS
	super.take_damage(amount, knockback, crit)
	if _dead or amount <= 0.0 or _quiet or type_id != "draugr" or kneeling:
		return
	_poise += 1
	_poise_time = POISE_RESET
	if _poise >= POISE:
		_poise = 0
		kneeling = true
		stagger = KNEEL_TIME
		action = ""
		_attack_cd = maxf(_attack_cd, 0.35)
	elif action == "":
		stagger = maxf(stagger, STAGGER_TIME)


# ———— 冰霜精魂 ————

func _caster(dir: Vector2, dist: float, delta: float) -> Vector2:
	_drift_cd -= delta
	if drift > 0.0:
		var before := 1.0 - drift / DRIFT_TIME
		drift -= delta
		var after := 1.0 - maxf(drift, 0.0) / DRIFT_TIME
		return _drift_dir * DRIFT_DISTANCE * (_ease_out(after) - _ease_out(before)) / maxf(delta, 0.0001)
	if action != "":
		return _advance(delta)
	if dist < DRIFT_TRIGGER and _drift_cd <= 0.0:
		_drift_dir = _escape(-dir)
		drift = DRIFT_TIME
		_drift_cd = DRIFT_COOLDOWN
		return Vector2.ZERO
	if dist <= shoot_range:
		_spell_cd -= delta
		if _spell_cd <= 0.0:
			_begin(_next_spell, dir)
			_next_spell = "spike" if _next_spell == "bolt" else "bolt"
			return Vector2.ZERO
	if dist > shoot_range * 0.9:
		return dir * speed * move_mult()
	return Vector2.ZERO


## 往后飘的方向：正后方被墙挡住时往两侧偏
func _escape(away: Vector2) -> Vector2:
	for turn: float in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5]:
		var direction := away.rotated(turn)
		var end := global_position + direction * DRIFT_DISTANCE
		if MapLayer.push_out(Game.clamp_to_map(end, radius), radius).distance_to(end) < 30.0:
			return direction
	return away
