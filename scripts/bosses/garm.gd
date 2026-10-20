class_name Garm
extends Boss
## 加姆 · 冥府猎犬（篇章一 第 2 关 03:00）
## 技能：
##   血腥撕咬：红色预警后连续三段扑击，每段重新瞄准玩家
##   地狱吠叫：震退身边的玩家，并清除玩家身上的增益（狂野西部秀、入阵曲）
##   锁链：登场时在身边插下 4 根锁桩，被锁链拴着只能在锁桩围出的范围里活动；
##         打断 4 根锁桩后挣脱，变得更快，但受到的伤害增加

const CHASE_TIME := 2.0
const WINDUP_TIME := 0.8
const LUNGES := 3
const LUNGE_SPEED := 820.0
const LUNGE_TIME := 0.24
const LUNGE_PAUSE := 0.22
const LUNGE_DAMAGE := 18.0
const RECOVER_TIME := 0.9
const HOWL_EVERY := 3        # 每几轮撕咬吠叫一次
const HOWL_RADIUS := 260.0
const HOWL_PUSH := 260.0     # 把玩家推出去多远
const HOWL_DAMAGE := 12.0
const STAKE_DISTANCE := 300.0
const CHAIN_RANGE := 420.0   # 被拴着时离锁桩中心最远能走多远
const FREE_SPEED := 1.5
const FREE_DAMAGE_TAKEN := 1.3
const CHAIN_COLOR := Color(0.55, 0.52, 0.5)

var _lunge_dir := Vector2.RIGHT
var _lunges_left := 0
var _rounds := 0
var _anchor := Vector2.ZERO
var _stakes: Array[Enemy] = []
var _free := false
var _bite_shown := false


func _init() -> void:
	intro_line = tr("加姆 · 冥府猎犬 —— 锁链的另一头，是诸神黄昏")
	defeat_line = tr("「提尔……不是你……杀死了我？」")


func init_stats(hp_scale: float) -> void:
	setup_boss("garm", tr("加姆"), tr("冥府猎犬"), 750.0, hp_scale, 34.0, 135.0, 16.0)
	gait = "quad"
	color = Color(0.35, 0.22, 0.22)
	reward_points = 120
	state_actions = {"bark_windup": &"windup", "bark": &"howl"}


func _ready() -> void:
	super._ready()
	_anchor = position
	for i in 4:
		var pos := Game.clamp_to_map(_anchor + Vector2.from_angle(PI / 4 + TAU * i / 4) * STAKE_DISTANCE, 40.0)
		var stake: Enemy = spawner.call("chain_stake", pos, false, true)
		if stake == null:
			continue
		_stakes.append(stake)
		stake.killed.connect(_on_stake_broken)
	change_state("chase")


func _on_stake_broken(stake: Enemy) -> void:
	_stakes.erase(stake)
	BossFx.play("garm_chain_break", stake.global_position)
	Audio.sfx("boss_block")
	FxLayer.floating_text(stake.global_position + Vector2(0, -30), tr("锁桩断了！"), CHAIN_COLOR.lightened(0.4))
	if _stakes.is_empty() and not _free:
		_free = true
		BossFx.play("garm_chain_break", global_position)
		speed *= FREE_SPEED
		Audio.sfx("boss_howl")
		target.shake(8.0, 0.4)
		var game := get_tree().current_scene
		if game.get("hud"):
			game.hud.announce(tr("加姆挣脱了锁链！它更快了，但也更脆弱"))


func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, crit: bool = false) -> void:
	super.take_damage(amount * (FREE_DAMAGE_TAKEN if _free else 1.0), knockback, crit)


func _update_state(delta: float) -> void:
	match state:
		"chase":
			chase(delta)
			if state_time >= CHASE_TIME:
				_rounds += 1
				change_state("bark_windup" if _rounds % HOWL_EVERY == 0 else "lunge_windup")
		"lunge_windup":
			_lunge_dir = global_position.direction_to(target.global_position)
			if state_time >= WINDUP_TIME:
				_lunges_left = LUNGES
				_bite_shown = false
				change_state("lunge")
		"lunge":
			if state_time < LUNGE_TIME:
				position += _lunge_dir * LUNGE_SPEED * delta
				if global_position.distance_to(target.global_position) < radius + Player.RADIUS + 6.0:
					target.take_damage(LUNGE_DAMAGE)
					if not _bite_shown:
						_bite_shown = true
						if not BossFx.play("garm_bite", target.global_position, _lunge_dir.angle()):
							FxLayer.mark(target.global_position, _lunge_dir.angle(), radius * 1.6, Color(1, 0.3, 0.25), "bite")
			elif state_time >= LUNGE_TIME + LUNGE_PAUSE:
				_lunges_left -= 1
				if _lunges_left > 0:
					_bite_shown = false
					_lunge_dir = global_position.direction_to(target.global_position)  # 下一段重新瞄准
					change_state("lunge")
				else:
					change_state("recover")
		"bark_windup":
			if state_time >= WINDUP_TIME:
				_howl()
				change_state("bark")
		"bark":
			if state_time >= 0.8:
				change_state("recover")
		"recover":
			if state_time >= RECOVER_TIME:
				change_state("chase")
	if not _free and position.distance_to(_anchor) > CHAIN_RANGE:  # 被锁链拉住
		position = _anchor + (position - _anchor).normalized() * CHAIN_RANGE


## 地狱吠叫：近身的玩家被震飞并受伤，身上的增益全部消失
func _howl() -> void:
	Audio.sfx("boss_howl")
	play_once(&"howl")
	target.shake(9.0, 0.35)
	if not BossFx.play("garm_howl_wave", global_position, 0.0, Vector2.ONE * HOWL_RADIUS / 62.0,
			Color.WHITE, false, HOWL_RADIUS):
		FxLayer.ring(global_position, HOWL_RADIUS)
	var offset := target.global_position - global_position
	var dispelled := offset.length() < HOWL_RADIUS and (target.frenzy_time > 0.0 or target.shield_time > 0.0)
	if offset.length() < HOWL_RADIUS:
		target.take_damage(HOWL_DAMAGE)
		target.position = MapLayer.push_out(Game.clamp_to_map(target.position + offset.normalized() * HOWL_PUSH, Player.RADIUS), Player.RADIUS)
	if dispelled:
		target.frenzy_time = 0.0
		target.shield_time = 0.0
		BossFx.play("garm_dispel", target.global_position)
		FxLayer.floating_text(target.global_position + Vector2(0, -40), tr("增益被驱散"), Color(0.9, 0.5, 0.5))


func _draw_telegraph() -> void:
	if not _free:  # 锁链：从加姆连到每根锁桩
		for stake in _stakes:
			if is_instance_valid(stake):
				var to := stake.global_position - global_position
				var sag := to.orthogonal().normalized() * 14.0
				var points := PackedVector2Array()
				for i in 11:
					var k := i / 10.0
					points.append(to * k + sag * sin(k * PI))
				if not BossFx.draw_chain(self, points):
					draw_polyline(points, Color(0.1, 0.1, 0.1, 0.7), 5.0)
					draw_polyline(points, CHAIN_COLOR, 2.5)
	match state:
		"lunge_windup":
			draw_line_telegraph(self, _lunge_dir, LUNGE_SPEED * LUNGE_TIME + radius, radius * 0.8, state_time / WINDUP_TIME)
		"bark_windup":
			draw_circle_telegraph(self, Vector2.ZERO, HOWL_RADIUS, state_time / WINDUP_TIME)
