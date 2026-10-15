class_name LevelUpPanel
extends CanvasLayer
## 升级三选一界面：显示卡牌，鼠标点击或按 1/2/3 选择

signal chosen(id: String)
signal reroll_requested

const CARD_SIZE := Vector2(260, 300)
const NEUTRAL_COLOR := Color(0.75, 0.78, 0.85)

var _title: Label
var _cards: HBoxContainer
var _ids: Array[String] = []
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
	hint.text = "点击卡牌或按数字键选择"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.5)
	box.add_child(hint)


func open(ids: Array[String], player: Player, title: String = "") -> void:
	_ids = ids
	if title == "":
		title = "选择你的第一份信仰" if player.faith.is_empty() else "升级！等级 %d" % player.level
	_title.text = title
	_reroll.visible = player.rerolls > 0
	_reroll.text = "重抽选项（剩余 %d 次）  [R]" % player.rerolls
	for child in _cards.get_children():
		child.queue_free()
	for i in ids.size():
		_cards.add_child(_make_card(i, ids[i], player))
	visible = true


func choose(index: int) -> void:
	if not visible or index >= _ids.size():
		return
	visible = false
	chosen.emit(_ids[index])


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


func _make_card(index: int, id: String, player: Player) -> Button:
	var info := UpgradeDB.get_info(id)
	var is_awaken: bool = info.get("awaken", false)
	var color := NEUTRAL_COLOR
	var tag := "通用属性"
	match info.kind:
		"god":
			var god: Dictionary = Gods.ALL[info.god]
			color = god.color
			tag = "神明 · %s · %s" % [god.name, god.title]
		"weapon":
			color = Color(0.85, 0.92, 1.0)
			tag = "基础武器 · " + CharacterDB.ALL[player.character_id].weapon

	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal", _card_style(color, 0.12, 2 if not is_awaken else 4))
	card.add_theme_stylebox_override("hover", _card_style(color, 0.2, 4))
	card.add_theme_stylebox_override("pressed", _card_style(color, 0.28, 4))
	card.pressed.connect(choose.bind(index))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 18
	box.offset_right = -18
	box.offset_top = 18
	box.offset_bottom = -18
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	_add_line(box, "[%d]  %s" % [index + 1, tag], 15, color)
	_add_line(box, info.name, 26, Color.WHITE if not is_awaken else color)
	_add_line(box, info.desc, 17, Color(0.85, 0.87, 0.92))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)

	var current: int = player.upgrade_levels.get(id, 0)
	if is_awaken:
		_add_line(box, "★ 神之觉醒 ★", 16, color)
	elif info.god != "":
		var next := mini(player.faith.get(info.god, 0) + 1, UpgradeDB.FAITH_MAX)
		_add_line(box, "信仰 %s %d/%d" % [faith_bar(next), next, UpgradeDB.FAITH_MAX], 15, color)
	if info.max > 1:
		_add_line(box, "等级 %d → %d / %d" % [current, current + 1, info.max], 14, Color(1, 1, 1, 0.6))
	elif current == 0 and info.get("skill", false):
		_add_line(box, "新技能", 14, Color(1, 1, 1, 0.6))
	return card


func _add_line(parent: Control, text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY  # 中文按字换行
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)


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
