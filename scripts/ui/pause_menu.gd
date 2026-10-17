class_name PauseMenu
extends CanvasLayer
## 暂停菜单：战斗中按 Esc 打开 / 关闭；游戏窗口失去焦点时自动打开
## 左边显示本局构筑（角色、信仰、已选强化），右边是「继续 / 设置 / 放弃本局」

signal abandon_requested

const GOLD := Color(1.0, 0.85, 0.4)
const DIM := Color(0.7, 0.73, 0.8)

var game: Game
var _root: Control
var _build_label: Label
var _abandon: Button
var _settings: SettingsPanel
var _abandon_armed := false  # 放弃要点两次，防止误触


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	center.add_child(row)

	# 左：本局构筑
	var build_box := VBoxContainer.new()
	build_box.custom_minimum_size = Vector2(420, 0)
	row.add_child(build_box)
	build_box.add_child(_label(tr("本局构筑"), 22, GOLD))
	_build_label = _label("", 15, Color.WHITE)
	_build_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_box.add_child(_build_label)

	# 右：按钮
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(buttons)
	buttons.add_child(_label(tr("暂停"), 36, Color.WHITE))
	buttons.add_child(_button(tr("继续游戏  [Esc]"), close))
	buttons.add_child(_button(tr("设置"), _open_settings))
	_abandon = _button(tr("放弃本局"), _on_abandon_pressed)
	buttons.add_child(_abandon)

	_settings = SettingsPanel.new()
	_settings.allow_language = false
	add_child(_settings)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not (key and key.pressed and not key.echo and key.keycode == KEY_ESCAPE):
		return
	get_viewport().set_input_as_handled()
	if _root.visible:
		close()
	elif _can_pause():
		open()


## 切到别的程序时自动暂停
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not _root.visible and _can_pause():
		open()


## 升级选择、结算界面等已经暂停游戏时，不再叠加暂停菜单
func _can_pause() -> bool:
	return not get_tree().paused and is_instance_valid(game) and not game.player.is_dead


func open() -> void:
	Audio.sfx("ui_open")
	get_tree().paused = true
	_abandon_armed = false
	_abandon.text = tr("放弃本局")
	_build_label.text = _build_text()
	_root.visible = true


func close() -> void:
	_settings.visible = false
	_root.visible = false
	get_tree().paused = false


func _open_settings() -> void:
	_settings.open()


func _on_abandon_pressed() -> void:
	if not _abandon_armed:
		_abandon_armed = true
		_abandon.text = tr("确定放弃？（已获得的奖励点会保留）")
		return
	_root.visible = false
	abandon_requested.emit()


func _build_text() -> String:
	var p := game.player
	var lines: Array[String] = []
	lines.append(tr("%s · %s　等级 %d") % [tr(p.data.name), tr(p.data.title), p.level])
	lines.append(tr("用时 %02d:%02d　击杀 %d　生命 %d / %d") % [int(game.elapsed) / 60, int(game.elapsed) % 60, game.kills, ceili(p.hp), int(p.max_hp)])
	if not p.faith.is_empty():
		var faiths: Array[String] = []
		for god_id: String in p.faith:
			faiths.append("%s %s" % [tr(Gods.ALL[god_id].name), LevelUpPanel.faith_bar(p.faith[god_id])])
		lines.append(tr("信仰　") + tr("　").join(faiths))
	lines.append("")
	for kind in [["weapon", tr("基础武器")], ["god", tr("神明")], ["stat", tr("通用属性")]]:
		var names: Array[String] = []
		for id: String in p.upgrade_levels:
			var info := UpgradeDB.get_info(id)
			if info.kind == kind[0]:
				var lv: int = p.upgrade_levels[id]
				names.append(tr(info.name) + ("" if info.max <= 1 else " Lv%d" % lv))
		if not names.is_empty():
			lines.append(tr("%s：%s") % [kind[1], tr("、").join(names)])
	if p.upgrade_levels.is_empty():
		lines.append(tr("还没有选择任何强化"))
	return "\n".join(lines)


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 48)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	return label
