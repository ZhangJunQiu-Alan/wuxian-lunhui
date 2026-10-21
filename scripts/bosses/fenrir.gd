class_name Fenrir
extends Boss
## 芬里尔 · 魔狼（篇章一 第 3 关 06:00）
## 技能：
##   扑咬：蓄力后向玩家扑出一段
##   天地巨口：在嘴前张开独立的上下颚（各 256×128），先有清楚的逃脱窗口（吸引 + 倒计时），之后才提交吞噬
##     吸引区、致死区都由控制器按铰点和轴线算出，预警和判定用同一份多边形；吸引期间上下颚之间至少留 64 的通道
##     吞噬走玩家正常的受伤流程：闪现、护盾、无敌时吞不掉，死了照常复活
##   狂奔：画出绕玩家一圈的路线，然后高速沿路线冲刺，撞到有命中冷却
##   格莱普尼尔：场上散落锁链碎片，捡起后束缚芬里尔一段时间（不能行动，受到的伤害增加）；吸引中被束缚则吞噬取消
## 改写命运：信仰奥丁并且奥丁觉醒 → 巨口张开时维达出现，撑开芬里尔的嘴（这段演出关闭吸引和吞噬，不伤玩家）
## 数值见 VigridTuning

const FOOT := Vector2(96, 190)
const BODY_CENTER := Vector2(0, -74)  # 192 方帧中心 (96,96)：脚锚 (96,190) 对齐到 (0, FOOT) 之后的位置
const K_ACTIONS := {"idle": true, "move": true, "windup": false, "attack": false, "swallow": false}
const UPPER_PATH := "res://assets/sprites/effects/bosses/fenrir_maw_upper.png"  # 256×128 4 帧，锚点 (32,128)
const LOWER_PATH := "res://assets/sprites/effects/bosses/fenrir_maw_lower.png"  # 256×128 4 帧，锚点 (32,0)
const LINK_PATH := "res://assets/sprites/effects/bosses/fenrir_bind_link.png"   # 16×8 编带
const VIDAR_IDLE := "res://assets/sprites/allies/vidar_idle.png"  # 96×96 4 帧，脚锚 (48,94)
const VIDAR_PRY := "res://assets/sprites/allies/vidar_pry.png"    # 96×96 6 帧
const JAW_SIZE := Vector2(256, 128)
const UPPER_ANCHOR := Vector2(32, 128)
const LOWER_ANCHOR := Vector2(32, 0)
const APERTURE := 120.0       # 口内中心 = 铰点 + 轴线 × 120（契约）
const HINGE_FORWARD := 70.0   # 铰点：身体中心沿轴线往前这么多
const BIND_RADII := Vector2(82, 84)  # 束缚带的椭圆（相对身体中心）
const BIND_PROTECT := Rect2(-40, -42, 80, 84)  # 192 方帧里的躯干保护区 (56,54)-(136,138)，不画束缚带
const BIND_WIDTH := 8.0
## 维达撑口：pry 第 2~4 帧（从 0 数）手和靴子的接触点（96 方帧像素），上下颚第 195 列的边缘对准它们
const VIDAR_HANDS := [Vector2(82, 8), Vector2(79, 6), Vector2(80, 5)]
const VIDAR_BOOTS := [Vector2(78, 92), Vector2(78, 92), Vector2(79, 92)]
const VIDAR_FOOT := Vector2(48, 94)
const JAW_CONTACT_X := 195
const VIDAR_TIME := 1.6       # 撑口演出：0~4 帧按 16 帧/秒，第 4 帧撑住，到这个时间撕开（第 5 帧）
const VIDAR_LEAVE := 1.2
const RUN_POINTS := 48
const SKILLS := ["bite", "maw", "bite", "run"]
const GOLD := Color(1.0, 0.85, 0.45)

static var _jaw_edges := {}   # 上颚第 195 列最低的不透明像素 y、下颚最高的，开局读一次贴图

var maw_open := false
var maw_hinge := Vector2.ZERO
var maw_axis := Vector2.RIGHT
var maw_gap := 0.0
var bound_time := 0.0
var fragments: Array[GleipnirFragment] = []
var route := PackedVector2Array()  # 狂奔路线，预警和移动用同一条
var _cycle := 0
var _lunge_dir := Vector2.RIGHT
var _bitten := false
var _committed := false
var _vidar_ready := false
var _vidar_t := -1.0
var _vidar_pried := false
var _vidar_local := Vector2.ZERO
var _run_at := 0
var _run_hit_cd := 0.0
var _trail_cd := 0.0
var _fragment_timer := 0.0
var _maw_layer: Node2D
var _bind_layer: Node2D
var _upper: Texture2D
var _lower: Texture2D
var _link: Texture2D
var _vidar_idle: Texture2D
var _vidar_pry: Texture2D


