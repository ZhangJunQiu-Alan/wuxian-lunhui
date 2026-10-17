class_name Skoll
extends Boss
## 斯库尔 · 追日之狼（篇章一 第 1 关 05:00）
## 技能：
##   扑咬冲锋：锁定方向，红色预警后高速直线冲刺（侧移就能躲开）
##   吞日：战斗越久画面越暗、视野越小；击败斯库尔后光明恢复
##   狼群呼唤：血量低于 50% 时立刻召唤一次，之后每 20 秒一次；半血后冲锋前摇变短

const CHASE_TIME := 2.2       # 两次冲锋之间追击多久
const WINDUP_TIME := 0.9      # 冲锋前摇（预警）时间
const WINDUP_TIME_ENRAGED := 0.6
const DASH_SPEED := 950.0
const DASH_TIME := 0.42
const DASH_DAMAGE := 25.0
const RECOVER_TIME := 0.7     # 冲锋后的硬直，输出窗口
const HOWL_EVERY := 20.0
const HOWL_WOLVES := 6
const DARKEN_TIME := 60.0     # 多少秒内画面暗到最深

var _dash_dir := Vector2.RIGHT
var _darkness: Darkness
var _fight_time := 0.0
var _enraged := false
var _howl_timer := 0.0


func _init() -> void:
	intro_line = tr("斯库尔 · 追日之狼 —— 它追上了太阳")
	defeat_line = tr("「太阳……还是逃走了吗……」")


func init_stats(hp_scale: float) -> void:
	setup_boss("skoll", tr("斯库尔"), tr("追日之狼"), 650.0, hp_scale, 34.0, 150.0, 15.0)
	gait = "quad"
	color = Color(0.55, 0.5, 0.62)
	state_actions = {"howl": &"windup"}


func _ready() -> void:
	super._ready()
	_darkness = Darkness.new()
	get_parent().add_child.call_deferred(_darkness)
	change_state("chase")


func _update_state(delta: float) -> void:
	_fight_time += delta
	if is_instance_valid(_darkness):
		_darkness.target_level = minf(1.0, _fight_time / DARKEN_TIME)

	if not _enraged and hp < max_hp * 0.5:
		_enraged = true
		change_state("howl")
		return
	if _enraged:
		_howl_timer -= delta

	match state:
		"chase":
			chase(delta)
			if state_time >= CHASE_TIME:
				_dash_dir = global_position.direction_to(target.global_position)
				change_state("windup")
		"windup":
			if state_time >= (WINDUP_TIME_ENRAGED if _enraged else WINDUP_TIME):
				change_state("dash")
		"dash":
			position += _dash_dir * DASH_SPEED * delta
			if global_position.distance_to(target.global_position) < radius + Player.RADIUS:
				target.take_damage(DASH_DAMAGE)
			if state_time >= DASH_TIME:
				change_state("recover")
		"recover":
			if state_time >= RECOVER_TIME:
				change_state("howl" if _enraged and _howl_timer <= 0.0 else "chase")
		"howl":
			if state_time >= 0.6 and _howl_timer <= 0.0:
				_summon_wolves()
			if state_time >= 1.2:
				change_state("chase")


func _summon_wolves() -> void:
	_howl_timer = HOWL_EVERY
	target.shake(5.0, 0.3)
	for i in HOWL_WOLVES:
		var pos := global_position + Vector2.from_angle(TAU * i / HOWL_WOLVES) * (radius + 40.0)
		spawner.call("wolf", pos)


func _die() -> void:
	if is_instance_valid(_darkness):
		_darkness.target_level = 0.0  # 光明恢复
	super._die()


func _draw_telegraph() -> void:
	match state:
		"windup":
			# 冲锋路线：红色长条，越接近冲刺越亮
			var t := state_time / (WINDUP_TIME_ENRAGED if _enraged else WINDUP_TIME)
			draw_line_telegraph(self, _dash_dir, DASH_SPEED * DASH_TIME + radius, radius, t)
		"howl":
			# 嚎叫：向外扩散的声波圈
			var r := radius + state_time * 160.0
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.9, 0.85, 1.0, maxf(0.0, 0.8 - state_time * 0.6)), 4.0)
