class_name UiKit
## 界面的统一样式：颜色、面板、按钮、标题、分隔线。所有界面都从这里拿，改一处全游戏一起变
## 风格是像素复古（2026-11-13 用户选定）：深蓝底、白色粗边框、硬阴影、会「按下去」的按钮，没有圆角和渐变
## 颜色取自 Sweetie 16 色板，和游戏里的像素角色、图标是同一套语言
## 全局主题（按钮、下拉框、滑块、滚动条、提示框的默认样子）由 install() 装到根窗口上

const GOLD := Color("ffcd75")         # 强调色：标题、选中、主要按钮
const GOLD_BRIGHT := Color("ffe2a8")
const IVORY := Color("f4f4f4")        # 正文、面板边框
const DIM := Color("94b0c2")          # 次要文字
const FAINT := Color("566c86")        # 更次要：未解锁、占位
const LINE := Color("566c86")         # 格子的边框、分隔线
const SURFACE := Color("29366f")      # 面板底色
const SURFACE_RAISED := Color("1a1c2c")  # 面板里凹下去的格子（装备格、部位格）
const BUTTON := Color("333c57")       # 普通按钮
const INK := Color("1a1c2c")          # 最深的底色、主要按钮上的字
const SHADOW := Color("0f101a")       # 硬阴影
const GOOD := Color("a7f070")
const BAD := Color("b13e53")
const INFO := Color("73eff7")
const BOLD := 0.45                    # 字体加粗的程度（项目里只有 Regular 一个字重）
const EDGE := 3                       # 格子边框的粗细
const DEPTH := 4                      # 按钮底下那条「厚度」的高度

static var _theme: Theme


## 把统一主题装到根窗口上（自动加载 Settings 启动时调用一次）
static func install(tree: SceneTree) -> void:
	tree.root.theme = theme()


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	_theme = t
	var font_path: String = ProjectSettings.get_setting("gui/theme/custom_font", "")
	if font_path != "" and ResourceLoader.exists(font_path):
		var bold := FontVariation.new()
		bold.base_font = load(font_path)
		bold.variation_embolden = BOLD
		t.default_font = bold
	for type in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, key(BUTTON))
		t.set_stylebox("hover", type, key(BUTTON.lightened(0.14)))
		t.set_stylebox("pressed", type, key(BUTTON.darkened(0.15), true))
		t.set_stylebox("disabled", type, key(Color("262b44")))
		t.set_stylebox("focus", type, outline(GOLD, EDGE))
		t.set_color("font_color", type, IVORY)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, GOLD)
		t.set_color("font_focus_color", type, Color.WHITE)
		t.set_color("font_disabled_color", type, FAINT)
	for type in ["CheckButton", "CheckBox"]:  # 开关只画图标，不要按钮的底板
		for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			t.set_stylebox(state, type, StyleBoxEmpty.new())

	t.set_stylebox("panel", "PopupMenu", box(INK, IVORY, EDGE, 6, 6))
	t.set_stylebox("hover", "PopupMenu", box(GOLD, Color(0, 0, 0, 0), 0, 6, 2))
	t.set_color("font_color", "PopupMenu", IVORY)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_constant("v_separation", "PopupMenu", 8)

	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "TooltipPanel", box(INK, GOLD, EDGE, 10, 6))
	t.set_color("font_color", "TooltipLabel", IVORY)
	t.set_font_size("font_size", "TooltipLabel", 14)

	var track := box(SHADOW, Color(0, 0, 0, 0), 0, 0, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var filled := box(GOLD, Color(0, 0, 0, 0), 0, 0, 0)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)

	for type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, box(SHADOW, Color(0, 0, 0, 0), 0, 4, 4))
		t.set_stylebox("grabber", type, box(LINE, Color(0, 0, 0, 0), 0, 4, 4))
		t.set_stylebox("grabber_highlight", type, box(DIM, Color(0, 0, 0, 0), 0, 4, 4))
		t.set_stylebox("grabber_pressed", type, box(GOLD, Color(0, 0, 0, 0), 0, 4, 4))

	t.set_color("default_color", "RichTextLabel", IVORY)
	return t


