class_name PauseMenu
extends CanvasLayer
## 暂停菜单：战斗中按 Esc 打开 / 关闭；游戏窗口失去焦点时自动打开
## 左边显示本局构筑（角色、信仰、套装、已选强化），右边是「继续 / 设置 / 放弃本局」

signal abandon_requested

const GOLD := UiKit.GOLD
const DIM := UiKit.DIM

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
	_root.theme = UiKit.theme()
	add_child(_root)
	_root.add_child(UiKit.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := UiKit.framed(28)
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	panel.add_child(row)

	# 左：本局构筑
	var build_box := VBoxContainer.new()
	build_box.custom_minimum_size = Vector2(460, 0)
	build_box.add_theme_constant_override("separation", 10)
	row.add_child(build_box)
	build_box.add_child(UiKit.heading(tr("本局构筑")))
	_build_label = UiKit.body("", 15)
	build_box.add_child(_build_label)

	var divider := ColorRect.new()
	divider.color = UiKit.LINE
	divider.custom_minimum_size = Vector2(1, 0)
	row.add_child(divider)

	# 右：按钮
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(buttons)
	buttons.add_child(UiKit.label(tr("暂停"), 36, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	buttons.add_child(UiKit.primary(tr("继续游戏  [Esc]"), close, Vector2(300, 48)))
	buttons.add_child(_button(tr("设置"), _open_settings))
	_abandon = _button(tr("放弃本局"), _on_abandon_pressed)
	UiKit.tint_button(_abandon, UiKit.BAD)
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
	return not get_tree().paused and is_instance_valid(game) and game.is_running() and not game.player.is_dead


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
	if game.is_running():
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
			faiths.append(LevelUpPanel.faith_line(p, god_id))
		lines.append(tr("信仰　") + tr("　").join(faiths))
	if SetEffects.active:
		var set_info: Dictionary = GearDB.SETS[SetEffects.active.set_id]
		lines.append(tr("套装　%s · %s：%s") % [tr(set_info.name), tr(set_info.effect), tr(set_info.rule)])
	lines.append("")
	for kind in [["weapon", tr("基础武器")], ["boon", tr("神明强化")], ["stat", tr("通用属性")], ["fusion", tr("融合技")]]:
		var names: Array[String] = []
		for id: String in p.upgrade_levels:
			var info := UpgradeDB.get_info(id)
			if info.kind == kind[0]:
				var lv: int = p.upgrade_levels[id]
				names.append(tr(info.name) + ("" if info.get("max", 1) <= 1 else " Lv%d" % lv))
		if not names.is_empty():
			lines.append(tr("%s：%s") % [kind[1], tr("、").join(names)])
	if p.upgrade_levels.is_empty():
		lines.append(tr("还没有选择任何强化"))
	return "\n".join(lines)


func _button(text: String, callback: Callable) -> Button:
	return UiKit.button(text, callback, Vector2(300, 48))
