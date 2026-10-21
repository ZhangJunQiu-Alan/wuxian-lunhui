extends Control
## 标题画面（游戏启动后的第一个画面）
## 开场动画：从黑暗中亮起 → 主神光球展开 → 标题逐字浮现 → 副标题、篇章名 → 「按任意键开始」
## 背景动画：夜空、极光、星星、飘雪、三层远山缓慢平移；两头巨狼在天边追逐太阳和月亮；四个化身站在山崖上
## 菜单：开始游戏、图鉴、设置、制作人员、退出游戏

const HUB_SCENE := "res://scenes/hub.tscn"
const GOLD := Color(1.0, 0.85, 0.4)
const TITLE_GLOW := Color(1.0, 0.8, 0.45)
const INTRO_TIME := 4.4        # 开场动画的长度，之后出现「按任意键开始」
const TITLE_Y := 0.3           # 标题中心在屏幕高度的什么位置
const STAR_COUNT := 140
const SNOW_COUNT := 170
const SKY_TOP := Color(0.02, 0.025, 0.06)
const SKY_HORIZON := Color(0.07, 0.11, 0.17)
const RIDGES := [  # 远山：[基准高度（屏幕比例）, 起伏, 颜色, 平移速度]
	[0.62, 70.0, Color(0.09, 0.12, 0.19), 4.0],
	[0.72, 60.0, Color(0.06, 0.08, 0.13), 9.0],
	[0.83, 40.0, Color(0.035, 0.045, 0.075), 16.0],
]
const AURORAS := [  # 极光：[中心高度, 厚度, 颜色, 相位]
	[0.2, 70.0, Color(0.3, 1.0, 0.65), 0.0],
	[0.27, 50.0, Color(0.45, 0.55, 1.0), 2.1],
]
const HEROES := ["swordsman", "gunslinger", "assassin", "mage"]
const HERO_X := [0.1, 0.19, 0.81, 0.9]
const CLIFF_Y := 0.93          # 化身脚下山崖的高度

static var _intro_seen := false       # 同一次启动里再回到标题（切换语言、从主神空间返回）时跳过开场动画
static var _reopen_settings := false

var _time := 0.0
var _menu_open := false
var _font: Font
var _stars := []     # [位置比例, 闪烁相位, 大小]
var _snow := []      # [位置, 下落速度, 摆动相位, 大小]
var _ridges := []    # 每层山的一圈高度采样（首尾相接，平移时循环）
var _sky: Node2D     # 太阳、月亮和两头巨狼
var _wolves := []
var _lights := [Vector2.ZERO, Vector2.ZERO]  # 太阳、月亮的位置
var _menu: VBoxContainer
var _settings: SettingsPanel
var _overlay: Control  # 打开中的图鉴或制作人员名单


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Audio.music("hub")
	_font = ThemeDB.fallback_font
	var custom: String = ProjectSettings.get_setting("gui/theme/custom_font", "")
	if custom != "":
		_font = load(custom)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in STAR_COUNT:
		_stars.append([Vector2(rng.randf(), rng.randf() * 0.6), rng.randf() * TAU, rng.randf_range(0.6, 1.8)])
	for i in SNOW_COUNT:
		_snow.append([Vector2(rng.randf() * 1280.0, rng.randf() * 720.0), rng.randf_range(25.0, 70.0), rng.randf() * TAU, rng.randf_range(1.0, 2.6)])
	for ridge: Array in RIDGES:
		var heights := PackedFloat32Array()
		var phase := rng.randf() * TAU
		for i in 64:  # 64 个采样点铺满 2 倍屏宽，叠加几层不同频率的起伏，再加一点随机的尖峰
			var x := float(i) / 64.0 * TAU
			heights.append(sin(x * 2.0 + phase) * 0.5 + sin(x * 5.0 + phase * 2.0) * 0.3 + rng.randf_range(-0.25, 0.25))
		_ridges.append(heights)

	_sky = Node2D.new()
	add_child(_sky)
	for id in ["skoll", "hati"]:
		var wolf := SpriteVisual.create("res://assets/sprites/bosses/" + id, 1.0)
		if wolf:
			wolf.modulate = Color(0.13, 0.15, 0.24, 0.9)  # 天边的剪影
			_sky.add_child(wolf)
		_wolves.append(wolf)

	var heroes := Node2D.new()
	add_child(heroes)
	for i in HEROES.size():
		var hero := SpriteVisual.create_actions(CharacterDB.CUTIN_DIR + HEROES[i], 128.0, {"idle": true})
		if hero == null:
			continue
		var stand := Node2D.new()
		stand.position = Vector2(1280.0 * HERO_X[i], 720.0 * CLIFF_Y - 64.0)
		stand.add_child(hero)
		hero.flip_h = HERO_X[i] > 0.5  # 右边的两人面朝中间
		hero.frame = i  # 呼吸错开
		hero.modulate = Color(0.75, 0.78, 0.9)
		heroes.add_child(stand)

	_build_menu()
	_settings = SettingsPanel.new()
	add_child(_settings)
	Settings.language_changed.connect(func() -> void:
		_reopen_settings = true
		get_tree().reload_current_scene())

	if _intro_seen:
		_time = INTRO_TIME
		_open_menu(false)
	_intro_seen = true
	if _reopen_settings:
		_reopen_settings = false
		_settings.open()


