class_name Jormungandr
extends Boss
## 耶梦加得 · 尘世巨蟒（篇章一 第 3 关 03:00）
## 只有蛇头是 Boss：在敌人组、空间索引和第 2 碰撞层里，能被打、能被锁定。蛇身和蛇尾不是节点，
## 沿同一条闭合路径（圆角矩形）画出来，也用同一条折线做接触判定：撞飞玩家，有自己的命中冷却
## 技能：
##   环绕：蛇头沿路径顺时针游动，身体跟在后面；路径每隔一段时间收紧一圈
##   毒液弹：游动途中不停下，朝玩家的预判位置吐几团毒液，落点先有圆形预警，落地留一小片毒雾
##   游完一段后按玩家离蛇头的远近出招，同一招不连出 3 次：
##   毒雾：玩家近。蛇头转向玩家（预判走位）蓄力，喷出扇形毒息，扇形区域留下一片毒雾。预警、毒息、毒雾用同一个多边形
##   猛噬：玩家远。蛇头离开路径，沿预警长条冲向玩家，身体被拉成一条横穿场地的颈；
##         扑空后咬进地里拔不出来（受到的伤害更高），再缩回路径。最后一小段蓄力锁定方向，横向走开就能躲
##   狂怒：血量低于一半，游得更快，毒液弹更多，猛噬的落点留下毒雾
## 改写命运：信仰托尔，并且在本场遭遇开始后（只算未暂停的时间）90 秒内击败它 → 托尔活下来，在最终战参战
## 数值见 VigridTuning

const HEAD_ACTIONS := {"idle": true, "windup": false, "attack": false}
const NECK := Vector2(-64, -2)   # 颈口 socket (0,62) 相对头部锚点 (64,64)
const MOUTH := Vector2(44, 2)    # 喷口 (108,66) 相对头部锚点
const BODY_PATH := "res://assets/sprites/bosses/jormungandr_body.png"  # 64×64，左右 socket (0,30) / (64,30)
const TAIL_PATH := "res://assets/sprites/bosses/jormungandr_tail.png"  # 64×64，右侧 socket (64,30) 接身体
const POOL_PATH := "res://assets/sprites/effects/poison_pool.png"      # 48×48 8 帧
const BODY_TOP := 30.0      # 贴图中线 y=30：中线以上 30 像素、以下 34 像素
const BODY_BOTTOM := 34.0
const SAMPLE := 16.0        # 身体折线的采样间距
const OVERLAP := 2.0        # 颈口和身体重叠 2 像素，消除采样边界的缝
const RELEASE_FRAME := 1    # 出招动作第 1 帧（从 0 数）喷出毒息
const POISON := Color(0.4, 0.75, 0.3)

var encounter_age := 0.0          # 本场遭遇的未暂停时长（托尔的 90 秒按它算，不是关卡总时间）
var rect := Rect2()               # 当前的环绕路径（圆角矩形）
var body_points := PackedVector2Array()  # 颈口 → 尾根的身体中线，绘制和接触判定共用
var mists: Array[Dictionary] = [] # 毒雾：{"polygon", "age", "life"}
var spits: Array[Dictionary] = [] # 飞行中的毒液弹：{"from", "to", "t"}，t < 0 是还没吐出
var raged := false
var lunge_dir := Vector2.RIGHT
var lunge_length := 0.0
var lunge_from := Vector2.ZERO
var _lunge_hit := false
var _spat := false
var _last_attack := ""
var _streak := 0
var _from_rect := Rect2()
var _to_rect := Rect2()
var _contract_t := -1.0
var _contract_timer := 0.0
var _u := 0.0                     # 蛇头在路径上的位置（0~1，周长的比例）
var _head_angle := 0.0
var _released := false
var _breath_polygon := PackedVector2Array()
var _body_cd := 0.0
var _body: Node2D
var _mist_layer: Node2D
var _body_tex: Texture2D
var _tail_tex: Texture2D
var _pool_tex: Texture2D


func _init() -> void:
	intro_line = tr("耶梦加得 · 尘世巨蟒 —— 它松开了咬住的尾巴")
	defeat_line = tr("「父亲的……锁链……终于……」")


