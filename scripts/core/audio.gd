class_name Audio
extends Node
## 音效与音乐：任何脚本都可以直接用 Audio.sfx("dash") / Audio.music("boss")
## 第一次调用时在场景树根节点下建一个常驻节点，切换场景也不会中断音乐
## 按文件名查找 assets/audio/sfx/<名字>.wav（或 <名字>_01~_03 随机挑一个）、assets/audio/music/<名字>.ogg
## 文件不存在就什么都不做，素材放进来就自动生效

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICES := 24          # 最多同时播放多少个音效
const MIN_GAP := 0.05       # 同一个音效两次播放的最短间隔，防止几十只怪同时被打时叠成噪音
const MAX_SAME := 4         # 同一个音效最多同时响几个
const FADE := 1.0           # 音乐切换时的淡入淡出秒数
const ONE_SHOT_MUSIC := ["victory", "defeat"]  # 不循环的音乐

static var _instance: Audio

var _streams := {}   # 名字 -> 可选的 AudioStream 列表（空列表表示没有素材）
var _last_played := {}  # 名字 -> 上次播放的时间
var _voices: Array[AudioStreamPlayer] = []
var _music: Array[AudioStreamPlayer] = []  # 两个播放器交替，用来交叉淡入淡出
var _music_name := ""
var _music_index := 0
var _tweens := {}  # 播放器 -> 正在进行的淡入淡出


static func _shared() -> Audio:
	if _instance == null:
		_instance = Audio.new()
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_instance)
	return _instance


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时界面音效和音乐照常播放
	(Engine.get_main_loop() as SceneTree).node_added.connect(_on_node_added)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_voices.append(player)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		add_child(player)
		_music.append(player)


## 所有按钮按下时都响一声；设了 meta "silent" 的按钮（升级卡）自己放音效
func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button:
		button.pressed.connect(func() -> void:
			if not button.has_meta("silent"):
				sfx("ui_click"))


## 播放音效。pitch 是随机变调的幅度，让重复的声音不那么单调
static func sfx(sound: String, volume_db: float = 0.0, pitch: float = 0.06) -> void:
	_shared()._play_sfx(sound, volume_db, pitch)


static func music(track: String) -> void:
	_shared()._play_music(track)


func _play_sfx(sound: String, volume_db: float, pitch: float) -> void:
	if not is_inside_tree():
		return
	var options := _find(sound, SFX_DIR, ["wav", "ogg"])
	if options.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_played.get(sound, -1.0) < MIN_GAP:
		return
	var same := 0
	var voice: AudioStreamPlayer = null
	for v in _voices:
		if not v.playing:
			voice = v
		elif v.get_meta("sound", "") == sound:
			same += 1
	if voice == null or same >= MAX_SAME:
		return
	_last_played[sound] = now
	voice.stream = options.pick_random()
	voice.volume_db = volume_db
	voice.pitch_scale = randf_range(1.0 - pitch, 1.0 + pitch)
	voice.set_meta("sound", sound)
	voice.play()


## 切换背景音乐（同一首不重新开始）。没有这首的素材时，当前音乐淡出
func _play_music(track: String) -> void:
	if track == _music_name:
		return
	_music_name = track
	var old := _music[_music_index]
	_fade(old, -40.0, true)
	var options := _find(track, MUSIC_DIR, ["ogg", "mp3", "wav"])
	if options.is_empty():
		return
	_music_index = 1 - _music_index
	var player := _music[_music_index]
	var stream: AudioStream = options[0]
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = not ONE_SHOT_MUSIC.has(track)
	player.stream = stream
	player.volume_db = -40.0
	if is_inside_tree():
		player.play()
	else:
		player.play.call_deferred()
	_fade(player, 0.0, false)


func _fade(player: AudioStreamPlayer, to_db: float, stop_after: bool) -> void:
	if _tweens.has(player):
		_tweens[player].kill()
	if stop_after and not player.playing:
		return
	if not is_inside_tree():  # 刚建好、还没进场景树
		player.volume_db = to_db
		return
	var tween := create_tween()
	_tweens[player] = tween
	tween.tween_property(player, "volume_db", to_db, FADE)
	if stop_after:
		tween.tween_callback(player.stop)


func _find(sound: String, dir: String, extensions: Array) -> Array:
	if _streams.has(sound):
		return _streams[sound]
	var found := []
	for ext in extensions:
		for path in [dir + sound + "." + ext, dir + sound + "_01." + ext, dir + sound + "_02." + ext, dir + sound + "_03." + ext]:
			if ResourceLoader.exists(path):
				found.append(load(path))
		if not found.is_empty():
			break
	_streams[sound] = found
	return found
