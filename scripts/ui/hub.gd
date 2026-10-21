extends Control
## 主神空间：局外大厅。选择化身（角色）、选择关卡、用奖励点购买永久强化、看图鉴、查看战绩、进入篇章
## 背景是主神光球和缓缓上升的光点；「化身」页左边是角色插画，右边是能力介绍和四个化身的头像

const BG_TOP := Color(0.03, 0.035, 0.06)
const BG_BOTTOM := Color(0.07, 0.06, 0.07)
const GOLD := Color(1.0, 0.85, 0.4)
const DIM := Color(0.7, 0.73, 0.8)
const PANEL := Color(0.07, 0.08, 0.12, 0.88)
const CARD_SIZE := Vector2(380, 104)
const BATTLE_SCENE := "res://scenes/main.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const ART_DIR := "res://assets/sprites/cards/"  # 角色插画和升级卡共用（<角色 id>.png）
const FACE_REGION := Rect2(120, 40, 480, 480)    # 头像从插画里裁出的区域（头和肩膀）
const MOTE_COUNT := 50

var _points_label: Label
var _story_label: Label
var _stats_label: Label
var _cards := {}  # 强化 id -> {panel, level, button}
var _level_cards := {}  # 关卡 id -> {panel, button}
var _subtitle: Label
var _start: Button
var _settings: SettingsPanel
var _tabs: TabContainer
var _tab_buttons: Array[Button] = []
var _viewing := ""  # 「化身」页正在看的角色（默认是已选择的角色）
var _hero := {}     # 「化身」页右侧的各个控件
var _faces := {}    # 角色 id -> 头像按钮
var _motes := []    # 上升的光点：[x 比例, 起始相位, 速度, 大小]
var _time := 0.0
var _launching := false
static var _reopen_settings := false  # 切换语言后重建界面，再把设置面板打开


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Audio.music("hub")
	_viewing = CharacterDB.selected()
	for i in MOTE_COUNT:
		_motes.append([randf(), randf(), randf_range(0.015, 0.04), randf_range(1.0, 2.5)])

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# ---- 顶部：标题 + 货币 ----
	var header := HBoxContainer.new()
	root.add_child(header)
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 0)
	header.add_child(title_box)
	title_box.add_child(_label(tr("主神空间"), 34, GOLD))
	_subtitle = _label("", 15, DIM)
	title_box.add_child(_subtitle)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var money := VBoxContainer.new()
	money.add_theme_constant_override("separation", 0)
	header.add_child(money)
	_points_label = _label("", 24, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	_story_label = _label("", 15, Color(0.75, 0.6, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	money.add_child(_points_label)
	money.add_child(_story_label)

	# ---- 分页按钮 + 四个分页「化身」「关卡」「永久强化」「图鉴」 ----
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	root.add_child(nav)
	_tabs = TabContainer.new()
	_tabs.tabs_visible = false
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	root.add_child(_tabs)
	for page_name in [tr("化身"), tr("关卡"), tr("永久强化"), tr("图鉴")]:
		var button := Button.new()
		button.text = page_name
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(112, 38)
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_show_tab.bind(_tab_buttons.size()))
		nav.add_child(button)
		_tab_buttons.append(button)

	_tabs.add_child(_make_character_page())

	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", 16)
	_tabs.add_child(levels)
	for i in LevelDB.ORDER.size():
		levels.add_child(_make_level_card(LevelDB.ORDER[i], i))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	_tabs.add_child(grid)
	for id: String in MetaDB.UPGRADES:
		grid.add_child(_make_card(id))

	_tabs.add_child(CodexView.new())
	_tabs.tab_changed.connect(func(_index: int) -> void: _style_tabs())
	_style_tabs()

	# ---- 底部：战绩、链接 + 进入篇章 ----
	var footer := HBoxContainer.new()
	root.add_child(footer)
	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_END
	footer.add_child(left)
	_stats_label = _label("", 14, DIM)
	left.add_child(_stats_label)
	var links := HBoxContainer.new()
	links.add_theme_constant_override("separation", 4)
	left.add_child(links)
	links.add_child(_link_button(tr("设置  [Esc]"), func() -> void: _settings.open()))
	links.add_child(_link_button(tr("返回标题"), func() -> void: get_tree().change_scene_to_file(TITLE_SCENE)))
	links.add_child(_link_button(tr("退出游戏"), func() -> void: get_tree().quit()))
	var reset := _link_button(tr("重置存档"), _confirm_reset)
	reset.modulate = Color(1, 1, 1, 0.4)
	links.add_child(reset)
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

	_settings = SettingsPanel.new()
	add_child(_settings)
	Settings.language_changed.connect(func() -> void:
		_reopen_settings = true
		get_tree().reload_current_scene())
	if _reopen_settings:
		_reopen_settings = false
		_settings.open()

	_refresh()


func _show_tab(index: int) -> void:
	_tabs.current_tab = index


## 当前分页的按钮：金色文字和下划线；其他的暗一些
func _style_tabs() -> void:
	for i in _tab_buttons.size():
		var button := _tab_buttons[i]
		var on := i == _tabs.current_tab
		var line := StyleBoxFlat.new()
		line.bg_color = Color(GOLD, 0.08) if on else Color(0, 0, 0, 0)
		line.border_color = GOLD if on else Color(1, 1, 1, 0.12)
		line.border_width_bottom = 2
		line.set_content_margin_all(6)
		var hover := line.duplicate()
		hover.bg_color = Color(GOLD, 0.12)
		for state in ["normal", "pressed"]:
			button.add_theme_stylebox_override(state, line)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_color_override("font_color", GOLD if on else DIM)
		button.add_theme_color_override("font_hover_color", GOLD)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not (key and key.pressed and not key.echo):
		return
	if _settings.visible:
		return  # 设置打开时，按键交给设置面板
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_start_battle()
	elif key.keycode == KEY_ESCAPE:
		_settings.open()


func _start_battle() -> void:
	if _launching: return
	_launching = true
	ChapterIntro.open(get_tree(), LevelDB.selected())


## 「化身」页：左边是正在看的角色的插画，右边是名字、三项能力，下面是四个化身的头像和选择 / 解锁按钮
func _make_character_page() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 26)

	var frame := Panel.new()  # 插画裁成圆角
	frame.custom_minimum_size = Vector2(290, 0)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.add_theme_stylebox_override("panel", _style(Color(0.06, 0.07, 0.1), Color(0, 0, 0, 0), 0))
	page.add_child(frame)
	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(art)
	var lock := _label(tr("未解锁"), 22, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock.add_theme_constant_override("outline_size", 6)
	lock.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	frame.add_child(lock)
	var border := Panel.new()
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(border)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 14)
	page.add_child(info)
	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 0)
	info.add_child(name_box)
	var hero_name := _label("", 40, Color.WHITE)
	var hero_title := _label("", 16, DIM)
	name_box.add_child(hero_name)
	name_box.add_child(hero_title)

	var abilities := HBoxContainer.new()
	abilities.add_theme_constant_override("separation", 14)
	info.add_child(abilities)
	var blocks := []
	for kind in [tr("武器"), tr("被动"), tr("大招")]:
		var block := PanelContainer.new()
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.size_flags_stretch_ratio = 1.0
		abilities.add_child(block)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		block.add_child(box)
		box.add_child(_label(kind, 13, DIM))
		var ability_name := _label("", 20, Color.WHITE)
		var ability_desc := _label("", 14, Color(0.85, 0.87, 0.92))
		ability_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ability_desc.custom_minimum_size = Vector2(200, 0)
		box.add_child(ability_name)
		box.add_child(ability_desc)
		blocks.append([block, ability_name, ability_desc])

	var quote_box := VBoxContainer.new()  # 大招特写上的台词和「最璀璨的时刻」
	quote_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quote_box.alignment = BoxContainer.ALIGNMENT_CENTER
	quote_box.add_theme_constant_override("separation", 6)
	info.add_child(quote_box)
	var quote := _label("", 19, Color(0.92, 0.9, 0.85, 0.85))
	var moment := _label("", 14, DIM)
	quote_box.add_child(quote)
	quote_box.add_child(moment)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	info.add_child(row)
	for id: String in CharacterDB.ALL:
		row.add_child(_make_face(id))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(12, 0)
	row.add_child(gap)
	var action := Button.new()
	action.custom_minimum_size = Vector2(250, 56)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action.add_theme_font_size_override("font_size", 17)
	action.focus_mode = Control.FOCUS_NONE
	action.pressed.connect(func() -> void: _on_character_pressed(_viewing))
	row.add_child(action)

	_hero = {"art": art, "lock": lock, "border": border, "name": hero_name, "title": hero_title, "blocks": blocks, "action": action,
		"quote": quote, "moment": moment}
	return page


