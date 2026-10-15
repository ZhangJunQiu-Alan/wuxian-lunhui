extends Control
## 主神空间：局外大厅。选择轮回者（角色）、用奖励点购买永久强化、查看战绩、进入篇章

const BG := Color(0.045, 0.05, 0.075)
const GOLD := Color(1.0, 0.85, 0.4)
const DIM := Color(0.7, 0.73, 0.8)
const CARD_SIZE := Vector2(380, 104)
const BATTLE_SCENE := "res://scenes/main.tscn"

var _points_label: Label
var _story_label: Label
var _stats_label: Label
var _cards := {}  # 强化 id -> {panel, level, button}
var _char_cards := {}  # 角色 id -> {panel, button}
var _subtitle: Label
var _start: Button
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# ---- 顶部：标题 + 货币 ----
	var header := HBoxContainer.new()
	root.add_child(header)
	var title_box := VBoxContainer.new()
	header.add_child(title_box)
	title_box.add_child(_label("主神空间", 40, GOLD))
	_subtitle = _label("", 16, DIM)
	title_box.add_child(_subtitle)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var money := VBoxContainer.new()
	header.add_child(money)
	_points_label = _label("", 26, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	_story_label = _label("", 16, Color(0.75, 0.6, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	money.add_child(_points_label)
	money.add_child(_story_label)

	# ---- 中间：两个分页「轮回者」「永久强化」 ----
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	root.add_child(tabs)

	var chars := HBoxContainer.new()
	chars.name = "轮回者"
	chars.add_theme_constant_override("separation", 16)
	tabs.add_child(chars)
	for id: String in CharacterDB.ALL:
		chars.add_child(_make_character_card(id))

	var grid := GridContainer.new()
	grid.name = "永久强化"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	tabs.add_child(grid)
	for id: String in MetaDB.UPGRADES:
		grid.add_child(_make_card(id))

	# ---- 底部：战绩 + 进入篇章 ----
	var footer := HBoxContainer.new()
	root.add_child(footer)
	var left := VBoxContainer.new()
	footer.add_child(left)
	_stats_label = _label("", 14, DIM)
	left.add_child(_stats_label)
	var reset := Button.new()
	reset.text = "重置存档"
	reset.flat = true
	reset.focus_mode = Control.FOCUS_NONE
	reset.modulate = Color(1, 1, 1, 0.45)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(_confirm_reset)
	left.add_child(reset)
	var push := Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(push)
	var start := Button.new()
	_start = start
	start.custom_minimum_size = Vector2(380, 72)
	start.add_theme_font_size_override("font_size", 18)
	start.add_theme_stylebox_override("normal", _style(Color(0.28, 0.2, 0.06), GOLD, 2))
	start.add_theme_stylebox_override("hover", _style(Color(0.4, 0.29, 0.08), GOLD, 3))
	start.add_theme_stylebox_override("pressed", _style(Color(0.5, 0.36, 0.1), GOLD, 3))
	start.focus_mode = Control.FOCUS_NONE
	start.pressed.connect(_start_battle)
	footer.add_child(start)

	_refresh()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
		_start_battle()


func _start_battle() -> void:
	get_tree().change_scene_to_file(BATTLE_SCENE)


## 角色卡：立绘、名字、武器、被动、大招，底部是选择 / 解锁按钮
func _make_character_card(id: String) -> Control:
	var info: Dictionary = CharacterDB.ALL[id]
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)

	# 立绘：有素材用素材，没有就用名字的第一个字做水墨风占位
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(0, 76)
	portrait.draw.connect(_draw_portrait.bind(portrait, id))
	box.add_child(portrait)

	box.add_child(_label(info.name, 22, info.color))
	box.add_child(_label(info.title, 13, DIM))
	for line in [["武器", info.weapon, info.weapon_desc], ["被动", info.passive, info.passive_desc], ["大招", info.ult_name, info.ult_desc]]:
		var label := _label("%s · %s\n%s" % line, 13, Color(0.85, 0.87, 0.92))
		label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		label.custom_minimum_size = Vector2(240, 0)
		box.add_child(label)

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(fill)
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 40)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_character_pressed.bind(id))
	box.add_child(button)
	_char_cards[id] = {"panel": panel, "button": button}
	return panel


func _draw_portrait(canvas: Control, id: String) -> void:
	var info: Dictionary = CharacterDB.ALL[id]
	var rect := Rect2(Vector2.ZERO, canvas.size)
	canvas.draw_rect(rect, Color(info.color, 0.12))
	var path: String = CharacterDB.CUTIN_DIR + id + ".png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		var zoom := maxf(1.0, floorf(rect.size.y / tex.get_height()))  # 像素画按整数倍放大
		var draw_size := tex.get_size() * zoom
		canvas.draw_texture_rect(tex, Rect2(rect.get_center() - draw_size / 2.0, draw_size), false)
	else:
		var font := ThemeDB.fallback_font
		var custom: String = ProjectSettings.get_setting("gui/theme/custom_font", "")
		if custom != "":
			font = load(custom)
		var glyph: String = info.name.substr(0, 1)
		var glyph_size := 56
		var w := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size).x
		canvas.draw_string(font, Vector2(rect.get_center().x - w / 2.0, rect.size.y * 0.78), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, Color(info.color, 0.85))
	if not CharacterDB.is_unlocked(id):
		canvas.draw_rect(rect, Color(0, 0, 0, 0.6))  # 未解锁：立绘压暗


