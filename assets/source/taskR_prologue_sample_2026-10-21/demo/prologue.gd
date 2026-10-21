extends Node2D

const DURATION := 12.0
const FPS := 24
const SIZE := Vector2(1280, 720)
const VILLAGE = preload("res://art/village_bg.png")
const FOREGROUND = preload("res://art/village_fg.png")
const SKY = preload("res://art/sky_bg.png")
const WOLF = preload("res://art/skoll.png")
const SUN = preload("res://art/sun.png")
const FONT = preload("res://fonts/NotoSansSC-Regular.otf")

var playhead := 0.0
var timeline: AnimationPlayer
var soundtrack: AudioStreamPlayer
var snowfall := []
var capture_dir := ""
var still_time := -1.0
var screenshot_path := ""
var ended := false
var report_path := ""

func _ready():
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
		if arg.begins_with("--at="): still_time = float(arg.trim_prefix("--at="))
		if arg.begins_with("--screenshot="): screenshot_path = arg.trim_prefix("--screenshot=")
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261021
	for i in range(170):
		snowfall.append(Vector4(rng.randf_range(-100, 1380), rng.randf_range(-100, 820), rng.randf_range(10, 28), rng.randf_range(0.5, 1.4)))
	timeline = AnimationPlayer.new()
	timeline.name = "Timeline"
	add_child(timeline)
	var animation := Animation.new()
	animation.length = DURATION
	var track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(".:playhead"))
	animation.track_insert_key(track, 0.0, 0.0)
	animation.track_insert_key(track, DURATION, DURATION)
	var library := AnimationLibrary.new()
	library.add_animation("prologue", animation)
	timeline.add_animation_library("", library)
	timeline.animation_finished.connect(_finished)
	soundtrack = AudioStreamPlayer.new()
	soundtrack.stream = preload("res://audio/sample_mix.wav")
	add_child(soundtrack)
	if not capture_dir.is_empty():
		_capture.call_deferred()
	elif still_time >= 0:
		_still.call_deferred()
	else:
		replay()

func replay():
	ended = false
	playhead = 0.0
	timeline.play("prologue")
	timeline.seek(0.0, true)
	soundtrack.stream_paused = false
	soundtrack.play()

func _process(_delta):
	queue_redraw()

func _unhandled_key_input(event):
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif event.keycode in [KEY_R, KEY_ENTER]:
		replay()
	elif event.keycode == KEY_SPACE:
		if timeline.is_playing():
			timeline.pause()
			soundtrack.stream_paused = true
		elif ended:
			replay()
		else:
			timeline.play()
			soundtrack.stream_paused = false

func _finished(_name):
	ended = true
	if not report_path.is_empty():
		var file = FileAccess.open(report_path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"completed": true, "playhead": playhead, "duration": DURATION, "viewport": [1280,720], "rendered_frames": Engine.get_frames_drawn()}, "\t"))
		get_tree().quit()

