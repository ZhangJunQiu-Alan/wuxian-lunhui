class_name Surtr
extends Boss
## 苏尔特 · 黑焰之王（篇章一 第 3 关 09:00，篇章最终 Boss）
## 六个动作画布 320×320，脚锚 (160,318)（K3 v1.2，覆盖基础契约的 256 规格）；静态 surtr.png 仍是 192
## 技能：
##   炎之剑横扫：蓄力时画出扇形，出招第 1 帧（从 0 数）结算，扇形里留下几块残火
##   穆斯贝尔之门：召唤动作第 2 帧张掌，玩家附近打开火门，放出火焰巨人（受敌人上限约束）
##   60% 血量（一次）九界燃烧：以当时玩家的位置为圆心，安全圆从外向里收缩，圆外持续掉血
##   25% 血量（一次）终焉之火：插剑后停在原地，安全圆里每隔几秒爆发一次火焰，只有符文标记的 64 格安全格能站人
##     格坐标 floor(world / 64)（负数也向下取整）；预警、符文、火焰和伤害用同一份格子集合
## 改写命运的援助（托尔落雷、弗雷治疗）由 VigridBattle 负责
## 数值见 VigridTuning

const FOOT := Vector2(160, 318)
const K_ACTIONS := {"idle": true, "move": true, "windup": false, "attack": false, "plant": false, "summon": false}
const RELEASE_FRAME := 1      # 横扫：出招第 1 帧接触
const PALM_FRAME := 2         # 召唤：第 2 帧张掌开门
const SWORD_FRAME := 2        # 插剑：第 2 帧剑尖触地
const RUNE := "surtr_safe_rune"
const FINAL_FIRE := "surtr_final_fire"
const BAND := "surtr_firewall_band"
const ARC_RADIUS := 60.0      # 剑弧贴图里弧的半径（128 方帧，中心锚点），按扇形半径缩放
const SKILLS := ["sweep", "sweep", "summon"]
const FIRE := Color(1.0, 0.45, 0.12)

var phase := 1
var firewall_center := Vector2.ZERO
var firewall_radius := 0.0
var firewall_age := -1.0      # >= 0：九界燃烧已经开始
var final_safe := {}          # 终焉之火这一轮的安全格 Vector2i -> true
var final_unsafe := {}        # 这一轮会爆发的格子
var final_area: Array[Vector2i] = []  # 这一轮规划时安全圆里的全部格子（安全 + 不安全）
var final_rows: Array[Rect2] = []     # 不安全格按行合并成的横条（预警和火焰按它画，几百个格子只要几十次绘制）
var final_columns: Array[Rect2] = []  # 按列合并的竖条（画格子竖线）
static var _fire_frames: Array[Texture2D] = []  # 终焉之火贴图切成单帧，横条里平铺
var final_stage := ""         # warn / burn / rest
var final_t := 0.0
var final_cycles := 0
var gates: Array[Dictionary] = []  # {"pos", "age", "spawned"}
var _cycle := 0
var _sweep_dir := Vector2.RIGHT
var _released := false
var _layer: Node2D


func _init() -> void:
	intro_line = tr("苏尔特 · 黑焰之王 —— 炎之剑比太阳更亮")
	defeat_line = tr("「这把火……本来就该燃起……我只是……先你一步……」")


func init_stats(hp_scale: float) -> void:
	setup_boss("surtr", tr("苏尔特"), tr("黑焰之王"), VigridTuning.FIRE_HP, hp_scale, 50.0, 70.0, VigridTuning.FIRE_CONTACT)
	actions = K_ACTIONS
	gait = "heavy"
	color = Color(0.85, 0.3, 0.1)
	reward_points = 400
	state_actions = {"sweep_windup": &"windup", "sweep": &"attack", "summon": &"summon", "plant": &"plant", "final": &"plant", "recover": &"idle"}


func _ready() -> void:
	super._ready()
	fit_k_actor(FOOT)
	_layer = Node2D.new()
	_layer.name = "Fire"
	_layer.top_level = true
	_layer.z_index = -1
	_layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_layer.draw.connect(_draw_fire_layer)
	add_child(_layer)
	change_state("chase")


# ———— 几何（静态函数，测试直接调用）————

## 终焉之火的格坐标：floor(world / 64)，负数也向下取整（-1 → -1，-64 → -1，-65 → -2）
static func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / VigridTuning.FINAL_CELL), floori(pos.y / VigridTuning.FINAL_CELL))


