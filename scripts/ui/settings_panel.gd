class_name SettingsPanel
extends Control
## 设置面板：主神空间和暂停菜单共用。所有修改立即生效并保存，按 Esc 或「返回」关闭

signal closed

const PANEL_WIDTH := 560.0
const GOLD := Color(1.0, 0.85, 0.4)


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
	box.add_child(_title("设置", 28, GOLD))

	box.add_child(_title("声音", 15, Color(0.7, 0.73, 0.8)))
	var grid := _grid(box)
	_slider(grid, "主音量", "master_volume")
	_slider(grid, "音乐", "music_volume")
	_slider(grid, "音效", "sfx_volume")
	var note := _title("音乐和音效素材还没有加入，加入后会按这里的音量播放", 12, Color(1, 1, 1, 0.4))
	box.add_child(note)

	box.add_child(_title("画面", 15, Color(0.7, 0.73, 0.8)))
	grid = _grid(box)
	_toggle(grid, "全屏", "fullscreen")
	_toggle(grid, "垂直同步", "vsync")
	_toggle(grid, "显示帧率", "show_fps")

	box.add_child(_title("战斗", 15, Color(0.7, 0.73, 0.8)))
	grid = _grid(box)
	_toggle(grid, "伤害数字", "damage_numbers")
	_slider(grid, "屏幕震动", "screen_shake")

	var back := Button.new()
	back.text = "返回  [Esc]"
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
