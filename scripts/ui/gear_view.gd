class_name GearView
extends HBoxContainer
## 「装备」页：左边是纸娃娃（角色剪影 + 围着它摆的五个部位格和套装徽记），中间是行囊（武器 + 10 套防具），右边是选中装备的详情
## 操作：点格子看详情，双击直接穿上 / 卸下；点纸娃娃上的部位，行囊只显示这个部位
## 防具按掉落的关卡分组，一套一行；还没拿到的显示剪影。穿齐一套 4 件触发套装效果（GearDB / SetEffects）
## 武器栏目前只有剑士有得选（SwordsmanLoadout 的 11 把），其他角色显示自带的武器

signal changed  # 换了装备或武器，主神空间跟着刷新

const TILE := 64.0
const CHAR_DIR := "res://assets/sprites/characters/"
const DOLL_SIZE := Vector2(272, 344)
## 纸娃娃上各个格子的位置和大小：头盔、胸甲、护腿、鞋子从上到下排在身体中线上，武器在左手边，右手边是套装徽记
const DOLL_SLOTS := {
	"helm": Rect2(100, 0, 72, 72),
	"chest": Rect2(92, 80, 88, 100),
	"legs": Rect2(100, 188, 72, 72),
	"boots": Rect2(100, 268, 72, 72),
	"weapon": Rect2(6, 66, 72, 128),
	"set": Rect2(194, 66, 72, 128),
}
const FILTERS := ["all", "weapon", "helm", "chest", "legs", "boots"]

var _filter := "all"
var _selected := ""      # 选中的条目："weapon:<id>" 或装备 id
var _filter_buttons := {}
var _slot_rows := {}     # 部位（含 "set" 套装徽记）-> {button, icon, name}
var _silhouette: TextureRect
var _tiles := {}         # 条目 id -> 格子按钮
var _list: VBoxContainer
var _scroll: ScrollContainer
var _set_box: VBoxContainer
var _detail: VBoxContainer
var _detail_scroll: ScrollContainer
var _action: Button
var _action_set: Button
var _collected: Label


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	_build_worn()
	_build_bag()
	_build_detail()
	_selected = _default_selection()
	refresh()


## 换了角色之后调用：武器栏跟着角色变
func refresh() -> void:
	if _selected.begins_with("weapon:") and not _weapon_ids().has(_selected.trim_prefix("weapon:")):
		_selected = "weapon:" + _current_weapon()
	_refresh_worn()
	_rebuild_bag()
	_refresh_detail()


func show_weapons() -> void:
	_filter = "weapon"
	_selected = "weapon:" + _current_weapon()
	refresh()


# ---------------------------------------------------------------- 左：穿戴

func _build_worn() -> void:
	var panel := UiKit.framed(12)
	panel.custom_minimum_size = Vector2(304, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UiKit.heading(tr("当前穿戴")))

	var doll := Control.new()
	doll.custom_minimum_size = DOLL_SIZE + Vector2(0, 8)
	doll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(doll)
	var stone := Panel.new()  # 纸娃娃的底板：凹下去的一块，剪影和格子都在它上面
	stone.position = Vector2(-4, -6)
	stone.size = DOLL_SIZE + Vector2(8, 12)
	stone.add_theme_stylebox_override("panel", UiKit.cell(UiKit.LINE, UiKit.BUTTON, 0))
	stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doll.add_child(stone)
	_silhouette = TextureRect.new()  # 角色的剪影垫在格子后面
	_silhouette.position = Vector2(-24, 4)
	_silhouette.size = Vector2(320, 320)
	_silhouette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_silhouette.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_silhouette.modulate = Color(0, 0, 0, 0.6)
	_silhouette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doll.add_child(_silhouette)
	for slot: String in DOLL_SLOTS:
		var rect: Rect2 = DOLL_SLOTS[slot]
		var button := Button.new()
		button.position = rect.position
		button.size = rect.size
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_slot_pressed.bind(slot))
		doll.add_child(button)
		var caption := UiKit.label(tr("套装") if slot == "set" else tr(GearDB.SLOT_NAMES[slot]), 12, UiKit.FAINT, HORIZONTAL_ALIGNMENT_CENTER)
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(caption)
		var icon := _icon_rect(0.0)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		button.add_child(icon)
		_slot_rows[slot] = {"button": button, "icon": icon, "name": caption}

	box.add_child(UiKit.spacer(false))
	box.add_child(UiKit.heading(tr("套装效果")))
	_set_box = VBoxContainer.new()
	_set_box.add_theme_constant_override("separation", 4)
	box.add_child(_set_box)
	_collected = UiKit.label("", 12, UiKit.DIM)
	box.add_child(_collected)