## 角色头像：从插画里裁出头和肩膀；点一下在上面查看这个角色
func _make_face(id: String) -> Button:
	var face := Button.new()
	face.custom_minimum_size = Vector2(96, 96)
	face.focus_mode = Control.FOCUS_NONE
	face.clip_contents = true
	face.pressed.connect(func() -> void:
		_viewing = id
		_refresh())
	var image := TextureRect.new()
	image.texture = _character_art(id, true)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.offset_left = 3
	image.offset_top = 3
	image.offset_right = -3
	image.offset_bottom = -3
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(image)
	_faces[id] = face
	return face


## 角色插画（cards/<id>.png，没有就用大招特写）；face = true 时只裁出头像部分
func _character_art(id: String, face: bool = false) -> Texture2D:
	var path := ART_DIR + id + ".png"
	if not ResourceLoader.exists(path):
		path = CharacterDB.CUTIN_DIR + id + "_cutin.png"
		return load(path) if ResourceLoader.exists(path) else null
	if not face:
		return load(path)
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	atlas.region = FACE_REGION
	return atlas


func _on_character_pressed(id: String) -> void:
	if CharacterDB.is_unlocked(id):
		Save.select_character(id)
	else:
		var unlock: Dictionary = CharacterDB.ALL[id].unlock
		if unlock.type == "story" and Save.unlock_character(id, unlock.value):
			Save.select_character(id)
	_refresh()