func _init() -> void:
	intro_line = tr("芬里尔 · 魔狼 —— 上颚抵住天空，下颚贴着大地")
	defeat_line = tr("「你们……也只是……更大的笼子里的狼……」")


func init_stats(hp_scale: float) -> void:
	setup_boss("fenrir", tr("芬里尔"), tr("魔狼"), VigridTuning.WOLF_HP, hp_scale, 46.0, 120.0, VigridTuning.WOLF_CONTACT)
	actions = K_ACTIONS
	gait = "quad"
	color = Color(0.35, 0.33, 0.38)
	reward_points = 220
	state_actions = {"maw": &"windup", "maw_windup": &"windup", "swallow": &"swallow", "run_prep": &"windup", "run": &"move",
		"bound": &"idle", "vidar": &"windup", "stagger": &"idle", "bite": &"attack"}


func _ready() -> void:
	super._ready()
	fit_k_actor(FOOT)
	for path: String in [UPPER_PATH, LOWER_PATH, LINK_PATH, VIDAR_IDLE, VIDAR_PRY]:
		if not ResourceLoader.exists(path):
			push_error("芬里尔缺少素材：" + path)
	_upper = load(UPPER_PATH)
	_lower = load(LOWER_PATH)
	_link = load(LINK_PATH)
	_vidar_idle = load(VIDAR_IDLE)
	_vidar_pry = load(VIDAR_PRY)
	_read_jaw_edges()
	_bind_layer = Node2D.new()
	_bind_layer.name = "Bind"
	_bind_layer.z_index = 1
	_bind_layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR  # 编带镜像重复，首尾接色不断
	_bind_layer.draw.connect(_draw_bind)
	add_child(_bind_layer)
	_maw_layer = Node2D.new()
	_maw_layer.name = "Maw"
	_maw_layer.top_level = true
	_maw_layer.z_index = 2
	_maw_layer.draw.connect(_draw_maw)
	add_child(_maw_layer)
	for i in VigridTuning.FRAGMENT_START:
		_spawn_fragment()
	change_state("chase")


func _read_jaw_edges() -> void:
	if not _jaw_edges.is_empty() or _upper == null or _lower == null:
		return
	var upper := _upper.get_image()
	var lower := _lower.get_image()
	var up := 0
	var low := int(JAW_SIZE.y)
	for y in int(JAW_SIZE.y):
		if upper.get_pixel(JAW_CONTACT_X, y).a > 0.5:
			up = y
		if lower.get_pixel(JAW_CONTACT_X, y).a > 0.5:
			low = mini(low, y)
	_jaw_edges = {"upper": up, "lower": low}


# ———— 巨口几何（预警、吸引、吞噬、绘制都从这里取）————

## 巨口局部坐标 → 世界：原点是铰点，x 沿轴线；朝左时整体镜像（上颚仍在上方）
static func maw_basis(hinge: Vector2, axis: Vector2) -> Transform2D:
	var y := Vector2(-axis.y, axis.x) if axis.x >= 0.0 else Vector2(axis.y, -axis.x)
	return Transform2D(axis, y, hinge)


static func transform_polygon(basis: Transform2D, points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(basis * p)
	return result


## 吸引区：铰点前方的扇形
static func attract_polygon(hinge: Vector2, axis: Vector2) -> PackedVector2Array:
	return transform_polygon(maw_basis(hinge, axis), BossFx.sector(Vector2.ZERO, VigridTuning.MAW_ATTRACT_RADIUS, 0.0, VigridTuning.MAW_ATTRACT_HALF))


## 致死区：上下颚之间的口腔
static func fatal_polygon(hinge: Vector2, axis: Vector2, gap: float) -> PackedVector2Array:
	var r := VigridTuning.MAW_FATAL
	var local := Rect2(r.position.x, -gap * 0.5, r.size.x, gap)
	return transform_polygon(maw_basis(hinge, axis), PackedVector2Array([local.position, Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)]))


static func aperture(hinge: Vector2, axis: Vector2) -> Vector2:
	return hinge + axis * APERTURE


func can_bind() -> bool:
	return not _dead and state != "vidar" and state != "swallow"


