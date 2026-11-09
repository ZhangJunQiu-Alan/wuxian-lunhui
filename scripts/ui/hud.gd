class_name Hud
extends CanvasLayer
## 战斗界面：经验条、血条、计时、击杀数、死亡结算

const GOLD := Color(1.0, 0.85, 0.4)
const RESULT_DIM := Color(0.62, 0.65, 0.72)
const RESULT_CARD := Vector2(88, 132)
const FATE_NAMES := {"thor_saved": "托尔活了下来", "vidar_intervened": "维达撕开巨口", "freyr_assisted": "弗雷参战"}
const LOKI_HINT := "谢谢你，轮回者。锁链断了，我也该去看看别的世界了。"
const ENDING_FADE := 0.25
const RESULT_KINDS := {
	"victory": {"title": "主线任务完成", "color": Color(1.0, 0.85, 0.4)},
	"death": {"title": "你死了", "color": Color(0.95, 0.38, 0.32)},
	"abandon": {"title": "你放弃了本局", "color": Color(0.7, 0.74, 0.82)},
}

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
var _fps_label: Label
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _hurt_flash: ColorRect
var _last_hp := -1.0
var _ending: Control           # 篇章结局字幕（显示时不为 null）
var _ending_beats := PackedStringArray()
var _ending_index := 0
var _ending_text: Label
var _ending_page: Label
var _ending_done: Callable


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

	_fps_label = Label.new()
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.offset_left = -120
	_fps_label.offset_right = -12
	_fps_label.offset_top = 8
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.modulate = Color(1, 1, 1, 0.5)
	add_child(_fps_label)

	_cutin = UltCutin.new()
	add_child(_cutin)


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
	_xp_bar.value = xp_to_next if level >= Player.MAX_LEVEL else xp
	_level_label.text = tr("%s  等级 %d") % [tr(CharacterDB.ALL[character_id].name), level]


func set_ult(energy: float, cost: float) -> void:
	_ult_bar.max_value = cost
	_ult_bar.value = energy
	var is_full := energy >= cost
	_ult_bar.modulate = Color(1.0, 0.85, 0.3) if is_full else Color(0.55, 0.65, 1.0)
	var ult_name: String = tr(CharacterDB.ALL[character_id].ult_name)
	_ult_label.text = (ult_name + tr(" 已就绪  [E]")) if is_full else ult_name
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


## 左侧显示每位已信仰神明的信仰，例如「托尔 ■■■■■■■□□□□□ 雷暴云」
func set_faith(player: Player) -> void:
	for child in _faith_box.get_children():
		child.queue_free()
	for god_id: String in player.faith:
		var label := Label.new()
		label.text = LevelUpPanel.faith_line(player, god_id)
		label.modulate = Gods.ALL[god_id].color
		_faith_box.add_child(label)


func set_stats(elapsed: float, kills: int) -> void:
	_time_label.text = "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]
	_time_label.offset_left = -_time_label.size.x / 2.0
	_kills_label.text = tr("击杀 %d") % kills


func _process(_delta: float) -> void:
	_fps_label.visible = Settings.show_fps
	if _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


## 结算界面。kind：victory 通关、death 死亡、abandon 放弃；run 是 game.gd 结算出来的数据
func show_result(kind: String, level_name: String, story: String, run: Dictionary, player: Player) -> void:
	for child in get_children():
		if child is CanvasItem:
			child.visible = false  # 其余战斗界面全部收起，只留结算
	var accent: Color = RESULT_KINDS[kind].color

	var screen := ColorRect.new()
	screen.color = Color(0.02, 0.03, 0.05, 0.88)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 900
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	column.add_child(_result_title(tr(RESULT_KINDS[kind].title), accent))
	column.add_child(_result_text(level_name, 18, RESULT_DIM))

	# 主体：左边本局构筑，右边数据
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _result_style(Color(0.06, 0.07, 0.1, 0.96), Color(accent, 0.5), 1, 20))
	column.add_child(panel)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	panel.add_child(body)
	body.add_child(_build_column(player))
	var divider := ColorRect.new()
	divider.color = Color(1, 1, 1, 0.08)
	divider.custom_minimum_size.x = 1
	body.add_child(divider)
	body.add_child(_numbers_column(run))

	if story != "":
		var story_label := _result_text(story, 17, Color(0.86, 0.8, 0.66))
		story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(story_label)
	if kind == "victory" and run.get("ever_faith_loki", false):  # 洛基的伏笔：本局信仰过洛基才出现
		var hint := _result_text(tr("「%s」") % tr(LOKI_HINT), 17, Gods.ALL.loki.color)
		hint.name = "LokiHint"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(hint)

	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	column.add_child(gap)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	column.add_child(buttons)
	var restart := _result_button(tr("再来一次"), accent, true)
	restart.pressed.connect(_on_restart_pressed)
	buttons.add_child(restart)
	var hub := _result_button(tr("返回主神空间"), accent, false)
	hub.pressed.connect(_on_hub_pressed)
	buttons.add_child(hub)
	restart.grab_focus()

	# 入场：整体淡入并上浮
	screen.modulate.a = 0.0
	center.position.y = 24.0
	var tween := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(screen, "modulate:a", 1.0, 0.35)
	tween.tween_property(center, "position:y", 0.0, 0.45)