func _refresh_worn() -> void:
	var character := CharacterDB.selected()
	var strip: Texture2D = load(CHAR_DIR + character + "_idle.png") if ResourceLoader.exists(CHAR_DIR + character + "_idle.png") else null
	if strip:  # 待机动作的第一帧（帧条是一排正方形）
		var frame := AtlasTexture.new()
		frame.atlas = strip
		frame.region = Rect2(0, 0, strip.get_height(), strip.get_height())
		_silhouette.texture = frame
	var active := GearDB.active_set()
	var closest := active  # 没凑齐时，徽记显示身上穿得最多的那一套
	for set_id: String in GearDB.SETS:
		if GearDB.worn_count(set_id) > (GearDB.worn_count(closest) if closest != "" else 0):
			closest = set_id

	for slot: String in _slot_rows:
		var row: Dictionary = _slot_rows[slot]
		var caption: Label = row.name
		var icon: TextureRect = row.icon
		var button: Button = row.button
		var selected := false
		var filled := true
		if slot == "weapon":
			var weapon := _current_weapon()
			icon.texture = _weapon_icon(weapon)
			filled = icon.texture != null
			caption.text = tr(GearDB.SLOT_NAMES[slot]) if filled else _weapon_name(weapon)
			button.tooltip_text = _weapon_name(weapon)
			selected = _selected == "weapon:" + weapon
		elif slot == "set":
			icon.texture = GearDB.set_icon(closest) if closest != "" else null
			icon.modulate = Color.WHITE if active != "" else Color(0.55, 0.55, 0.6)
			filled = closest != ""
			caption.text = tr("套装") if closest == "" else "%d / %d" % [GearDB.worn_count(closest), GearDB.SET_SIZE]
			caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if closest == "" else VERTICAL_ALIGNMENT_BOTTOM
			caption.add_theme_color_override("font_color", UiKit.GOLD if active != "" else UiKit.DIM)
			button.tooltip_text = tr("%s：%s") % [tr(GearDB.SETS[closest].effect), tr(GearDB.SETS[closest].rule)] if closest != "" else tr("穿齐同一套的 4 件防具，触发套装效果。")
			selected = active != ""
		else:
			var id: String = Save.equipped.get(slot, "")
			icon.texture = GearDB.icon(id) if id != "" else null
			filled = id != ""
			button.tooltip_text = tr(GearDB.piece(id).name) if filled else tr("%s：空") % tr(GearDB.SLOT_NAMES[slot])
			selected = filled and _selected == id
		if slot != "set":
			caption.visible = not filled or (slot == "weapon" and icon.texture == null)
		var border := UiKit.GOLD if selected else (UiKit.IVORY if filled else UiKit.LINE)
		var bg := Color(UiKit.SURFACE_RAISED, 0.92)
		button.add_theme_stylebox_override("normal", UiKit.cell(border, bg))
		button.add_theme_stylebox_override("pressed", UiKit.cell(UiKit.GOLD, bg))
		button.add_theme_stylebox_override("hover", UiKit.cell(UiKit.GOLD, Color("333c57")))

	for child in _set_box.get_children():
		child.queue_free()
	if active != "":
		var info: Dictionary = GearDB.SETS[active]
		_set_box.add_child(_set_line(active, tr("%s · 已激活") % tr(info.name), UiKit.GOLD))
		_set_box.add_child(UiKit.label(tr(info.effect), 13, UiKit.IVORY))  # 规则太长，放在右边的详情里
		return
	if closest != "":
		_set_box.add_child(_set_line(closest, "%s  %d / %d" % [tr(GearDB.SETS[closest].name), GearDB.worn_count(closest), GearDB.SET_SIZE], UiKit.DIM))
	_set_box.add_child(UiKit.body(tr("穿齐同一套的 4 件防具，触发套装效果。") if closest != "" else tr("还没有穿任何防具。击败 Boss 会掉落所在关卡的套装部件。"), 12, UiKit.DIM))