static func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * VigridTuning.FINAL_CELL, Vector2.ONE * VigridTuning.FINAL_CELL)


## 格子中心在圆里、整格在地图里的所有格子
static func cells_in_circle(center: Vector2, r: float, map_bounds: Rect2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var from := cell_of(center - Vector2.ONE * r)
	var to := cell_of(center + Vector2.ONE * r)
	for x in range(from.x, to.x + 1):
		for y in range(from.y, to.y + 1):
			var cell := Vector2i(x, y)
			var box := cell_rect(cell)
			if box.get_center().distance_to(center) <= r and map_bounds.encloses(box):
				cells.append(cell)
	return cells


## 这一轮的安全格：若干块 2×2，第一块保证离玩家所在格不超过 FINAL_SAFE_REACH 格（来得及跑过去）
static func plan_cells(area: Array[Vector2i], player_cell: Vector2i, rng: RandomNumberGenerator, allowed_safe: Dictionary = {}) -> Dictionary:
	var lookup := {}
	for cell in area:
		lookup[cell] = true
	var blocks: Array[Vector2i] = []
	var near: Array[Vector2i] = []
	for cell in area:
		if not allowed_safe.is_empty() and not [cell, cell + Vector2i(1, 0), cell + Vector2i(0, 1), cell + Vector2i(1, 1)].all(func(c): return allowed_safe.has(c)):
			continue
		if lookup.has(cell + Vector2i(1, 0)) and lookup.has(cell + Vector2i(0, 1)) and lookup.has(cell + Vector2i(1, 1)):
			blocks.append(cell)
			if maxi(absi(cell.x - player_cell.x), absi(cell.y - player_cell.y)) <= VigridTuning.FINAL_SAFE_REACH:
				near.append(cell)
	var safe := {}
	if blocks.is_empty():
		return {"safe": safe, "unsafe": lookup}
	var first: Vector2i
	if not near.is_empty():
		first = near[rng.randi() % near.size()]
	else:  # 玩家不在区域里：取离玩家最近的一块
		first = blocks[0]
		for cell in blocks:
			if Vector2(cell - player_cell).length() < Vector2(first - player_cell).length():
				first = cell
	var picks: Array[Vector2i] = [first]
	for i in VigridTuning.FINAL_SAFE_BLOCKS - 1:
		picks.append(blocks[rng.randi() % blocks.size()])
	for block in picks:
		for offset in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			safe[block + offset] = true
	var unsafe := {}
	for cell in area:
		if not safe.has(cell):
			unsafe[cell] = true
	return {"safe": safe, "unsafe": unsafe}


## 把格子集合按行（vertical = true 时按列）合并成连续的长条，返回世界坐标的矩形
static func merge_runs(cells: Dictionary, vertical: bool) -> Array[Rect2]:
	var lines := {}
	for cell: Vector2i in cells:
		var line := cell.x if vertical else cell.y
		if not lines.has(line):
			lines[line] = []
		lines[line].append(cell.y if vertical else cell.x)
	var runs: Array[Rect2] = []
	var size := VigridTuning.FINAL_CELL
	for line: int in lines:
		var list: Array = lines[line]
		list.sort()
		var from: int = list[0]
		for i in range(1, list.size() + 1):
			if i < list.size() and list[i] == list[i - 1] + 1:
				continue
			var count: int = list[i - 1] - from + 1
			runs.append(Rect2(line * size, from * size, size, count * size) if vertical else Rect2(from * size, line * size, count * size, size))
			if i < list.size():
				from = list[i]
	return runs


static func sweep_polygon(center: Vector2, dir: Vector2) -> PackedVector2Array:
	return BossFx.sector(center, VigridTuning.SWEEP_RADIUS, dir.angle(), VigridTuning.SWEEP_HALF)


## 九界燃烧的安全圆半径：从 FIREWALL_START 线性收缩到 FIREWALL_MIN
static func firewall_radius_at(age: float) -> float:
	return lerpf(VigridTuning.FIREWALL_START, VigridTuning.FIREWALL_MIN, clampf(age / VigridTuning.FIREWALL_SHRINK, 0.0, 1.0))


func in_firewall(pos: Vector2) -> bool:
	return firewall_age >= 0.0 and pos.distance_to(firewall_center) > firewall_radius + 0.001


func foot_cell() -> Vector2i:
	return cell_of(target.global_position + Vector2(0, MapLayer.FOOT))


# ———— 行动 ————

func change_state(new_state: String) -> void:
	_released = false  # 每个出招状态各自只结算一次
	super.change_state(new_state)


func _update_state(delta: float) -> void:
	_check_phases()
	_tick_firewall(delta)
	_tick_gates(delta)
	match state:
		"chase":
			chase(delta)
			if state_time >= VigridTuning.FIRE_CHASE:
				var skill: String = SKILLS[_cycle % SKILLS.size()]
				_cycle += 1
				change_state("sweep_windup" if skill == "sweep" else "summon")
		"sweep_windup":
			if state_time < VigridTuning.SWEEP_WINDUP * 0.6:  # 前六成还在瞄，之后锁定方向，预警时长由这里控制
				_sweep_dir = global_position.direction_to(target.global_position)
			if state_time >= VigridTuning.SWEEP_WINDUP:
				change_state("sweep")
		"sweep":
			if not _released and state_time >= RELEASE_FRAME / SpriteVisual.ACTION_FPS.attack:
				_released = true
				_sweep()
			if state_time >= 0.6:
				change_state("recover")
		"summon":
			if not _released and state_time >= PALM_FRAME / SpriteVisual.ACTION_FPS.attack:
				_released = true
				_open_gates()
			if state_time >= 0.8:
				change_state("recover")
		"plant":
			if not _released and state_time >= SWORD_FRAME / SpriteVisual.ACTION_FPS.attack:
				_released = true  # 25% 阶段的声音是越过阈值时的 boss_warning（K6 事件表），这里只有画面
				target.shake(12.0, 0.4)
				FxLayer.burst(global_position + Vector2(0, MapLayer.FOOT), FIRE, 40, 300.0, 5.0)
			if state_time >= 0.7:
				final_t = 0.0
				_plan_final()
				change_state("final")
		"final":
			_tick_final(delta)
		"recover":
			if state_time >= 0.7:
				change_state("chase")
	_layer.queue_redraw()


## 60% / 25% 各触发一次。一次掉很多血同时越过两个阈值时，按顺序都触发
func _check_phases() -> void:
	if phase < 2 and hp <= max_hp * VigridTuning.PHASE_FIREWALL:
		phase = 2
		Audio.sfx("boss_warning")
		_announce(tr("九界燃烧 —— 火焰从平原的边缘烧向中心"))
		firewall_center = Game.bounds.grow(-VigridTuning.FIREWALL_MIN).get_center() if not is_instance_valid(target) else \
			target.global_position.clamp(Game.bounds.position + Vector2.ONE * VigridTuning.FIREWALL_MIN, Game.bounds.end - Vector2.ONE * VigridTuning.FIREWALL_MIN)
		firewall_age = 0.0
		firewall_radius = firewall_radius_at(0.0)
	if phase < 3 and hp <= max_hp * VigridTuning.PHASE_FINAL:
		phase = 3
		Audio.sfx("boss_warning")
		_announce(tr("终焉之火 —— 苏尔特把剑插进了大地"))
		change_state("plant")


func _announce(text: String) -> void:
	var game := get_tree().current_scene
	if game.get("hud"):
		game.hud.announce(text)


func _tick_firewall(delta: float) -> void:
	if firewall_age < 0.0:
		return
	firewall_age += delta
	firewall_radius = firewall_radius_at(firewall_age)
	if in_firewall(target.global_position):
		target.take_dot(VigridTuning.FIREWALL_DPS * delta)


func _sweep() -> void:
	Audio.sfx("katana_slash", 2.0, 0.02)
	var polygon := sweep_polygon(global_position, _sweep_dir)
	if Geometry2D.is_point_in_polygon(target.global_position, polygon):
		target.take_damage(VigridTuning.SWEEP_DAMAGE)
	target.shake(6.0, 0.2)
	BossFx.play("surtr_sword_arc", global_position, _sweep_dir.angle(), Vector2.ONE * VigridTuning.SWEEP_RADIUS / ARC_RADIUS,
		Color.WHITE, false, VigridTuning.SWEEP_RADIUS, VigridTuning.SWEEP_HALF)
	for k in [-0.6, 0.0, 0.6]:  # 残火落在扇形里
		var at := global_position + _sweep_dir.rotated(k * VigridTuning.SWEEP_HALF) * VigridTuning.SWEEP_RADIUS * 0.7
		FireHazard.patch(get_parent(), Game.clamp_to_map(at, 32.0), VigridTuning.RESIDUAL_LIFE, VigridTuning.RESIDUAL_DPS)


func _open_gates() -> void:
	Audio.sfx("surtr_gate")
	var base := global_position.direction_to(target.global_position).angle()
	for i in VigridTuning.GATE_COUNT:
		var angle := base + PI + (i - (VigridTuning.GATE_COUNT - 1) * 0.5) * 1.2
		var at := Game.clamp_to_map(target.global_position + Vector2.from_angle(angle) * 300.0, 80.0)
		gates.append({"pos": at, "age": 0.0, "spawned": 0})


func _tick_gates(delta: float) -> void:
	var alive: Array[Dictionary] = []
	for gate in gates:
		gate.age += delta
		var due := int(gate.age / (VigridTuning.GATE_LIFE * 0.8) * VigridTuning.GATE_GIANTS + 0.3)
		while gate.spawned < mini(due, VigridTuning.GATE_GIANTS):
			gate.spawned += 1
			if spawner.is_valid():
				spawner.call("fire_giant", gate.pos + Vector2(randf_range(-16, 16), 6))
		if gate.age < VigridTuning.GATE_LIFE:
			alive.append(gate)
	gates = alive


func _plan_final() -> void:
	var area := cells_in_circle(firewall_center if firewall_age >= 0.0 else global_position, firewall_radius if firewall_age >= 0.0 else VigridTuning.FIREWALL_MIN, Game.bounds)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([final_cycles, get_instance_id()])
	final_area = area
	var allowed_safe := {}
	var safe_center := firewall_center if firewall_age >= 0.0 else global_position
	var safe_radius := firewall_radius_at(firewall_age + VigridTuning.FINAL_WARN + VigridTuning.FINAL_BURN + 0.1) if firewall_age >= 0.0 else VigridTuning.FIREWALL_MIN
	for cell in area:
		var box := cell_rect(cell)
		var corners := [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]
		if corners.all(func(p: Vector2): return (p - Vector2(0, MapLayer.FOOT)).distance_to(safe_center) <= safe_radius):
			allowed_safe[cell] = true
	var plan := plan_cells(area, foot_cell(), rng, allowed_safe)
	final_safe = plan.safe
	final_unsafe = plan.unsafe
	final_rows = merge_runs(final_unsafe, false)
	final_columns = merge_runs(final_unsafe, true)
	final_stage = "warn"
	final_t = 0.0


## 终焉之火：预警 → 爆发（伤害只在爆发瞬间结算一次）→ 间歇 → 重新规划安全格
func _tick_final(delta: float) -> void:
	final_t += delta
	match final_stage:
		"warn":
			if final_t >= VigridTuning.FINAL_WARN:
				final_stage = "burn"
				final_t = 0.0
				Audio.sfx("boss_slam", -2.0)  # 一批格子一起爆发，只放一次
				Audio.sfx("fire_burn", -2.0)
				target.shake(8.0, 0.25)
				if final_unsafe.has(foot_cell()):
					target.take_damage(VigridTuning.FINAL_DAMAGE)
		"burn":
			if final_t >= VigridTuning.FINAL_BURN:
				final_stage = "rest"
				final_t = 0.0
		"rest":
			if final_t >= VigridTuning.FINAL_REST:
				final_cycles += 1
				_plan_final()


func chase(delta: float, speed_mult: float = 1.0) -> void:
	if phase < 3:
		super.chase(delta, speed_mult)


# ———— 画面 ————

static func _final_fire_frames() -> Array[Texture2D]:
	if _fire_frames.is_empty() and BossFx.texture(FINAL_FIRE):
		var image := BossFx.texture(FINAL_FIRE).get_image()
		var cell := int(VigridTuning.FINAL_CELL)
		for i in 4:
			_fire_frames.append(ImageTexture.create_from_image(image.get_region(Rect2i(i * cell, 0, cell, cell))))
	return _fire_frames


func _draw_telegraph() -> void:
	if state == "sweep_windup":
		var t := state_time / VigridTuning.SWEEP_WINDUP
		var local := PackedVector2Array()
		for p in sweep_polygon(Vector2.ZERO, _sweep_dir):
			local.append(p)
		draw_colored_polygon(local, Color(FIRE, 0.1 + 0.25 * t))
		local.append(local[0])
		draw_polyline(local, Color(FIRE.lightened(0.3), 0.8), 2.0)


func _draw_fire_layer() -> void:
	if _dead:
		return
	for gate in gates:  # 火门画在角色下面，走出来的巨人在门前
		var fade := minf(1.0, gate.age / 0.3) * minf(1.0, (VigridTuning.GATE_LIFE - gate.age) / 0.4)
		if not BossFx.draw(_layer, "surtr_gate", gate.age, gate.pos, 0.0, Vector2.ONE, Color(1, 1, 1, fade)):
			_layer.draw_circle(gate.pos, 40.0, Color(FIRE, 0.5 * fade))
	if firewall_age >= 0.0:
		_draw_firewall()
	if phase >= 3 and final_stage != "":
		_draw_final()


## 九界燃烧：圆外整片发红，边界上一圈火墙条带（上半火焰朝外，内侧透明），再画一条清楚的边界线
## 红色区域和条带各自合成一次提交（BossFx.draw_quads），红色只画到镜头看得到的地方
func _draw_firewall() -> void:
	var c := firewall_center
	var r := firewall_radius
	var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	var outer := maxf(r + 64.0, c.distance_to(view.get_center()) + view.size.length() * 0.5 + 32.0)
	var steps := 72
	var ring := PackedVector2Array()
	for i in steps:
		var a0 := Vector2.from_angle(TAU * i / steps)
		var a1 := Vector2.from_angle(TAU * (i + 1) / steps)
		ring.append_array([c + a0 * (r + 30.0), c + a1 * (r + 30.0), c + a1 * outer, c + a0 * outer])
	BossFx.draw_quads(_layer, ring, PackedVector2Array(), null, Color(0.9, 0.25, 0.05, 0.22))
	var strip := BossFx.texture(BAND)
	if strip:
		var frame := posmod(int(firewall_age * BossFx.fps(BAND)), 4)
		var tiles := maxi(8, roundi(TAU * r / 64.0))  # 每段弧长约 64，贴图横向一整块
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in tiles:
			for k in 3:  # 每块再分 3 段，弧线更圆
				var a0 := Vector2.from_angle(TAU * (i + k / 3.0) / tiles)
				var a1 := Vector2.from_angle(TAU * (i + (k + 1) / 3.0) / tiles)
				points.append_array([c + a0 * (r + 32.0), c + a1 * (r + 32.0), c + a1 * (r - 32.0), c + a0 * (r - 32.0)])
				var u0 := (frame + k / 3.0) / 4.0
				var u1 := (frame + (k + 1) / 3.0) / 4.0
				uvs.append_array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)])
		BossFx.draw_quads(_layer, points, uvs, strip)
	else:
		_layer.draw_arc(c, r + 16.0, 0.0, TAU, 96, Color(FIRE, 0.7), 32.0)
	_layer.draw_arc(c, r, 0.0, TAU, 128, Color(1.0, 0.85, 0.5, 0.8), 2.0)


