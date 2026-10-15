class_name Hud
extends CanvasLayer
## 战斗界面：经验条、血条、计时、击杀数、死亡结算

var _xp_bar: ProgressBar
var _hp_bar: ProgressBar
var _level_label: Label
var _time_label: Label
var _kills_label: Label
var _faith_box: VBoxContainer
var _ult_bar: ProgressBar
var _ult_label: Label
var _announce: Label
var _game_over: Control
var _result_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 游戏暂停时界面仍然可以点击

	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_xp_bar.offset_bottom = 14
	_xp_bar.modulate = Color(0.4, 0.85, 1.0)
	add_child(_xp_bar)

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.position = Vector2(16, 24)
	_hp_bar.size = Vector2(240, 16)
	_hp_bar.modulate = Color(1.0, 0.35, 0.35)
	add_child(_hp_bar)

	_level_label = _make_label(Vector2(16, 44))
	_kills_label = _make_label(Vector2(16, 68))

	_time_label = Label.new()
	_time_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_time_label.offset_top = 20
	_time_label.add_theme_font_size_override("font_size", 28)
	add_child(_time_label)

	_faith_box = VBoxContainer.new()
	_faith_box.position = Vector2(16, 100)
	add_child(_faith_box)

	# 底部中间：大招能量条
	_ult_bar = ProgressBar.new()
	_ult_bar.show_percentage = false
	_ult_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_ult_bar.offset_left = -160
	_ult_bar.offset_right = 160
	_ult_bar.offset_top = -40
	_ult_bar.offset_bottom = -26
	add_child(_ult_bar)

	_ult_label = Label.new()
	_ult_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_ult_label.offset_left = -160
	_ult_label.offset_right = 160
	_ult_label.offset_top = -66
	_ult_label.offset_bottom = -42
	_ult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_ult_label)

	# 屏幕上方的事件提示，例如「狼群包围！」
	_announce = Label.new()
	_announce.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_announce.offset_top = 70
	_announce.offset_bottom = 110
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.add_theme_font_size_override("font_size", 26)
	_announce.modulate = Color(1.0, 0.75, 0.4, 0.0)
	add_child(_announce)

	_build_game_over()


func _make_label(pos: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	add_child(label)
	return label


func set_hp(hp: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp


func set_xp(xp: float, xp_to_next: int, level: int) -> void:
	_xp_bar.max_value = xp_to_next
	_xp_bar.value = xp
	_level_label.text = "%s  等级 %d" % [Player.CHARACTER_NAME, level]


func set_ult(energy: float, cost: float) -> void:
	_ult_bar.max_value = cost
	_ult_bar.value = energy
	var is_full := energy >= cost
	_ult_bar.modulate = Color(1.0, 0.85, 0.3) if is_full else Color(0.55, 0.65, 1.0)
	_ult_label.text = "次元斩 已就绪  [空格]" if is_full else "次元斩"
	_ult_label.modulate = Color(1.0, 0.85, 0.3) if is_full else Color(1, 1, 1, 0.6)



## 在屏幕上方显示一行提示，停留一会儿后淡出
func announce(text: String) -> void:
	_announce.text = text
	var tween := create_tween()
	tween.tween_property(_announce, "modulate:a", 1.0, 0.2)
	tween.tween_interval(2.0)
	tween.tween_property(_announce, "modulate:a", 0.0, 0.6)


## 左侧显示每位已信仰神明的信仰值，例如「托尔 ■■■□□」
func set_faith(faith: Dictionary) -> void:
	for child in _faith_box.get_children():
		child.queue_free()
	for god_id: String in faith:
		var god: Dictionary = Gods.ALL[god_id]
		var label := Label.new()
		label.text = "%s %s" % [god.name, LevelUpPanel.faith_bar(faith[god_id])]
		label.modulate = god.color
		_faith_box.add_child(label)


func set_stats(elapsed: float, kills: int) -> void:
	_time_label.text = "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]
	_time_label.offset_left = -_time_label.size.x / 2.0
	_kills_label.text = "击杀 %d" % kills


func show_game_over(elapsed: float, kills: int, level: int) -> void:
	_result_label.text = "你死了\n\n存活 %02d:%02d　等级 %d　击杀 %d" % [int(elapsed) / 60, int(elapsed) % 60, level, kills]
	_game_over.visible = true


func _build_game_over() -> void:
	_game_over = ColorRect.new()
	(_game_over as ColorRect).color = Color(0, 0, 0, 0.7)
	_game_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over.visible = false
	add_child(_game_over)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 28)
	box.add_child(_result_label)

	var restart := Button.new()
	restart.text = "重新开始"
	restart.pressed.connect(_on_restart_pressed)
	box.add_child(restart)


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
