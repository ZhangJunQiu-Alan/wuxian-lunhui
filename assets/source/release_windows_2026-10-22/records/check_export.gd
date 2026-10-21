extends SceneTree

var checks := 0
var failures := []
var output := ""

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func check(ok, label):
	checks += 1
	if not ok: failures.append(label); push_error(label)

func frames(n := 4):
	for i in n: await process_frame

func files_at(path: String) -> Array:
	var files := []
	for name in DirAccess.get_files_at(path): files.append(path.path_join(name))
	for name in DirAccess.get_directories_at(path): files.append_array(files_at(path.path_join(name)))
	return files

func clear_scene():
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames()

func run():
	var save = root.get_node("Save")
	check(save.path != save.DEFAULT_PATH, "isolated save path")
	if save.path == save.DEFAULT_PATH: quit(2); return
	var entries = files_at("res://")
	for path in entries:
		check(not path.begins_with("res://assets/source/") and not path.begins_with("res://docs/") and not path.begins_with("res://tools/") and not path.begins_with("res://build/"), "no development artifacts " + path)
	var data_path = "res://assets/cinematics/norse/sequences.json"
	check(FileAccess.file_exists(data_path), "cinematic JSON included")
	check(FileAccess.file_exists("res://scripts/data/vigrid_ending_timeline.json"), "ending JSON included")
	check(FileAccess.file_exists("res://assets/LICENSES.md"), "asset credits included")
	var book = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	check(book is Dictionary and book.size() == 3, "three chapter sequences")
	for id in book:
		var sequence = book[id]
		for shot in sequence.shots:
			check(shot.language == "English", "English narration " + id)
		for stem in ["music", "effects", "narration"]:
			var audio = load("res://assets/cinematics/norse/audio/" + id + "_" + stem + ".ogg")
			check(audio is AudioStream and absf(audio.get_length()-sequence.duration)<0.05, "packed audio " + id + "/" + stem)
	change_scene_to_file("res://scenes/title.tscn")
	await frames(8)
	check(current_scene._buttons.size() == 5, "packed title menu")
	await clear_scene()
	change_scene_to_file("res://scenes/hub.tscn")
	await frames(8)
	check(current_scene.scene_file_path == "res://scenes/hub.tscn", "packed hub")
	await clear_scene()
	save.cleared_levels.assign(["midgard", "helheim"])
	var intro = load("res://scripts/ui/chapter_intro.gd")
	for id in ["midgard", "helheim", "vigrid"]:
		save.selected_level = id
		intro.open(self,id)
		await frames(8)
		check(current_scene.level_id == id and not current_scene._textures.is_empty(), "packed intro " + id)
		current_scene._finish(true)
		await frames(8)
		check(current_scene.level_id == id and is_instance_valid(current_scene.player), "packed battle " + id)
		check(current_scene.elapsed == 0, "initial selection pauses packed battle " + id)
		await clear_scene()
	var audio_script = load("res://scripts/core/audio.gd")
	var audio = audio_script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values(): tween.kill()
		for child in audio.get_children():
			if child is AudioStreamPlayer: child.stop(); child.stream=null
		audio._streams.clear(); audio.free(); audio_script._instance=null
	await create_timer(0.2).timeout
	var result = {"checks":checks,"failures":failures,"pack_file_entries":entries.size(),"scope":"Windows-target PCK tested with macOS Godot 4.7.2; not Windows executable execution"}
	if not output.is_empty(): FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("EXPORT_PACK_RESULT ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
