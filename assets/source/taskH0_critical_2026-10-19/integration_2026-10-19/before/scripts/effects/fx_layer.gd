class_name FxLayer
extends Node2D
## 战斗反馈特效层：伤害数字、死亡碎片、刀痕爪痕、冲击波圈
## 所有数字和碎片都在这一个节点里统一绘制，比每个数字各建一个 Label 节点快得多，
## 同屏几百个也不卡。任何地方都可以直接调用 FxLayer.damage_number(...) / FxLayer.burst(...)

const MAX_NUMBERS := 150     # 同屏数字上限，超过就丢掉最旧的
const MAX_PARTICLES := 800
const NUMBER_LIFE := 0.6
const NUMBER_RISE := 45.0    # 数字每秒上浮多少像素
const PARTICLE_LIFE := 0.45
const MAX_MARKS := 120
const MARK_LIFE := 0.22
const RING_LIFE := 0.35
const RING := preload("res://assets/sprites/effects/frost_shockwave.png")
const RING_RADIUS := 62.0  # 素材最后一帧冰环的半径

static var instance: FxLayer

var _numbers := []    # 每项是字典：pos, text, life, crit
var _particles := []  # 每项是字典：pos, vel, life, color, size
var _marks := []      # 每项是字典：pos, angle, length, count, kind, color, life
var _rings := []      # 每项是字典：pos, radius, life
var _font: Font


static func damage_number(pos: Vector2, amount: float, crit: bool = false) -> void:
	if instance == null or not Settings.damage_numbers:  # 设置里可以关闭伤害数字
		return
	if instance._numbers.size() >= MAX_NUMBERS:
		instance._numbers.pop_front()
	instance._numbers.append({"pos": pos, "text": str(maxi(1, roundi(amount))), "life": NUMBER_LIFE, "crit": crit})


## 飘出一段文字，例如「格挡」
static func floating_text(pos: Vector2, text: String, color: Color) -> void:
	if instance == null:
		return
	if instance._numbers.size() >= MAX_NUMBERS:
		instance._numbers.pop_front()
	instance._numbers.append({"pos": pos, "text": text, "life": NUMBER_LIFE, "crit": false, "color": color})


## 在 pos 处炸出 count 个小碎片
static func burst(pos: Vector2, color: Color, count: int, speed: float = 160.0, size: float = 3.0) -> void:
	if instance == null:
		return
	for i in count:
		if instance._particles.size() >= MAX_PARTICLES:
			return
		var vel := Vector2.from_angle(randf() * TAU) * speed * randf_range(0.4, 1.0)
		instance._particles.append({"pos": pos, "vel": vel, "life": PARTICLE_LIFE * randf_range(0.6, 1.0), "color": color, "size": size})


## 痕迹特效。kind：slash 一道刀痕；claw 三道爪痕；bite 上下两道弧合拢
static func mark(pos: Vector2, angle: float, length: float, color: Color, kind: String = "slash") -> void:
	if instance == null:
		return
	if instance._marks.size() >= MAX_MARKS:
		instance._marks.pop_front()
	instance._marks.append({"pos": pos, "angle": angle, "length": length, "kind": kind, "color": color, "life": MARK_LIFE})


## 从 pos 向外扩散的霜冻冲击波圈（素材 4 帧，越来越大），最大半径 radius
static func ring(pos: Vector2, radius: float) -> void:
	if instance == null:
		return
	instance._rings.append({"pos": pos, "radius": radius, "life": RING_LIFE})