## 篇章结局：一段一段显示字幕，「继续」看下一段，「跳过演出」直接结束；最后一段之后（或跳过）调用一次 on_done
## 游戏这时是暂停的，界面照常处理输入；不会自动推进，也不会自动切场景
func show_ending(beats: PackedStringArray, on_done: Callable) -> void:
	for child in get_children():
		if child is CanvasItem:
			child.visible = false
	_ending_beats = beats
	_ending_index = 0
	_ending_done = on_done
	_ending = ColorRect.new()
	_ending.name = "Ending"
	(_ending as ColorRect).color = Color(0.02, 0.03, 0.05, 0.98)
	_ending.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ending.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			advance_ending())
	add_child(_ending)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ending.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 760
	column.add_theme_constant_override("separation", 28)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)
	_ending_text = _result_text("", 26, Color(0.92, 0.86, 0.72))
	_ending_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ending_text.custom_minimum_size.y = 150
	column.add_child(_ending_text)
	_ending_page = _result_text("", 14, RESULT_DIM)
	column.add_child(_ending_page)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	column.add_child(buttons)
	var next := _result_button(tr("继续"), GOLD, true)
	next.name = "Next"
	next.pressed.connect(advance_ending)
	buttons.add_child(next)
	var skip := _result_button(tr("跳过演出"), GOLD, false)
	skip.name = "Skip"
	skip.pressed.connect(skip_ending)
	buttons.add_child(skip)
	next.grab_focus()
	_show_beat()


func ending_index() -> int:
	return _ending_index if _ending else -1


func advance_ending() -> void:
	if not _ending:
		return
	_ending_index += 1
	if _ending_index >= _ending_beats.size():
		_finish_ending()
	else:
		_show_beat()


func skip_ending() -> void:
	if _ending:
		_finish_ending()


func _show_beat() -> void:
	_ending_text.text = tr(_ending_beats[_ending_index])
	_ending_page.text = "%d / %d" % [_ending_index + 1, _ending_beats.size()]
	_ending_text.modulate.a = 0.0
	create_tween().tween_property(_ending_text, "modulate:a", 1.0, ENDING_FADE)  # 淡入不挡操作，随时可以继续或跳过


## 结局结束（读完或跳过）：只走一次，之后显示结算
func _finish_ending() -> void:
	var done := _ending_done
	_ending.queue_free()
	_ending = null
	_ending_done = Callable()
	if done.is_valid():
		done.call()


func _unhandled_input(event: InputEvent) -> void:
	if _ending and event.is_action_pressed("ui_cancel"):  # Esc 跳过整段结局
		get_viewport().set_input_as_handled()
		skip_ending()