## 「化身」页：按正在看的角色刷新插画、能力、头像边框和按钮
func _refresh_character_page(selected: String) -> void:
	var info: Dictionary = CharacterDB.ALL[_viewing]
	var unlocked := CharacterDB.is_unlocked(_viewing)
	var color: Color = info.color
	(_hero.art as TextureRect).texture = _character_art(_viewing)
	(_hero.art as TextureRect).modulate = Color.WHITE if unlocked else Color(0.35, 0.35, 0.4)
	(_hero.lock as Label).visible = not unlocked
	(_hero.border as Panel).add_theme_stylebox_override("panel", _border(color, 2))
	(_hero.name as Label).text = tr(info.name)
	(_hero.name as Label).modulate = color
	(_hero.title as Label).text = tr(info.title)
	(_hero.quote as Label).text = tr("「%s」") % tr(info.cutin_line)
	(_hero.moment as Label).text = "—— " + tr(info.cutin_moment)
	var lines := [[info.weapon, info.weapon_desc], [info.passive, info.passive_desc], [info.ult_name, info.ult_desc]]
	for i in 3:
		var block: Array = _hero.blocks[i]
		(block[0] as PanelContainer).add_theme_stylebox_override("panel", _block_style(color))
		(block[1] as Label).text = tr(lines[i][0])
		(block[2] as Label).text = tr(lines[i][1])

	var action: Button = _hero.action
	if _viewing == selected:
		action.text = tr("已选择")
		action.disabled = true
	elif unlocked:
		action.text = tr("选择")
		action.disabled = false
	elif info.unlock.type == "story":
		action.text = tr("解锁（%d 支线剧情点）") % info.unlock.value
		action.disabled = Save.story_points < info.unlock.value
	else:
		action.text = tr("未解锁：") + tr(info.unlock.text)
		action.disabled = true
	action.add_theme_stylebox_override("normal", _style(Color(color.darkened(0.7), 0.9), color, 2))
	action.add_theme_stylebox_override("hover", _style(Color(color.darkened(0.55), 0.95), color, 3))
	action.add_theme_stylebox_override("pressed", _style(Color(color.darkened(0.45), 0.95), color, 3))
	action.add_theme_stylebox_override("disabled", _style(Color(0.08, 0.09, 0.12, 0.8), Color(color, 0.35), 1))

	for id: String in _faces:
		var face: Button = _faces[id]
		var face_color: Color = CharacterDB.ALL[id].color
		var border := GOLD if id == selected else (face_color if id == _viewing else Color(0.3, 0.32, 0.4))
		var width := 3 if id == selected or id == _viewing else 1
		for state in ["normal", "hover", "pressed"]:
			face.add_theme_stylebox_override(state, _style(Color(0.06, 0.07, 0.1), border if state != "hover" else face_color, width, 0))
		face.get_child(0).modulate = Color.WHITE if CharacterDB.is_unlocked(id) else Color(0.35, 0.35, 0.4)
		face.tooltip_text = tr(CharacterDB.ALL[id].name)


func _block_style(color: Color) -> StyleBoxFlat:
	var style := _style(PANEL, Color(color, 0.7), 0, 14)
	style.border_width_top = 2
	return style


func _border(color: Color, width: int) -> StyleBoxFlat:
	var style := _style(Color(0, 0, 0, 0), color, width)
	style.draw_center = false
	return style


