class_name Credits
extends Control
## 制作人员名单：从下往上滚动，按住鼠标或空格加速，滚完从头再来。按 Esc 或「返回」关闭
## 最后附上 Godot 引擎的许可证全文（MIT 许可要求随游戏附带）

signal closed

const GOLD := Color(1.0, 0.85, 0.4)
const DIM := Color(0.7, 0.73, 0.8)
const SPEED := 45.0       # 每秒滚动多少像素
const FAST := 5.0         # 加速时的倍率
const PRODUCER := "ZhangJunQiu-Alan"
## [职位, [名字, ...]]
const SECTIONS := [
	["制作人 · 游戏设计", [PRODUCER]],
	["程序", ["Claude（Anthropic）"]],
	["美术与音频制作", ["Codex（OpenAI）"]],
	["音效与音乐素材（CC0）", ["Kenney", "rubberduck", "Emma_MA", "nene", "TokyoGeisha", "RandomMind", "Eldritch Grim",
		"NaturesTemper", "Nox_Sound", "tkane0512", "The Free Firearm Sound Library"]],
	["字体", ["Noto Sans SC — Google、Adobe（SIL Open Font License 1.1）"]],
	["引擎", ["Godot Engine（MIT License）"]],
	["特别感谢", ["每一位轮回者"]],
]

var _roll: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.02, 0.035, 0.985)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var clip := Control.new()
	clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	_roll = VBoxContainer.new()
	_roll.alignment = BoxContainer.ALIGNMENT_CENTER
	_roll.add_theme_constant_override("separation", 6)
	_roll.custom_minimum_size = Vector2(760, 0)
	clip.add_child(_roll)

	_add(tr("无限轮回"), 48, GOLD)
	_add("INFINITE SAMSARA" if Settings.current_language() == "zh" else "无限轮回", 18, DIM)
	_gap(80)
	for section: Array in SECTIONS:
		_add(tr(section[0]), 15, DIM)
		for person: String in section[1]:
			_add(tr(person), 22, Color.WHITE)
		_gap(44)
	_gap(40)
	_add(tr("感谢游玩"), 30, GOLD)
	_gap(160)
	_add(tr("Godot 引擎许可证"), 15, DIM)
	var license := _add(Engine.get_license_text(), 12, Color(1, 1, 1, 0.5))
	license.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	license.custom_minimum_size = Vector2(760, 0)
	_gap(60)
	_roll.position = Vector2((size.x - 760.0) * 0.5, size.y * 0.55)  # 打开时标题已经在屏幕下半部分

	var back := Button.new()
	back.text = tr("返回  [Esc]")
	back.custom_minimum_size = Vector2(160, 40)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void: closed.emit())
	add_child(back)
	back.position = Vector2(size.x - 200.0, 30.0)


func _process(delta: float) -> void:
	var fast := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE)
	_roll.position.y -= SPEED * (FAST if fast else 1.0) * delta
	_roll.position.x = (size.x - _roll.size.x) * 0.5
	if _roll.position.y + _roll.size.y < 0.0:
		_roll.position.y = size.y


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		closed.emit()


func _add(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # 名字和许可证原文不翻译
	_roll.add_child(label)
	return label


func _gap(height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	_roll.add_child(gap)