## 左栏：角色和信仰的神各一张小卡，下面列出融合技
func _build_column(player: Player) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(_result_text(tr("本局构筑"), 15, RESULT_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	box.add_child(cards)
	var character: Dictionary = CharacterDB.ALL[player.character_id]
	cards.add_child(_mini_card(player.character_id, tr(character.name), tr(character.ult_name), Color(0.8, 0.84, 0.95), false))
	for god_id: String in player.faith:
		var power: GodPower = player.gods.get(god_id)
		var awakened := power != null and power.awakened
		var line := tr(UpgradeDB.UPGRADES[power.path].name) if power and power.path != "" else tr("信仰 %d") % player.faith[god_id]
		cards.add_child(_mini_card(god_id + ("_awaken" if awakened else ""), tr(Gods.ALL[god_id].name), line, Gods.ALL[god_id].color, awakened))
	for i in cards.get_child_count():  # 卡片逐张亮起
		var card := cards.get_child(i) as Control
		card.modulate.a = 0.0
		create_tween().tween_property(card, "modulate:a", 1.0, 0.3).set_delay(0.25 + i * 0.1)
	for id: String in GodPower.fusions:
		box.add_child(_result_text(tr("融合技 · %s") % tr(Gods.FUSIONS[id].name), 15, Color(0.88, 0.75, 1.0), HORIZONTAL_ALIGNMENT_LEFT))
	return box


func _mini_card(art: String, title: String, line: String, color: Color, awakened: bool) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size.x = RESULT_CARD.x
	card.add_theme_constant_override("separation", 2)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = RESULT_CARD
	frame.clip_contents = true
	frame.add_theme_stylebox_override("panel", _result_style(Color(color.darkened(0.75), 1.0), GOLD if awakened else Color(color, 0.8), 2, 2))
	card.add_child(frame)
	var path := LevelUpPanel.ART_DIR + art + ".png"
	if ResourceLoader.exists(path):
		var image := TextureRect.new()
		image.texture = load(path)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		frame.add_child(image)
	else:
		frame.add_child(_result_text(title.substr(0, 1), 44, Color(color, 0.6)))
	card.add_child(_result_text(title, 15, color.lightened(0.2)))
	var sub := _result_text(line + (" ★" if awakened else ""), 12, GOLD if awakened else RESULT_DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(sub)
	return card


## 右栏：用时、等级、击杀；命运；奖励
func _numbers_column(run: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 16)
	var elapsed := int(run.elapsed)
	box.add_child(_tile_row([
		_stat_tile(tr("用时"), "%02d:%02d" % [elapsed / 60, elapsed % 60], Color.WHITE),
		_stat_tile(tr("等级"), str(run.level), Color.WHITE),
		_count_up(_stat_tile(tr("击杀"), "", Color.WHITE), run.kills, "%d"),
	]))
	if run.has("fates"):  # 第 3 关：改写的命运
		box.add_child(_rule())
		var fates: Dictionary = run.fates
		var row := _tile_row([_stat_tile(tr("改写的命运"), "%d / %d" % [run.fate_count, fates.size()], GOLD)])
		row.name = "Fates"
		for id: String in FATE_NAMES:
			if fates.has(id):
				row.add_child(_stat_tile(tr(FATE_NAMES[id]), "✓" if fates[id] else "—", GOLD if fates[id] else Color(RESULT_DIM, 0.6)))
		box.add_child(row)
	box.add_child(_rule())
	box.add_child(_tile_row([
		_count_up(_stat_tile(tr("奖励点"), "", GOLD, tr("累计 %d") % run.reward_total), run.reward_points, "+%d"),
	]))
	return box


func _tile_row(tiles: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	for tile: Control in tiles:
		row.add_child(tile)
	return row


## 一格数据：大号数值在上，说明在下，可选再加一行小字
func _stat_tile(caption: String, value: String, color: Color, note: String = "") -> VBoxContainer:
	var tile := VBoxContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_constant_override("separation", 0)
	tile.add_child(_result_text(value, 32, color))
	tile.add_child(_result_text(caption, 14, RESULT_DIM))
	if note != "":
		tile.add_child(_result_text(note, 12, Color(RESULT_DIM, 0.7)))
	return tile


## 数值从 0 滚动到 target
func _count_up(tile: VBoxContainer, target: int, format: String) -> VBoxContainer:
	var label := tile.get_child(0) as Label
	label.text = format % 0
	create_tween().tween_method(func(v: float) -> void: label.text = format % int(v), 0.0, float(target), 0.9) \
		.set_delay(0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return tile


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.08)
	rule.custom_minimum_size.y = 1
	return rule


## 标题：两侧各一条渐隐的装饰线
func _result_title(text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	for side in 2:
		var line := TextureRect.new()
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(color, 0.0), Color(color, 0.7)] if side == 0 else [Color(color, 0.7), Color(color, 0.0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 160
		texture.height = 2
		line.texture = texture
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(line)
	var label := _result_text(text, 40, color)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	row.add_child(label)
	row.move_child(label, 1)
	return row


func _result_text(text: String, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _result_button(text: String, accent: Color, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(200, 48)
	button.add_theme_font_size_override("font_size", 18)
	var base := Color(accent.darkened(0.72), 0.95) if primary else Color(0.07, 0.08, 0.11, 0.95)
	button.add_theme_stylebox_override("normal", _result_style(base, Color(accent, 0.9 if primary else 0.35), 2 if primary else 1, 8))
	var hover := _result_style(Color(accent.darkened(0.55), 0.95), accent, 2, 8)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", _result_style(Color(accent.darkened(0.4), 0.95), accent, 2, 8))
	return button


func _result_style(bg: Color, border: Color, width: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(padding)
	return style


func _on_hub_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/hub.tscn")


func _on_restart_pressed() -> void:
	get_tree().paused = false
	ChapterIntro.open(get_tree(), LevelDB.selected())