## 捡到碎片：束缚 BIND_TIME 秒。吸引中被束缚，吞噬取消（不放提交声）
func bind() -> void:
	if not can_bind():
		return
	maw_open = false
	bound_time = VigridTuning.BIND_TIME
	Audio.sfx("gleipnir_tension")
	FxLayer.floating_text(global_position + Vector2(0, -150), tr("格莱普尼尔！"), GOLD)
	change_state("bound")


func is_bound() -> bool:
	return bound_time > 0.0


func _vidar_eligible() -> bool:
	var game := get_tree().current_scene
	return is_instance_valid(target) and target.faith.has("odin") and target.gods.has("odin") and target.gods.odin.awakened \
		and game.get("fates") is Dictionary and game.fates.has("vidar_intervened") and not game.fates.vidar_intervened


# ———— 行动 ————

func _update_state(delta: float) -> void:
	_fragment_timer += delta
	_run_hit_cd -= delta
	if _fragment_timer >= VigridTuning.FRAGMENT_EVERY:
		_fragment_timer = 0.0
		fragments = fragments.filter(func(f) -> bool: return is_instance_valid(f) and not f.taken and not f.is_queued_for_deletion())
		if fragments.size() < VigridTuning.FRAGMENT_MAX:
			_spawn_fragment()
	match state:
		"chase":
			chase(delta)
			if state_time >= VigridTuning.WOLF_CHASE:
				_next_skill()
		"bite_windup":
			_lunge_dir = global_position.direction_to(target.global_position)
			if state_time >= VigridTuning.BITE_WINDUP:
				_bitten = false
				change_state("bite")
		"bite":
			var length := 0.25
			if state_time < length:
				position += _lunge_dir * VigridTuning.BITE_LUNGE / length * delta
			if not _bitten and state_time >= 1.0 / SpriteVisual.ACTION_FPS.attack:  # 出招第 1 帧咬合
				_bitten = true
				var mouth := global_position + BODY_CENTER * 0.5 + _lunge_dir * (radius + 20.0)
				FxLayer.mark(mouth, _lunge_dir.angle(), 70.0, Color(1.0, 0.9, 0.85), "bite")
				if mouth.distance_to(target.global_position) < 48.0 + Player.RADIUS:
					target.take_damage(VigridTuning.BITE_DAMAGE)
			if state_time >= 0.6:
				change_state("recover")
		"maw_windup":
			maw_axis = (target.global_position - _maw_root()).normalized()
			maw_hinge = _maw_root() + maw_axis * HINGE_FORWARD
			maw_gap = lerpf(VigridTuning.MAW_GAP_MIN, VigridTuning.MAW_GAP, minf(1.0, state_time / VigridTuning.MAW_WINDUP))
			maw_open = true
			if state_time >= VigridTuning.MAW_WINDUP:
				_committed = false
				_vidar_ready = _vidar_eligible()
				change_state("maw")
		"maw":
			maw_gap = VigridTuning.MAW_GAP
			_attract(delta)
			if _vidar_ready and state_time >= VigridTuning.MAW_ESCAPE * 0.35:
				_begin_vidar()
			elif state_time >= VigridTuning.MAW_ESCAPE:
				_commit_swallow()
		"swallow":
			maw_gap = maxf(0.0, VigridTuning.MAW_GAP * (1.0 - state_time / 0.25))  # 判定已经结束，只是合口演出
			if state_time >= 0.45:
				maw_open = false
				change_state("recover")
		"vidar":
			_vidar_t += delta
			_update_vidar()
		"run_prep":
			if state_time < 0.05:
				_plan_run()
			position = position.lerp(route[0], minf(1.0, delta * 8.0))
			if state_time >= VigridTuning.RUN_WINDUP:
				_run_at = 1
				Audio.sfx("boss_howl")  # 狂奔开始
				change_state("run")
		"run":
			_run(delta)
		"bound":
			bound_time -= delta
			if bound_time <= 0.0:
				bound_time = 0.0
				BossFx.play("garm_chain_break", global_position + BODY_CENTER, 0.0, Vector2.ONE, GOLD)  # 束缚解除，暖金色
				change_state("chase")
		"stagger":
			if state_time >= VigridTuning.VIDAR_STAGGER:
				change_state("chase")
		"recover":
			if state_time >= 0.8:
				change_state("chase")
	_maw_layer.queue_redraw()
	_bind_layer.queue_redraw()


