class_name FxLayer
extends Node2D
## 战斗反馈特效层：伤害数字、死亡碎片
## 所有数字和碎片都在这一个节点里统一绘制，比每个数字各建一个 Label 节点快得多，
## 同屏几百个也不卡。任何地方都可以直接调用 FxLayer.damage_number(...) / FxLayer.burst(...)

const MAX_NUMBERS := 150     # 同屏数字上限，超过就丢掉最旧的
const MAX_PARTICLES := 800
const NUMBER_LIFE := 0.6
const NUMBER_RISE := 45.0    # 数字每秒上浮多少像素
const PARTICLE_LIFE := 0.45

static var instance: FxLayer

var _numbers := []    # 每项是字典：pos, text, life, crit
var _particles := []  # 每项是字典：pos, vel, life, color, size
var _font: Font


static func damage_number(pos: Vector2, amount: float, crit: bool = false) -> void:
	if instance == null:
		return
	if instance._numbers.size() >= MAX_NUMBERS:
		instance._numbers.pop_front()
	instance._numbers.append({"pos": pos, "text": str(maxi(1, roundi(amount))), "life": NUMBER_LIFE, "crit": crit})


## 在 pos 处炸出 count 个小碎片
static func burst(pos: Vector2, color: Color, count: int, speed: float = 160.0, size: float = 3.0) -> void:
	if instance == null:
		return
	for i in count:
		if instance._particles.size() >= MAX_PARTICLES:
			return
		var vel := Vector2.from_angle(randf() * TAU) * speed * randf_range(0.4, 1.0)
		instance._particles.append({"pos": pos, "vel": vel, "life": PARTICLE_LIFE * randf_range(0.6, 1.0), "color": color, "size": size})


func _ready() -> void:
	instance = self
	z_index = 30  # 画在敌人和技能特效上面
	_font = ThemeDB.fallback_font


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

	queue_redraw()


func _draw() -> void:
	for p in _particles:
		var s: float = p.size * (p.life / PARTICLE_LIFE + 0.3)
		draw_rect(Rect2(p.pos - Vector2(s, s) * 0.5, Vector2(s, s)), Color(p.color, minf(1.0, p.life / PARTICLE_LIFE * 2.0)))

	for n in _numbers:
		var t: float = n.life / NUMBER_LIFE                  # 1 → 0
		var pop := 1.0 + 0.4 * maxf(0.0, t - 0.8) / 0.2      # 刚出现时放大一下再缩回
		var font_size := int((22.0 if n.crit else 15.0) * pop)
		var color := Color(1.0, 0.82, 0.3) if n.crit else Color(1, 1, 1)
		color.a = minf(1.0, t * 2.5)
		var width := _font.get_string_size(n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var at: Vector2 = n.pos - Vector2(width * 0.5, 0)
		draw_string_outline(_font, at, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, color.a * 0.8))
		draw_string(_font, at, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
