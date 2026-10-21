extends "res://tools/acceptance_vigrid_visual.gd"

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _out=arg.trim_prefix("--output=")
	var save=root.get_node("Save")
	if save.path==save.DEFAULT_PATH or _out.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	save.reset()
	save.cleared_levels.assign(["midgard","helheim"])
	save.selected_level="vigrid"
	await _resize(Vector2i(1280,720))
	await _fixture()
	_player.add_god("baldr")
	var light=_player.gods.baldr
	light.path="baldr_daylight"
	light.awakened=true
	light.stats={"baldr_prism":2,"baldr_radiance":100.0,"baldr_afterglow":2.0}
	light._process(1.4)
	_settle_hits()
	await _shot("daylight_firing","Actual Game renderer: rotating beam burst, 5 rays, 3s firing duration")
	light._process(1.7)
	await process_frame
	await _shot("daylight_hidden_cd","After 3s: rays and owned glow trails gone; 4s cooldown, internal angle still rotating")
	light._process(4.0)
	_settle_hits()
	await _shot("daylight_firing_again","Cooldown ends: rays fire from the advanced internal rotation angle")
	await _fixture()
	_player.add_god("odin")
	var rune=_player.gods.odin
	rune.path="odin_nights"
	rune.stats={"odin_resonance":300.0}
	for enemy in get_nodes_in_group("enemies"): rune.detonate(enemy)
	var fx=load("res://scripts/effects/fx_layer.gd").instance
	fx._process(0.22)
	_settle_hits()
	await _shot("rune_rings_compact","80 enemies with actual resonance detonations: white rings radius<=48, alpha .45, maximum24; damage reach300 unchanged")
	await _fixture()
	_player.add_god("skadi")
	var snow=_player.gods.skadi
	snow.path="skadi_winter"
	snow.awakened=true
	snow._process(1.0)
	_settle_hits()
	await _shot("winter_compact","Awakened winter: visual radius128 and alpha .28; actual damage radius700 preserved")
	var file=FileAccess.open(_out.path_join("captures.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"actual Game renderer, controlled positions, invincible, muted, manually advanced god phases; no natural-clear claim","captures":_shots},"\t"))
	file.close()
	_game.queue_free()
	await process_frame
	var audio_script=load("res://scripts/core/audio.gd")
	var audio=audio_script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values(): tween.kill()
		for child in audio.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream=null
		audio._streams.clear()
		audio.free()
		audio_script._instance=null
	load("res://scripts/world/vigrid_map.gd").fire_material=null
	await process_frame
	OS.delay_msec(200)
	print("GOD_FX_REVIEW_DONE ",_shots.size()," captures")
	quit()

func _fixture() -> void:
	await _new_game()
	_game.process_mode=Node.PROCESS_MODE_DISABLED
	for god in _player.gods.values(): god.free()
	_player.gods.clear()
	_player.faith.clear()
	_player.cooldown_mult=1.0
	_player.god_cooldown_mult=1.0
	_player.damage_mult=1.0
	_teleport(Vector2.ZERO)
	for i in 80:
		var enemy=_game.spawn_enemy("dead",Vector2(130+(i%10)*38,-150+(i/10)*40))
		enemy.hp=100000
		enemy.max_hp=100000

func _settle_hits() -> void:
	_game.hud.set_faith(_player)
	for enemy in get_nodes_in_group("enemies"):
		enemy._flash_time=0.0
		enemy.queue_redraw()
