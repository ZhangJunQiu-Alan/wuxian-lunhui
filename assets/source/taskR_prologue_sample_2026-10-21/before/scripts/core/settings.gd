extends Node
## 游戏设置（自动加载：任何脚本都可以直接用 Settings.xxx 访问）
## 语言、音量、窗口大小、全屏、垂直同步、伤害数字、屏幕震动、帧率显示。修改后立即生效并保存
## 文件位置：user://settings.cfg；测试时用 --settings-file=user://test_settings.cfg 换一个文件

const DEFAULT_PATH := "user://settings.cfg"
const BUSES := ["Music", "SFX"]  # 音乐和音效各走一条音频通道，都汇入主通道 Master
## 代码里的文字都是简体中文，其他语言的翻译在 locale/text.csv（第一列是中文原文）
const LANGUAGES := {"zh": "简体中文", "en": "English"}
const TRANSLATIONS := ["res://locale/text.en.translation"]
const WINDOW_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

signal language_changed

var path := DEFAULT_PATH
var language := ""         # 空 = 跟随系统语言（系统是中文就用中文，否则用英文）
var window_size := 0       # WINDOW_SIZES 的序号，窗口模式下的窗口大小
var master_volume := 1.0   # 0 ~ 1
var music_volume := 0.8
var sfx_volume := 0.8
var fullscreen := false
var vsync := true
var damage_numbers := true
var screen_shake := 1.0    # 0 = 关闭，1 = 正常
var show_fps := false

## 会被保存的设置项（变量名）
const KEYS := ["language", "window_size", "master_volume", "music_volume", "sfx_volume", "fullscreen", "vsync", "damage_numbers", "screen_shake", "show_fps"]


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
	_apply_language()


func _ready() -> void:
	apply()  # 窗口相关的设置要等窗口准备好再应用
	_apply_window_size()


func current_language() -> String:
	if LANGUAGES.has(language):
		return language
	return "zh" if OS.get_locale_language() == "zh" else "en"


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
	if key == "window_size" or key == "fullscreen":
		_apply_window_size()
	if key == "language":
		_apply_language()
		language_changed.emit()


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


## 只加载当前语言的翻译：没有加载翻译时显示代码里的中文原文
## （如果英文翻译一直挂着，中文模式下会被当成后备语言用上）
func _apply_language() -> void:
	var lang := current_language()
	for file: String in TRANSLATIONS:
		var translation: Translation = load(file)
		if translation.locale == lang:
			TranslationServer.add_translation(translation)
		else:
			TranslationServer.remove_translation(translation)
	TranslationServer.set_locale(lang)


## 只在启动和改窗口大小时调用，玩家自己拖动调整的窗口大小不会被别的设置改回去
func _apply_window_size() -> void:
	if DisplayServer.get_name() == "headless" or fullscreen:
		return
	var want: Vector2i = WINDOW_SIZES[clampi(window_size, 0, WINDOW_SIZES.size() - 1)]
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	want = want.min(screen.size)
	if DisplayServer.window_get_size() != want:
		DisplayServer.window_set_size(want)
		DisplayServer.window_set_position(screen.position + (screen.size - want) / 2)


func _set_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.0)