func _on_character_pressed(id: String) -> void:
	if CharacterDB.is_unlocked(id):
		Save.select_character(id)
	else:
		var unlock: Dictionary = CharacterDB.ALL[id].unlock
		if unlock.type == "story" and Save.unlock_character(id, unlock.value):
			Save.select_character(id)
	_refresh()


func _make_card(id: String) -> Control:
	var info: Dictionary = MetaDB.UPGRADES[id]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # 三列平均铺满宽度
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	row.add_child(text)
	text.add_child(_label(info.name, 18, Color.WHITE))
	text.add_child(_label(info.desc, 13, DIM))
	var level := _label("", 14, GOLD)
	text.add_child(level)

	var button := Button.new()
	button.custom_minimum_size = Vector2(108, 0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_buy.bind(id))
	row.add_child(button)

	_cards[id] = {"panel": panel, "level": level, "button": button}
	return panel


func _buy(id: String) -> void:
	if Save.buy_meta(id):
		var panel: Control = _cards[id].panel
		panel.modulate = Color(1.6, 1.4, 0.9)  # 购买成功时闪一下
		create_tween().tween_property(panel, "modulate", Color.WHITE, 0.4)
	_refresh()


func _refresh() -> void:
	var selected := CharacterDB.selected()
	var selected_info: Dictionary = CharacterDB.ALL[selected]
	_subtitle.text = "轮回者：%s · %s" % [selected_info.name, selected_info.title]
	_start.text = "以 %s 进入篇章一 · 诸神黄昏\n第 1 关 · 芬布尔之冬    [Enter]" % selected_info.name
	for id: String in _char_cards:
		var info: Dictionary = CharacterDB.ALL[id]
		var card: Dictionary = _char_cards[id]
		var unlocked := CharacterDB.is_unlocked(id)
		var button: Button = card.button
		if id == selected:
			button.text = "已选择"
			button.disabled = true
		elif unlocked:
			button.text = "选择"
			button.disabled = false
		elif info.unlock.type == "story":
			button.text = "解锁（%d 支线剧情点）" % info.unlock.value
			button.disabled = Save.story_points < info.unlock.value
		else:
			button.text = "未解锁：" + info.unlock.text
			button.disabled = true
		var border: Color = info.color if id == selected else (Color(0.4, 0.43, 0.52) if unlocked else Color(0.22, 0.24, 0.3))
		(card.panel as PanelContainer).add_theme_stylebox_override("panel", _style(Color(0.08, 0.09, 0.13), border, 3 if id == selected else 2, 12))
		(card.panel as Control).queue_redraw()
		for child in (card.panel as Control).get_children():
			(child as Control).get_child(0).queue_redraw()  # 重画立绘（解锁后不再压暗）

	_points_label.text = "奖励点  %d" % Save.reward_points
	_story_label.text = "支线剧情点  %d" % Save.story_points
	var s: Dictionary = Save.stats
	_stats_label.text = "轮回 %d 次　通关 %d 次　最久存活 %s　最快通关 %s　累计击杀 %d" % [
		s.runs, s.clears, _format_time(s.best_time), _format_time(s.best_clear_time) if s.best_clear_time > 0.0 else "—", s.total_kills]
	for id: String in _cards:
		var info: Dictionary = MetaDB.UPGRADES[id]
		var lv := Save.meta_level(id)
		var maxed: bool = lv >= info.max
		var cost := MetaDB.cost(id, lv)
		var card: Dictionary = _cards[id]
		card.level.text = "■".repeat(lv) + "□".repeat(info.max - lv) + "  %d / %d" % [lv, info.max]
		card.button.text = "已满级" if maxed else "强化\n%d 点" % cost
		card.button.disabled = maxed or Save.reward_points < cost
		var border := GOLD if maxed else (Color(0.55, 0.6, 0.75) if lv > 0 else Color(0.3, 0.33, 0.42))
		(card.panel as PanelContainer).add_theme_stylebox_override("panel", _style(Color(0.08, 0.09, 0.13), border, 2, 12))


func _confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "重置存档"
	dialog.dialog_text = "确定要清空所有奖励点、永久强化和战绩吗？此操作无法撤销。"
	dialog.ok_button_text = "清空"
	dialog.cancel_button_text = "取消"
	dialog.confirmed.connect(func() -> void:
		Save.reset()
		_refresh())
	add_child(dialog)
	dialog.popup_centered()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	# 主神：悬在空中的光球，缓慢脉动
	var center := Vector2(size.x * 0.5, 70.0)
	var pulse := 0.5 + 0.5 * sin(_time * 1.5)
	for i in 6:
		var r := 30.0 + i * 26.0 + pulse * 6.0
		draw_circle(center, r, Color(1.0, 0.95, 0.8, 0.05 - i * 0.006))
	draw_circle(center, 22.0 + pulse * 2.0, Color(1.0, 0.97, 0.88, 0.9))


func _label(text: String, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	return label


func _style(bg: Color, border: Color, width: int, padding: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(padding)
	return style


static func _format_time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]
