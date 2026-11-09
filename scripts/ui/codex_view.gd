class_name CodexView
extends HBoxContainer
## 图鉴界面：左边选分类，中间是条目格子，右边是选中条目的详情
## 主神空间的「图鉴」分页和标题画面共用。没遇到过的条目显示剪影和「？？？」

const GOLD := Color(1.0, 0.85, 0.4)
const DIM := Color(0.7, 0.73, 0.8)
const TILE := Vector2(88, 88)
const WIDE_TILE := Vector2(176, 46)
const SPRITE_HEIGHT := 150.0
const UNKNOWN := "？？？"

var _category := "enemies"
var _category_buttons := {}
var _list: VBoxContainer
var _scroll: ScrollContainer
var _progress: Label
var _selected: Button
var _stage: Control
var _sprite_root: Node2D
var _name: Label
var _subtitle: Label
var _lore: Label
var _extra: Label
var _count: Label


func _ready() -> void:
	add_theme_constant_override("separation", 16)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(180, 0)
	left.add_theme_constant_override("separation", 8)
	add_child(left)
	for category: String in CodexDB.CATEGORIES:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 44)
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_show_category.bind(category))
		left.add_child(button)
		_category_buttons[category] = button
	_progress = _label("", 14, DIM)
	left.add_child(_progress)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)

	var detail := PanelContainer.new()
	detail.custom_minimum_size = Vector2(440, 0)
	detail.add_theme_stylebox_override("panel", _style(Color(0.08, 0.09, 0.13), Color(0.3, 0.33, 0.42), 2, 16))
	add_child(detail)
	var detail_scroll := ScrollContainer.new()  # 文字长时在面板里滚动，不把整个界面撑高
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail.add_child(detail_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	detail_scroll.add_child(box)
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(0, 180)
	_stage.clip_contents = true
	_sprite_root = Node2D.new()
	_stage.add_child(_sprite_root)
	_stage.resized.connect(func() -> void: _sprite_root.position = _stage.size * 0.5)
	box.add_child(_stage)
	_name = _label("", 24, GOLD)
	_subtitle = _label("", 14, DIM)
	_lore = _label("", 15, Color(0.88, 0.9, 0.95))
	_extra = _label("", 14, Color(0.6, 0.8, 1.0))
	_count = _label("", 14, GOLD)
	for label in [_name, _subtitle, _count, _lore, _extra]:
		box.add_child(label)
	for label in [_lore, _extra]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(390, 0)

	_show_category(_category)


func _show_category(category: String) -> void:
	_category = category
	var found_all := 0
	var total_all := 0
	for key: String in CodexDB.CATEGORIES:
		var found := 0
		var total := 0
		for section: Dictionary in _sections(key):
			for item: Dictionary in section.items:
				total += 1
				if item.count >= 0:
					found += 1
		found_all += found
		total_all += total
		var button: Button = _category_buttons[key]
		button.text = "%s   %d / %d" % [tr(CodexDB.NAMES[key]), found, total]
		var border := GOLD if key == category else Color(0.3, 0.33, 0.42)
		for state in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, _style(Color(0.08, 0.09, 0.13), border, 2, 12))
	_progress.text = tr("收集进度  %d%%") % roundi(100.0 * found_all / maxf(1.0, total_all))

	for child in _list.get_children():
		child.queue_free()
	_selected = null
	var first: Button
	for section: Dictionary in _sections(category):
		_list.add_child(_label(section.title, 15, DIM))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		_list.add_child(flow)
		for item: Dictionary in section.items:
			var tile := _make_tile(item)
			flow.add_child(tile)
			if first == null:
				first = tile
	_scroll.scroll_vertical = 0
	if first:
		first.pressed.emit()


func _make_tile(item: Dictionary) -> Button:
	var known: bool = item.count >= 0
	var tile := Button.new()
	tile.focus_mode = Control.FOCUS_NONE
	if item.sprite != "" and ResourceLoader.exists(item.sprite + ".png"):
		tile.custom_minimum_size = TILE
		var image := TextureRect.new()
		image.texture = load(item.sprite + ".png")
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.offset_left = 6
		image.offset_top = 6
		image.offset_right = -6
		image.offset_bottom = -6
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.modulate = Color.WHITE if known else Color(0, 0, 0, 0.8)
		tile.add_child(image)
	else:
		tile.custom_minimum_size = WIDE_TILE
		tile.text = item.name if known else UNKNOWN
		tile.clip_text = true
	tile.pressed.connect(_select.bind(tile, item))
	_set_tile_style(tile, item, false)
	return tile


func _set_tile_style(tile: Button, item: Dictionary, selected: bool) -> void:
	var border: Color = GOLD if selected else (Color(item.color, 0.8) if item.count >= 0 else Color(0.22, 0.24, 0.3))
	for state in ["normal", "hover", "pressed"]:
		tile.add_theme_stylebox_override(state, _style(Color(0.08, 0.09, 0.13), border, 3 if selected else 2, 6))


func _select(tile: Button, item: Dictionary) -> void:
	if is_instance_valid(_selected):
		_set_tile_style(_selected, _selected.get_meta("item"), false)
	tile.set_meta("item", item)
	_selected = tile
	_set_tile_style(tile, item, true)

	var known: bool = item.count >= 0
	for child in _sprite_root.get_children():
		child.queue_free()
	var sprite: Node2D = SpriteVisual.create(item.sprite, SPRITE_HEIGHT) if item.sprite != "" else null
	if sprite:
		_fit_stage(sprite)
		sprite.modulate = Color.WHITE if known else Color(0, 0, 0, 0.85)
		_sprite_root.add_child(sprite)
	_stage.visible = sprite != null
	_name.text = item.name if known else UNKNOWN
	_subtitle.text = item.subtitle
	_lore.text = item.lore if known else tr(item.unknown)
	_extra.text = item.extra if known else ""
	_extra.visible = _extra.text != ""
	_count.text = _count_text(item.count)


