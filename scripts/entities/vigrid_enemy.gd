class_name VigridEnemy
extends Enemy
## 第 3 关的三种普通敌人（亡者直接复用第 2 关的 dead）：
##   火焰巨人 fire_giant      死亡时原地预警一下再爆炸（只炸一次），留下一块火焰地面
##   霜巨人精锐 frost_veteran 定期冲锋（先蓄力、画出路线）；定期举盾，正面挡掉大部分伤害，举盾时转身慢，绕到背后就能打
##   狂狼战士 wolf_berserker  披狼皮的人类，血量低于 40% 时狂暴一次：移速、攻速提高
## 数值都是暂定值，见 VigridTuning

const ACTIONS_BY_ID := {
	"fire_giant": {"move": true, "attack": false},
	"frost_veteran": {"move": true, "attack": false, "charge": true, "shield": false},
	"wolf_berserker": {"move": true, "attack": false, "rage": false},
}
const SHIELD_COLOR := Color(0.75, 0.88, 1.0)

var _charge_cd := randf_range(0.4, 1.0) * VigridTuning.CHARGE_EVERY
var _charge_t := -1.0   # >= 0：正在冲锋（含蓄力），这是已经过去的时间
var _charge_dir := Vector2.RIGHT
var _charge_hit := false
var _shield_cd := randf_range(0.3, 1.0) * VigridTuning.SHIELD_EVERY
var _shield_t := -1.0   # >= 0：正在举盾
var _facing := Vector2.RIGHT
var raged := false
var _rage_pose := 0.0


func _ready() -> void:
	actions = ACTIONS_BY_ID.get(type_id, ACTIONS)
	super._ready()
	var foot: Vector2 = EnemyDB.ALL[type_id].get("foot", Vector2.ZERO)
	if _sprite and foot != Vector2.ZERO:  # 脚锚对齐到 root + (0, FOOT)，不按透明画布的中心猜脚底
		var tex_height := _actions.sprite_frames.get_frame_texture(_actions.animation, 0).get_height() if _actions else (_sprite as Sprite2D).texture.get_height()
		var base_pos := Vector2(0, MapLayer.FOOT + (tex_height - foot.y) * _sprite.scale.y)
		_sprite.position = base_pos
		_sprite.set_meta("base_pos", base_pos)


func _physics_process(delta: float) -> void:
	if _dead or not is_instance_valid(target) or _frozen_time > 0.0 or has_status("charm"):
		_charge_t = -1.0
		_end_shield()
		super._physics_process(delta)
		return
	match type_id:
		"frost_veteran":
			if _update_veteran(delta):
				if _flash_time > 0.0:
					_flash_time -= delta
				_tick_statuses(delta)
				return
		"wolf_berserker":
			_update_berserker(delta)
	super._physics_process(delta)
	if is_shielding() and _sprite:
		_sprite.set("flip_h", _facing.x < 0.0)  # 盾牌朝哪边，身体就朝哪边


# ———— 霜巨人精锐 ————

## 冲锋时自己移动，返回 true（不再走普通追击）
func _update_veteran(delta: float) -> bool:
	var to_player := target.global_position - global_position
	if _charge_t >= 0.0:
		_charge_t += delta
		if _charge_t < VigridTuning.CHARGE_WINDUP:
			_charge_dir = to_player.normalized() if to_player != Vector2.ZERO else _charge_dir  # 蓄力时还在瞄
			_pose(&"charge")
		elif _charge_t < VigridTuning.CHARGE_WINDUP + VigridTuning.CHARGE_TIME:
			position += _charge_dir * speed * VigridTuning.CHARGE_MULT * move_mult() * delta
			if not _charge_hit and to_player.length() < radius + Player.RADIUS + 6.0:
				_charge_hit = true
				target.take_damage(contact_damage * 1.5)
				FxLayer.mark(target.global_position, _charge_dir.angle(), radius * 2.0, Color(0.8, 0.9, 1.0), "claw")
		else:
			_charge_t = -1.0
			_pose(&"move")
			return false
		if _sprite:
			_sprite.set("flip_h", _charge_dir.x < 0.0)
		queue_redraw()
		return true
	if _shield_t >= 0.0:
		_shield_t += delta
		var want := to_player.normalized()
		_facing = _facing.rotated(clampf(_facing.angle_to(want), -VigridTuning.SHIELD_TURN * delta, VigridTuning.SHIELD_TURN * delta))
		_attack_cd = maxf(_attack_cd, 0.2)  # 举盾时不出手
		if _shield_t >= VigridTuning.SHIELD_TIME:
			_end_shield()
		queue_redraw()
		return false
	_charge_cd -= delta
	_shield_cd -= delta
	var dist := to_player.length()
	if _charge_cd <= 0.0 and dist > VigridTuning.CHARGE_RANGE.x and dist < VigridTuning.CHARGE_RANGE.y:
		_charge_cd = VigridTuning.CHARGE_EVERY * randf_range(0.85, 1.15)
		_charge_t = 0.0
		_charge_hit = false
		_charge_dir = to_player.normalized()
		Audio.sfx("boss_windup", -6.0)  # 冲锋开始
		_pose(&"charge")
		return true
	if _shield_cd <= 0.0 and dist < 320.0:
		_shield_cd = VigridTuning.SHIELD_EVERY * randf_range(0.85, 1.15)
		_shield_t = 0.0
		_facing = to_player.normalized() if to_player != Vector2.ZERO else Vector2.RIGHT
		_pose(&"shield")
	return false