func init_stats(hp_scale: float) -> void:
	setup_boss("jormungandr", tr("耶梦加得"), tr("尘世巨蟒"), VigridTuning.SERPENT_HP, hp_scale, 40.0, 0.0, VigridTuning.SERPENT_CONTACT)
	sprite_name = "jormungandr_head"
	actions = HEAD_ACTIONS
	gait = "float"
	ghost = true  # 蛇头贴着路径走，不被物件推开
	casts_shadow = false
	color = Color(0.25, 0.45, 0.4)
	reward_points = 200
	state_actions = {"coil": &"idle", "breath_windup": &"windup", "breath": &"attack", "recover": &"idle",
		"lunge_windup": &"windup", "lunge": &"attack", "bite": &"idle", "retract": &"idle"}


func _ready() -> void:
	super._ready()
	fit_k_actor(Vector2(64, 64))
	if _sprite:  # 蛇头绕锚点 (64,64) 转向，不按脚底
		_sprite.set("offset", Vector2.ZERO)
		_sprite.position = Vector2.ZERO
		_sprite.set_meta("base_pos", Vector2.ZERO)
	_body_tex = load(BODY_PATH) if ResourceLoader.exists(BODY_PATH) else null
	_tail_tex = load(TAIL_PATH) if ResourceLoader.exists(TAIL_PATH) else null
	_pool_tex = load(POOL_PATH) if ResourceLoader.exists(POOL_PATH) else null
	var center := target.global_position if is_instance_valid(target) else global_position
	rect = path_rect(center, Game.bounds)
	_u = nearest_u(rect, global_position)
	_mist_layer = _world_layer("Mist", _draw_mists)
	_body = _world_layer("Body", _draw_body)
	_body.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_head_angle = path_at(rect, _u * perimeter(rect))[1].angle()
	_place_head(0.0)
	change_state("coil")


## 画在世界坐标、角色下面的一层（蛇身、毒雾）
func _world_layer(layer_name: String, painter: Callable) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	layer.top_level = true
	layer.z_index = -1
	layer.draw.connect(painter)
	add_child(layer)
	return layer


# ———— 路径（静态函数，测试直接调用）————

## 环绕路径：以 center 为中心的 SERPENT_SQUARE 方区，和地图内缩 SERPENT_INSET 求交
static func path_rect(center: Vector2, map_bounds: Rect2) -> Rect2:
	var square := Rect2(center - Vector2.ONE * VigridTuning.SERPENT_SQUARE * 0.5, Vector2.ONE * VigridTuning.SERPENT_SQUARE)
	return square.intersection(map_bounds.grow(-VigridTuning.SERPENT_INSET))


static func corner(r: Rect2) -> float:
	return minf(VigridTuning.SERPENT_CORNER, minf(r.size.x, r.size.y) * 0.5)


static func perimeter(r: Rect2) -> float:
	var c := corner(r)
	return 2.0 * (r.size.x + r.size.y) - 8.0 * c + TAU * c


## 路径上弧长 s 处的 [位置, 切线]。从左上圆角之后的上边起点开始，顺时针
static func path_at(r: Rect2, s: float) -> PackedVector2Array:
	var c := corner(r)
	var w := r.size.x - 2.0 * c
	var h := r.size.y - 2.0 * c
	var arc := PI * 0.5 * c
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	s = fposmod(s, perimeter(r))
	var pieces := [[w, Vector2(x0 + c, y0), Vector2.RIGHT], [arc, Vector2(x1 - c, y0 + c), -PI * 0.5],
		[h, Vector2(x1, y0 + c), Vector2.DOWN], [arc, Vector2(x1 - c, y1 - c), 0.0],
		[w, Vector2(x1 - c, y1), Vector2.LEFT], [arc, Vector2(x0 + c, y1 - c), PI * 0.5],
		[h, Vector2(x0, y1 - c), Vector2.UP], [arc, Vector2(x0 + c, y0 + c), PI]]
	for piece: Array in pieces:
		var length: float = piece[0]
		if s <= length or piece == pieces.back():
			if piece[2] is Vector2:  # 直边
				return PackedVector2Array([piece[1] + piece[2] * s, piece[2]])
			var angle: float = piece[2] + (s / c if c > 0.0 else 0.0)
			return PackedVector2Array([piece[1] + Vector2.from_angle(angle) * c, Vector2.from_angle(angle + PI * 0.5)])
		s -= length
	return PackedVector2Array([r.position, Vector2.RIGHT])