func _ready() -> void:
	instance = self
	z_index = 30  # 画在敌人和技能特效上面
	var custom: String = ProjectSettings.get_setting("gui/theme/custom_font", "")
	_font = load(custom) if custom != "" else ThemeDB.fallback_font  # 和界面用同一款字体


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	for n in _numbers:
		n.life -= delta
		n.pos += Vector2(0, -NUMBER_RISE * delta)
	_numbers = _numbers.filter(func(n: Dictionary) -> bool: return n.life > 0.0)

	var damping := exp(-6.0 * delta)  # 碎片逐渐减速
	for p in _particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= damping
	_particles = _particles.filter(func(p: Dictionary) -> bool: return p.life > 0.0)

	for m in _marks:
		m.life -= delta
	_marks = _marks.filter(func(m: Dictionary) -> bool: return m.life > 0.0)
	for r in _rings:
		r.life -= delta
	_rings = _rings.filter(func(r: Dictionary) -> bool: return r.life > 0.0)

	queue_redraw()


func _draw() -> void:
	for r in _rings:
		var k: float = 1.0 - r.life / RING_LIFE  # 0 → 1
		SpriteVisual.draw_frame(self, RING, 4, mini(3, int(k * 4.0)), r.pos, Vector2(64, 64), 0.0, Vector2.ONE * r.radius / RING_RADIUS, Color(1, 1, 1, minf(1.0, 3.0 * (1.0 - k))))

	for m in _marks:
		_draw_mark(m)

	for p in _particles:
		var s: float = p.size * (p.life / PARTICLE_LIFE + 0.3)
		draw_rect(Rect2(p.pos - Vector2(s, s) * 0.5, Vector2(s, s)), Color(p.color, minf(1.0, p.life / PARTICLE_LIFE * 2.0)))

	for n in _numbers:
		var t: float = n.life / NUMBER_LIFE                  # 1 → 0
		var pop := 1.0 + 0.4 * maxf(0.0, t - 0.8) / 0.2      # 刚出现时放大一下再缩回
		var font_size := int((22.0 if n.crit else 15.0) * pop)
		var color: Color = n.get("color", Color(1.0, 0.82, 0.3) if n.crit else Color(1, 1, 1))
		color.a = minf(1.0, t * 2.5)
		var width := _font.get_string_size(n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var at: Vector2 = n.pos - Vector2(width * 0.5, 0)
		draw_string_outline(_font, at, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, color.a * 0.8))
		draw_string(_font, at, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## 痕迹先快速划出（前 30% 的时间），然后变细淡出
func _draw_mark(m: Dictionary) -> void:
	var k: float = 1.0 - m.life / MARK_LIFE           # 0 → 1
	var grow := minf(1.0, k / 0.3)
	var fade := 1.0 - maxf(0.0, (k - 0.3) / 0.7)
	var dir := Vector2.from_angle(m.angle)
	var half: float = m.length * 0.5
	var color: Color = m.color
	match m.kind:
		"claw":
			var side := dir.orthogonal()
			for i in 3:
				var o: Vector2 = m.pos + side * (i - 1) * 6.0
				_draw_streak(o - dir * half, o - dir * half + dir * m.length * grow, 3.0 * fade + 0.5, color, fade)
		"bite":
			var gap := 10.0 * (1.0 - grow)  # 上下颚合拢
			var a: float = m.angle
			draw_arc(m.pos + Vector2(0, -gap), half, a + PI * 0.15, a + PI * 0.85, 10, Color(color, fade), 3.0)
			draw_arc(m.pos + Vector2(0, gap), half, a - PI * 0.85, a - PI * 0.15, 10, Color(color, fade), 3.0)
		_:
			_draw_streak(m.pos - dir * half * grow, m.pos + dir * half * grow, 6.0 * fade + 1.0, color, fade)


## 两头尖、中间粗的一道光
func _draw_streak(from: Vector2, to: Vector2, width: float, color: Color, alpha: float) -> void:
	var side := (to - from).normalized().orthogonal() * width * 0.5
	var mid := (from + to) * 0.5
	draw_colored_polygon(PackedVector2Array([from, mid + side, to, mid - side]), Color(color, alpha))
	draw_line(from, to, Color(1, 1, 1, alpha * 0.9), maxf(1.0, width * 0.3))
