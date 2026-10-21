extends Control
## 神殿首页：独立背景与书法标题，原生菜单支持鼠标和键盘。

const HUB_SCENE := "res://scenes/hub.tscn"
const BACKGROUND := "res://assets/ui/title/temple_background.png"
const LOGO := "res://assets/ui/title/embers_logo.png"
const DESIGN_SIZE := Vector2(1280, 720)
const GOLD := Color(0.94, 0.78, 0.49)
const IVORY := Color(0.82, 0.82, 0.79)
const SNOW_COUNT := 42

static var _intro_seen := false
static var _reopen_settings := false

var _time := 0.0
var _snow := []
var _content: Control
var _atmosphere: Control
var _decoration: Control
var _menu: VBoxContainer
var _buttons: Array[Button] = []
var _selected := 0
var _settings: SettingsPanel
var _overlay: Control
var _subtitle_font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Audio.music("hub")
	_build_background()
	_build_brand()
	_build_menu()
	_settings = SettingsPanel.new()
	add_child(_settings)
	_settings.closed.connect(func() -> void: _set_menu_active(true))
	Settings.language_changed.connect(func() -> void:
		_reopen_settings = true
		get_tree().reload_current_scene())
	resized.connect(_layout)
	_layout()
	_set_menu_active(true)
	if not _intro_seen:
		_content.modulate.a = 0.0
		create_tween().tween_property(_content, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	_intro_seen = true
	if _reopen_settings:
		_reopen_settings = false
		_open_settings()


func _build_background() -> void:
	var background := TextureRect.new()
	background.texture = load(BACKGROUND)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(0.015, 0.02, 0.025, 0.0), Color(0.015, 0.02, 0.025, 0.04), Color(0.015, 0.02, 0.025, 0.65)])
	var vignette := GradientTexture2D.new()
	vignette.gradient = gradient
	vignette.fill = GradientTexture2D.FILL_RADIAL
	vignette.fill_from = Vector2(0.5, 0.5)
	vignette.fill_to = Vector2(1.0, 1.0)
	var shade := TextureRect.new()
	shade.texture = vignette
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	_atmosphere = Control.new()
	_atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_atmosphere.draw.connect(_draw_atmosphere)
	add_child(_atmosphere)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	for i in SNOW_COUNT:
		_snow.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.012, 0.035), rng.randf() * TAU))


func _build_brand() -> void:
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	var texture: Texture2D = load(LOGO)
	var title_texture := AtlasTexture.new()
	title_texture.atlas = texture
	title_texture.region = Rect2(texture.get_image().get_used_rect())
	var logo := TextureRect.new()
	logo.texture = title_texture
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.position = Vector2(340, 144)
	logo.size = Vector2(600, 140)
	_content.add_child(logo)
	_subtitle_font = get_theme_font("font")
	_decoration = Control.new()
	_decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_decoration.draw.connect(_draw_decoration)
	_content.add_child(_decoration)


func _build_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.position = Vector2(496, 386)
	_menu.custom_minimum_size = Vector2(288, 0)
	_menu.add_theme_constant_override("separation", 8)
	_content.add_child(_menu)
	var entries := [[tr("开始游戏"), _start], [tr("图鉴"), _open_codex], [tr("设置"), _open_settings],
		[tr("制作人员"), _open_credits], [tr("退出游戏"), func() -> void: get_tree().quit()]]
	for i in entries.size():
		var button := Button.new()
		button.text = entries[i][0]
		button.custom_minimum_size = Vector2(288, 48 if i == 0 else 34)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 24 if i == 0 else 20)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.add_theme_color_override("font_color", IVORY)
		button.add_theme_color_override("font_hover_color", GOLD)
		button.add_theme_color_override("font_focus_color", GOLD)
		button.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.65))
		button.add_theme_color_override("font_disabled_color", IVORY)
		button.add_theme_color_override("font_outline_color", Color(0.015, 0.02, 0.025, 0.9))
		button.add_theme_constant_override("outline_size", 4)
		button.pressed.connect(entries[i][1])
		button.mouse_entered.connect(func() -> void:
			if not button.disabled:
				button.grab_focus())
		button.focus_entered.connect(_select_menu.bind(i))
		_buttons.append(button)
		_menu.add_child(button)
	for i in _buttons.size():
		var button := _buttons[i]
		button.focus_neighbor_top = button.get_path_to(_buttons[posmod(i - 1, _buttons.size())])
		button.focus_neighbor_bottom = button.get_path_to(_buttons[(i + 1) % _buttons.size()])
		button.focus_next = button.focus_neighbor_bottom
		button.focus_previous = button.focus_neighbor_top
	_menu.resized.connect(func() -> void: _decoration.queue_redraw())


