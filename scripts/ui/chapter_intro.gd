class_name ChapterIntro
extends Control

signal sequence_finished(level: String, skipped: bool)

const ROOT := "res://assets/cinematics/norse/"
const DATA := ROOT + "sequences.json"
const BATTLE := "res://scenes/main.tscn"
const HUB := "res://scenes/hub.tscn"
const SCENE := "res://scenes/chapter_intro.tscn"
const CANVAS := Vector2(1280, 720)
const FONT = preload("res://assets/fonts/NotoSansSC-Regular.otf")

static var _requested_level := ""
static var _requested_replay := false

var level_id := ""
var replay_only := false
var playhead := 0.0
var duration := 0.0
var timeline: AnimationPlayer
var music: AudioStreamPlayer
var effects: AudioStreamPlayer
var narration: AudioStreamPlayer
var _sequence := {}
var _textures := {}
var _particles := []
var _leaving := false
var _user_paused := false
var _focus_paused := false
var _pause_button: Button
var _exporting := false


static func open(tree: SceneTree, id: String, replay := false) -> void:
	if tree == null or not _requested_level.is_empty(): return
	_requested_level = id
	_requested_replay = replay
	tree.change_scene_to_file(SCENE)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if level_id.is_empty():
		level_id = _requested_level if not _requested_level.is_empty() else LevelDB.selected()
		replay_only = _requested_replay
	_requested_level = ""
	_requested_replay = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cinematic-export="):
			level_id = arg.trim_prefix("--cinematic-export=")
			_exporting = true
	var book: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not book.has(level_id):
		push_error("Missing chapter intro: " + level_id)
		_finish.call_deferred(true)
		return
	_sequence = book[level_id]
	duration = float(_sequence.duration)
	for shot: Dictionary in _sequence.shots:
		var art: String = shot.art
		if art == "village":
			for name in ["village_bg", "village_fg"]: _textures[name] = load(ROOT + "art/" + name + ".png")
		elif art == "wolf_sky":
			for name in ["sky_bg", "sun", "skoll", "hati"]: _textures[name] = load(ROOT + "art/" + name + ".png")
		else:
			_textures[art] = load(ROOT + "art/" + art + ".png")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261021
	for i in 120:
		_particles.append(Vector4(rng.randf_range(-100,1380),rng.randf_range(-100,820),rng.randf_range(10,27),rng.randf_range(0.5,1.6)))
	timeline = AnimationPlayer.new()
	add_child(timeline)
	var animation := Animation.new()
	animation.length = duration
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(".:playhead"))
	animation.track_insert_key(track, 0.0, 0.0)
	animation.track_insert_key(track, duration, duration)
	var library := AnimationLibrary.new()
	library.add_animation("intro", animation)
	timeline.add_animation_library("", library)
	timeline.animation_finished.connect(func(_name: StringName) -> void: _finish(false))
	Audio.music("")
	music = _audio("music", "Music")
	effects = _audio("effects", "SFX")
	narration = _audio("narration", "SFX")
	if not _exporting: _controls()
	timeline.play("intro")
	for player in [music,effects,narration]: player.play()


func _audio(stem: String, bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	player.stream = load(ROOT + "audio/" + level_id + "_" + stem + ".ogg")
	add_child(player)
	return player


func _controls() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	row.offset_left = -330
	row.offset_right = -24
	row.offset_top = 20
	row.add_theme_constant_override("separation",12)
	add_child(row)
	_pause_button = Button.new()
	_pause_button.text = tr("暂停 [Space]")
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.pressed.connect(_toggle_pause)
	row.add_child(_pause_button)
	var skip := Button.new()
	skip.text = tr("跳过 [Esc]")
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(func() -> void: _finish(true))
	row.add_child(skip)
	for button: Button in [_pause_button,skip]:
		button.custom_minimum_size = Vector2(145,36)
		button.add_theme_font_size_override("font_size",15)
		button.set_meta("silent",true)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.025,0.035,0.05,0.68)
		style.set_content_margin_all(6)
		button.add_theme_stylebox_override("normal",style)
		button.add_theme_color_override("font_color",Color(0.78,0.80,0.79))