func _set_line(set_id: String, text: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := _icon_rect(24.0)
	icon.texture = GearDB.set_icon(set_id)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	row.add_child(UiKit.label(text, 15, color))
	return row


func _on_slot_pressed(slot: String) -> void:
	if slot == "set":  # 套装徽记：回到全部，选中这一套里的一件
		var active := GearDB.active_set()
		_filter = "all"
		for piece_slot: String in GearDB.SLOTS:
			var id: String = Save.equipped.get(piece_slot, "")
			if id != "" and (active == "" or GearDB.set_of(id) == active):
				_selected = id
				break
		refresh()
		return
	_filter = slot
	if slot == "weapon":
		_selected = "weapon:" + _current_weapon()
	elif Save.equipped.has(slot):
		_selected = Save.equipped[slot]
	else:
		_selected = ""
	refresh()
	if _selected == "":  # 这个部位没穿：选中第一件已经有的
		for id: String in _tiles:
			if _owned(id):
				_select(id)
				break


# ---------------------------------------------------------------- 中：行囊

func _build_bag() -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	column.add_child(bar)
	for filter: String in FILTERS:
		var button := UiKit.button(tr("全部") if filter == "all" else tr(GearDB.SLOT_NAMES[filter]), _set_filter.bind(filter), Vector2(64, 36), 14)
		bar.add_child(button)
		_filter_buttons[filter] = button
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)


func _set_filter(filter: String) -> void:
	_filter = filter
	_scroll.scroll_vertical = 0
	_rebuild_bag()


func _rebuild_bag() -> void:
	for filter: String in _filter_buttons:
		UiKit.toggle_button(_filter_buttons[filter], filter == _filter)
	_collected.text = tr("防具收集  %d / %d") % [Save.gear.size(), GearDB.SETS.size() * GearDB.SET_SIZE]
	for child in _list.get_children():
		child.queue_free()
	_tiles.clear()

	if _filter == "all" or _filter == "weapon":
		_list.add_child(UiKit.heading(tr("武器 · %s") % tr(CharacterDB.ALL[CharacterDB.selected()].name)))
		var flow := _flow()
		_list.add_child(flow)
		for weapon in _weapon_ids():
			flow.add_child(_make_tile("weapon:" + weapon))
		if _weapon_ids().size() <= 1:
			_list.add_child(UiKit.body(tr("这位化身目前只有自带的武器。"), 12, UiKit.FAINT))
	if _filter == "weapon":
		return

	for i in LevelDB.ORDER.size():
		var level: String = LevelDB.ORDER[i]
		_list.add_child(UiKit.heading(tr("第 %d 关 · %s") % [i + 1, tr(LevelDB.NAMES[level])]))
		if _filter == "all":
			for set_id in GearDB.sets_of_level(level):
				_list.add_child(_make_set_row(set_id))
		else:
			var flow := _flow()
			_list.add_child(flow)
			for set_id in GearDB.sets_of_level(level):
				flow.add_child(_make_tile(GearDB.item_id(set_id, _filter)))


## 一套一行：套装图标和名字、收集进度，后面是 4 件
func _make_set_row(set_id: String) -> Control:
	var info: Dictionary = GearDB.SETS[set_id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var head := VBoxContainer.new()
	head.custom_minimum_size = Vector2(196, 0)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 2)
	row.add_child(head)
	var owned := GearDB.owned_count(set_id)
	var active := GearDB.active_set() == set_id
	head.add_child(_set_line(set_id, tr(info.name), UiKit.GOLD if active else (UiKit.IVORY if owned > 0 else UiKit.DIM)))
	var status := tr("%s · 已激活") % tr(info.effect) if active else tr("%s · 已有 %d / %d") % [tr(info.effect), owned, GearDB.SET_SIZE]
	var status_label := UiKit.label(status, 12, UiKit.GOLD if active else UiKit.DIM)
	status_label.clip_text = true
	head.add_child(status_label)
	for slot: String in GearDB.SLOTS:
		row.add_child(_make_tile(GearDB.item_id(set_id, slot)))
	return row


func _flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	return flow