func _select_menu(index: int) -> void:
	_selected = index
	for i in _buttons.size():
		var color := GOLD if i == index else IVORY
		_buttons[i].add_theme_color_override("font_color", color)
		_buttons[i].add_theme_color_override("font_hover_color", color)
	_decoration.queue_redraw()


func _layout() -> void:
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_content.size = DESIGN_SIZE
	_content.scale = Vector2.ONE * factor
	_content.position = (size - DESIGN_SIZE * factor) * 0.5
	_decoration.queue_redraw()


func _set_menu_active(active: bool) -> void:
	for button in _buttons:
		button.disabled = not active
		if not active:
			button.release_focus()
	_decoration.queue_redraw()
	if active:
		_restore_focus.call_deferred()


func _restore_focus() -> void:
	if is_instance_valid(_overlay) or _settings.visible:
		return
	_buttons[_selected].grab_focus()


func _open_settings() -> void:
	_set_menu_active(false)
	_settings.open()


func _start() -> void:
	get_tree().change_scene_to_file(HUB_SCENE)


func _open_codex() -> void:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.035, 0.055, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	page.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = tr("图鉴")
	title.add_theme_font_size_override("font_size", 36)
	title.modulate = GOLD
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var back := Button.new()
	back.text = tr("返回  [Esc]")
	back.custom_minimum_size = Vector2(160, 40)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_close_overlay)
	header.add_child(back)
	var codex := CodexView.new()
	codex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(codex)
	_show_overlay(page)


func _open_credits() -> void:
	var credits := Credits.new()
	credits.closed.connect(_close_overlay)
	_show_overlay(credits)


func _show_overlay(page: Control) -> void:
	_set_menu_active(false)
	_overlay = page
	add_child(page)
	page.modulate.a = 0.0
	create_tween().tween_property(page, "modulate:a", 1.0, 0.2)


func _close_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_set_menu_active(true)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _settings.visible:
		return
	if is_instance_valid(_overlay) and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close_overlay()


func _process(delta: float) -> void:
	_time += delta
	for i in _snow.size():
		var flake: Vector4 = _snow[i]
		flake.x = fposmod(flake.x + (-0.004 + sin(_time * 0.45 + flake.w) * 0.003) * delta, 1.0)
		flake.y = fposmod(flake.y + flake.z * delta, 1.0)
		_snow[i] = flake
	_atmosphere.queue_redraw()


func _draw_atmosphere() -> void:
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	for flake: Vector4 in _snow:
		var alpha := 0.08 + 0.14 * (0.5 + 0.5 * sin(_time * 0.7 + flake.w))
		_atmosphere.draw_circle(Vector2(flake.x, flake.y) * size, (0.6 + flake.z * 18.0) * factor, Color(0.87, 0.9, 0.92, alpha))


func _draw_decoration() -> void:
	var text := "EMBERS OF THE REALMS"
	var font_size := 15
	var spacing := 6.0
	var width := _subtitle_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing * (text.length() - 1)
	var x := (DESIGN_SIZE.x - width) * 0.5
	for ch in text:
		_decoration.draw_char(_subtitle_font, Vector2(x, 303), ch, font_size, Color(0.87, 0.82, 0.69))
		x += _subtitle_font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing
	if _buttons.is_empty() or _buttons[_selected].disabled:
		return
	var button := _buttons[_selected]
	var y := _menu.position.y + button.position.y + button.size.y - 2.0
	_decoration.draw_line(Vector2(536, y), Vector2(630, y), Color(GOLD, 0.75), 1.0, true)
	_decoration.draw_line(Vector2(650, y), Vector2(744, y), Color(GOLD, 0.75), 1.0, true)
	_decoration.draw_polyline(PackedVector2Array([Vector2(640, y - 5), Vector2(645, y), Vector2(640, y + 5), Vector2(635, y), Vector2(640, y - 5)]), GOLD, 1.0, true)