func _process(_delta: float) -> void:
	queue_redraw()
	if _exporting: RenderingServer.force_draw.call_deferred(false)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _exporting or playhead < 0.35: return
	if event is InputEventKey:
		if not event.pressed or event.echo: return
		if event.keycode == KEY_SPACE:
			_toggle_pause()
		elif event.keycode in [KEY_ESCAPE,KEY_ENTER,KEY_KP_ENTER]:
			_finish(true)
		else: return
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START: _toggle_pause()
		elif event.button_index in [JOY_BUTTON_A,JOY_BUTTON_B]: _finish(true)
		else: return
	else: return
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if _exporting or not is_instance_valid(timeline) or _leaving: return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focus_paused = true
		_apply_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focus_paused = false
		_apply_pause()


func _toggle_pause() -> void:
	_user_paused = not _user_paused
	_apply_pause()


func _apply_pause() -> void:
	var stopped := _user_paused or _focus_paused
	if stopped: timeline.pause()
	else: timeline.play()
	for player in [music,effects,narration]: player.stream_paused = stopped
	if is_instance_valid(_pause_button):
		_pause_button.text = tr("继续 [Space]") if stopped else tr("暂停 [Space]")


func _finish(skipped: bool) -> void:
	if _leaving: return
	if _exporting: print("CINEMATIC_EXPORT_DONE ",level_id," time=",playhead," frames=",Engine.get_frames_drawn())
	_leaving = true
	if is_instance_valid(timeline): timeline.stop()
	for player in [music,effects,narration]:
		if is_instance_valid(player): player.stop()
	sequence_finished.emit(level_id,skipped)
	if _exporting:
		get_tree().quit()
	else:
		get_tree().change_scene_to_file.call_deferred(HUB if replay_only else BATTLE)


func _plate(texture: Texture2D, zoom: float, pan: Vector2, tint: Color) -> void:
	var scale_factor := maxf(CANVAS.x/texture.get_width(),CANVAS.y/texture.get_height())*zoom
	var dimensions := texture.get_size()*scale_factor
	draw_texture_rect(texture,Rect2((CANVAS-dimensions)/2+pan,dimensions),false,tint)


func _shot(shot: Dictionary, opacity: float) -> void:
	var progress := clampf((playhead-float(shot.start))/(float(shot.end)-float(shot.start)),0,1)
	var art: String = shot.art
	if art == "village":
		_plate(_textures.village_bg,lerpf(1.015,1.065,progress),Vector2(lerpf(7,-7,progress),3),Color(0.83,0.87,0.94,opacity))
		var fg: Texture2D = _textures.village_fg
		var width := lerpf(670,710,progress)
		draw_texture_rect(fg,Rect2(Vector2(lerpf(-160,-200,progress),590),Vector2(width,width*fg.get_height()/fg.get_width())),false,Color(0.65,0.72,0.82,opacity))
	elif art == "wolf_sky":
		var eclipse := smoothstep(0.55,0.95,progress)
		var exposure := lerpf(0.85,0.4,eclipse)
		_plate(_textures.sky_bg,lerpf(1.02,1.06,progress),Vector2(0,4),Color(exposure*0.87,exposure*0.94,exposure,opacity))
		var moonlight := (1-smoothstep(0.70,0.98,progress))*opacity
		draw_texture_rect(_textures.sun,Rect2(507,62,66,66),false,Color(0.65,0.80,1.0,moonlight*0.8))
		var hati: Texture2D = _textures.hati
		draw_texture_rect(hati,Rect2(Vector2(lerpf(70,140,progress),20),Vector2(420,420.0*hati.get_height()/hati.get_width())),false,Color(0.48,0.54,0.65,opacity*0.88))
		var sunlight := (1-smoothstep(0.65,0.92,progress))*opacity
		draw_texture_rect(_textures.sun,Rect2(990,170,100,100),false,Color(1,0.94,0.82,sunlight))
		var wolf: Texture2D = _textures.skoll
		var light := lerpf(0.56,0.28,eclipse)
		draw_texture_rect(wolf,Rect2(Vector2(lerpf(-110,62,smoothstep(0,1,progress)),20),Vector2(1050,1050.0*wolf.get_height()/wolf.get_width())),false,Color(light*0.90,light*0.96,light,opacity))
	else:
		var zoom := lerpf(1.005,1.055,progress)
		if art == "midgard_hrym": zoom = 1.0
		var exposure := 0.90 if level_id == "midgard" else 0.88
		_plate(_textures[art],zoom,Vector2.ZERO,Color(exposure,exposure*1.01,exposure*1.04,opacity))


