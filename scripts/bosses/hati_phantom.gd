class_name HatiPhantom
extends Enemy
## 哈提的月影分身：外形和本体一模一样，跟本体同步出招，但打不掉血，也没有影子
## 持续一段时间后消散；本体死亡时立即消散

const LIFETIME := 12.0

var hati: Hati
var _aim_dir := Vector2.RIGHT
var _life := LIFETIME
var _last_state := ""


func _ready() -> void:
	type_id = "hati_phantom"
	gait = "quad"
	mass = 50.0
	super._ready()
	if _sprite == null:  # 有哈提的素材就用同一张图，看起来一模一样
		_sprite = SpriteVisual.create("res://assets/sprites/bosses/hati", radius * 2.6)
		if _sprite:
			add_child(_sprite)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0 or not is_instance_valid(hati) or not is_instance_valid(target):
		FxLayer.burst(global_position, color, 16, 180.0)
		queue_free()
		return
	if _flash_time > 0.0:
		_flash_time -= delta
	if _frozen_time > 0.0:
		_frozen_time -= delta
		return

	# 跟着本体的状态出招，但用自己的位置瞄准
	if hati.state != _last_state:
		_last_state = hati.state
		if hati.state == "lunge_windup":
			_aim_dir = global_position.direction_to(target.global_position)
	if _sprite:
		_sprite.set("flip_h", target.global_position.x < global_position.x)
		_anim_t += delta
		SpriteVisual.animate(_sprite, _anim_t * 0.6, 0.5, gait, signf(target.global_position.x - global_position.x) * 0.5)
		if hati.state.ends_with("windup"):
			SpriteVisual.windup_tremble(_sprite, hati.state_time)
	match hati.state:
		"lunge":
			position += _aim_dir * Hati.LUNGE_SPEED * delta
		"chase":
			position += global_position.direction_to(target.global_position) * speed * delta
	queue_redraw()
	if global_position.distance_to(target.global_position) < radius + Player.RADIUS:
		target.take_damage(contact_damage)


## 虚影受击：闪一下，但不掉血、不给大招能量
func take_damage(_amount: float, _knockback: Vector2 = Vector2.ZERO, _crit: bool = false) -> void:
	_flash_time = 0.08


func _draw() -> void:
	if not is_instance_valid(hati):
		return
	if hati.state == "lunge_windup":
		var t := hati.state_time / hati.windup_time(Hati.LUNGE_WINDUP)
		Boss.draw_line_telegraph(self, _aim_dir, Hati.LUNGE_LENGTH + radius, radius, t, Hati.MOON_COLOR)
	if _sprite:
		_sprite.modulate = Color(3, 3, 3) if _flash_time > 0.0 else Color.WHITE
		return
	draw_circle(Vector2.ZERO, radius + 3.0, Color(0.1, 0.05, 0.05))
	draw_circle(Vector2.ZERO, radius, Color.WHITE if _flash_time > 0.0 else color)