## 苏尔特这种 320 高的动作图放不进展示台：按整数分之一缩小（脚底轴心不变）
func _fit_stage(sprite: Node2D) -> void:
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, 0) if sprite is AnimatedSprite2D else sprite.texture
	var tex_height := float(texture.get_height())
	if tex_height <= SPRITE_HEIGHT * 1.5:
		return
	sprite.scale = Vector2.ONE / roundf(tex_height / SPRITE_HEIGHT)
	sprite.position = Vector2(0, tex_height * 0.5 * sprite.scale.y)


func _count_text(count: int) -> String:
	if count < 0:
		return ""
	match _category:
		"enemies":
			return tr("击杀 %d") % count
		"bosses":
			return tr("击败 %d 次") % count if count > 0 else tr("遭遇过，还没有击败")
	return tr("选择过 %d 次") % count


## 一个分类的所有条目，按关卡（强化按角色、神明）分组：[{title, items: [{name, subtitle, lore, extra, sprite, color, count, unknown}]}]
func _sections(category: String) -> Array:
	var sections := []
	match category:
		"enemies":
			for level: String in CodexDB.ENEMIES:
				var items := []
				for row: Array in CodexDB.ENEMIES[level]:
					var data: Dictionary = EnemyDB.ALL[row[0]]
					items.append(_item(category, row[0], tr(data.name), tr(LevelDB.PLACES[level]), tr(row[1]), tr(row[2]),
						"res://assets/sprites/enemies/" + row[0], data.color, "还没有遇到过。"))
				sections.append({"title": tr(LevelDB.NAMES[level]), "items": items})
		"bosses":
			for level: String in CodexDB.BOSSES:
				var items := []
				for row: Array in CodexDB.BOSSES[level]:
					items.append(_item(category, row[0], tr(row[1]), tr(row[2]), tr(row[3]), tr(row[4]),
						"res://assets/sprites/bosses/" + (row[5] if row.size() > 5 else row[0]), Color(1.0, 0.45, 0.4), "还没有遇到过。"))
				sections.append({"title": tr(LevelDB.NAMES[level]), "items": items})
		"upgrades":
			for id: String in CharacterDB.ALL:
				var weapon := tr("基础武器 · %s") % tr(CharacterDB.ALL[id].weapon)
				sections.append({"title": "%s（%s）" % [weapon, tr(CharacterDB.ALL[id].name)],
					"items": _upgrade_items(func(info: Dictionary) -> bool: return info.kind == "weapon" and info.character == id, weapon, CharacterDB.ALL[id].color)})
			for god_id: String in Gods.ALL:
				var god: Dictionary = Gods.ALL[god_id]
				var title := tr("神明 · %s · %s") % [tr(god.name), tr(god.title)]
				sections.append({"title": title, "items": _upgrade_items(func(info: Dictionary) -> bool: return info.get("god", "") == god_id, title, god.color)})
			sections.append({"title": tr("通用属性"), "items": _upgrade_items(func(info: Dictionary) -> bool: return info.kind == "stat", tr("通用属性"), DIM)})
			var fusions := []
			for fusion: String in Gods.FUSIONS:
				var info := UpgradeDB.get_info("fusion_" + fusion)
				var pair := "%s + %s" % [tr(Gods.ALL[info.gods[0]].name), tr(Gods.ALL[info.gods[1]].name)]
				fusions.append(_item("upgrades", "fusion_" + fusion, tr(info.name), tr("融合技 · ") + pair, tr(info.desc),
					tr("两位神都觉醒后出现"), "", Gods.ALL[info.gods[0]].color, "还没有获得过。"))
			sections.append({"title": tr("融合技"), "items": fusions})
	return sections


func _upgrade_items(belongs: Callable, subtitle: String, color: Color) -> Array:
	var items := []
	for id: String in UpgradeDB.UPGRADES:
		var info := UpgradeDB.get_info(id)
		if not belongs.call(info):
			continue
		var extra: String
		match info.kind:
			"skill":
				extra = tr("神术：选择这位神时获得")
			"path":
				extra = tr("质变：信仰达到 %d 时三选一") % UpgradeDB.FAITH_PATH
			"awaken":
				extra = tr("神之觉醒：选了「%s」后，信仰达到 %d 时出现") % [tr(UpgradeDB.UPGRADES[info.path].name), UpgradeDB.FAITH_AWAKEN]
			_:
				extra = tr("最多选择 %d 次") % info.max
				if info.has("values"):
					var values: Array[String] = []
					for v: float in info.values:
						values.append(str(int(v)) if is_equal_approx(v, roundf(v)) else str(v))
					extra += tr("　普通 / 稀有 / 史诗 / 传说：%s") % " / ".join(values)
		items.append(_item("upgrades", id, tr(info.name), subtitle, UpgradeDB.describe(id, 0), extra, "", color, "还没有获得过。"))
	return items


func _item(category: String, id: String, item_name: String, subtitle: String, lore: String, extra: String,
		sprite: String, color: Color, unknown: String) -> Dictionary:
	return {"name": item_name, "subtitle": subtitle, "lore": lore, "extra": extra, "sprite": sprite, "color": color,
		"count": Save.codex_count(category, id), "unknown": unknown}


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	return label


func _style(bg: Color, border: Color, width: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(padding)
	return style
