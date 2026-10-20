class_name Nidhogg
extends Boss
## 尼德霍格 · 噬根之龙（篇章一 第 2 关 06:00）
## 技能：
##   潜地：钻入地下，玩家脚下先出现裂纹预警，然后从裂纹里冲出来
##   毒息：扇形毒雾，地面留下持续伤害的毒池
##   啃噬树根：登场时从地下拱出一段世界树根；它隔一段时间跑去啃树根回血，啃的时候打够伤害就能打断

const CHASE_TIME := 2.4
const BREATH_WINDUP := 0.9
const BREATH_RANGE := 300.0
const BREATH_HALF_ANGLE := 0.6   # 扇形半角（弧度，约 35°）
const BREATH_DAMAGE := 22.0
const BURROW_TIME := 0.5
const UNDER_TIME := 1.3          # 在地下多久；前一半时间裂纹跟着玩家，后一半锁定
const EMERGE_RADIUS := 100.0
const EMERGE_DAMAGE := 28.0
const RECOVER_TIME := 1.0
const GNAW_EVERY := 15.0
const GNAW_RUN_SPEED := 1.8
const GNAW_HEAL := 0.025         # 每秒回复最大生命的比例
const GNAW_MAX := 6.0
const GNAW_BREAK := 0.06         # 啃的时候受到这么多比例的伤害就被打断
const STAGGER_TIME := 2.0
const ROOT_PATH := "res://assets/sprites/props/helheim/world_tree_root.png"
const CRACK_PATH := "res://assets/sprites/effects/ground_crack.png"  # 96×96 的 4 帧，裂纹越来越大
const POISON := Color(0.4, 0.75, 0.3)

var _breath_dir := Vector2.RIGHT
var _crack := Vector2.ZERO
var _root: Node2D
var _gnaw_timer := GNAW_EVERY * 0.6
var _gnaw_damage := 0.0
var _cycle := 0
var _crack_strip: Texture2D


func _init() -> void:
	intro_line = tr("尼德霍格 · 噬根之龙 —— 世界树在颤抖")
	defeat_line = tr("「世界树……终究……会枯萎……」")


func init_stats(hp_scale: float) -> void:
	setup_boss("nidhogg", tr("尼德霍格"), tr("噬根之龙"), 1100.0, hp_scale, 44.0, 95.0, 20.0)
	gait = "heavy"
	color = Color(0.2, 0.28, 0.2)
	reward_points = 150
	state_actions = {"go_root": &"move", "gnaw": &"gnaw", "burrow": &"burrow", "emerge": &"emerge", "stagger": &"idle"}


func _ready() -> void:
	super._ready()
	if ResourceLoader.exists(CRACK_PATH):
		_crack_strip = load(CRACK_PATH)
	_root = _make_root(position)
	get_parent().add_child.call_deferred(_root)
	change_state("chase")


## 世界树根：有素材用素材，没有就画一道拱起的粗弧
func _make_root(at: Vector2) -> Node2D:
	var root := Node2D.new()
	root.position = at
	root.z_index = -1
	if ResourceLoader.exists(ROOT_PATH):
		var sprite := Sprite2D.new()
		sprite.texture = load(ROOT_PATH)
		sprite.offset = Vector2(0, -sprite.texture.get_height() * 0.5)
		root.add_child(sprite)
	else:
		root.draw.connect(func() -> void:
			root.draw_arc(Vector2(0, 40), 150.0, PI * 1.1, PI * 1.9, 24, Color(0.18, 0.13, 0.09), 34.0)
			root.draw_arc(Vector2(0, 40), 150.0, PI * 1.1, PI * 1.9, 24, Color(0.32, 0.24, 0.16), 22.0))
	return root