func is_shielding() -> bool:
	return _shield_t >= 0.0


func is_charging() -> bool:
	return _charge_t >= 0.0


## 伤害是否来自盾牌正面：以玩家的位置作为攻击来源（和赫列姆的冰川巨盾同一套规则）
func blocks_from(source: Vector2) -> bool:
	return is_shielding() and absf(_facing.angle_to(source - global_position)) < VigridTuning.SHIELD_HALF


func _end_shield() -> void:
	if _shield_t >= 0.0:
		_shield_t = -1.0
		_pose(&"move")


func move_mult() -> float:
	return super.move_mult() * (0.35 if is_shielding() else 1.0)


# ———— 狂狼战士 ————

func _update_berserker(delta: float) -> void:
	if raged:
		_attack_cd = minf(_attack_cd, ATTACK_COOLDOWN * VigridTuning.RAGE_ATTACK)
		if _rage_pose > 0.0:
			_rage_pose -= delta
			if _rage_pose <= 0.0:
				_pose(&"move")
		return
	if hp > 0.0 and hp < max_hp * VigridTuning.RAGE_AT:
		raged = true  # 只狂暴一次
		speed *= VigridTuning.RAGE_SPEED
		_rage_pose = 0.4
		_pose(&"rage")
		Audio.sfx("boss_howl", -8.0)
		FxLayer.burst(global_position, Color(1.0, 0.35, 0.25), 12, 150.0, 3.0)


# ———— 共用 ————

func _pose(action: StringName) -> void:
	if _actions and _actions.sprite_frames.has_animation(action) and _actions.animation != action:
		_actions.play(action)


## 攻击动作播完：举盾 / 冲锋 / 狂暴的姿势优先
func _on_action_finished() -> void:
	if _actions.animation == &"attack":
		_pose(&"shield" if is_shielding() else (&"charge" if is_charging() else &"move"))


func _play_attack_frames() -> void:
	if is_shielding() or is_charging() or _rage_pose > 0.0:
		return
	super._play_attack_frames()


func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, crit: bool = false) -> void:
	if not _dead and amount > 0.0 and is_instance_valid(target) and blocks_from(target.global_position):
		amount *= 1.0 - VigridTuning.SHIELD_BLOCK
		knockback = Vector2.ZERO
		Audio.sfx("boss_block", -10.0)  # 盾牌真的挡下了这一击
		if randf() < 0.3:
			FxLayer.burst(global_position + _facing * (radius + 4.0), SHIELD_COLOR, 4, 90.0, 2.0)
	super.take_damage(amount, knockback, crit)


func _die() -> void:
	if type_id == "fire_giant":
		_dead = true
		remove_from_group("enemies")  # 先撤掉索敌和推挤登记，再在死亡中心爆炸
		_remove_from_grid()
		FireHazard.blast(get_parent(), global_position, is_elite)
		_drop_and_free()
		return
	super._die()


## 火焰巨人：不放通用的死亡碎片（爆炸本身就是死亡反馈），其余和普通死亡一样
func _drop_and_free() -> void:
	var gem := XpGem.new()
	gem.value = xp_value
	gem.big = is_elite
	gem.player = target
	gem.position = position
	get_parent().call_deferred("add_child", gem)
	if is_elite and is_instance_valid(target):
		target.shake(6.0, 0.2)
	get_tree().call_group("god_powers", "on_enemy_died", self)
	killed.emit(self)
	queue_free()


func _draw() -> void:
	if _charge_t >= 0.0 and _charge_t < VigridTuning.CHARGE_WINDUP:  # 冲锋路线预警
		var length := speed * VigridTuning.CHARGE_MULT * VigridTuning.CHARGE_TIME
		Boss.draw_line_telegraph(self, _charge_dir, length, radius * 0.8, _charge_t / VigridTuning.CHARGE_WINDUP, Color(0.6, 0.8, 1.0))
	if is_shielding():  # 盾牌挡住的正面扇区
		draw_arc(Vector2.ZERO, radius + 6.0, _facing.angle() - VigridTuning.SHIELD_HALF, _facing.angle() + VigridTuning.SHIELD_HALF, 16, Color(SHIELD_COLOR, 0.75), 3.0)
	super._draw()
	if raged and _sprite:
		_sprite.modulate = _sprite.modulate * Color(1.25, 0.8, 0.75)