## 关卡卡片：第几关、关名、地点、三个 Boss，底部是选择按钮
func _make_level_card(id: String, index: int) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(_label(tr("第 %d 关") % (index + 1), 14, DIM))
	box.add_child(_label(tr(LevelDB.NAMES[id]), 26, GOLD))
	box.add_child(_label(tr(LevelDB.PLACES[id]), 14, DIM))
	box.add_child(_label(tr("Boss：") + tr(LevelDB.BOSS_NAMES[id]), 13, Color(0.85, 0.87, 0.92)))
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(fill)
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 40)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void:
		Save.select_level(id)
		_refresh())
	box.add_child(button)
	var replay := Button.new()
	replay.text = tr("回看本关剧情")
	replay.custom_minimum_size = Vector2(0, 34)
	replay.disabled = not (LevelDB.is_built(id) and LevelDB.is_unlocked(id))
	replay.pressed.connect(func() -> void:
		if _launching: return
		_launching = true
		ChapterIntro.open(get_tree(), id, true))
	box.add_child(replay)
	_level_cards[id] = {"panel": panel, "button": button}
	return panel


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
	text.add_child(_label(tr(info.name), 18, Color.WHITE))
	text.add_child(_label(tr(info.desc), 13, DIM))
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
	_subtitle.text = tr("化身：%s · %s") % [tr(selected_info.name), tr(selected_info.title)]
	var level := LevelDB.selected()
	_start.text = tr("以 %s 进入%s\n第 %d 关 · %s    [Enter]") % [tr(selected_info.name), tr(LevelDB.CHAPTER), LevelDB.ORDER.find(level) + 1, tr(LevelDB.NAMES[level])]
	for id: String in _level_cards:
		var card: Dictionary = _level_cards[id]
		var button: Button = card.button
		var open := LevelDB.is_built(id) and LevelDB.is_unlocked(id)
		if id == level:
			button.text = tr("已选择")
		elif not LevelDB.is_built(id):
			button.text = tr("制作中")
		elif not LevelDB.is_unlocked(id):
			button.text = tr("未解锁：通关上一关")
		else:
			button.text = tr("选择")
		button.disabled = id == level or not open
		var border := GOLD if id == level else (Color(0.4, 0.43, 0.52) if open else Color(0.22, 0.24, 0.3))
		(card.panel as PanelContainer).add_theme_stylebox_override("panel", _style(Color(0.08, 0.09, 0.13), border, 3 if id == level else 2, 12))
		(card.panel as Control).modulate = Color.WHITE if open else Color(1, 1, 1, 0.55)
	_refresh_character_page(selected)

	_points_label.text = tr("奖励点  %d") % Save.reward_points
	_story_label.text = tr("支线剧情点  %d") % Save.story_points
	var s: Dictionary = Save.stats
	_stats_label.text = tr("轮回 %d 次　通关 %d 次　最久存活 %s　最快通关 %s　累计击杀 %d") % [
		s.runs, s.clears, _format_time(s.best_time), _format_time(s.best_clear_time) if s.best_clear_time > 0.0 else "—", s.total_kills]
	for id: String in _cards:
		var info: Dictionary = MetaDB.UPGRADES[id]
		var lv := Save.meta_level(id)
		var maxed: bool = lv >= info.max
		var cost := MetaDB.cost(id, lv)
		var card: Dictionary = _cards[id]
		card.level.text = "■".repeat(lv) + "□".repeat(info.max - lv) + "  %d / %d" % [lv, info.max]
		card.button.text = tr("已满级") if maxed else tr("强化\n%d 点") % cost
		card.button.disabled = maxed or Save.reward_points < cost
		var border := GOLD if maxed else (Color(0.55, 0.6, 0.75) if lv > 0 else Color(0.3, 0.33, 0.42))
		(card.panel as PanelContainer).add_theme_stylebox_override("panel", _style(Color(0.08, 0.09, 0.13), border, 2, 12))


func _confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = tr("重置存档")
	dialog.dialog_text = tr("确定要清空所有奖励点、永久强化和战绩吗？此操作无法撤销。")
	dialog.ok_button_text = tr("清空")
	dialog.cancel_button_text = tr("取消")
	dialog.confirmed.connect(func() -> void:
		Save.reset()
		_refresh())
	add_child(dialog)
	dialog.popup_centered()


func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM]))
	GodSphere.draw(self, Vector2(size.x * 0.5, 64.0), _time, 1.0, 150.0)
	draw_circle(Vector2(size.x * 0.5, 64.0), 22.0, Color(1.0, 0.97, 0.88, 0.9))
	for mote: Array in _motes:  # 光点从下往上飘，越往上越淡
		var t := fposmod(mote[1] + _time * mote[2], 1.0)
		var at := Vector2(mote[0] * size.x + sin(_time * 0.7 + mote[1] * TAU) * 14.0, size.y * (1.05 - t * 1.1))
		draw_circle(at, mote[3], Color(1.0, 0.88, 0.6, 0.35 * sin(t * PI)))


func _link_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button


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