func _next_skill() -> void:
	var skill: String = SKILLS[_cycle % SKILLS.size()]
	_cycle += 1
	match skill:
		"bite":
			change_state("bite_windup")
		"maw":
			change_state("maw_windup")
		"run":
			change_state("run_prep")


## 巨口从头部前方张开（身体中心偏上）
func _maw_root() -> Vector2:
	return global_position + BODY_CENTER


## 吸引：玩家在吸引区里就被拉向口内中心，速度比玩家慢，跑得掉
func _attract(delta: float) -> void:
	if not Geometry2D.is_point_in_polygon(target.global_position, attract_polygon(maw_hinge, maw_axis)):
		return
	var to := aperture(maw_hinge, maw_axis) - target.global_position
	if to.length() > 1.0:
		target.position = Game.clamp_to_map(target.position + to.normalized() * minf(to.length(), VigridTuning.MAW_PULL * delta), Player.RADIUS)


## 逃脱窗口结束：这时还在致死区里就被吞下（走玩家正常的受伤流程）
func _commit_swallow() -> void:
	if _committed:
		return
	_committed = true
	Audio.sfx("fenrir_swallow")
	if Geometry2D.is_point_in_polygon(target.global_position, fatal_polygon(maw_hinge, maw_axis, maw_gap)):
		target.take_damage(target.max_hp * VigridTuning.MAW_FATAL_DAMAGE_MULT)
	target.shake(10.0, 0.3)
	change_state("swallow")


## 维达登场：吸引和吞噬关闭，巨口转成水平，维达撑开上下颚
func _begin_vidar() -> void:
	var game := get_tree().current_scene
	if not game.confirm_fate("vidar_intervened"):
		_vidar_ready = false
		return
	Audio.sfx("awaken")
	game.hud.announce(tr("奥丁之子维达踏进了巨狼的嘴里！"))
	maw_axis = Vector2(signf(maw_axis.x) if maw_axis.x != 0.0 else 1.0, 0.0)
	maw_hinge = _maw_root() + maw_axis * HINGE_FORWARD
	_vidar_local = Vector2(JAW_CONTACT_X - UPPER_ANCHOR.x - (VIDAR_HANDS[0].x - VIDAR_FOOT.x), 44.0)
	_vidar_t = 0.0
	_vidar_pried = false
	change_state("vidar")


func _update_vidar() -> void:
	if not _vidar_pried and _vidar_t >= VIDAR_TIME:
		_vidar_pried = true
		Audio.sfx("boss_slam")
		target.shake(10.0, 0.35)
		FxLayer.burst(maw_basis(maw_hinge, maw_axis) * Vector2(160, 0), GOLD, 30, 260.0, 4.0)
		take_damage(max_hp * VigridTuning.VIDAR_DAMAGE)
	if _vidar_t >= VIDAR_TIME + VIDAR_LEAVE:
		maw_open = false
		_vidar_t = -1.0
		change_state("stagger")


## 维达当前的 pry 帧：0~4 按 16 帧/秒，停在第 4 帧撑住，撕开时第 5 帧
func vidar_frame() -> int:
	if _vidar_pried:
		return 5
	return mini(4, int(_vidar_t * 16.0))


## 维达手、靴子的接触点（巨口局部坐标）
func vidar_contacts() -> PackedVector2Array:
	var index := clampi(vidar_frame() - 2, 0, 2)
	var foot := _vidar_local
	return PackedVector2Array([foot + VIDAR_HANDS[index] - VIDAR_FOOT, foot + VIDAR_BOOTS[index] - VIDAR_FOOT])


## 狂奔路线：以玩家为中心的一圈（半径在 RUN_RADIUS_MIN~MAX 之间），每个点都收进地图
func _plan_run() -> void:
	var center := target.global_position
	var r := clampf(global_position.distance_to(center), VigridTuning.RUN_RADIUS_MIN, VigridTuning.RUN_RADIUS_MAX)
	var start := (global_position - center).angle()
	route = PackedVector2Array()
	for i in RUN_POINTS + 1:
		route.append(Game.clamp_to_map(center + Vector2.from_angle(start + TAU * i / RUN_POINTS) * r, radius))