func _center(value: String, y: float, font_size: int, color: Color) -> void:
	var lines := value.split("\n")
	for i in lines.size():
		var width := FONT.get_string_size(lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var pos := Vector2((CANVAS.x-width)/2,y+i*(font_size+9))
		draw_string_outline(FONT,pos,lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,4,Color(0.015,0.02,0.03,color.a*0.92))
		draw_string(FONT,pos,lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.008,0.012,0.02))
	if _sequence.is_empty(): return
	var scale_factor := minf(size.x/CANVAS.x,size.y/CANVAS.y)
	draw_set_transform((size-CANVAS*scale_factor)/2,0,Vector2.ONE*scale_factor)
	for i in _sequence.shots.size():
		var shot: Dictionary = _sequence.shots[i]
		if playhead < float(shot.start) or playhead > float(shot.end): continue
		_shot(shot,1.0 if i == 0 else smoothstep(float(shot.start),float(shot.start)+1.2,playhead))
	for i in _particles.size():
		var point: Vector4 = _particles[i]
		var t := playhead
		var ash := level_id == "vigrid"
		var x := fposmod(point.x+t*point.z*0.7,1480)-100
		var y := fposmod(point.y+t*point.z*(-0.8 if ash else 1.0),920)-100
		var color := Color(0.88,0.42,0.18,0.23) if ash and i%7==0 else Color(0.72,0.78,0.84,0.10)
		draw_line(Vector2(x,y),Vector2(x+1,y+2),color,point.w,true)
	for row in 155:
		draw_rect(Rect2(0,565+row,1280,1),Color(0.012,0.018,0.027,float(row)/155*0.87))
	var title_alpha := smoothstep(0.8,1.5,playhead)*(1-smoothstep(3.8,4.6,playhead))
	if title_alpha > 0:
		var prefix := tr("第 %d 关") % int(_sequence.index)
		draw_string_outline(FONT,Vector2(65,105),prefix,HORIZONTAL_ALIGNMENT_LEFT,-1,18,3,Color(0,0,0,title_alpha))
		draw_string(FONT,Vector2(65,105),prefix,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(0.78,0.73,0.61,title_alpha))
		draw_string_outline(FONT,Vector2(65,155),tr(_sequence.title),HORIZONTAL_ALIGNMENT_LEFT,-1,36,4,Color(0,0,0,title_alpha))
		draw_string(FONT,Vector2(65,155),tr(_sequence.title),HORIZONTAL_ALIGNMENT_LEFT,-1,36,Color(0.92,0.90,0.84,title_alpha))
	for shot: Dictionary in _sequence.shots:
		var start := float(shot.caption_start)
		var end := float(shot.caption_end)
		var alpha := smoothstep(start,start+0.35,playhead)*(1-smoothstep(end-0.35,end,playhead))
		if alpha > 0:
			var text := tr(str(shot.caption))
			_center(text,641 if text.contains("\n") else 662,24,Color(0.92,0.91,0.86,alpha))
	var blackout := maxf(1-smoothstep(0,0.8,playhead),smoothstep(duration-0.9,duration,playhead))
	if blackout > 0: draw_rect(Rect2(Vector2.ZERO,CANVAS),Color(0.008,0.012,0.02,blackout))