func _make_tile(id: String) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(TILE, TILE)
	tile.focus_mode = Control.FOCUS_NONE
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.pressed.connect(_select.bind(id))
	tile.gui_input.connect(func(event: InputEvent) -> void:  # 双击：直接穿上 / 卸下
		var click := event as InputEventMouseButton
		if click and click.pressed and click.double_click and click.button_index == MOUSE_BUTTON_LEFT and _owned(id):
			_selected = id
			if not (id.begins_with("weapon:") and _worn(id)):
				_on_action())
	var owned := _owned(id)
	var icon := _icon_rect(0.0)
	icon.texture = _icon(id)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	icon.modulate = Color.WHITE if owned else Color(0, 0, 0, 0.75)
	tile.add_child(icon)
	tile.tooltip_text = tr("%s（双击穿上 / 卸下）") % _name(id) if owned else tr("%s（未获得）") % _name(id)
	if icon.texture == null:  # 没有图标的武器（枪手、刺客、法师自带的）：写名字
		tile.text = _name(id)
		tile.custom_minimum_size = Vector2(TILE * 2.0, TILE)
	if _worn(id):
		var badge := UiKit.label(tr("穿"), 11, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
		var plate := PanelContainer.new()
		plate.add_theme_stylebox_override("panel", UiKit.box(UiKit.GOLD, Color(0, 0, 0, 0), 0, 4, 0))
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(badge)
		plate.position = Vector2(UiKit.EDGE, UiKit.EDGE)
		tile.add_child(plate)
	elif Save.gear_new.has(id):
		var dot := UiKit.Diamond.new()
		dot.color = UiKit.BAD
		dot.square = true
		dot.position = Vector2(TILE - 16.0, 5.0)
		tile.add_child(dot)
	_tiles[id] = tile
	_style_tile(id)
	return tile


func _style_tile(id: String) -> void:
	var tile: Button = _tiles.get(id)
	if tile == null:
		return
	var selected := id == _selected
	var border := UiKit.IVORY if selected else (UiKit.GOLD if _worn(id) else (UiKit.LINE if _owned(id) else Color("333c57")))
	var bg := UiKit.SURFACE if selected else UiKit.SURFACE_RAISED
	tile.add_theme_stylebox_override("normal", UiKit.cell(border, bg))
	tile.add_theme_stylebox_override("pressed", UiKit.cell(border, bg))
	tile.add_theme_stylebox_override("hover", UiKit.cell(UiKit.GOLD, UiKit.SURFACE))


func _select(id: String) -> void:
	var previous := _selected
	_selected = id
	if Save.gear_new.has(id):  # 看过了，去掉「新」标记
		Save.mark_gear_seen(id)
		var tile: Button = _tiles.get(id)
		for child in tile.get_children():
			if child is UiKit.Diamond:
				child.queue_free()
		changed.emit()
	_style_tile(previous)
	_style_tile(id)
	_refresh_worn()
	_refresh_detail()


# ---------------------------------------------------------------- 右：详情

func _build_detail() -> void:
	var panel := UiKit.framed(16)
	panel.custom_minimum_size = Vector2(372, 0)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	_detail_scroll.add_child(_detail)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	_action = UiKit.primary("", _on_action, Vector2(0, 44))
	_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_action)
	_action_set = UiKit.button(tr("穿上整套"), _on_action_set, Vector2(110, 44), 15)
	buttons.add_child(_action_set)


func _refresh_detail() -> void:
	for child in _detail.get_children():
		child.queue_free()
	_detail_scroll.scroll_vertical = 0
	_action_set.visible = false
	if _selected == "":
		_detail.add_child(UiKit.body(tr("选一件装备查看详情。"), 14, UiKit.DIM))
		_action.visible = false
		return
	_action.visible = true
	var owned := _owned(_selected)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	_detail.add_child(head)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiKit.cell(UiKit.LINE, UiKit.SURFACE_RAISED, 8))
	head.add_child(plate)
	var icon := _icon_rect(80.0)
	icon.texture = _icon(_selected)
	icon.modulate = Color.WHITE if owned else Color(0, 0, 0, 0.75)
	plate.add_child(icon)
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 2)
	head.add_child(title)
	var name_label := UiKit.label(_name(_selected), 24, UiKit.GOLD if owned else UiKit.DIM)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_child(name_label)

	if _selected.begins_with("weapon:"):
		var weapon := _selected.trim_prefix("weapon:")
		title.add_child(UiKit.label(tr("武器 · %s") % tr(CharacterDB.ALL[CharacterDB.selected()].name), 13, UiKit.DIM))
		_detail.add_child(UiKit.rule())
		_detail.add_child(UiKit.body(_weapon_desc(weapon), 15))
		var current := weapon == _current_weapon()
		_action.text = tr("使用中") if current else tr("使用这把武器")
		_action.disabled = current
		return

	var set_id := GearDB.set_of(_selected)
	var info: Dictionary = GearDB.SETS[set_id]
	var piece := GearDB.piece(_selected)
	var level_index := LevelDB.ORDER.find(info.level) + 1
	title.add_child(UiKit.label("%s · %s" % [tr(GearDB.SLOT_NAMES[GearDB.slot_of(_selected)]), tr(info.name)], 13, UiKit.DIM))
	title.add_child(UiKit.label(tr("第 %d 关 · %s 掉落") % [level_index, tr(LevelDB.NAMES[info.level])], 12, UiKit.DIM))
	_detail.add_child(UiKit.rule())
	_detail.add_child(UiKit.body(tr(piece.desc), 13, UiKit.IVORY))

	_detail.add_child(UiKit.heading(tr("套装效果 · %s") % tr(info.effect)))
	var pieces := HBoxContainer.new()
	pieces.add_theme_constant_override("separation", 6)
	_detail.add_child(pieces)
	for slot: String in GearDB.SLOTS:
		var id := GearDB.item_id(set_id, slot)
		var worn := _worn(id)
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiKit.cell(UiKit.GOLD if worn else UiKit.LINE))
		chip.tooltip_text = tr(GearDB.SETS[set_id].pieces[slot].name)
		var chip_icon := _icon_rect(32.0)
		chip_icon.texture = GearDB.icon(id)
		chip_icon.modulate = Color.WHITE if Save.gear.has(id) else Color(0, 0, 0, 0.75)
		chip.add_child(chip_icon)
		pieces.add_child(chip)
	var count := UiKit.label(tr("已穿 %d / %d") % [GearDB.worn_count(set_id), GearDB.SET_SIZE], 13,
		UiKit.GOLD if GearDB.active_set() == set_id else UiKit.DIM)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pieces.add_child(count)
	_detail.add_child(UiKit.rich(tr(info.effect_text), 14))
	_detail.add_child(UiKit.body(tr("规则：%s") % tr(info.rule), 12, UiKit.DIM))
	_detail.add_child(UiKit.heading(tr("传说"), UiKit.DIM))
	_detail.add_child(UiKit.rich(tr(info.lore), 13, UiKit.DIM))

	if not owned:
		_action.text = tr("未获得 · 击败第 %d 关的 Boss 掉落") % level_index
		_action.disabled = true
	else:
		_action.text = tr("卸下") if _worn(_selected) else tr("穿上")
		_action.disabled = false
	var owned_in_set := GearDB.owned_count(set_id)
	_action_set.visible = owned_in_set > 1 and GearDB.worn_count(set_id) < owned_in_set


