extends SceneTree
## 第 3 关图鉴截图（真实窗口）：在隔离存档里记下第 3 关的敌人和 Boss，打开主神空间的图鉴页，逐个选中截图
##   Godot --path . --script tools/review_vigrid_codex.gd -- --save-file=user://k_codex.json --settings-file=user://k_settings_zh.cfg --output=<目录>

const SHOTS := [["enemies", 3, "enemy"], ["bosses", 3, "boss"]]

var _out := ""
var _frame := 0
var _plan: Array = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			_out = arg.trim_prefix("--output=")
	var save = root.get_node("Save")
	if save.path == save.DEFAULT_PATH or _out == "":
		push_error("Use an isolated --save-file and --output=<dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	save.reset()
	save.cleared_levels.assign(["midgard", "helheim"])
	save.record_codex({"enemies": {"fire_giant": 41, "frost_veteran": 17, "wolf_berserker": 0}, "bosses": {"jormungandr": 1, "fenrir": 0, "surtr": 1}})
	change_scene_to_file("res://scenes/hub.tscn")
	for shot in SHOTS:
		for i in shot[1]:
			_plan.append([shot[0], i, "%s_%d" % [shot[2], i]])


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 10:
		current_scene.find_children("*", "TabContainer", true, false)[0].current_tab = 3
	if _frame < 30 or _frame % 12 != 0:
		return false
	var step := (_frame - 30) / 12
	var view = current_scene.find_children("*", "CodexView", true, false)[0]
	if step % 2 == 0:
		if step / 2 >= _plan.size():
			quit()
			return false
		var item: Array = _plan[step / 2]
		if view._category != item[0]:
			view._show_category(item[0])
		var tiles: Array = view._list.find_children("*", "Button", true, false)
		tiles[tiles.size() - 3 + item[1]].pressed.emit()
		view._scroll.scroll_vertical = 100000
	else:
		root.get_texture().get_image().save_png(_out.path_join(_plan[step / 2][2] + ".png"))
	return false
