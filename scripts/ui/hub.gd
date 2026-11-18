extends Control
## 主神空间：局外大厅。流程是两步——
##   第一步「整备」：选化身、整理装备、买永久强化、看图鉴，然后点「开始游戏」
##   第二步「选择关卡」：三张关卡卡片里选一关，点「进入」开打；Esc 或「返回」回到第一步
## 样式都来自 UiKit（像素复古）；「装备」页是 GearView，「图鉴」页是 CodexView

const BATTLE_SCENE := "res://scenes/main.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const ART_DIR := "res://assets/sprites/cards/"  # 角色插画和升级卡共用（<角色 id>.png）
const BOSS_DIR := "res://assets/sprites/bosses/"
const FACE_REGION := Rect2(120, 40, 480, 480)    # 头像从插画里裁出的区域（头和肩膀）
const MOTE_COUNT := 40
const CHECKER := 32.0  # 背景棋盘格的大小
const TAB_GEAR := 1

var _points_label: Label
var _stats_label: Label
var _cards := {}  # 强化 id -> {panel, pips, level, button}
var _level_cards := {}  # 关卡 id -> {panel, button, state, drops}
var _subtitle: Label
var _start: Button
var _start_title: Label
var _start_detail: Label
var _back: Button
var _links: Control
var _nav: Control
var _step_title: Label
var _settings: SettingsPanel
var _tabs: TabContainer
var _stage: Control      # 第二步「选择关卡」的页面
var _picking_level := false
var _tab_buttons: Array[Button] = []
var _gear: GearView
var _gear_dot: Control
var _hero := {}     # 「化身」页的各个控件
var _faces := {}    # 角色 id -> {button, name}
var _motes := []    # 上升的光点：[x 比例, 起始相位, 速度, 大小]
var _time := 0.0
var _launching := false
static var _reopen_settings := false  # 切换语言后重建界面，再把设置面板打开


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Audio.music("hub")
	for i in MOTE_COUNT:
		_motes.append([randf(), randf(), randf_range(0.015, 0.04), float(randi_range(1, 2)) * 2.0])

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	root.add_child(_make_header())
	_tabs = TabContainer.new()
	_tabs.tabs_visible = false
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	root.add_child(_tabs)

	_tabs.add_child(_make_character_page())
	_gear = GearView.new()
	_gear.changed.connect(_refresh)
	_tabs.add_child(_gear)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 14)
	_tabs.add_child(grid)
	for id: String in MetaDB.UPGRADES:
		grid.add_child(_make_card(id))
	_tabs.add_child(CodexView.new())
	_tabs.tab_changed.connect(func(_index: int) -> void: _style_tabs())
	_style_tabs()

	var levels := HBoxContainer.new()  # 第二步：选择关卡
	_stage = levels
	levels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	levels.add_theme_constant_override("separation", 18)
	levels.visible = false
	root.add_child(levels)
	for i in LevelDB.ORDER.size():
		levels.add_child(_make_level_card(LevelDB.ORDER[i], i))

	root.add_child(UiKit.rule())
	root.add_child(_make_footer())

	_settings = SettingsPanel.new()
	add_child(_settings)
	Settings.language_changed.connect(func() -> void:
		_reopen_settings = true
		get_tree().reload_current_scene())
	if _reopen_settings:
		_reopen_settings = false
		_settings.open()

	_refresh()


