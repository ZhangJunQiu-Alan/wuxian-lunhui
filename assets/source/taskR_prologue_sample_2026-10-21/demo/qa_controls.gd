extends SceneTree

var results := []
var sample
var output := ""

func _initialize():
	call_deferred("run")

func verify(condition, label):
	results.append({"check": label, "passed": condition})
	if not condition: push_error(label)

func key(code):
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	if output.is_empty(): quit(2); return
	sample = load("res://main.tscn").instantiate()
	root.add_child(sample)
	current_scene = sample
	await create_timer(0.4).timeout
	verify(sample.playhead > 0.1 and sample.timeline.is_playing(), "timeline advances in live window")
	verify(sample.soundtrack.playing, "soundtrack starts")
	await key(KEY_SPACE)
	var paused_at = sample.playhead
	await create_timer(0.2).timeout
	verify(is_equal_approx(sample.playhead,paused_at) and sample.soundtrack.stream_paused, "Space pauses picture and soundtrack")
	await key(KEY_R)
	await create_timer(0.2).timeout
	verify(sample.playhead < 0.5 and sample.timeline.is_playing() and not sample.soundtrack.stream_paused, "R restarts from paused state with soundtrack unpaused")
	await key(KEY_SPACE)
	await key(KEY_SPACE)
	await create_timer(0.2).timeout
	verify(sample.timeline.is_playing() and not sample.soundtrack.stream_paused, "Space resumes")
	sample.timeline.seek(8.7,true)
	await key(KEY_SPACE)
	root.size = Vector2i(960,540)
	await process_frame
	await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image().save_png(output.path_join("controls_960x540.png"))
	verify(result == OK and root.size == Vector2i(960,540), "960x540 window renders")
	await key(KEY_ENTER)
	await create_timer(0.2).timeout
	verify(sample.playhead < 0.5 and sample.timeline.is_playing(), "Enter restarts")
	sample.timeline.seek(11.9,true)
	await create_timer(0.3).timeout
	verify(sample.ended and not sample.timeline.is_playing(), "timeline completes and stays on replay screen")
	await key(KEY_R)
	await create_timer(0.2).timeout
	verify(not sample.ended and sample.playhead < 0.5, "replay after completion")
	sample.queue_free()
	await process_frame
	verify(not is_instance_valid(sample), "preview scene freed")
	var file = FileAccess.open(output.path_join("controls.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	var failures = results.filter(func(row): return not row.passed).size()
	print("CONTROLS_RESULT ",results.size()," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
