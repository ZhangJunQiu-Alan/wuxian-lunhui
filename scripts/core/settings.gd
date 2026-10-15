extends Node
## 游戏设置（自动加载：任何脚本都可以直接用 Settings.xxx 访问）
## 音量、全屏、垂直同步、伤害数字、屏幕震动、帧率显示。修改后立即生效并保存
## 文件位置：user://settings.cfg；测试时用 --settings-file=user://test_settings.cfg 换一个文件

const DEFAULT_PATH := "user://settings.cfg"
const BUSES := ["Music", "SFX"]  # 音乐和音效各走一条音频通道，都汇入主通道 Master

var path := DEFAULT_PATH
var master_volume := 1.0   # 0 ~ 1
var music_volume := 0.8
var sfx_volume := 0.8
var fullscreen := false
var vsync := true
var damage_numbers := true
var screen_shake := 1.0    # 0 = 关闭，1 = 正常
var show_fps := false

## 会被保存的设置项（变量名）
const KEYS := ["master_volume", "music_volume", "sfx_volume", "fullscreen", "vsync", "damage_numbers", "screen_shake", "show_fps"]


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--settings-file="):
			path = arg.trim_prefix("--settings-file=")
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
	load_settings()


func _ready() -> void:
	apply()  # 窗口相关的设置要等窗口准备好再应用


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for key: String in KEYS:
		set(key, cfg.get_value("settings", key, get(key)))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key: String in KEYS:
		cfg.set_value("settings", key, get(key))
	cfg.save(path)


## 修改一项设置：立即生效并保存
func change(key: String, value: Variant) -> void:
	set(key, value)
	apply()
	save_settings()


func apply() -> void:
	_set_volume("Master", master_volume)
	_set_volume("Music", music_volume)
	_set_volume("SFX", sfx_volume)
	if DisplayServer.get_name() == "headless":
		return  # 后台测试时没有窗口
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func _set_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.0)