## 顶部：左边标题，中间分页（第二步时换成「选择关卡」），右边奖励点
func _make_header() -> Control:
	var header := Control.new()
	header.custom_minimum_size = Vector2(0, 58)
	var title_box := VBoxContainer.new()
	title_box.position = Vector2(0, 0)
	title_box.add_theme_constant_override("separation", -2)
	header.add_child(title_box)
	var brand := UiKit.label(tr("主神空间"), 30, UiKit.GOLD)
	brand.add_theme_color_override("font_shadow_color", UiKit.BAD)  # 标题右下一层红色硬投影
	brand.add_theme_constant_override("shadow_offset_x", 3)
	brand.add_theme_constant_override("shadow_offset_y", 3)
	title_box.add_child(brand)
	_subtitle = UiKit.label("", 13, UiKit.DIM)
	title_box.add_child(_subtitle)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(center)
	var middle := VBoxContainer.new()
	center.add_child(middle)
	var nav := HBoxContainer.new()
	_nav = nav
	nav.add_theme_constant_override("separation", 10)
	middle.add_child(nav)
	for page_name in [tr("化身"), tr("装备"), tr("永久强化"), tr("图鉴")]:
		var index := _tab_buttons.size()
		var button := UiKit.button(page_name, _show_tab.bind(index), Vector2(112, 44), 18)
		button.tooltip_text = tr("快捷键 %d") % (index + 1)
		nav.add_child(button)
		_tab_buttons.append(button)
	var dot := UiKit.Diamond.new()  # 有没看过的新装备时，「装备」上亮一个红点
	_gear_dot = dot
	dot.color = UiKit.BAD
	dot.square = true
	dot.position = Vector2(96, 4)
	_tab_buttons[TAB_GEAR].add_child(dot)
	_step_title = UiKit.label(tr("选择关卡"), 26, UiKit.IVORY, HORIZONTAL_ALIGNMENT_CENTER)
	_step_title.visible = false
	middle.add_child(_step_title)

	var money := HBoxContainer.new()
	money.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	money.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	money.grow_vertical = Control.GROW_DIRECTION_BOTH
	money.add_theme_constant_override("separation", 10)
	header.add_child(money)
	var money_caption := UiKit.label(tr("奖励点"), 14, UiKit.DIM)
	money_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money.add_child(money_caption)
	_points_label = UiKit.label("", 28, UiKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	money.add_child(_points_label)
	return header


## 底部：左边是战绩和链接（第二步时换成「返回」），右边是「开始游戏」/「进入」
func _make_footer() -> Control:
	var footer := HBoxContainer.new()
	footer.custom_minimum_size = Vector2(0, 66)
	var left := VBoxContainer.new()
	_links = left
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 6)
	footer.add_child(left)
	_stats_label = UiKit.label("", 13, UiKit.DIM)
	left.add_child(_stats_label)
	var links := HBoxContainer.new()
	links.add_theme_constant_override("separation", 6)
	left.add_child(links)
	links.add_child(UiKit.link(tr("设置  [Esc]"), func() -> void: _settings.open()))
	links.add_child(UiKit.link(tr("返回标题"), func() -> void: get_tree().change_scene_to_file(TITLE_SCENE)))
	links.add_child(UiKit.link(tr("退出游戏"), func() -> void: get_tree().quit()))
	var reset := UiKit.link(tr("重置存档"), _confirm_reset)
	reset.add_theme_color_override("font_color", UiKit.FAINT)
	links.add_child(reset)
	_back = UiKit.button(tr("‹ 返回整备  [Esc]"), _show_levels.bind(false), Vector2(220, 52), 17)
	_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_back.visible = false
	footer.add_child(_back)
	footer.add_child(UiKit.spacer())

	_start = UiKit.primary("", _on_start_pressed, Vector2(400, 62))
	_start.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_start)
	var start_box := VBoxContainer.new()
	start_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_box.offset_bottom = -UiKit.DEPTH
	start_box.alignment = BoxContainer.ALIGNMENT_CENTER
	start_box.add_theme_constant_override("separation", -2)
	start_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start.add_child(start_box)
	_start_title = UiKit.label("", 21, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_start_detail = UiKit.label("", 13, Color(UiKit.INK, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	start_box.add_child(_start_title)
	start_box.add_child(_start_detail)
	return footer


func _show_tab(index: int) -> void:
	if _picking_level:
		_show_levels(false)
	if _tabs.current_tab != index:
		Audio.sfx("ui_open", -8.0)
	_tabs.current_tab = index


## 当前分页的按钮是金色、按下去的样子
func _style_tabs() -> void:
	for i in _tab_buttons.size():
		UiKit.toggle_button(_tab_buttons[i], i == _tabs.current_tab)


## 在第一步「整备」和第二步「选择关卡」之间切换
func _show_levels(on: bool) -> void:
	if _picking_level != on:
		Audio.sfx("ui_open", -6.0)
	_picking_level = on
	_tabs.visible = not on
	_stage.visible = on
	_nav.visible = not on
	_step_title.visible = on
	_links.visible = not on
	_back.visible = on
	_refresh()


## 右下角的大按钮：第一步是「开始游戏」（去选关卡），第二步是「进入」（开打）
func _on_start_pressed() -> void:
	if not _picking_level:
		_show_levels(true)
	elif not _launching:
		_launching = true
		ChapterIntro.open(get_tree(), LevelDB.selected())


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
		_on_start_pressed()
	elif key.keycode == KEY_ESCAPE:
		if _picking_level:
			_show_levels(false)
		else:
			_settings.open()
	elif _picking_level and (key.keycode == KEY_LEFT or key.keycode == KEY_RIGHT or key.keycode == KEY_A or key.keycode == KEY_D):
		_step_level(-1 if key.keycode == KEY_LEFT or key.keycode == KEY_A else 1)
	elif not _picking_level and key.keycode >= KEY_1 and key.keycode < KEY_1 + _tab_buttons.size():
		_show_tab(key.keycode - KEY_1)


## 选关页用左右键换关：跳到那个方向上最近的一个已解锁的关卡
func _step_level(direction: int) -> void:
	var index := LevelDB.ORDER.find(LevelDB.selected()) + direction
	while index >= 0 and index < LevelDB.ORDER.size():
		var id: String = LevelDB.ORDER[index]
		if LevelDB.is_built(id) and LevelDB.is_unlocked(id):
			Save.select_level(id)
			_refresh()
			return
		index += direction


# ---------------------------------------------------------------- 化身

## 「化身」页：左边是选中角色的插画，右边是名字、三项能力、台词，下面一排四个化身，点一下就换
func _make_character_page() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 24)

	var frame := PanelContainer.new()  # 插画的画框
	frame.custom_minimum_size = Vector2(300, 0)
	frame.add_theme_stylebox_override("panel", UiKit.panel(0, UiKit.IVORY, UiKit.INK))
	page.add_child(frame)
	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	frame.add_child(art)
	var border := Panel.new()  # 插画会盖住画框的边，再描一圈
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(border)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 12)
	page.add_child(info)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 14)
	info.add_child(name_row)
	var hero_name := UiKit.label("", 40, Color.WHITE)
	var hero_title := UiKit.label("", 16, UiKit.DIM)
	hero_title.size_flags_vertical = Control.SIZE_SHRINK_END
	name_row.add_child(hero_name)
	name_row.add_child(hero_title)
	name_row.add_child(UiKit.spacer())
	var hero_stats := UiKit.label("", 14, UiKit.DIM)
	hero_stats.size_flags_vertical = Control.SIZE_SHRINK_END
	name_row.add_child(hero_stats)

	var abilities := HBoxContainer.new()
	abilities.add_theme_constant_override("separation", 14)
	info.add_child(abilities)
	var blocks := []
	for kind in [tr("武器"), tr("被动"), tr("大招")]:
		var block := PanelContainer.new()
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.custom_minimum_size = Vector2(0, 136)
		abilities.add_child(block)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		block.add_child(box)
		var kind_label := UiKit.label(kind, 12, UiKit.DIM)
		box.add_child(kind_label)
		var ability_name := UiKit.label("", 20, Color.WHITE)
		var ability_desc := UiKit.body("", 14, UiKit.IVORY)
		ability_desc.custom_minimum_size = Vector2(200, 0)
		box.add_child(ability_name)
		box.add_child(ability_desc)
		blocks.append([block, ability_name, ability_desc, kind_label])
	var weapon_box: VBoxContainer = (blocks[0][0] as PanelContainer).get_child(0)
	weapon_box.add_child(UiKit.spacer(false))
	var change_weapon := UiKit.link(tr("更换武器 ›"), func() -> void:
		_show_tab(TAB_GEAR)
		_gear.show_weapons(), 13)
	change_weapon.size_flags_horizontal = Control.SIZE_SHRINK_END
	change_weapon.add_theme_color_override("font_color", UiKit.GOLD)
	weapon_box.add_child(change_weapon)

	var set_row := HBoxContainer.new()  # 身上的套装：一行小字，点了去装备页
	set_row.add_theme_constant_override("separation", 8)
	info.add_child(set_row)
	var set_icon := TextureRect.new()
	set_icon.custom_minimum_size = Vector2(24, 24)
	set_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	set_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_row.add_child(set_icon)
	var set_text := UiKit.label("", 14, UiKit.DIM)
	set_text.clip_text = true
	set_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_row.add_child(set_text)
	var change_gear := UiKit.link(tr("整理装备 ›"), _show_tab.bind(TAB_GEAR), 13)
	change_gear.add_theme_color_override("font_color", UiKit.GOLD)
	set_row.add_child(change_gear)

	var quote_box := VBoxContainer.new()  # 大招特写上的台词和「最璀璨的时刻」
	quote_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quote_box.alignment = BoxContainer.ALIGNMENT_CENTER
	quote_box.add_theme_constant_override("separation", 6)
	info.add_child(quote_box)
	var quote := UiKit.label("", 19, UiKit.IVORY)
	var moment := UiKit.label("", 13, UiKit.DIM)
	quote_box.add_child(quote)
	quote_box.add_child(moment)

	info.add_child(UiKit.heading(tr("选择化身")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	info.add_child(row)
	for id: String in CharacterDB.ALL:
		row.add_child(_make_face(id))

	_hero = {"art": art, "border": border, "name": hero_name, "title": hero_title, "stats": hero_stats,
		"blocks": blocks, "quote": quote, "moment": moment, "change_weapon": change_weapon,
		"set_icon": set_icon, "set_text": set_text}
	return page


## 一个化身的选择卡：头像（从插画里裁出头和肩膀）加名字，点一下就选中
func _make_face(id: String) -> Button:
	var face := Button.new()
	face.custom_minimum_size = Vector2(0, 92)
	face.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	face.focus_mode = Control.FOCUS_NONE
	face.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	face.pressed.connect(_on_character_pressed.bind(id))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(row)
	var image := TextureRect.new()
	image.texture = _character_art(id, true)
	image.custom_minimum_size = Vector2(80, 80)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(image)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var face_name := UiKit.label(tr(CharacterDB.ALL[id].name), 18)
	text.add_child(face_name)
	var state := UiKit.label("", 12, UiKit.DIM)
	text.add_child(state)
	_faces[id] = {"button": face, "image": image, "name": face_name, "state": state}
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
	if not CharacterDB.is_unlocked(id) or id == CharacterDB.selected():
		return
	Audio.sfx("ui_open", -6.0)
	Save.select_character(id)
	_gear.refresh()  # 武器栏和纸娃娃跟着角色变
	_refresh()


## 「化身」页：按选中的角色刷新插画、能力和下面一排选择卡
func _refresh_character_page(selected: String) -> void:
	var info: Dictionary = CharacterDB.ALL[selected]
	var color: Color = info.color
	(_hero.art as TextureRect).texture = _character_art(selected)
	(_hero.border as Panel).add_theme_stylebox_override("panel", UiKit.outline(UiKit.IVORY, 4))
	(_hero.name as Label).text = tr(info.name)
	(_hero.name as Label).add_theme_color_override("font_color", color)
	(_hero.title as Label).text = tr(info.title)
	(_hero.stats as Label).text = tr("生命 %d　移速 %d　大招充能 %d 击杀") % [int(info.hp), int(info.speed), int(info.ult_cost)]
	(_hero.quote as Label).text = tr("「%s」") % tr(info.cutin_line)
	(_hero.moment as Label).text = "—— " + tr(info.cutin_moment)
	var lines := [[info.weapon, info.weapon_desc], [info.passive, info.passive_desc], [info.ult_name, info.ult_desc]]
	if selected == "swordsman":
		lines[0] = SwordsmanLoadout.KITS[SwordsmanLoadout.valid(Save.swordsman_weapon)]
	(_hero.change_weapon as Button).visible = selected == "swordsman"
	for i in 3:
		var block: Array = _hero.blocks[i]
		(block[0] as PanelContainer).add_theme_stylebox_override("panel", UiKit.panel(14, color))
		(block[1] as Label).text = tr(lines[i][0])
		(block[2] as Label).text = tr(lines[i][1])
		(block[3] as Label).add_theme_color_override("font_color", color)

	var active := GearDB.active_set()
	(_hero.set_icon as TextureRect).texture = GearDB.set_icon(active) if active != "" else null
	(_hero.set_icon as TextureRect).visible = active != ""
	if active != "":
		(_hero.set_text as Label).text = tr("套装 · %s　%s") % [tr(GearDB.SETS[active].name), tr(GearDB.SETS[active].effect)]  # 规则在鼠标提示和装备页里
		(_hero.set_text as Label).tooltip_text = tr(GearDB.SETS[active].rule)
		(_hero.set_text as Label).mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		(_hero.set_text as Label).text = tr("套装 · 未激活（防具 %d / 4）") % Save.equipped.size()

	for id: String in _faces:
		var face: Dictionary = _faces[id]
		var on := id == selected
		var unlocked := CharacterDB.is_unlocked(id)
		var face_color: Color = CharacterDB.ALL[id].color
		var button: Button = face.button
		button.add_theme_stylebox_override("normal", UiKit.cell(UiKit.GOLD if on else UiKit.LINE, UiKit.SURFACE if on else UiKit.SURFACE_RAISED, 6))
		button.add_theme_stylebox_override("pressed", UiKit.cell(UiKit.GOLD, UiKit.SURFACE, 6))
		button.add_theme_stylebox_override("hover", UiKit.cell(UiKit.GOLD if on else face_color, UiKit.SURFACE, 6))
		(face.image as TextureRect).modulate = Color.WHITE if on else (Color(0.7, 0.7, 0.75) if unlocked else Color(0.3, 0.3, 0.35))
		(face.name as Label).add_theme_color_override("font_color", face_color if on else UiKit.IVORY)
		(face.state as Label).text = tr("出战中") if on else (tr(CharacterDB.ALL[id].title) if unlocked else tr("未解锁"))
		(face.state as Label).add_theme_color_override("font_color", UiKit.GOLD if on else UiKit.DIM)


# ---------------------------------------------------------------- 关卡

## 关卡卡片：第几关、关名、地点、三个 Boss、本关掉落的套装，底部是选择和回看剧情
func _make_level_card(id: String, index: int) -> Control:
	var panel := UiKit.framed(18)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.gui_input.connect(func(event: InputEvent) -> void:  # 点卡片上任何地方都算选这一关
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and LevelDB.is_built(id) and LevelDB.is_unlocked(id):
			if click.double_click:
				_on_start_pressed()
			elif LevelDB.selected() != id:
				Audio.sfx("ui_open", -8.0)
				Save.select_level(id)
				_refresh())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	top.add_child(UiKit.label(tr("第 %d 关") % (index + 1), 13, UiKit.DIM))
	top.add_child(UiKit.spacer())
	var state := UiKit.label("", 13, UiKit.DIM)
	top.add_child(state)
	box.add_child(UiKit.label(tr(LevelDB.NAMES[id]), 28, UiKit.GOLD))
	box.add_child(UiKit.label(tr(LevelDB.PLACES[id]), 14, UiKit.DIM))

	box.add_child(UiKit.heading("Boss"))
	var bosses := HBoxContainer.new()
	bosses.add_theme_constant_override("separation", 8)
	box.add_child(bosses)
	for row: Array in CodexDB.BOSSES.get(id, []):
		var known := Save.codex_count("bosses", row[0]) >= 0
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 2)
		bosses.add_child(cell)
		var plate := PanelContainer.new()
		plate.add_theme_stylebox_override("panel", UiKit.cell())
		plate.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.add_child(plate)
		var image := TextureRect.new()
		var sprite: String = BOSS_DIR + (row[5] if row.size() > 5 else row[0]) + ".png"
		image.texture = load(sprite) if ResourceLoader.exists(sprite) else null
		image.custom_minimum_size = Vector2(0, 84)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.modulate = Color.WHITE if known else Color(0, 0, 0, 0.8)
		plate.add_child(image)
		cell.add_child(UiKit.label(tr(row[1]) if known else CodexView.UNKNOWN, 13, UiKit.IVORY if known else UiKit.FAINT, HORIZONTAL_ALIGNMENT_CENTER))

	box.add_child(UiKit.heading(tr("本关掉落")))
	var drops := VBoxContainer.new()
	drops.add_theme_constant_override("separation", 3)
	box.add_child(drops)

	box.add_child(UiKit.spacer(false))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	var button := UiKit.button("", func() -> void:
		Save.select_level(id)
		_refresh(), Vector2(0, 42))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(button)
	var replay := UiKit.button(tr("回看本关剧情"), func() -> void:
		if _launching: return
		_launching = true
		ChapterIntro.open(get_tree(), id, true), Vector2(132, 42), 14)
	replay.disabled = not (LevelDB.is_built(id) and LevelDB.is_unlocked(id))
	buttons.add_child(replay)
	_level_cards[id] = {"panel": panel, "button": button, "state": state, "drops": drops}
	return panel


func _refresh_level_cards(level: String) -> void:
	for id: String in _level_cards:
		var card: Dictionary = _level_cards[id]
		var button: Button = card.button
		var open := LevelDB.is_built(id) and LevelDB.is_unlocked(id)
		if id == level:
			button.text = tr("已选择") + " ✔"
		elif not LevelDB.is_built(id):
			button.text = tr("制作中")
		elif not LevelDB.is_unlocked(id):
			button.text = tr("未解锁：通关上一关")
		else:
			button.text = tr("选择")
		button.disabled = not open
		UiKit.toggle_button(button, id == level)
		var cleared := Save.cleared_levels.has(id)
		(card.state as Label).text = tr("已通关") if cleared else (tr("未通关") if open else tr("未解锁"))
		(card.state as Label).add_theme_color_override("font_color", UiKit.GOOD if cleared else UiKit.DIM)
		(card.panel as PanelContainer).add_theme_stylebox_override("panel",
			UiKit.panel(18, UiKit.GOLD if id == level else UiKit.IVORY))
		(card.panel as Control).modulate = Color.WHITE if open else Color(1, 1, 1, 0.5)
		(card.panel as Control).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if open else Control.CURSOR_ARROW
		var drops: VBoxContainer = card.drops
		for child in drops.get_children():
			child.queue_free()
		for set_id in GearDB.sets_of_level(id):
			var owned := GearDB.owned_count(set_id)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			drops.add_child(row)
			var icon := TextureRect.new()
			icon.texture = GearDB.set_icon(set_id)
			icon.custom_minimum_size = Vector2(24, 24)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			row.add_child(icon)
			row.add_child(UiKit.label(tr(GearDB.SETS[set_id].name), 14, UiKit.IVORY))
			row.add_child(UiKit.label(tr(GearDB.SETS[set_id].effect), 12, UiKit.DIM))
			row.add_child(UiKit.spacer())
			row.add_child(UiKit.label("%d / %d" % [owned, GearDB.SET_SIZE], 13, UiKit.GOLD_BRIGHT if owned >= GearDB.SET_SIZE else UiKit.DIM))


# ---------------------------------------------------------------- 永久强化

func _make_card(id: String) -> Control:
	var info: Dictionary = MetaDB.UPGRADES[id]
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # 两列平均铺满宽度
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 3)
	row.add_child(text)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	text.add_child(head)
	head.add_child(UiKit.label(tr(info.name), 18, Color.WHITE))
	var pips := UiKit.Pips.new()
	pips.total = info.max
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(pips)
	var level := UiKit.label("", 13, UiKit.DIM)
	head.add_child(level)
	text.add_child(UiKit.label(tr(info.desc), 13, UiKit.DIM))

	var button := UiKit.button("", _buy.bind(id), Vector2(120, 0), 15)
	row.add_child(button)
	_cards[id] = {"panel": panel, "pips": pips, "level": level, "button": button}
	return panel