## 路径上离 pos 最近的位置（周长比例）
static func nearest_u(r: Rect2, pos: Vector2) -> float:
	var best := 0.0
	var best_d := INF
	var total := perimeter(r)
	for i in 256:
		var d := path_at(r, total * i / 256.0)[0].distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = i / 256.0
	return best


## 猛噬的冲刺长度：想冲 want，但落点不能出地图内缩 64 的范围
static func lunge_reach(from: Vector2, dir: Vector2, want: float, map_bounds: Rect2) -> float:
	var inner := map_bounds.grow(-64.0)
	var reach := want
	for axis in 2:
		if absf(dir[axis]) < 0.0001:
			continue
		var edge: float = inner.end[axis] if dir[axis] > 0.0 else inner.position[axis]
		reach = minf(reach, maxf(0.0, (edge - from[axis]) / dir[axis]))
	return reach


## 改写命运的条件：信仰托尔，并且本场遭遇的未暂停时长 <= 90 秒（90.001 就不算）
static func thor_condition(has_thor: bool, age: float) -> bool:
	return has_thor and age <= VigridTuning.THOR_DEADLINE


# ———— 行动 ————

func change_state(new_state: String) -> void:
	_released = false
	if new_state == "coil":
		_spat = false
	super.change_state(new_state)


## 游完一段后出哪一招：玩家在毒息射程里就喷，远了就猛噬；同一招最多连出 2 次
func next_attack() -> String:
	var near := global_position.distance_to(target.global_position) <= VigridTuning.BREATH_RANGE * 0.85
	var pick := "breath_windup" if near else "lunge_windup"
	if pick == _last_attack and _streak >= 2:
		pick = "lunge_windup" if pick == "breath_windup" else "breath_windup"
	_streak = _streak + 1 if pick == _last_attack else 1
	_last_attack = pick
	return pick


## 玩家 lead 秒后的位置（按当前速度预判，收在地图里）
func aim_point(lead: float) -> Vector2:
	var at: Vector2 = target.global_position + target.velocity * lead
	return at.clamp(Game.bounds.position, Game.bounds.end)


## 咬进地里：可以多吃伤害
func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, crit: bool = false) -> void:
	super.take_damage(amount * (VigridTuning.LUNGE_WEAK_MULT if state == "bite" else 1.0), knockback, crit)


func _physics_process(delta: float) -> void:
	if not _dead:
		encounter_age += delta  # 物理帧只在没暂停时跑，所以这就是未暂停时长
	super._physics_process(delta)


func _update_state(delta: float) -> void:
	_update_contraction(delta)
	if not raged and hp <= max_hp * VigridTuning.SERPENT_RAGE_AT:
		raged = true
		Audio.sfx("jormungandr_hiss", 2.0, 0.0)
		target.shake(8.0, 0.4)
	match state:
		"coil":
			var total := perimeter(rect)
			var speed_mult := VigridTuning.SERPENT_RAGE_SPEED if raged else 1.0
			_u = fposmod(_u + VigridTuning.SERPENT_SPEED * speed_mult * move_mult() * delta / total, 1.0)
			_place_head(delta)
			if not _spat and state_time >= VigridTuning.SERPENT_COIL_TIME * 0.5:
				_spat = true
				_spit()
			if state_time >= VigridTuning.SERPENT_COIL_TIME:
				change_state(next_attack())
		"breath_windup":
			_place_head(0.0)
			var tangent := path_at(rect, _u * perimeter(rect))[1].angle()
			var want := clampf(angle_difference(tangent, global_position.direction_to(aim_point(VigridTuning.BREATH_LEAD)).angle()), -VigridTuning.BREATH_TURN, VigridTuning.BREATH_TURN)
			_head_angle = lerp_angle(_head_angle, tangent + want, minf(1.0, delta * 6.0))
			_breath_polygon = breath_polygon(mouth(), _head_angle)
			if state_time >= VigridTuning.BREATH_WINDUP:
				change_state("breath")
		"breath":
			_place_head(0.0)
			if not _released and state_time >= RELEASE_FRAME / SpriteVisual.ACTION_FPS.attack:
				_released = true
				_breathe()
			if state_time >= 0.7:
				change_state("coil")
		"lunge_windup":
			_place_head(0.0)
			if state_time < VigridTuning.LUNGE_WINDUP - VigridTuning.LUNGE_LOCK:  # 最后一小段锁定方向
				var aim := aim_point(VigridTuning.BREATH_LEAD)
				_head_angle = lerp_angle(_head_angle, global_position.direction_to(aim).angle(), minf(1.0, delta * 8.0))
				lunge_dir = Vector2.from_angle(_head_angle)
				var want := clampf(global_position.distance_to(aim) + 80.0, VigridTuning.LUNGE_MIN, VigridTuning.LUNGE_RANGE)
				lunge_length = lunge_reach(global_position, lunge_dir, want, Game.bounds)
			if state_time >= VigridTuning.LUNGE_WINDUP:
				lunge_from = global_position
				_lunge_hit = false
				change_state("lunge")
		"lunge":
			var travelled := minf(lunge_length, state_time * VigridTuning.LUNGE_SPEED)
			position = lunge_from + lunge_dir * travelled
			_lunge_contact()
			if travelled >= lunge_length:
				_bite()
		"bite":
			if state_time >= VigridTuning.LUNGE_STUCK:
				lunge_from = global_position
				change_state("retract")
		"retract":
			var k := minf(1.0, state_time / VigridTuning.LUNGE_RETRACT)
			var at := path_at(rect, _u * perimeter(rect))
			position = lunge_from.lerp(at[0], k * k * (3.0 - 2.0 * k))
			_head_angle = lerp_angle(_head_angle, at[1].angle(), minf(1.0, delta * 6.0))
			if k >= 1.0:
				change_state("coil")
	_update_body()
	_body_contact(delta)
	_tick_spits(delta)
	_tick_mists(delta)
	_body.queue_redraw()
	_mist_layer.queue_redraw()