func _run(delta: float) -> void:
	var travel := VigridTuning.RUN_SPEED * move_mult() * delta
	while travel > 0.0 and _run_at < route.size():
		var to := route[_run_at]
		var d := position.distance_to(to)
		if d <= travel:
			position = to
			travel -= d
			_run_at += 1
		else:
			position = position.move_toward(to, travel)
			travel = 0.0
	_trail_cd -= delta
	if _trail_cd <= 0.0 and _run_at < route.size():
		_trail_cd = 0.09
		BossFx.play("skoll_dash_trail", global_position, global_position.direction_to(route[_run_at]).angle())
	if _run_hit_cd <= 0.0 and global_position.distance_to(target.global_position) < radius + Player.RADIUS + 6.0:
		_run_hit_cd = VigridTuning.RUN_HIT_COOLDOWN
		target.take_damage(VigridTuning.RUN_DAMAGE)
		FxLayer.mark(target.global_position, randf() * TAU, 60.0, Color(1.0, 0.9, 0.85), "bite")
	if _run_at >= route.size():
		route = PackedVector2Array()
		change_state("recover")


func _spawn_fragment() -> void:
	if not is_instance_valid(target):
		return
	var inner := Game.bounds.grow(-80.0)
	var at := target.global_position
	for i in 12:
		at = target.global_position + Vector2.from_angle(randf() * TAU) * randf_range(260.0, 420.0)
		if inner.has_point(at):
			break
	var fragment := GleipnirFragment.new()
	fragment.fenrir = self
	fragment.player = target
	fragment.position = Game.clamp_to_map(at, 80.0)
	fragments.append(fragment)
	get_parent().add_child.call_deferred(fragment)


func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, crit: bool = false) -> void:
	super.take_damage(amount * (VigridTuning.BIND_DAMAGE_MULT if is_bound() else 1.0), knockback, crit)


## 维达撑口的演出期间，身体也不撞人
func touches_player() -> bool:
	return super.touches_player() and state != "vidar"


func chase(delta: float, speed_mult: float = 1.0) -> void:
	if not is_bound():
		super.chase(delta, speed_mult)


func _die() -> void:
	for fragment in fragments:
		if is_instance_valid(fragment):
			fragment.queue_free()
	super._die()


# ———— 画面 ————

func _update_visual(delta: float) -> void:
	super._update_visual(delta)
	if maw_open:
		_sprite.set("flip_h", maw_axis.x < 0.0)
	elif state == "run" and _run_at < route.size():
		_sprite.set("flip_h", route[_run_at].x < global_position.x)


func _draw_telegraph() -> void:
	match state:
		"bite_windup":
			draw_line_telegraph(self, _lunge_dir, VigridTuning.BITE_LUNGE, 40.0, state_time / VigridTuning.BITE_WINDUP)
		"run_prep":
			if route.size() > 1:
				var local := PackedVector2Array()
				for p in route:
					local.append(p - global_position)
				var t := state_time / VigridTuning.RUN_WINDUP
				draw_polyline(local, Color(1.0, 0.2, 0.15, 0.12 + 0.2 * t), radius * 2.0)
				draw_polyline(local, Color(1.0, 0.45, 0.35, 0.7), 2.0)


## 束缚：一条细编带沿椭圆绕着躯干（保护区里不画），一个小亮点沿着走
func _draw_bind() -> void:
	if not is_bound() or _dead:
		return
	var center := BODY_CENTER
	var steps := 72
	var travelled := 0.0
	for i in steps:
		var a0 := TAU * i / steps
		var a1 := TAU * (i + 1) / steps
		var p0 := center + Vector2(cos(a0) * BIND_RADII.x, sin(a0) * BIND_RADII.y)
		var p1 := center + Vector2(cos(a1) * BIND_RADII.x, sin(a1) * BIND_RADII.y)
		var n0 := Vector2(cos(a0), sin(a0)) * BIND_WIDTH * 0.5
		var n1 := Vector2(cos(a1), sin(a1)) * BIND_WIDTH * 0.5
		var step := p0.distance_to(p1)
		if _link:
			_bind_layer.draw_polygon(PackedVector2Array([p0 - n0, p1 - n1, p1 + n1, p0 + n0]), PackedColorArray([Color.WHITE]),
				PackedVector2Array([Vector2(travelled / 16.0, 0), Vector2((travelled + step) / 16.0, 0), Vector2((travelled + step) / 16.0, 1), Vector2(travelled / 16.0, 1)]), _link)
		else:
			_bind_layer.draw_line(p0, p1, GOLD, 3.0)
		travelled += step
	var phase := int(state_time * 8.0) % 4  # 四相位 8 帧/秒移动的小亮点
	var glint := TAU * (state_time * 0.35 + phase * 0.02)
	_bind_layer.draw_circle(center + Vector2(cos(glint) * BIND_RADII.x, sin(glint) * BIND_RADII.y), 2.5, Color(1.0, 0.95, 0.75, 0.9))
	var k := bound_time / VigridTuning.BIND_TIME
	_bind_layer.draw_arc(center + Vector2(0, -BIND_RADII.y - 14.0), 8.0, -PI * 0.5, -PI * 0.5 + TAU * k, 16, GOLD, 2.0)