func _capture():
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var errors := []
	for frame in range(int(DURATION * FPS)):
		playhead = float(frame) / FPS
		queue_redraw()
		await RenderingServer.frame_post_draw
		var path = capture_dir.path_join("frame_%04d.png" % frame)
		var result = get_viewport().get_texture().get_image().save_png(path)
		if result != OK: errors.append({"frame": frame, "error": result})
		if frame % FPS == 0: print("CAPTURE_SECOND ", frame / FPS)
	var file = FileAccess.open(capture_dir.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames": int(DURATION * FPS), "fps": FPS, "size": [1280,720], "errors": errors}, "\t"))
	print("CAPTURE_DONE ", DURATION * FPS, " errors=", errors.size())
	get_tree().quit(0 if errors.is_empty() else 1)

func _still():
	playhead = clampf(still_time, 0, DURATION)
	queue_redraw()
	await RenderingServer.frame_post_draw
	var result = get_viewport().get_texture().get_image().save_png(screenshot_path)
	print("STILL ", playhead, " result=", result)
	get_tree().quit(result)

func plate(texture, zoom, pan, tint):
	var factor = maxf(SIZE.x / texture.get_width(), SIZE.y / texture.get_height()) * zoom
	var dimensions = texture.get_size() * factor
	draw_texture_rect(texture, Rect2((SIZE - dimensions) / 2 + pan, dimensions), false, tint)

func blend_at(a, b, value):
	return smoothstep(a, b, value)

func text_center(value, y, size, color):
	var width = FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos = Vector2((SIZE.x - width) / 2, y)
	draw_string_outline(FONT, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.025,0.032,0.045,color.a * 0.9))
	draw_string(FONT, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func subtitle(value, start, finish):
	var alpha = blend_at(start, start + 0.45, playhead) * (1.0 - blend_at(finish - 0.4, finish, playhead))
	if alpha > 0: text_center(value, 659, 26, Color(0.90,0.89,0.85,alpha))

func _draw():
	var t = playhead
	var dissolve = blend_at(5.25, 6.55, t)
	var winter_progress = clampf(t / 6.5, 0, 1)
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.04,0.055,0.075))
	plate(VILLAGE, lerpf(1.025, 1.09, winter_progress), Vector2(lerpf(12,-8,winter_progress),lerpf(3,12,winter_progress)), Color(0.80,0.84,0.91))
	var fg_width = lerpf(670, 730, winter_progress)
	var fg_size = Vector2(fg_width, fg_width * FOREGROUND.get_height() / FOREGROUND.get_width())
	draw_texture_rect(FOREGROUND, Rect2(Vector2(lerpf(-160,-210,winter_progress), 580),fg_size), false, Color(0.62,0.69,0.79))
	if dissolve > 0:
		var progress = clampf((t - 5.3) / 6.7, 0, 1)
		var eclipse = blend_at(9.0, 10.9, t)
		var exposure = lerpf(0.86, 0.36, eclipse)
		plate(SKY, lerpf(1.065,1.11,progress), Vector2(lerpf(8,-14,progress),lerpf(7,15,progress)), Color(exposure * 0.86,exposure * 0.92,exposure,dissolve))
		var sun = Vector2(1040,220)
		var sunlight = (1.0 - blend_at(9.75,10.7,t)) * dissolve
		draw_texture_rect(SUN,Rect2(sun-Vector2(50,50),Vector2(100,100)),false,Color(1.0,0.94,0.82,sunlight))
		var wolf_x = lerpf(-110,62,blend_at(5.8,11.2,t))
		var wolf_size = Vector2(1050, 1050.0 * WOLF.get_height() / WOLF.get_width())
		var wolf_exposure = lerpf(0.56,0.26,eclipse)
		draw_texture_rect(WOLF, Rect2(Vector2(wolf_x,20),wolf_size),false,Color(wolf_exposure * 0.90,wolf_exposure * 0.96,wolf_exposure,dissolve * blend_at(5.7,6.8,t)))
	for i in range(snowfall.size()):
		var flake = snowfall[i]
		var near = i > 143
		var speed = flake.z * (2.4 if near else 1.0)
		var x = fposmod(flake.x + t * speed * 0.65, 1480) - 100
		var y = fposmod(flake.y + t * speed, 920) - 100
		var opacity = (0.22 if near else 0.095) * lerpf(1.0,0.5,dissolve)
		draw_line(Vector2(x,y), Vector2(x + (2.4 if near else 0.5),y + (3.4 if near else 0.8)),Color(0.77,0.83,0.88,opacity),flake.w,true)
	# Soft edge shade and a reserved subtitle band are drawn separately from the art.
	for edge in range(28):
		var a = 0.006
		draw_rect(Rect2(edge * 2,0,2,SIZE.y),Color(0.01,0.02,0.035,a * (28-edge)))
		draw_rect(Rect2(SIZE.x-edge * 2-2,0,2,SIZE.y),Color(0.01,0.02,0.035,a * (28-edge)))
	for row in range(140):
		draw_rect(Rect2(0,580+row,SIZE.x,1),Color(0.015,0.022,0.033,float(row)/140*0.88))
	draw_rect(Rect2(0,0,SIZE.x,35),Color(0.013,0.018,0.025))
	draw_rect(Rect2(0,685,SIZE.x,35),Color(0.013,0.018,0.025))
	subtitle("第三个没有夏天的冬季。",0.9,5.65)
	subtitle("巨狼追上了最后的太阳。",6.5,11.35)
	var blackout = maxf(1.0-blend_at(0,0.8,t),blend_at(11.25,12.0,t))
	if blackout > 0: draw_rect(Rect2(Vector2.ZERO,SIZE),Color(0.008,0.012,0.02,blackout))
	if ended and report_path.is_empty() and capture_dir.is_empty():
		text_center("R / Enter 重播    Space 暂停    Esc 退出",370,18,Color(0.68,0.72,0.77))