func _on_action() -> void:
	if _selected.begins_with("weapon:"):
		Save.select_swordsman_weapon(_selected.trim_prefix("weapon:"))
	elif _worn(_selected):
		Save.unequip(GearDB.slot_of(_selected))
	else:
		Save.equip(_selected)
	Audio.sfx("ui_open")
	refresh()
	changed.emit()


func _on_action_set() -> void:
	Save.equip_set(GearDB.set_of(_selected))
	Audio.sfx("ui_open")
	refresh()
	changed.emit()


# ---------------------------------------------------------------- 条目

func _default_selection() -> String:
	for id: String in Save.gear_new:  # 有新装备：先看新的
		return id
	for slot: String in GearDB.SLOTS:
		if Save.equipped.has(slot):
			return Save.equipped[slot]
	return "weapon:" + _current_weapon()


func _weapon_ids() -> Array:
	return SwordsmanLoadout.KITS.keys() if CharacterDB.selected() == "swordsman" else [CharacterDB.selected()]


func _current_weapon() -> String:
	return SwordsmanLoadout.valid(Save.swordsman_weapon) if CharacterDB.selected() == "swordsman" else CharacterDB.selected()


func _weapon_name(weapon: String) -> String:
	return tr(SwordsmanLoadout.KITS[weapon][0]) if SwordsmanLoadout.KITS.has(weapon) else tr(CharacterDB.ALL[weapon].weapon)


func _weapon_desc(weapon: String) -> String:
	return tr(SwordsmanLoadout.KITS[weapon][1]) if SwordsmanLoadout.KITS.has(weapon) else tr(CharacterDB.ALL[weapon].weapon_desc)


func _weapon_icon(weapon: String) -> Texture2D:
	return SwordsmanLoadout.icon(weapon) if SwordsmanLoadout.KITS.has(weapon) else null


func _name(id: String) -> String:
	return _weapon_name(id.trim_prefix("weapon:")) if id.begins_with("weapon:") else tr(GearDB.piece(id).name)


func _icon(id: String) -> Texture2D:
	return _weapon_icon(id.trim_prefix("weapon:")) if id.begins_with("weapon:") else GearDB.icon(id)


func _owned(id: String) -> bool:
	return id.begins_with("weapon:") or Save.gear.has(id)


func _worn(id: String) -> bool:
	if id.begins_with("weapon:"):
		return id.trim_prefix("weapon:") == _current_weapon()
	return Save.equipped.get(GearDB.slot_of(id), "") == id


## 像素图标：最近邻放大，保持比例。edge 是正方形边长，0 表示由调用的地方自己排版
func _icon_rect(edge: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.custom_minimum_size = Vector2(edge, edge)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