## 通用的方框样式：直角、不抗锯齿
static func box(bg: Color, border: Color, width: int, pad_x: float = 12.0, pad_y: float = 10.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.anti_aliasing = false
	style.content_margin_left = pad_x
	style.content_margin_right = pad_x
	style.content_margin_top = pad_y
	style.content_margin_bottom = pad_y
	return style


## 按钮的样子：一块色板，底下一条深色的「厚度」；pressed = true 时厚度挪到上面，看起来像按下去了
static func key(bg: Color, pressed: bool = false, pad_x: float = 12.0) -> StyleBoxFlat:
	var style := box(bg, SHADOW, 0, pad_x, 5)
	if pressed:
		style.border_width_top = DEPTH
		style.content_margin_top = 5 + DEPTH
	else:
		style.border_width_bottom = DEPTH
		style.content_margin_bottom = 5 + DEPTH
	return style


## 凹下去的格子（装备格、部位格、图鉴格）
static func cell(border := LINE, bg := SURFACE_RAISED, pad: float = 4.0) -> StyleBoxFlat:
	return box(bg, border, EDGE, pad, pad)


## 面板底板：深蓝底 + 白色粗边框 + 右下的硬阴影
static func panel(padding: float = 16.0, border := IVORY, bg := SURFACE) -> StyleBoxFlat:
	var style := box(bg, border, 4, padding, padding)
	style.shadow_color = Color(SHADOW, 0.7)
	style.shadow_size = 1
	style.shadow_offset = Vector2(6, 6)
	return style


## 只有边框、不填底色（盖在图片上当画框）
static func outline(color: Color, width: int = 1) -> StyleBoxFlat:
	var style := box(Color(0, 0, 0, 0), color, width, 0, 0)
	style.draw_center = false
	return style


## 一块面板。内容加到返回的 PanelContainer 里
static func framed(padding: float = 16.0, border := IVORY) -> PanelContainer:
	var container := PanelContainer.new()
	container.add_theme_stylebox_override("panel", panel(padding, border))
	return container


static func label(text: String, font_size: int = 15, color := IVORY, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := Label.new()
	node.text = text
	node.horizontal_alignment = align
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node


## 会自动换行的正文
static func body(text: String, font_size: int = 14, color := IVORY) -> Label:
	var node := label(text, font_size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_constant_override("line_spacing", 4)
	return node


## 小节标题：▶ 文字 ·········
static func heading(text: String, color := GOLD) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var mark := Diamond.new()
	mark.color = color
	row.add_child(mark)
	row.add_child(label(text, 14, color))
	var line := Dots.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	return row


## 一条细分隔线
static func rule(color := LINE) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(0, 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func spacer(horizontal := true) -> Control:
	var node := Control.new()
	if horizontal:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## 普通按钮（样子来自全局主题）
static func button(text: String, callback: Callable, min_size := Vector2(0, 40), font_size: int = 16) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = min_size
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size", font_size)
	node.pressed.connect(callback)
	return node


## 主要按钮：金色底，一屏里只放一个（进入篇章、穿上、确认）
static func primary(text: String, callback: Callable, min_size := Vector2(0, 44), font_size: int = 17) -> Button:
	var node := button(text, callback, min_size, font_size)
	tint_button(node, GOLD)
	return node


## 把按钮染成某个颜色（主要按钮的金色、角色色、危险红）：整块填色，字的深浅跟着底色走
static func tint_button(node: Button, color: Color) -> void:
	var text := INK if color.get_luminance() > 0.45 else IVORY
	node.add_theme_stylebox_override("normal", key(color))
	node.add_theme_stylebox_override("hover", key(color.lightened(0.18)))
	node.add_theme_stylebox_override("pressed", key(color.darkened(0.12), true))
	node.add_theme_stylebox_override("disabled", key(Color("262b44")))
	for state in ["normal", "hover", "pressed"]:
		(node.get_theme_stylebox(state) as StyleBoxFlat).border_color = color.darkened(0.45)
	node.add_theme_color_override("font_color", text)
	node.add_theme_color_override("font_hover_color", text)
	node.add_theme_color_override("font_pressed_color", text)
	node.add_theme_color_override("font_focus_color", text)
	node.add_theme_color_override("font_disabled_color", FAINT)


## 分页、筛选这类「选中一个」的按钮：选中的是金色、按下去的样子
static func toggle_button(node: Button, on: bool) -> void:
	node.add_theme_stylebox_override("normal", key(GOLD, true) if on else key(BUTTON))
	node.add_theme_stylebox_override("hover", key(GOLD.lightened(0.15), true) if on else key(BUTTON.lightened(0.14)))
	node.add_theme_stylebox_override("pressed", key(GOLD, true))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		node.add_theme_color_override(state, INK if on else IVORY)


## 没有底色的文字按钮（底部的「设置」「返回标题」）
static func link(text: String, callback: Callable, font_size: int = 14) -> Button:
	var node := button(text, callback, Vector2.ZERO, font_size)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 6
		empty.content_margin_right = 6
		node.add_theme_stylebox_override(state, empty)
	node.add_theme_color_override("font_color", DIM)
	node.add_theme_color_override("font_hover_color", GOLD)
	return node


## 全屏的半透明黑幕（弹出面板后面）
static func scrim(alpha: float = 0.72) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(INK, alpha)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


## 把正文里的 **重点** 换成金色（RichTextLabel 的 BBCode），其余文字原样
static func emphasize(text: String) -> String:
	var regex := RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
	return regex.sub(text.replace("[", "[lb]"), "[color=#%s]$1[/color]" % GOLD_BRIGHT.to_html(false), true)


## 能显示 **重点** 的自动换行正文
static func rich(text: String, font_size: int = 14, color := IVORY) -> RichTextLabel:
	var node := RichTextLabel.new()
	node.bbcode_enabled = true
	node.fit_content = true
	node.scroll_active = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("normal_font_size", font_size)
	node.add_theme_color_override("default_color", color)
	node.add_theme_constant_override("line_separation", 4)
	node.text = emphasize(text)
	return node


## 进度条（血条、经验条、大招条）：暗底细边，填充是白色，用 modulate 染成需要的颜色
static func style_bar(bar: ProgressBar, color: Color) -> void:
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", box(Color(SHADOW, 0.85), Color(1, 1, 1, 0.55), 2, 0, 0))
	var fill := box(Color.WHITE, Color(0, 0, 0, 0), 0, 0, 0)
	fill.border_color = Color(0, 0, 0, 0)
	fill.set_border_width_all(2)  # 透明的一圈，让填充缩在边框里面
	bar.add_theme_stylebox_override("fill", fill)
	bar.modulate = color


## 战斗界面上直接压在画面上的字：加一圈深色描边，雪地上也看得清
static func outlined(node: Label, width: int = 4) -> Label:
	node.add_theme_color_override("font_outline_color", Color(INK, 0.9))
	node.add_theme_constant_override("outline_size", width)
	return node


static func format_time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]


## 面板四角的金色折角。加到面板里，自动铺满、不挡鼠标、不占排版位置
class Corners extends Control:
	var color := UiKit.GOLD
	var arm := 12.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	## PanelContainer 会把子节点缩进内边距里，所以按父面板的大小画，而不是按自己的大小
	func _draw() -> void:
		var parent := get_parent_control()
		var origin := -position if parent else Vector2.ZERO
		var w := parent.size.x if parent else size.x
		var h := parent.size.y if parent else size.y
		for corner: Array in [[Vector2(0, 0), 1, 1], [Vector2(w, 0), -1, 1], [Vector2(0, h), 1, -1], [Vector2(w, h), -1, -1]]:
			var at: Vector2 = origin + corner[0]
			var sx: float = corner[1]
			var sy: float = corner[2]
			draw_line(at + Vector2(sx * 0.5, sy * 0.5), at + Vector2(sx * arm, sy * 0.5), color, 2.0)
			draw_line(at + Vector2(sx * 0.5, sy * 0.5), at + Vector2(sx * 0.5, sy * arm), color, 2.0)


## 小记号：小节标题前面是 ▶，其他地方（新装备的红点）是方块
class Diamond extends Control:
	var color := UiKit.GOLD
	var radius := 4.0
	var square := false

	func _ready() -> void:
		custom_minimum_size = Vector2(radius * 2.0 + 2.0, radius * 2.0 + 2.0)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := (size * 0.5).floor()
		if square:
			draw_rect(Rect2(c - Vector2(radius, radius), Vector2(radius, radius) * 2.0), color)
		else:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-radius, -radius - 1), c + Vector2(radius, 0), c + Vector2(-radius, radius + 1)]), color)


## 一条方点虚线（小节标题后面）
class Dots extends Control:
	var color := UiKit.LINE

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 4)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var x := 0.0
		while x + 4.0 <= size.x:
			draw_rect(Rect2(x, 0, 4, 4), color)
			x += 8.0


## 等级格子：一排小菱形，亮的是已有等级
class Pips extends Control:
	var total := 5
	var filled := 0:
		set(value):
			filled = value
			queue_redraw()
	var color := UiKit.GOLD

	func _ready() -> void:
		custom_minimum_size = Vector2(total * 16.0, 14.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in total:
			var rect := Rect2(2.0 + i * 16.0, floorf(size.y * 0.5) - 5.0, 10, 10)
			draw_rect(rect, color if i < filled else UiKit.SHADOW)
			if i >= filled:
				draw_rect(rect, UiKit.LINE, false, 2.0)
