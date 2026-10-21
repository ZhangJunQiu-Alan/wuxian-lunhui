class_name LevelUpPanel
extends CanvasLayer
## 升级四选一界面：显示卡牌，鼠标点击或按 1/2/3/4 选择
## 卡面上半部分是插画（神明卡是神明的画像），下半部分是文字；边框颜色和标签表示稀有度
## 同一个面板也用来选神、选质变、觉醒和融合技（见 game.gd 的 _pending_rewards）

signal chosen(offer: Dictionary)
signal reroll_requested

const CARD_SIZE := Vector2(260, 450)
const ART_HEIGHT := 205.0  # 插画上半部分不被文字盖住的高度
const ART_DIR := "res://assets/sprites/cards/"  # 卡面插画：<神明 id>.png、<神明 id>_awaken.png、<角色 id>.png（基础武器）、general.png（通用属性）；质变、觉醒、融合技有 <卡牌 id>.png 时优先用它
const NEUTRAL_COLOR := Color(0.75, 0.78, 0.85)
const FAITH_COLOR := Color(0.25, 0.9, 0.72)

var _title: Label
var _cards: HBoxContainer
var _offers: Array[Dictionary] = []
var _reroll: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 游戏暂停时也要能操作
	layer = 10
	visible = false

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	center.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	box.add_child(_title)

	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 24)
	box.add_child(_cards)

	_reroll = Button.new()
	_reroll.focus_mode = Control.FOCUS_NONE
	_reroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll.custom_minimum_size = Vector2(220, 40)
	_reroll.pressed.connect(func() -> void: reroll_requested.emit())
	box.add_child(_reroll)

	var hint := Label.new()
	hint.text = tr("点击卡牌或按数字键选择")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.5)
	box.add_child(hint)


## entry 是 game.gd 里的一次奖励：kind = level / god / path / awaken / fusion
func open(offers: Array[Dictionary], player: Player, entry: Dictionary) -> void:
	_offers = offers
	_title.text = _title_for(entry, player)
	_reroll.visible = player.rerolls > 0 and ["level", "god"].has(entry.kind)
	_reroll.text = tr("重抽选项（剩余 %d 次）  [R]") % player.rerolls
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for i in offers.size():
		_cards.add_child(_make_card(i, offers[i], player))
	visible = true


func _title_for(entry: Dictionary, player: Player) -> String:
	match entry.kind:
		"god":
			return tr("选择你的第一位神") if player.faith.is_empty() else tr("等级 %d：选择第 %d 位神") % [player.level, player.faith.size() + 1]
		"path":
			return tr("%s的信仰达到 %d：选择一条道路") % [tr(Gods.ALL[entry.god].name), UpgradeDB.FAITH_PATH]
		"awaken":
			return tr("%s的信仰达到 %d：神之觉醒") % [tr(Gods.ALL[entry.god].name), UpgradeDB.FAITH_AWAKEN]
		"fusion":
			return tr("两位神同时觉醒：融合技")
	var title: String = entry.get("title", "")
	return title if title != "" else tr("升级！等级 %d") % player.level


func choose(index: int) -> void:
	if not visible or index >= _offers.size():
		return
	visible = false
	Audio.sfx("card_pick")
	chosen.emit(_offers[index])


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_4:
		choose(key.keycode - KEY_1)
		get_viewport().set_input_as_handled()
	elif key and key.pressed and not key.echo and key.keycode == KEY_R and _reroll.visible:
		reroll_requested.emit()
		get_viewport().set_input_as_handled()