func _update_state(delta: float) -> void:
	_gnaw_timer -= delta
	match state:
		"chase":
			chase(delta)
			if state_time >= CHASE_TIME:
				_cycle += 1
				if _gnaw_timer <= 0.0 and is_instance_valid(_root):
					change_state("go_root")
				elif _cycle % 2 == 0:
					change_state("burrow")
				else:
					change_state("breath_windup")
		"breath_windup":
			_breath_dir = global_position.direction_to(target.global_position)
			if state_time >= BREATH_WINDUP:
				_breathe()
				change_state("breath")
		"breath":
			if state_time >= 0.5:
				change_state("recover")
		"burrow":
			if state_time >= BURROW_TIME:
				set_untouchable(true)
				FxLayer.burst(global_position, Color(0.3, 0.25, 0.2), 20, 160.0, 4.0)
				_crack = target.global_position
				change_state("under")
		"under":
			if state_time < UNDER_TIME * 0.55:
				_crack = target.global_position  # 前半段跟着玩家，之后锁定
			if state_time >= UNDER_TIME:
				position = _crack
				set_untouchable(false)
				_emerge()
				change_state("emerge")
		"emerge":
			if state_time >= 0.6:
				change_state("recover")
		"go_root":
			var to := _root.global_position + Vector2(0, -50)
			position = position.move_toward(to, speed * GNAW_RUN_SPEED * slow * delta)
			if position.distance_to(to) < 8.0:
				_gnaw_damage = 0.0
				change_state("gnaw")
		"gnaw":
			hp = minf(max_hp, hp + max_hp * GNAW_HEAL * delta)
			hp_changed.emit(hp, max_hp)
			if state_time >= GNAW_MAX:
				_gnaw_timer = GNAW_EVERY
				change_state("chase")
		"stagger":
			if state_time >= STAGGER_TIME:
				change_state("chase")
		"recover":
			if state_time >= RECOVER_TIME:
				change_state("chase")


func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, crit: bool = false) -> void:
	super.take_damage(amount, knockback, crit)
	if state == "gnaw" and not _dead:
		_gnaw_damage += amount
		if _gnaw_damage >= max_hp * GNAW_BREAK:  # 打断啃食
			_gnaw_timer = GNAW_EVERY
			FxLayer.floating_text(global_position + Vector2(0, -radius - 20), tr("打断！"), Color(1.0, 0.85, 0.4))
			Audio.sfx("boss_block")
			change_state("stagger")


func _breathe() -> void:
	Audio.sfx("boss_slam", -4.0)
	var offset := target.global_position - global_position
	if offset.length() < BREATH_RANGE + Player.RADIUS and absf(_breath_dir.angle_to(offset)) < BREATH_HALF_ANGLE \
			and not Stonehenge.shields(get_tree(), target.global_position):  # 法师的巨石阵挡得住毒息
		target.take_damage(BREATH_DAMAGE)
	for i in 3:
		var at := global_position + _breath_dir.rotated(randf_range(-0.3, 0.3)) * (110.0 + i * 85.0)
		PoisonPool.spawn(get_parent(), Game.clamp_to_map(at, 40.0))
	for i in 24:
		FxLayer.burst(global_position + _breath_dir.rotated(randf_range(-BREATH_HALF_ANGLE, BREATH_HALF_ANGLE)) * randf_range(60.0, BREATH_RANGE), POISON, 1, 60.0, 5.0)


func _emerge() -> void:
	Audio.sfx("boss_slam")
	target.shake(10.0, 0.35)
	FxLayer.ring(global_position, EMERGE_RADIUS)
	FxLayer.burst(global_position, Color(0.35, 0.3, 0.25), 36, 260.0, 5.0)
	if global_position.distance_to(target.global_position) < EMERGE_RADIUS + Player.RADIUS:
		target.take_damage(EMERGE_DAMAGE)


func _die() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	super._die()


func _draw_telegraph() -> void:
	match state:
		"breath_windup":
			var t := state_time / BREATH_WINDUP
			var points := PackedVector2Array([Vector2.ZERO])
			for i in 13:
				points.append(_breath_dir.rotated(-BREATH_HALF_ANGLE + BREATH_HALF_ANGLE * 2.0 * i / 12.0) * BREATH_RANGE)
			draw_colored_polygon(points, Color(POISON, 0.1 + 0.25 * t))
			points.append(Vector2.ZERO)
			draw_polyline(points, Color(POISON.lightened(0.3), 0.7), 2.0)
		"under":
			# 裂纹预警画在 _crack（世界坐标）处
			var local := _crack - global_position
			var t := state_time / UNDER_TIME
			if _crack_strip:
				SpriteVisual.draw_frame(self, _crack_strip, 4, mini(3, int(t * 4.0)), local, Vector2(48, 48))
			else:
				for i in 6:
					var dir := Vector2.from_angle(i * TAU / 6.0 + 0.4)
					draw_line(local, local + dir * EMERGE_RADIUS * t, Color(0.15, 0.1, 0.08), 3.0)
			draw_circle_telegraph(self, local, EMERGE_RADIUS, t)