func _draw_final() -> void:
	var size := Vector2.ONE * VigridTuning.FINAL_CELL
	var half := size * 0.5
	match final_stage:
		"warn":  # 不安全格整片发红，格线标出每一格
			var t := final_t / VigridTuning.FINAL_WARN
			var line := Color(1.0, 0.5, 0.2, 0.35 + 0.4 * t)
			for run in final_rows:
				_layer.draw_rect(run, Color(1.0, 0.2, 0.05, 0.12 + 0.3 * t))
				_layer.draw_line(run.position, Vector2(run.end.x, run.position.y), line, 1.0)
				_layer.draw_line(Vector2(run.position.x, run.end.y), run.end, line, 1.0)
			for run in final_columns:
				_layer.draw_line(run.position, Vector2(run.position.x, run.end.y), line, 1.0)
				_layer.draw_line(Vector2(run.end.x, run.position.y), run.end, line, 1.0)
		"burn":  # 同一份横条里平铺火焰帧，每格一帧图
			var frames := _final_fire_frames()
			var frame := mini(3, int(final_t * BossFx.fps(FINAL_FIRE)))
			for run in final_rows:
				if frames.is_empty():
					_layer.draw_rect(run, Color(1.0, 0.4, 0.1, 0.7))
				else:
					_layer.draw_texture_rect(frames[frame], run, true)
	if final_stage == "rest":
		return
	for cell: Vector2i in final_safe:  # 安全格的符文在预警和火焰上面
		var center := Vector2(cell) * size + half
		if not BossFx.draw(_layer, RUNE, 0.0, center):
			_layer.draw_rect(cell_rect(cell).grow(-6.0), Color(0.5, 0.9, 1.0, 0.6), false, 2.0)