func _build_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	_menu.custom_minimum_size = Vector2(300, 0)
	_menu.position = Vector2(640.0 - 150.0, 720.0 * 0.53)
	_menu.visible = false
	add_child(_menu)
	for entry in [[tr("开始游戏  [Enter]"), _start], [tr("图鉴"), _open_codex], [tr("设置"), func() -> void: _settings.open()],
			[tr("制作人员"), _open_credits], [tr("退出游戏"), func() -> void: get_tree().quit()]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(300, 46)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_stylebox_override("normal", _style(Color(0.06, 0.07, 0.11, 0.85), Color(GOLD, 0.45), 1))
		button.add_theme_stylebox_override("hover", _style(Color(0.2, 0.15, 0.05, 0.9), GOLD, 2))
		button.add_theme_stylebox_override("pressed", _style(Color(0.3, 0.22, 0.07, 0.9), GOLD, 2))
		button.pressed.connect(entry[1])
		_menu.add_child(button)


func _open_menu(animate: bool = true) -> void:
	_menu_open = true
	_menu.visible = true
	if not animate:
		return
	for i in _menu.get_child_count():  # 按钮从下往上依次浮现
		var button: Control = _menu.get_child(i)
		button.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(i * 0.07)
		tween.tween_property(button, "modulate:a", 1.0, 0.3)


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
	_overlay = page
	add_child(page)
	page.modulate.a = 0.0
	create_tween().tween_property(page, "modulate:a", 1.0, 0.2)


func _close_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var click := event as InputEventMouseButton
	var pressed := (key and key.pressed and not key.echo) or (click and click.pressed)
	if not pressed or _settings.visible:
		return
	if is_instance_valid(_overlay):
		if key and key.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close_overlay()
		return
	if not _menu_open:
		get_viewport().set_input_as_handled()
		if _time < INTRO_TIME:
			_time = INTRO_TIME  # 开场动画中按键：直接跳到结尾
		else:
			Audio.sfx("ui_open")
			_open_menu()
	elif key and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
		_start()


func _process(delta: float) -> void:
	_time += delta
	for flake: Array in _snow:
		flake[0] += Vector2(-12.0 + sin(_time * 0.8 + flake[2]) * 10.0, flake[1]) * delta
		if flake[0].y > size.y + 4.0:
			flake[0] = Vector2(randf() * (size.x + 200.0), -4.0)
		elif flake[0].x < -4.0:
			flake[0].x += size.x + 8.0
	_update_sky()
	queue_redraw()


## 太阳和月亮缓缓划过天边，斯库尔和哈提的剪影跟在后面
func _update_sky() -> void:
	for i in 2:
		var period := 70.0 if i == 0 else 95.0
		var t := fposmod(_time / period + (0.15 if i == 0 else 0.65), 1.0)
		var x := lerpf(-200.0, size.x + 400.0, t)
		var y := size.y * (0.1 if i == 0 else 0.15) - sin(t * PI) * 24.0
		_lights[i] = Vector2(x, y)
		var wolf: Node2D = _wolves[i]
		if wolf:
			wolf.position = Vector2(x - 100.0, y + 40.0)  # 精灵的轴心在脚底


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_HORIZON, SKY_HORIZON]))
	for star: Array in _stars:
		var twinkle := 0.45 + 0.55 * sin(_time * 1.7 + star[1])
		draw_circle(Vector2(star[0].x * w, star[0].y * h), star[2] * 0.6, Color(0.9, 0.93, 1.0, 0.25 + 0.5 * twinkle))
	for aurora: Array in AURORAS:
		_draw_aurora(aurora[0] * h, aurora[1], aurora[2], aurora[3])
	_draw_sun_and_moon()
	for i in RIDGES.size():
		_draw_ridge(i)
	_draw_cliff()
	for flake: Array in _snow:
		draw_circle(flake[0], flake[3], Color(0.92, 0.95, 1.0, 0.25 + flake[3] * 0.2))
	_draw_title()
	if _time < 1.4:  # 开场从黑暗中亮起
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 1.0 - _time / 1.4))