## 路径每隔一段时间往里收一圈（每边最多 128），过渡几秒，收到 SERPENT_MIN_SIZE 为止
func _update_contraction(delta: float) -> void:
	if _contract_t >= 0.0:
		_contract_t += delta
		var k := minf(1.0, _contract_t / VigridTuning.SERPENT_CONTRACT_TIME)
		rect = Rect2(_from_rect.position.lerp(_to_rect.position, k), _from_rect.size.lerp(_to_rect.size, k))
		if k >= 1.0:
			_contract_t = -1.0
		return
	_contract_timer += delta
	if _contract_timer < VigridTuning.SERPENT_CONTRACT_EVERY:
		return
	_contract_timer = 0.0
	var step := Vector2.ONE * VigridTuning.SERPENT_CONTRACT_STEP
	var size := (rect.size - step * 2.0).max(Vector2.ONE * VigridTuning.SERPENT_MIN_SIZE).min(rect.size)
	if size == rect.size:
		return
	_from_rect = rect
	_to_rect = Rect2(rect.get_center() - size * 0.5, size)
	_contract_t = 0.0


func _place_head(_delta: float) -> void:
	var at := path_at(rect, _u * perimeter(rect))
	position = at[0]
	if state == "coil":
		_head_angle = lerp_angle(_head_angle, at[1].angle(), 0.5)


func mouth() -> Vector2:
	return global_position + MOUTH.rotated(_head_angle)


## 毒息的扇形（裁到地图里）。预警、毒息伤害、地上的毒雾用的都是它
static func breath_polygon(from: Vector2, angle: float) -> PackedVector2Array:
	var sector := BossFx.sector(from, VigridTuning.BREATH_RANGE, angle, VigridTuning.BREATH_HALF)
	var b := Game.bounds
	var clipped := Geometry2D.intersect_polygons(sector, PackedVector2Array([b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]))
	return clipped[0] if not clipped.is_empty() else sector


func _breathe() -> void:
	Audio.sfx("jormungandr_hiss")
	_breath_polygon = breath_polygon(mouth(), _head_angle)
	if Geometry2D.is_point_in_polygon(target.global_position, _breath_polygon) and not Stonehenge.shields(get_tree(), target.global_position):
		target.take_damage(VigridTuning.BREATH_DAMAGE)
	mists.append({"polygon": _breath_polygon, "age": 0.0, "life": VigridTuning.MIST_LIFE})
	var scale := Vector2(VigridTuning.BREATH_RANGE / 92.0, VigridTuning.BREATH_RANGE * tan(VigridTuning.BREATH_HALF) / 32.0)
	BossFx.play("nidhogg_poison_breath", mouth(), _head_angle, scale, Color.WHITE, false, VigridTuning.BREATH_RANGE, VigridTuning.BREATH_HALF)