func _make_card(index: int, offer: Dictionary, player: Player) -> Button:
	var id: String = offer.id
	var rarity: int = offer.rarity
	var info := UpgradeDB.get_info(id)
	var is_awaken: bool = info.kind == "awaken" or info.kind == "fusion"
	var color := NEUTRAL_COLOR
	var tag := tr("通用属性")
	var art := ART_DIR + "general.png"
	var art2 := ""  # 融合技：右半边画第二位神
	if info.has("god"):
		var god: Dictionary = Gods.ALL[info.god]
		color = god.color
		art = ART_DIR + info.god + ".png"
		match info.kind:
			"skill":
				tag = tr("神明 · %s · %s") % [tr(god.name), tr(god.title)]
			"boon":
				tag = tr("%s · 强化") % tr(god.name)
			"path":
				tag = tr("%s · 质变") % tr(god.name)
			"awaken":
				tag = tr("%s · 觉醒") % tr(god.name)
				if ResourceLoader.exists(ART_DIR + info.god + "_awaken.png"):
					art = ART_DIR + info.god + "_awaken.png"
			"fusion":
				tag = tr("融合技 · %s + %s") % [tr(god.name), tr(Gods.ALL[info.gods[1]].name)]
				art2 = ART_DIR + info.gods[1] + ".png"
	elif info.kind == "weapon":
		color = Color(0.85, 0.92, 1.0)
		tag = tr("基础武器 · ") + tr(CharacterDB.ALL[player.character_id].weapon)
		art = ART_DIR + player.character_id + ".png"
	if info.kind in ["path", "awaken", "fusion"] and ResourceLoader.exists(ART_DIR + id + ".png"):  # 有专属插画就用它
		art = ART_DIR + id + ".png"
		art2 = ""
	var edge := color
	if info.kind == "skill":
		edge = FAITH_COLOR
	elif rarity >= 0:
		edge = UpgradeDB.RARITY_COLORS[rarity]

	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed"]:
		card.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	card.set_meta("silent", true)
	card.pressed.connect(choose.bind(index))

	# 插画铺满整张卡，圆角外的部分被卡底裁掉
	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", _card_style(color, 0.12, 0))
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)
	var picture := _card_art(art, info, color)
	if art2 != "":  # 融合技：两位神的画像左右各一半
		picture = _split_art(picture, _card_art(art2, info, Gods.ALL[info.gods[1]].color))
	picture.modulate = Color(0.8, 0.8, 0.8)
	frame.add_child(picture)
	var shade := TextureRect.new()  # 下半部分压暗，文字写在上面
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.52, 1.0])
	var bg := Color(0.06, 0.07, 0.1)
	gradient.colors = PackedColorArray([Color(bg, 0.0), Color(bg, 0.0), Color(bg, 0.92), Color(bg, 0.97)])
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	fade.fill_from = Vector2(0, 0)
	fade.fill_to = Vector2(0, 1)
	shade.texture = fade
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(shade)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 18
	box.offset_right = -18
	box.offset_top = ART_HEIGHT
	box.offset_bottom = -18
	box.add_theme_constant_override("separation", 6)
	box.minimum_size_changed.connect(func() -> void:
		box.offset_top = minf(ART_HEIGHT, CARD_SIZE.y - 18.0 - box.get_combined_minimum_size().y))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var number := Label.new()  # 左上角的按键提示
	number.text = str(index + 1)
	number.position = Vector2(14, 8)
	number.add_theme_font_size_override("font_size", 22)
	number.add_theme_constant_override("outline_size", 6)
	number.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	number.modulate = edge
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(number)

	_add_line(box, tag + ("" if rarity < 0 else "  ·  " + tr(UpgradeDB.RARITY_NAMES[rarity])), 14, edge)
	_add_line(box, tr(info.name), 24, Color.WHITE if not is_awaken else color)
	_add_line(box, UpgradeDB.describe(id, rarity), 14, Color(0.85, 0.87, 0.92))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)

	var current: int = player.upgrade_levels.get(id, 0)
	match info.kind:
		"awaken":
			_add_line(box, tr("★ 神之觉醒 ★"), 16, color)
		"fusion":
			_add_line(box, tr("★ 融合技 ★"), 16, color)
		"path":
			_add_line(box, tr("三条道路只能选一条"), 14, Color(1, 1, 1, 0.6))
		"skill":
			_add_line(box, tr("新的神明（一局最多 %d 位）") % UpgradeDB.MAX_GODS, 14, Color(1, 1, 1, 0.6))
		"boon":
			var now: int = player.faith.get(info.god, 0)
			var next := mini(now + UpgradeDB.faith_gain(rarity), UpgradeDB.FAITH_MAX)
			var hint := ""
			if now < UpgradeDB.FAITH_PATH and next >= UpgradeDB.FAITH_PATH:
				hint = tr("（选择道路）")
			elif now < UpgradeDB.FAITH_AWAKEN and next >= UpgradeDB.FAITH_AWAKEN:
				hint = tr("（觉醒）")
			_add_line(box, tr("信仰 %d → %d / %d") % [now, next, UpgradeDB.FAITH_MAX] + hint, 14, color)
	if info.get("max", 1) > 1:
		_add_line(box, tr("等级 %d → %d / %d") % [current, current + 1, info.max], 14, Color(1, 1, 1, 0.6))

	# 边框画在最上面；鼠标移上去时边框变粗、插画变亮
	var border := Panel.new()
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width := 4 if is_awaken else (3 if info.kind == "path" else 2 + maxi(rarity, 0))
	border.add_theme_stylebox_override("panel", _border_style(edge, width))
	card.add_child(border)
	card.mouse_entered.connect(func() -> void:
		border.add_theme_stylebox_override("panel", _border_style(edge, width + 2))
		picture.modulate = Color.WHITE)
	card.mouse_exited.connect(func() -> void:
		border.add_theme_stylebox_override("panel", _border_style(edge, width))
		picture.modulate = Color(0.8, 0.8, 0.8))
	return card