func _buy(id: String) -> void:
	if Save.buy_meta(id):
		Audio.sfx("level_up", -6.0)
		var panel: Control = _cards[id].panel
		panel.modulate = Color(1.6, 1.4, 0.9)  # 购买成功时闪一下
		create_tween().tween_property(panel, "modulate", Color.WHITE, 0.4)
	_refresh()


func _refresh_meta_cards() -> void:
	for id: String in _cards:
		var info: Dictionary = MetaDB.UPGRADES[id]
		var lv := Save.meta_level(id)
		var maxed: bool = lv >= info.max
		var cost := MetaDB.cost(id, lv)
		var card: Dictionary = _cards[id]
		(card.pips as UiKit.Pips).filled = lv
		card.level.text = "%d / %d" % [lv, info.max]
		var button: Button = card.button
		button.text = tr("已满级") if maxed else tr("强化\n%d 点") % cost
		button.disabled = maxed or Save.reward_points < cost
		UiKit.tint_button(button, UiKit.GOLD)
		button.tooltip_text = "" if maxed or not button.disabled else tr("奖励点不够，还差 %d 点") % (cost - Save.reward_points)
		(card.panel as PanelContainer).add_theme_stylebox_override("panel", UiKit.panel(14, UiKit.GOLD if maxed else UiKit.IVORY))