## 猛噬冲刺中，蛇头扫过的长条（半宽 LUNGE_HALF）碰到玩家：一次伤害并往路线外侧撞开
func _lunge_contact() -> void:
	if _lunge_hit or not is_instance_valid(target):
		return
	var nearest := Geometry2D.get_closest_point_to_segment(target.global_position, lunge_from, global_position)
	if nearest.distance_to(target.global_position) >= VigridTuning.LUNGE_HALF + Player.RADIUS:
		return
	_lunge_hit = true
	if target.is_invulnerable():
		return
	var side := signf(lunge_dir.cross(target.global_position - lunge_from))
	target.take_damage(VigridTuning.LUNGE_DAMAGE)
	target.shove((lunge_dir.orthogonal() * (side if side != 0.0 else 1.0) + lunge_dir * 0.4).normalized() * VigridTuning.LUNGE_SHOVE)
	target.shake(8.0, 0.25)


func _bite() -> void:
	change_state("bite")
	Audio.sfx("boss_slam")
	target.shake(10.0, 0.3)
	FxLayer.burst(mouth(), Color(0.55, 0.5, 0.4), 26, 220.0, 3.0)
	if raged:
		mists.append({"polygon": circle_polygon(mouth(), VigridTuning.LUNGE_MIST_RADIUS), "age": 0.0, "life": VigridTuning.MIST_LIFE})


