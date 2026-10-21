extends SceneTree

var output := ""
var level := "midgard"
var sample_time := -1.0
var movie := false

func _initialize():
	call_deferred("run")

func run():
	var language := "zh"
	var dimensions := Vector2i(1280,720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cinematic-export="): level=arg.trim_prefix("--cinematic-export=");movie=true
		if arg.begins_with("--intro-level="): level=arg.trim_prefix("--intro-level=")
		if arg.begins_with("--at="): sample_time=float(arg.trim_prefix("--at="))
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--lang="): language=arg.trim_prefix("--lang=")
		if arg=="--small": dimensions=Vector2i(960,540)
	if root.get_node("Save").path=="user://save.json":quit(2);return
	root.get_node("Settings").change("language",language)
	root.size=dimensions
	var intro=load("res://scripts/ui/chapter_intro.gd").new()
	intro.level_id=level
	root.add_child(intro);current_scene=intro
	if movie:return
	intro.timeline.seek(sample_time,true)
	intro._toggle_pause()
	await process_frame
	await RenderingServer.frame_post_draw
	var result=root.get_texture().get_image().save_png(output)
	print("INTRO_STILL ",level," ",sample_time," ",dimensions," result=",result)
	intro.queue_free()
	await process_frame
	var audio_script=load("res://scripts/core/audio.gd")
	var audio=audio_script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values():tween.kill()
		for child in audio.get_children():
			if child is AudioStreamPlayer:child.stop();child.stream=null
		audio._streams.clear();audio.free();audio_script._instance=null
	quit(result)