func _draw_aurora(center_y: float, thickness: float, color: Color, phase: float) -> void:
	var step := 16.0
	var x := 0.0
	while x < size.x:
		var y0 := _aurora_y(x, center_y, phase)
		var y1 := _aurora_y(x + step, center_y, phase)
		var a := 0.07 + 0.06 * sin(x * 0.012 + _time * 0.6 + phase)
		var core := Color(color, a)
		var edge := Color(color, 0.0)
		var t0 := thickness * (0.8 + 0.3 * sin(x * 0.02 + _time + phase))
		var t1 := thickness * (0.8 + 0.3 * sin((x + step) * 0.02 + _time + phase))
		draw_polygon(PackedVector2Array([Vector2(x, y0 - t0), Vector2(x + step, y1 - t1), Vector2(x + step, y1), Vector2(x, y0)]),
			PackedColorArray([edge, edge, core, core]))
		draw_polygon(PackedVector2Array([Vector2(x, y0), Vector2(x + step, y1), Vector2(x + step, y1 + t1 * 0.4), Vector2(x, y0 + t0 * 0.4)]),
			PackedColorArray([core, core, edge, edge]))
		x += step


func _aurora_y(x: float, center_y: float, phase: float) -> float:
	return center_y + sin(x * 0.004 + _time * 0.18 + phase) * 38.0 + sin(x * 0.011 - _time * 0.3 + phase) * 12.0


func _draw_sun_and_moon() -> void:
	for i in 2:
		var at: Vector2 = _lights[i]
		var color := Color(1.0, 0.62, 0.35) if i == 0 else Color(0.82, 0.88, 1.0)  # 黯淡的太阳、冷白的月亮
		for r in 4:
			draw_circle(at, 18.0 + r * 10.0, Color(color, 0.05))
		draw_circle(at, 16.0, Color(color, 0.75))


func _draw_ridge(index: int) -> void:
	var ridge: Array = RIDGES[index]
	var heights: PackedFloat32Array = _ridges[index]
	var span := size.x * 2.0
	var offset := fposmod(_time * ridge[3], span)
	var points := PackedVector2Array([Vector2(size.x, size.y), Vector2(0, size.y)])
	var x := 0.0
	while x <= size.x + 20.0:
		var u := fposmod(x + offset, span) / span * heights.size()
		var i := int(u)
		var y := lerpf(heights[i % heights.size()], heights[(i + 1) % heights.size()], u - i)
		points.append(Vector2(x, size.y * ridge[0] - y * ridge[1]))
		x += 20.0
	draw_colored_polygon(points, ridge[2])