## 两张插画左右各显示一半
func _split_art(left: Control, right: Control) -> Control:
	var holder := HBoxContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_theme_constant_override("separation", 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part in [left, right]:
		var half := Control.new()
		half.clip_contents = true
		half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		half.mouse_filter = Control.MOUSE_FILTER_IGNORE
		half.add_child(part)
		holder.add_child(half)
	return holder


## 卡面插画：assets/sprites/cards/ 里有就用；基础武器卡没有插画时用角色的大招特写；都没有就画一张神明颜色的占位
func _card_art(path: String, info: Dictionary, color: Color) -> Control:
	var texture: Texture2D
	var smooth := true  # 插画不是像素画，缩放时要平滑
	if ResourceLoader.exists(path):
		texture = load(path)
	elif info.kind == "weapon" and ResourceLoader.exists(path.replace(ART_DIR, CharacterDB.CUTIN_DIR).replace(".png", "_cutin.png")):
		texture = load(path.replace(ART_DIR, CharacterDB.CUTIN_DIR).replace(".png", "_cutin.png"))
		smooth = false
	if texture:
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if smooth else CanvasItem.TEXTURE_FILTER_NEAREST
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return image
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := tr(Gods.ALL[info.god].name if info.has("god") else "通用属性").substr(0, 1)
	holder.draw.connect(func() -> void:
		var size := holder.size
		var top := Color(color.darkened(0.55), 1.0)
		var mid := Color(color.darkened(0.8), 1.0)
		holder.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
			PackedColorArray([top, top, mid, mid]))
		var center := Vector2(size.x * 0.5, ART_HEIGHT * 0.55)
		for i in 3:
			holder.draw_arc(center, 54.0 + i * 16.0, 0.0, TAU, 64, Color(color, 0.25 - i * 0.07), 2.0)
		var font := holder.get_theme_default_font()
		var w := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
		holder.draw_string(font, center + Vector2(-w * 0.5, 22.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(color, 0.55)))
	return holder


func _add_line(parent: Control, text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # 中文按字、英文按词换行
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)


func _border_style(color: Color, width: int) -> StyleBoxFlat:
	var style := _card_style(color, 0.0, width)
	style.draw_center = false
	return style


func _card_style(border: Color, brightness: float, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.17).lerp(border, brightness)
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(10)
	return style


static func faith_bar(points: int) -> String:
	points = mini(points, UpgradeDB.FAITH_MAX)
	return "■".repeat(points) + "□".repeat(UpgradeDB.FAITH_MAX - points)


## 一位神的信仰一行：「托尔 ■■■■■■■□□□□□ 雷暴云」，觉醒后带 ★
static func faith_line(player: Player, god_id: String) -> String:
	var god: Dictionary = Gods.ALL[god_id]
	var text := "%s %s" % [TranslationServer.translate(god.name), faith_bar(player.faith[god_id])]
	var power: GodPower = player.gods.get(god_id)
	if power and power.path != "":
		text += " " + TranslationServer.translate(UpgradeDB.UPGRADES[power.path].name)
		if power.awakened:
			text += " ★"
	return text
