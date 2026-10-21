class_name Skoll
extends Boss
## 斯库尔 · 追日之狼（篇章一 第 1 关 03:00）
## 技能：
##   扑咬冲锋：短促侧向绕位，锁定方向，红色预警后高速直线冲刺
##   吞日：开场狼嚎后迅速压缩视野；击败斯库尔后光明恢复
##   狼群呼唤：半血后每 14 秒召唤 10 只强化冬狼；半血后绕位和冲锋前摇变短

const STALK_TIME := 0.85
const STALK_TIME_ENRAGED := 0.55
const STALK_DISTANCE := 280.0
const STALK_SPEED := 1.65
const WINDUP_TIME := 0.9      # 冲锋前摇（预警）时间
const WINDUP_TIME_ENRAGED := 0.6
const DASH_SPEED := 950.0
const DASH_TIME := 0.42
const DASH_DAMAGE := 25.0
const RECOVER_TIME := 0.7     # 冲锋后的恢复间歇，半速追击
const HOWL_EVERY := 14.0
const HOWL_WOLVES := 10
const HOWL_RELEASE := 0.6
const HOWL_TIME := 1.2
const WOLF_HP_MULT := 1.5
const WOLF_DAMAGE_MULT := 1.4
const WOLF_SPEED_MULT := 1.1

var _dash_dir := Vector2.RIGHT
var _darkness: Darkness
var _stalk_side := 1.0
var _eclipse_cast := false
var _enraged := false
var _howl_timer := 0.0
var _bite_shown := false


func _init() -> void:
	intro_line = tr("斯库尔 · 追日之狼 —— 它追上了太阳")
	defeat_line = tr("「太阳……还是逃走了吗……」")


func init_stats(hp_scale: float) -> void:
	setup_boss("skoll", tr("斯库尔"), tr("追日之狼"), 650.0, hp_scale, 34.0, 150.0, 15.0)
	gait = "quad"
	color = Color(0.55, 0.5, 0.62)
	state_actions = {"howl": &"howl", "eclipse_howl": &"howl", "stalk": &"move"}


func _ready() -> void:
	super._ready()
	_darkness = Darkness.new()
	get_parent().add_child.call_deferred(_darkness)
	change_state("eclipse_howl")


func _update_state(delta: float) -> void:
	if not _enraged and hp < max_hp * 0.5:
		_enraged = true
		change_state("howl")
		return
	if _enraged:
		_howl_timer -= delta

	match state:
		"stalk":
			var to_player := global_position.direction_to(target.global_position)
			if to_player == Vector2.ZERO:
				to_player = _dash_dir
			var distance := global_position.distance_to(target.global_position)
			var approach := clampf((distance - STALK_DISTANCE) / 120.0, -0.75, 0.75)
			var direction := (to_player * approach + to_player.orthogonal() * _stalk_side).normalized()
			position += direction * speed * STALK_SPEED * move_mult() * delta
			if state_time >= (STALK_TIME_ENRAGED if _enraged else STALK_TIME):
				_dash_dir = global_position.direction_to(target.global_position)
				change_state("windup")
		"windup":
			if state_time >= (WINDUP_TIME_ENRAGED if _enraged else WINDUP_TIME):
				_bite_shown = false
				change_state("dash")
		"dash":
			position += _dash_dir * DASH_SPEED * delta
			if global_position.distance_to(target.global_position) < radius + Player.RADIUS:
				target.take_damage(DASH_DAMAGE)
				if not _bite_shown:
					_bite_shown = true
					BossFx.play("skoll_bite", target.global_position, _dash_dir.angle())
			if state_time >= DASH_TIME:
				change_state("recover")
		"recover":
			if state_time >= RECOVER_TIME:
				if _enraged and _howl_timer <= 0.0:
					change_state("howl")
				else:
					_start_stalk()
		"howl", "eclipse_howl":
			if state_time >= HOWL_RELEASE:
				if not _eclipse_cast and is_instance_valid(_darkness):
					_darkness.target_level = 1.0
					_eclipse_cast = true
				if state == "howl" and _howl_timer <= 0.0:
					_summon_wolves()
			if state_time >= HOWL_TIME:
				_start_stalk()


func _start_stalk() -> void:
	_stalk_side = -_stalk_side
	change_state("stalk")


func _summon_wolves() -> void:
	_howl_timer = HOWL_EVERY
	target.shake(5.0, 0.3)
	for i in HOWL_WOLVES:
		var pos := global_position + Vector2.from_angle(TAU * i / HOWL_WOLVES) * (radius + 40.0)
		var wolf = spawner.call("wolf", pos)
		if is_instance_valid(wolf):
			wolf.max_hp *= WOLF_HP_MULT
			wolf.hp = wolf.max_hp
			wolf.contact_damage *= WOLF_DAMAGE_MULT
			wolf.speed *= WOLF_SPEED_MULT


func _die() -> void:
	if is_instance_valid(_darkness):
		_darkness.target_level = 0.0  # 光明恢复
	super._die()


func _draw_telegraph() -> void:
	match state:
		"dash":
			BossFx.draw(self, "skoll_dash_trail", state_time, -_dash_dir * radius * 0.5, _dash_dir.angle())
		"windup":
			# 冲锋路线：红色长条，越接近冲刺越亮
			var t := state_time / (WINDUP_TIME_ENRAGED if _enraged else WINDUP_TIME)
			draw_line_telegraph(self, _dash_dir, DASH_SPEED * DASH_TIME + radius, radius, t)
		"howl", "eclipse_howl":
			# 嚎叫：向外扩散的声波圈
			var r := radius + state_time * 160.0
			if BossFx.texture("skoll_howl") == null:
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.9, 0.85, 1.0, maxf(0.0, 0.8 - state_time * 0.6)), 4.0)
			elif state_time >= HOWL_RELEASE and state_time < 1.1:
				BossFx.draw(self, "skoll_howl", state_time - HOWL_RELEASE, Vector2.ZERO, 0.0,
					Vector2.ONE * r / 62.0, Color.WHITE, false, 0.0, PI, false)
