class_name SettingsPanel
extends Control
## 设置面板：标题画面、主神空间和暂停菜单共用。所有修改立即生效并保存，按 Esc 或「返回」关闭
## 切换语言后，打开它的界面要重新创建自己（Settings.language_changed），战斗中不能切换语言

signal closed

const PANEL_WIDTH := 560.0
const GOLD := Color(1.0, 0.85, 0.4)

var allow_language := true  # 战斗中关掉：局内很多文字是开局时生成的，中途换语言会中英混杂


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.12)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(_title(tr("设置"), 28, GOLD))

	var grid: GridContainer
	if allow_language:
		grid = _grid(box)
		var codes: Array = Settings.LANGUAGES.keys()
		_option(grid, tr("语言"), codes.map(func(code: String) -> String: return Settings.LANGUAGES[code]), codes.find(Settings.current_language()),
			func(index: int) -> void: Settings.change("language", codes[index]))

	box.add_child(_title(tr("声音"), 15, Color(0.7, 0.73, 0.8)))
	grid = _grid(box)
	_slider(grid, tr("主音量"), "master_volume")
	_slider(grid, tr("音乐"), "music_volume")
	_slider(grid, tr("音效"), "sfx_volume")

	box.add_child(_title(tr("画面"), 15, Color(0.7, 0.73, 0.8)))
	grid = _grid(box)
	_option(grid, tr("窗口大小"), Settings.WINDOW_SIZES.map(func(v: Vector2i) -> String: return "%d × %d" % [v.x, v.y]), Settings.window_size,
		func(index: int) -> void: Settings.change("window_size", index))
	_toggle(grid, tr("全屏"), "fullscreen")
	_toggle(grid, tr("垂直同步"), "vsync")
	_toggle(grid, tr("显示帧率"), "show_fps")

	box.add_child(_title(tr("战斗"), 15, Color(0.7, 0.73, 0.8)))
	grid = _grid(box)
	_toggle(grid, tr("伤害数字"), "damage_numbers")
	_slider(grid, tr("屏幕震动"), "screen_shake")

	var back := Button.new()
	back.text = tr("返回  [Esc]")
	back.custom_minimum_size = Vector2(200, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(close)
	box.add_child(back)


func open() -> void:
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()  # 只关闭设置，不要让暂停菜单也收到这次 Esc
		close()


func _grid(parent: Control) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	parent.add_child(grid)
	return grid


## 滑块：0~100%，对应设置里的 0~1
func _slider(grid: GridContainer, text: String, key: String) -> void:
	grid.add_child(_row_label(text))
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = Settings.get(key) * 100.0
	slider.custom_minimum_size = Vector2(300, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(slider)
	var value := _row_label("%d%%" % slider.value)
	value.custom_minimum_size = Vector2(50, 0)
	grid.add_child(value)
	slider.value_changed.connect(func(v: float) -> void:
		value.text = "%d%%" % v
		Settings.change(key, v / 100.0))


func _toggle(grid: GridContainer, text: String, key: String) -> void:
	grid.add_child(_row_label(text))
	var check := CheckButton.new()
	check.button_pressed = Settings.get(key)
	check.focus_mode = Control.FOCUS_NONE
	check.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # 开关统一靠左
	check.toggled.connect(func(on: bool) -> void: Settings.change(key, on))
	grid.add_child(check)
	grid.add_child(Control.new())  # 占位，保持三列对齐


## 下拉选项：items 是显示的文字，selected 是当前选中的序号
func _option(grid: GridContainer, text: String, items: Array, selected: int, on_select: Callable) -> void:
	grid.add_child(_row_label(text))
	var option := OptionButton.new()
	option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # 语言名用各自的文字显示
	for item: String in items:
		option.add_item(item)
	option.select(selected)
	option.focus_mode = Control.FOCUS_NONE
	option.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	option.item_selected.connect(on_select)
	grid.add_child(option)
	grid.add_child(Control.new())


func _row_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(90, 0)
	return label


func _title(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	return label
