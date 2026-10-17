class_name UltCutin
extends Control
## 大招特写：释放大招时从右上角滑入，展示角色最璀璨的时刻、台词和大招名，然后滑出
## 有立绘素材（<角色id>_cutin.png，建议 480×160 的眼部特写）就显示立绘，没有就画一双锐利的眼睛占位

const PANEL_SIZE := Vector2(480, 160)
const PORTRAIT_WIDTH := 200.0
const SLANT := 36.0          # 面板左边的斜切宽度
const SLIDE_IN := 0.18
const HOLD := 1.5
const SLIDE_OUT := 0.25

var _accent := Color.WHITE
var _portrait: TextureRect
var _moment: Label
var _line: Label
var _ult_name: Label
var _has_portrait := false


func _ready() -> void:
	size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_portrait = TextureRect.new()
	_portrait.position = Vector2(SLANT, 0)
	_portrait.size = Vector2(PORTRAIT_WIDTH, PANEL_SIZE.y)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.clip_contents = true
	add_child(_portrait)

	var text_x := SLANT + PORTRAIT_WIDTH + 14.0
	_moment = _make_label(Vector2(text_x, 8), 13, Color(1, 1, 1, 0.6))     # 两行：角色名 / 时刻
	_line = _make_label(Vector2(text_x, 48), 16, Color.WHITE)
	_ult_name = _make_label(Vector2(text_x, 104), 28, Color.WHITE)


func _make_label(pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = Vector2(PANEL_SIZE.x - pos.x - 10.0, 0)
	label.clip_text = true  # 文字太长时裁掉，不会超出面板
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.modulate = color
	add_child(label)
	return label


func play(character_id: String) -> void:
	var data: Dictionary = CharacterDB.ALL[character_id]
	_accent = data.cutin_color
	_moment.text = "%s\n%s" % [tr(data.name), tr(data.cutin_moment)]
	_line.text = tr(data.cutin_line)
	_ult_name.text = tr(data.ult_name)
	_ult_name.modulate = _accent.lightened(0.3)

	var path: String = CharacterDB.CUTIN_DIR + character_id + "_cutin.png"
	_has_portrait = ResourceLoader.exists(path)
	_portrait.texture = load(path) if _has_portrait else null

	# 从屏幕右侧外面滑进来，停留，再滑出去
	var shown_x := get_viewport_rect().size.x - PANEL_SIZE.x - 16.0
	var hidden_x := get_viewport_rect().size.x + 20.0
	position = Vector2(hidden_x, 72)
	visible = true
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "position:x", shown_x, SLIDE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD)
	tween.tween_property(self, "position:x", hidden_x, SLIDE_OUT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(hide)


func _draw() -> void:
	var w := PANEL_SIZE.x
	var h := PANEL_SIZE.y
	# 斜切的深色面板 + 强调色描边
	var panel := PackedVector2Array([Vector2(SLANT, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])
	draw_colored_polygon(panel, Color(0.04, 0.05, 0.09, 0.92))
	draw_polyline(PackedVector2Array([Vector2(SLANT, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h), Vector2(SLANT, 0)]), _accent, 2.0)
	draw_line(Vector2(SLANT + PORTRAIT_WIDTH, 0), Vector2(SLANT + PORTRAIT_WIDTH - 8, h), _accent, 2.0)
	if not _has_portrait:
		_draw_placeholder_eyes(Rect2(SLANT, 0, PORTRAIT_WIDTH - 8, h))


## 占位立绘：一双锐利的眼睛
func _draw_placeholder_eyes(area: Rect2) -> void:
	var band := Rect2(area.position.x, area.position.y + area.size.y * 0.32, area.size.x, area.size.y * 0.36)
	draw_rect(band, Color(0.2, 0.16, 0.14))
	var cy := band.get_center().y
	for side in [-1.0, 1.0]:
		var cx: float = area.get_center().x + side * area.size.x * 0.24
		# 细长上挑的眼形
		var eye := PackedVector2Array([
			Vector2(cx - 30 * side, cy + 4), Vector2(cx - 6 * side, cy - 8),
			Vector2(cx + 26 * side, cy - 12), Vector2(cx + 8 * side, cy + 6)])
		draw_colored_polygon(eye, Color(0.92, 0.9, 0.86))
		draw_circle(Vector2(cx + 2 * side, cy - 2), 6.0, Color(0.15, 0.08, 0.06))
		draw_circle(Vector2(cx + 3 * side, cy - 4), 1.6, _accent.lightened(0.5))  # 眼中的寒光
		# 压低的眉
		draw_line(Vector2(cx - 30 * side, cy - 14), Vector2(cx + 30 * side, cy - 26), Color(0.08, 0.06, 0.05), 5.0)