## 巨口：上下颚分别从铰点 ± gap/2 画出，各自只占自己那半边；预警多边形和判定是同一份
func _draw_maw() -> void:
	if not maw_open or _dead:
		return
	var basis := maw_basis(maw_hinge, maw_axis)
	var frame := int(state_time * 8.0) % 4
	if state == "maw" or state == "maw_windup":
		var t := state_time / (VigridTuning.MAW_ESCAPE if state == "maw" else VigridTuning.MAW_WINDUP)
		_maw_layer.draw_colored_polygon(attract_polygon(maw_hinge, maw_axis), Color(1.0, 0.3, 0.2, 0.06 + 0.06 * t))
		var fatal := fatal_polygon(maw_hinge, maw_axis, maw_gap)
		_maw_layer.draw_colored_polygon(fatal, Color(1.0, 0.1, 0.05, 0.12 + 0.25 * t if state == "maw" else 0.08))
		fatal.append(fatal[0])
		_maw_layer.draw_polyline(fatal, Color(1.0, 0.45, 0.35, 0.9), 2.0)
		if state == "maw":  # 逃脱倒计时
			_maw_layer.draw_arc(aperture(maw_hinge, maw_axis), 30.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - t), 32, Color(1.0, 0.85, 0.4, 0.9), 4.0)
	if state == "vidar":
		_draw_vidar(basis, frame)
		return
	_blit(basis, _upper, 4, frame, Vector2(0, -maw_gap * 0.5), UPPER_ANCHOR)
	_blit(basis, _lower, 4, frame, Vector2(0, maw_gap * 0.5), LOWER_ANCHOR)
	_maw_layer.draw_set_transform_matrix(Transform2D.IDENTITY)


## 在巨口局部坐标里画帧条的一帧：帧里的 anchor 对准 pos（不能用 SpriteVisual.draw_frame，它会覆盖巨口的镜像 / 旋转）
func _blit(basis: Transform2D, strip: Texture2D, frames: int, frame: int, pos: Vector2, anchor: Vector2, tint := Color.WHITE) -> void:
	if strip == null:
		return
	var size := Vector2(strip.get_width() / frames, strip.get_height())
	_maw_layer.draw_set_transform_matrix(basis * Transform2D(0.0, pos))
	_maw_layer.draw_texture_rect_region(strip, Rect2(-anchor, size), Rect2(Vector2(size.x * posmod(frame, frames), 0), size), tint)


## 维达撑口：上下颚按维达手、靴子的接触点摆放（不拉伸维达），这段时间没有任何判定
func _draw_vidar(basis: Transform2D, frame: int) -> void:
	var contacts := vidar_contacts()
	var hand := contacts[0]
	var boot := contacts[1]
	if _vidar_pried:  # 撕开之后上下颚往外翻开
		var k := minf(1.0, (_vidar_t - VIDAR_TIME) / 0.25)
		hand.y -= 40.0 * k
		boot.y += 40.0 * k
	var edges := _jaw_edges if not _jaw_edges.is_empty() else {"upper": 115, "lower": 13}
	_blit(basis, _upper, 4, frame, hand - Vector2(JAW_CONTACT_X, edges.upper) + UPPER_ANCHOR, UPPER_ANCHOR)
	_blit(basis, _lower, 4, frame, boot - Vector2(JAW_CONTACT_X, edges.lower) + LOWER_ANCHOR, LOWER_ANCHOR)
	var fade := 1.0 if _vidar_t < VIDAR_TIME + VIDAR_LEAVE - 0.3 else maxf(0.0, (VIDAR_TIME + VIDAR_LEAVE - _vidar_t) / 0.3)
	var strip := _vidar_pry if not _vidar_pried or _vidar_t < VIDAR_TIME + 0.3 else _vidar_idle
	var count := 6 if strip == _vidar_pry else 4
	var index := vidar_frame() if strip == _vidar_pry else int(_vidar_t * 8.0) % 4
	_blit(basis, strip, count, index, _vidar_local, VIDAR_FOOT, Color(1, 1, 1, fade))
	_maw_layer.draw_set_transform_matrix(Transform2D.IDENTITY)