static func circle_polygon(center: Vector2, r: float, segments: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		points.append(center + Vector2.from_angle(TAU * i / segments) * r)
	var b := Game.bounds
	var clipped := Geometry2D.intersect_polygons(points, PackedVector2Array([b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]))
	return clipped[0] if not clipped.is_empty() else points


## 毒液弹：第一团正对玩家的预判位置，其余散开；一团接一团吐出
func _spit() -> void:
	var center := aim_point(VigridTuning.SPIT_LEAD)
	var count := VigridTuning.SPIT_COUNT_RAGE if raged else VigridTuning.SPIT_COUNT
	var inner := Game.bounds.grow(-VigridTuning.SPIT_RADIUS)
	for i in count:
		var to := center
		if i > 0:
			to += Vector2.from_angle(TAU * i / (count - 1) + randf() * 0.6) * VigridTuning.SPIT_SPREAD * randf_range(0.95, 1.15)  # 外圈之间留出能跑出去的缝
		spits.append({"from": mouth(), "to": to.clamp(inner.position, inner.end), "t": -i * VigridTuning.SPIT_STAGGER})
	Audio.sfx("jormungandr_hiss", -8.0)


func _tick_spits(delta: float) -> void:
	var flying: Array[Dictionary] = []
	for spit in spits:
		spit.t += delta
		if spit.t < VigridTuning.SPIT_FLIGHT:
			flying.append(spit)
			continue
		var to: Vector2 = spit.to
		if is_instance_valid(target) and target.global_position.distance_to(to) < VigridTuning.SPIT_RADIUS + Player.RADIUS \
				and not Stonehenge.shields(get_tree(), target.global_position):
			target.take_damage(VigridTuning.SPIT_DAMAGE)
		mists.append({"polygon": circle_polygon(to, VigridTuning.SPIT_RADIUS), "age": 0.0, "life": VigridTuning.SPIT_MIST_LIFE})
		FxLayer.burst(to, POISON, 10, 140.0, 2.5)
	spits = flying


func _tick_mists(delta: float) -> void:
	var inside := false
	var alive: Array[Dictionary] = []
	for mist in mists:
		mist.age += delta
		if mist.age >= mist.get("life", VigridTuning.MIST_LIFE):
			continue
		alive.append(mist)
		if not inside and is_instance_valid(target) and Geometry2D.is_point_in_polygon(target.global_position, mist.polygon):
			inside = true
	mists = alive
	if inside:
		target.take_dot(VigridTuning.MIST_DPS * delta)


## 身体中线：从颈口开始，三次贝塞尔弯回路径（两端分别和蛇头朝向、路径切线相切，猛噬拉长时也不会折角），再沿路径往回采样到尾根
func _update_body() -> void:
	body_points = PackedVector2Array()
	var total := perimeter(rect)
	var head_s := _u * total
	var neck := global_position + NECK.rotated(_head_angle) + Vector2.from_angle(_head_angle) * OVERLAP
	var at := path_at(rect, head_s + NECK.x - SAMPLE * 3.0)
	var join := at[0]
	var reach := neck.distance_to(join)
	var c1 := neck - Vector2.from_angle(_head_angle) * minf(48.0, reach * 0.5) if reach < 96.0 else neck - Vector2.from_angle(_head_angle) * reach * 0.35
	var c2 := join + at[1] * reach * 0.35 if reach >= 96.0 else c1
	var steps := maxi(2, ceili(reach / (SAMPLE * 0.75)))
	for i in steps:
		var t := float(i) / steps
		body_points.append(neck.bezier_interpolate(c1, c2, join, t))
	var count := int(VigridTuning.SERPENT_BODY / SAMPLE)
	for i in range(3, count + 1):
		body_points.append(path_at(rect, head_s + NECK.x - SAMPLE * i)[0])


## 身体中线到 pos 的最近距离
func body_distance(pos: Vector2) -> Array:
	var best := INF
	var best_point := Vector2.ZERO
	for i in range(1, body_points.size()):
		var p := Geometry2D.get_closest_point_to_segment(pos, body_points[i - 1], body_points[i])
		var d := p.distance_to(pos)
		if d < best:
			best = d
			best_point = p
	return [best, best_point]


## 蛇身撞人：同一条中线，半宽 SERPENT_BODY_HALF。被撞到掉血并被撞飞，冷却期间不再判定
func _body_contact(delta: float) -> void:
	_body_cd -= delta
	if _body_cd > 0.0 or not is_instance_valid(target) or body_points.size() < 2:
		return
	var hit := body_distance(target.global_position)
	if hit[0] >= VigridTuning.SERPENT_BODY_HALF + Player.RADIUS:
		return
	_body_cd = VigridTuning.SERPENT_BODY_COOLDOWN
	if target.is_invulnerable():
		return
	var away: Vector2 = target.global_position - hit[1]
	if away.length() < 0.5:
		away = Vector2.from_angle(randf() * TAU)
	target.take_damage(VigridTuning.SERPENT_BODY_DAMAGE)
	target.shove(away.normalized() * VigridTuning.SERPENT_BODY_SHOVE)
	target.shake(6.0, 0.2)
	Audio.sfx("boss_slam", -4.0)


func _die() -> void:
	if not _dead:
		_check_thor()
	super._die()


func _check_thor() -> void:
	var game := get_tree().current_scene
	if not is_instance_valid(target) or not game.has_method("confirm_fate"):
		return
	if thor_condition(target.faith.has("thor"), encounter_age) and game.confirm_fate("thor_saved"):
		Audio.sfx("quest_done")
		game.hud.announce(tr("托尔挡下了毒液，没有倒下。他会在最终战中参战"))


# ———— 画面 ————

func _update_visual(_delta: float) -> void:
	_sprite.rotation = _head_angle  # 顺时针游动时，蛇背始终朝圈外
	_update_action()


func _draw_telegraph() -> void:
	draw_arc(Vector2.ZERO, radius + 10.0, 0.0, TAU, 40, Color(1.0, 0.85, 0.4, 0.35 + 0.2 * sin(state_time * 6.0)), 2.0)  # 只有蛇头能打
	if state == "bite":  # 咬进地里：弱点，金圈加粗闪烁
		var pulse := 0.5 + 0.5 * sin(state_time * 14.0)
		draw_arc(Vector2.ZERO, radius + 16.0, 0.0, TAU, 48, Color(1.0, 0.85, 0.3, 0.55 + 0.4 * pulse), 4.0)
	if state == "lunge_windup":
		var locked := state_time >= VigridTuning.LUNGE_WINDUP - VigridTuning.LUNGE_LOCK
		if locked:  # 锁定：整条变红变亮，马上冲出来
			draw_line_telegraph(self, lunge_dir, lunge_length, VigridTuning.LUNGE_HALF, 1.0, Color(1.0, 0.15, 0.1))
		else:  # 还在瞄准：淡黄、几乎只有边线，跟着玩家转
			draw_line_telegraph(self, lunge_dir, lunge_length, VigridTuning.LUNGE_HALF, -0.3, Color(1.0, 0.8, 0.3))
	for spit in spits:  # 飞行中的毒液团：画在空中（抛物线），落点预警在地面层
		if spit.t < 0.0:
			continue
		var k: float = spit.t / VigridTuning.SPIT_FLIGHT
		var at: Vector2 = spit.from.lerp(spit.to, k) - Vector2(0, sin(PI * k) * 160.0) - global_position
		draw_circle(at, 9.0, Color(POISON, 0.95))
		draw_arc(at, 9.0, 0.0, TAU, 16, Color(POISON.darkened(0.5), 0.9), 2.0)
	if state == "breath_windup" and _breath_polygon.size() > 2:
		var t := state_time / VigridTuning.BREATH_WINDUP
		var local := PackedVector2Array()
		for p in _breath_polygon:
			local.append(p - global_position)
		draw_colored_polygon(local, Color(POISON, 0.1 + 0.25 * t))
		local.append(local[0])
		draw_polyline(local, Color(POISON.lightened(0.3), 0.8), 2.0)


## 身体：沿中线一条连续的纹理带，u 按弧长每 64 像素重复一次；转角处用相邻两段的平均法线，接缝不会裂开
func _draw_body() -> void:
	if body_points.size() < 2 or _dead:
		return
	var normals := PackedVector2Array()
	for i in body_points.size():
		var a := body_points[maxi(0, i - 1)]
		var b := body_points[mini(body_points.size() - 1, i + 1)]
		normals.append(a.direction_to(b).orthogonal())  # 朝尾巴方向的法线，贴图上边在它的反方向
	if _body_tex == null:
		_body.draw_polyline(body_points, color, (BODY_TOP + BODY_BOTTOM) * 0.8)
		return
	var travelled := 0.0
	var quads := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in range(1, body_points.size()):
		var a := body_points[i - 1]
		var b := body_points[i]
		var step := a.distance_to(b)
		var u0 := travelled / 64.0
		var u1 := (travelled + step) / 64.0
		quads.append_array([a - normals[i - 1] * BODY_TOP, b - normals[i] * BODY_TOP, b + normals[i] * BODY_BOTTOM, a + normals[i - 1] * BODY_BOTTOM])
		uvs.append_array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)])
		travelled += step
	BossFx.draw_quads(_body, quads, uvs, _body_tex)  # 整条身体一次提交；直接给三角形，急弯处不做三角剖分
	if _tail_tex:  # 尾巴：右侧 socket (64,30) 接在身体末端，x 轴指向蛇头，上边和身体同一侧
		var end := body_points[body_points.size() - 1]
		var forward := end.direction_to(body_points[body_points.size() - 2])
		_body.draw_set_transform_matrix(Transform2D(forward, normals[normals.size() - 1], end))
		_body.draw_texture(_tail_tex, Vector2(-64, -BODY_TOP))
		_body.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_mists() -> void:
	for spit in spits:  # 毒液弹的落点：同一个半径
		draw_circle_telegraph(_mist_layer, spit.to, VigridTuning.SPIT_RADIUS, clampf(spit.t / VigridTuning.SPIT_FLIGHT, 0.0, 1.0), POISON)
	for mist in mists:
		var fade := minf(1.0, (mist.get("life", VigridTuning.MIST_LIFE) - mist.age) / 0.8) * minf(1.0, mist.age / 0.3)
		var polygon: PackedVector2Array = mist.polygon
		_mist_layer.draw_colored_polygon(polygon, Color(POISON, 0.22 * fade))
		if _pool_tex:
			var box := Rect2(polygon[0], Vector2.ZERO)
			for p in polygon:
				box = box.expand(p)
			var frame := int(mist.age * 8.0)
			var y := box.position.y + 24.0
			while y < box.end.y:
				var x := box.position.x + 24.0 + fmod(y, 48.0) * 0.5
				while x < box.end.x:
					if Geometry2D.is_point_in_polygon(Vector2(x, y), polygon):
						SpriteVisual.draw_frame(_mist_layer, _pool_tex, 8, frame + int(x + y), Vector2(x, y), Vector2(24, 24), 0.0, Vector2.ONE, Color(1, 1, 1, 0.55 * fade))
					x += 56.0
				y += 44.0
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		_mist_layer.draw_polyline(outline, Color(POISON.lightened(0.35), 0.75 * fade), 2.0)  # 毒雾的边界清楚可见