## 化身脚下的山崖：两侧高、中间低，给菜单留出位置
func _draw_cliff() -> void:
	var y := size.y * CLIFF_Y
	var color := Color(0.02, 0.025, 0.04)
	for side: float in [-1.0, 1.0]:
		var x0 := size.x * 0.5 + side * size.x * 0.5
		var points := PackedVector2Array([Vector2(x0, size.y), Vector2(x0, y - 6.0)])
		for k in 9:
			var t := float(k) / 8.0
			var x := lerpf(x0, size.x * 0.5 + side * size.x * 0.24, t)
			points.append(Vector2(x, y + (sin(k * 2.3) * 4.0 if t < 0.7 else (t - 0.7) * 100.0)))
		points.append(Vector2(size.x * 0.5 + side * size.x * 0.24, size.y))
		draw_colored_polygon(points, color)
		draw_polyline(points.slice(1, points.size() - 1), Color(0.4, 0.5, 0.7, 0.25), 2.0)  # 山崖边缘的一线反光


func _draw_title() -> void:
	var center := Vector2(size.x * 0.5, size.y * TITLE_Y)
	var zh := Settings.current_language() == "zh"
	var title := tr("诸界余烬")

	# 主神：光球从一点展开，两道光环带着光点缓缓转动
	var grow := _ease((_time - 0.6) / 1.4)
	GodSphere.draw(self, center, _time, grow)
	if grow > 0.0:
		var flash := clampf(1.0 - absf(_time - 1.6) / 0.5, 0.0, 1.0)  # 光球展开到最大时闪一下
		draw_circle(center, 34.0 * grow + flash * 40.0, Color(1.0, 0.97, 0.9, 0.12 + flash * 0.25))

	# 标题：逐字浮现（从大到小落定），之后一道光从左到右扫过
	var font_size := 104 if zh else 64
	var spacing := 26.0 if zh else 6.0
	var widths := []
	var total := -spacing
	for ch in title:
		var cw := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		widths.append(cw)
		total += cw + spacing
	var x := center.x - total * 0.5
	var baseline := (_font.get_ascent(font_size) - _font.get_descent(font_size)) * 0.5
	var step := 0.22 if zh else 0.06
	var sweep := fposmod(_time - INTRO_TIME, 6.0) / 1.2  # 每 6 秒扫过一次，扫一次用 1.2 秒
	for i in title.length():
		var t := _ease((_time - 1.7 - i * step) / 0.6)
		if t > 0.0:
			var char_center := Vector2(x + widths[i] * 0.5, center.y)
			var shine := 0.0
			if _time > INTRO_TIME:
				shine = clampf(1.0 - absf(sweep - float(i + 0.5) / title.length()) * 4.0, 0.0, 1.0)
			draw_set_transform(char_center, 0.0, Vector2.ONE * lerpf(1.7, 1.0, t))
			var at := Vector2(-widths[i] * 0.5, baseline)
			draw_char_outline(_font, at, title[i], font_size, 22, Color(TITLE_GLOW, 0.12 * t))
			draw_char_outline(_font, at, title[i], font_size, 8, Color(TITLE_GLOW, 0.28 * t))
			draw_char(_font, at, title[i], font_size, Color(1.0, 0.95, 0.82).lerp(Color.WHITE, shine) * Color(1, 1, 1, t))
		x += widths[i] + spacing
	draw_set_transform(Vector2.ZERO)

	# 副标题（另一种语言的标题）
	var sub_t := _ease((_time - 3.0) / 0.7)
	if sub_t > 0.0:
		var sub := "EMBERS OF THE REALMS" if zh else "诸界余烬"
		_draw_spaced(sub, center + Vector2(0, 92), 20, lerpf(22.0, 10.0, sub_t), Color(0.85, 0.88, 0.95, 0.85 * sub_t))

	if not _menu_open and _time >= INTRO_TIME:
		var prompt := tr("按任意键开始")
		var pw := _font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var blink := 0.35 + 0.65 * absf(sin((_time - INTRO_TIME) * 1.8 + PI * 0.5))
		draw_string(_font, Vector2(center.x - pw * 0.5, size.y * 0.66), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, blink * minf(1.0, _time - INTRO_TIME + 0.3)))


## 字距可调的一行文字，水平居中在 center
func _draw_spaced(text: String, center: Vector2, font_size: int, spacing: float, color: Color) -> void:
	var total := -spacing
	for ch in text:
		total += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing
	var x := center.x - total * 0.5
	for ch in text:
		draw_char(_font, Vector2(x, center.y), ch, font_size, color)
		x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing


static func _ease(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	return style
