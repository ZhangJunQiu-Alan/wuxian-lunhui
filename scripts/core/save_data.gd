extends Node
## 存档（自动加载：任何脚本都可以直接用 Save.xxx 访问）
## 保存局外进度：奖励点、支线剧情点、主神空间的永久强化、角色选择与解锁、关卡选择与通关记录、战绩统计
## 文件位置：user://save.json（Mac 上在 ~/Library/Application Support/Godot/app_userdata/无限轮回/）
## 测试时用命令行参数 --save-file=user://test_save.json 换一个文件，避免弄乱真实存档

const DEFAULT_PATH := "user://save.json"
const VERSION := 3

var path := DEFAULT_PATH
var reward_points := 0
var story_points := 0
var meta := {}  # 永久强化 id -> 等级
var stats := _default_stats()
var selected_character := "swordsman"
var unlocked_characters: Array[String] = []  # 花点数解锁的角色（其他角色按条件自动解锁）
var selected_level := "midgard"
var cleared_levels: Array[String] = []  # 通关过的关卡 id


static func _default_stats() -> Dictionary:
	return {"runs": 0, "clears": 0, "best_time": 0.0, "best_clear_time": 0.0, "total_kills": 0, "quests_done": 0}


## 在节点创建时（而不是加入场景树后）就读取存档：
## 这样即使别的脚本在很早的时机访问 Save，拿到的也是正确的存档文件和数据
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-file="):
			path = arg.trim_prefix("--save-file=")
	load_game()


func load_game() -> void:
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("存档文件损坏，使用新存档：" + path)
		return
	reward_points = int(data.get("reward_points", 0))
	story_points = int(data.get("story_points", 0))
	meta = {}
	for id: String in data.get("meta", {}):
		meta[id] = int(data.meta[id])
	selected_character = data.get("selected_character", "swordsman")
	unlocked_characters.assign(data.get("unlocked_characters", []))
	selected_level = data.get("selected_level", "midgard")
	cleared_levels.assign(data.get("cleared_levels", []))
	var saved_stats: Dictionary = data.get("stats", {})
	for key: String in stats:
		if saved_stats.has(key):
			stats[key] = type_convert(saved_stats[key], typeof(stats[key]))  # JSON 读出的数字都是小数，转回原来的类型
	if not data.has("cleared_levels") and stats.clears > 0:
		cleared_levels.append("midgard")  # 第 2 版存档只有第 1 关，通关次数都是第 1 关的


## 先写到临时文件再改名，写到一半断电也不会把原存档写坏
func save_game() -> void:
	var data := {"version": VERSION, "reward_points": reward_points, "story_points": story_points, "meta": meta, "stats": stats,
		"selected_character": selected_character, "unlocked_characters": unlocked_characters,
		"selected_level": selected_level, "cleared_levels": cleared_levels}
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入存档：" + tmp_path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	DirAccess.rename_absolute(tmp_path, path)


func meta_level(id: String) -> int:
	return meta.get(id, 0)


## 购买一级永久强化，成功返回 true
func buy_meta(id: String) -> bool:
	var level := meta_level(id)
	if level >= MetaDB.UPGRADES[id].max:
		return false
	var cost := MetaDB.cost(id, level)
	if reward_points < cost:
		return false
	reward_points -= cost
	meta[id] = level + 1
	save_game()
	return true


func select_character(id: String) -> void:
	selected_character = id
	save_game()


func select_level(id: String) -> void:
	selected_level = id
	save_game()


## 花支线剧情点解锁角色，成功返回 true
func unlock_character(id: String, cost: int) -> bool:
	if id in unlocked_characters or story_points < cost:
		return false
	story_points -= cost
	unlocked_characters.append(id)
	save_game()
	return true


## 一局结束时调用：把本局收获存进存档。第一次通关某一关时，自动选好下一关
func record_run(level_id: String, points: int, story: int, cleared: bool, elapsed: float, kills: int, quests_done: int) -> void:
	reward_points += points
	story_points += story
	stats.runs += 1
	stats.quests_done += quests_done
	stats.total_kills += kills
	stats.best_time = maxf(stats.best_time, elapsed)
	if cleared:
		if not cleared_levels.has(level_id):
			cleared_levels.append(level_id)
			if LevelDB.is_built(LevelDB.next_of(level_id)):
				selected_level = LevelDB.next_of(level_id)
		stats.clears += 1
		if stats.best_clear_time <= 0.0 or elapsed < stats.best_clear_time:
			stats.best_clear_time = elapsed
	save_game()


## 清空存档（主神空间里的「重置存档」用）
func reset() -> void:
	reward_points = 0
	story_points = 0
	meta = {}
	stats = _default_stats()
	selected_character = "swordsman"
	unlocked_characters = []
	selected_level = "midgard"
	cleared_levels = []
	save_game()
