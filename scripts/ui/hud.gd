class_name Hud
extends CanvasLayer
## 战斗界面：经验条、血条、计时、击杀数、死亡结算

var character_id := CharacterDB.DEFAULT_ID  # 由 game.gd 在创建 HUD 前设置
var _xp_bar: ProgressBar
var _hp_bar: ProgressBar
var _level_label: Label
var _time_label: Label
var _kills_label: Label
var _faith_box: VBoxContainer
var _ult_bar: ProgressBar
var _ult_label: Label
var _announce: Label
var _cutin: UltCutin
var _quest_box: VBoxContainer
var _quest_title: Label
var _quest_objective: Label
var _quest_timer: Label
var _pointer: QuestPointer
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _hurt_flash: ColorRect
var _last_hp := -1.0
var _game_over: Control
var _result_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 游戏暂停时界面仍然可以点击
	layer = 5  # 界面在最上层（画面变暗效果是 1，升级面板是 10）

	# 受伤时整个屏幕闪一下红色
	_hurt_flash = ColorRect.new()
	_hurt_flash.color = Color(0.8, 0.0, 0.0, 0.0)
	_hurt_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hurt_flash)

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

	# 屏幕下方的事件提示，例如「狼群包围！」
	_announce = Label.new()
	_announce.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_announce.offset_top = -150
	_announce.offset_bottom = -110
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.add_theme_font_size_override("font_size", 26)
	_announce.modulate = Color(1.0, 0.75, 0.4, 0.0)
	add_child(_announce)

	# 顶部中间：Boss 名字和血条，Boss 出场时才显示
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_box.offset_left = -260
	_boss_box.offset_right = 260
	_boss_box.offset_top = 58
	_boss_box.visible = false
	add_child(_boss_box)
	_boss_name = Label.new()
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.add_theme_font_size_override("font_size", 18)
	_boss_name.modulate = Color(1.0, 0.75, 0.6)
	_boss_box.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size.y = 14
	_boss_bar.modulate = Color(0.9, 0.25, 0.2)
	_boss_box.add_child(_boss_bar)

	_cutin = UltCutin.new()
	add_child(_cutin)

	# 右侧：支线任务面板
	_quest_box = VBoxContainer.new()
	_quest_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_quest_box.offset_left = -300
	_quest_box.offset_right = -16
	_quest_box.offset_top = 250
	_quest_box.visible = false
	add_child(_quest_box)
	_quest_title = Label.new()
	_quest_title.add_theme_font_size_override("font_size", 18)
	_quest_objective = Label.new()
	_quest_timer = Label.new()
	_quest_timer.modulate = Color(1, 1, 1, 0.7)
	for label in [_quest_title, _quest_objective, _quest_timer]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_quest_box.add_child(label)

	_pointer = QuestPointer.new()
	add_child(_pointer)

	_build_game_over()


func _make_label(pos: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	add_child(label)
	return label


func set_hp(hp: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	if hp < _last_hp - 0.5:  # 回血不闪，只有掉血才闪
		_hurt_flash.color.a = 0.25
		create_tween().tween_property(_hurt_flash, "color:a", 0.0, 0.3)
	_last_hp = hp


func set_xp(xp: float, xp_to_next: int, level: int) -> void:
	_xp_bar.max_value = xp_to_next
	_xp_bar.value = xp
	_level_label.text = "%s  等级 %d" % [CharacterDB.ALL[character_id].name, level]


func set_ult(energy: float, cost: float) -> void:
	_ult_bar.max_value = cost
	_ult_bar.value = energy
	var is_full := energy >= cost
	_ult_bar.modulate = Color(1.0, 0.85, 0.3) if is_full else Color(0.55, 0.65, 1.0)
	var ult_name: String = CharacterDB.ALL[character_id].ult_name
	_ult_label.text = (ult_name + " 已就绪  [空格]") if is_full else ult_name
	_ult_label.modulate = Color(1.0, 0.85, 0.3) if is_full else Color(1, 1, 1, 0.6)




func show_boss(boss_name: String, title: String, max_hp: float) -> void:
	_boss_name.text = "%s · %s" % [boss_name, title]
	_boss_bar.max_value = max_hp
	_boss_bar.value = max_hp
	_boss_box.visible = true


func set_boss_hp(hp: float, max_hp: float) -> void:
	_boss_bar.max_value = max_hp
	_boss_bar.value = hp


func hide_boss() -> void:
	_boss_box.visible = false



## 支线任务面板和指向箭头，每帧由 game.gd 更新
func show_quest(quest: SideQuest) -> void:
	_quest_box.visible = true
	_quest_title.text = "支线剧情 · " + quest.title
	_quest_title.modulate = quest.color
	_quest_objective.text = quest.objective
	if quest.state == "active":
		_quest_timer.text = "剩余 %d 秒" % ceili(quest.time_left)
	else:
		_quest_timer.text = "标记 %d 秒后消失" % ceili(quest._offer_left)
	_pointer.targets = quest.pointer_targets()
	_pointer.color = quest.color


func hide_quest() -> void:
	_quest_box.visible = false
	_pointer.targets = []


## 大招特写
func show_cutin(character_id: String) -> void:
	_cutin.play(character_id)


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


func show_game_over(elapsed: float, kills: int, level: int, rewards: String) -> void:
	_result_label.text = "你死了\n\n" + _stats_text(elapsed, kills, level) + "\n" + rewards
	hide_quest()
	_game_over.visible = true


func show_victory(level_name: String, story: String, elapsed: float, kills: int, level: int, rewards: String) -> void:
	_result_label.text = "主线任务完成 · %s\n\n%s\n%s\n\n%s" % [level_name, _stats_text(elapsed, kills, level), rewards, story]
	hide_quest()
	_result_label.modulate = Color(1.0, 0.88, 0.55)
	hide_boss()
	_game_over.visible = true


func _stats_text(elapsed: float, kills: int, level: int) -> String:
	return "用时 %02d:%02d　等级 %d　击杀 %d" % [int(elapsed) / 60, int(elapsed) % 60, level, kills]


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

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	box.add_child(buttons)
	var restart := Button.new()
	restart.text = "再来一次"
	restart.custom_minimum_size = Vector2(180, 44)
	restart.pressed.connect(_on_restart_pressed)
	buttons.add_child(restart)
	var hub := Button.new()
	hub.text = "返回主神空间"
	hub.custom_minimum_size = Vector2(180, 44)
	hub.pressed.connect(_on_hub_pressed)
	buttons.add_child(hub)


func _on_hub_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/hub.tscn")


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