# ---------------------------------------------------------------- 刷新

func _refresh() -> void:
	var selected := CharacterDB.selected()
	var selected_info: Dictionary = CharacterDB.ALL[selected]
	var level := LevelDB.selected()
	_subtitle.text = tr("篇章一 · 诸神黄昏")
	var loadout := tr(selected_info.name) + " · " + tr(SwordsmanLoadout.KITS[SwordsmanLoadout.valid(Save.swordsman_weapon)][0] if selected == "swordsman" else selected_info.weapon)
	if GearDB.active_set() != "":
		loadout += " · " + tr(GearDB.SETS[GearDB.active_set()].name)
	if _picking_level:
		_start_title.text = tr("进入 第 %d 关 · %s    [Enter]") % [LevelDB.ORDER.find(level) + 1, tr(LevelDB.NAMES[level])]
	else:
		_start_title.text = tr("开始游戏    [Enter]")
	_start_detail.text = loadout
	_refresh_level_cards(level)
	_refresh_character_page(selected)
	_refresh_meta_cards()
	_gear_dot.visible = not Save.gear_new.is_empty()

	_points_label.text = str(Save.reward_points)
	var s: Dictionary = Save.stats
	_stats_label.text = tr("轮回 %d 次　通关 %d 次　最久存活 %s　最快通关 %s　累计击杀 %d") % [
		s.runs, s.clears, UiKit.format_time(s.best_time), UiKit.format_time(s.best_clear_time) if s.best_clear_time > 0.0 else "—", s.total_kills]


func _confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = tr("重置存档")
	dialog.dialog_text = tr("确定要清空所有奖励点、永久强化、装备和战绩吗？此操作无法撤销。")
	dialog.ok_button_text = tr("清空")
	dialog.cancel_button_text = tr("取消")
	dialog.confirmed.connect(func() -> void:
		Save.reset()
		_gear.refresh()
		_refresh())
	add_child(dialog)
	dialog.popup_centered()


## 背景：深色棋盘格，方形的光点从下往上飘
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiKit.INK)
	var light := Color("1e2134")
	for y in ceili(size.y / CHECKER):
		for x in ceili(size.x / CHECKER):
			if (x + y) % 2 == 0:
				draw_rect(Rect2(x * CHECKER, y * CHECKER, CHECKER, CHECKER), light)
	for mote: Array in _motes:
		var t := fposmod(mote[1] + _time * mote[2], 1.0)
		var at := Vector2(mote[0] * size.x, size.y * (1.05 - t * 1.1)).snappedf(2.0)
		draw_rect(Rect2(at, Vector2(mote[3], mote[3])), Color(UiKit.GOLD, 0.35 * sin(t * PI)))
