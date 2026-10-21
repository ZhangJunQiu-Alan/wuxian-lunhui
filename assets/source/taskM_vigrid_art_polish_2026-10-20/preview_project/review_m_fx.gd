extends "res://tools/review_m_terrain.gd"

func _run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):
            _out = arg.trim_prefix("--output=")
    if _out == "" or root.get_node("Save").path == "user://save.json":
        get_tree().quit(2)
        return
    DirAccess.make_dir_recursive_absolute(_out)
    var save = root.get_node("Save")
    save.reset()
    save.cleared_levels.assign(["midgard", "helheim"])
    save.selected_level = "vigrid"
    await _resize(Vector2i(1280,720))
    await _new_game()
    _quiet_player()
    for i in 10:
        var enemy = _game.spawn_enemy("dead", Vector2.from_angle(TAU * i / 10) * 120 + Vector2(35, 0))
        if enemy:
            enemy.process_mode = Node.PROCESS_MODE_DISABLED
    var boss = await _spawn_boss(2)
    boss.position = Vector2(240,0)
    boss._sweep_dir = Vector2.LEFT
    boss.change_state("sweep_windup")
    boss.state_time = .7
    boss.queue_redraw()
    _game.process_mode = Node.PROCESS_MODE_DISABLED
    var overlay = load("res://tools/m_art_overlay.gd").new()
    overlay.arc = true
    overlay.z_index = 31
    overlay.position = boss.position
    _game.add_child(overlay)
    for f in 4:
        overlay.frame = f
        overlay.guide = false
        overlay.queue_redraw()
        await _shot("surtr_arc_f%d" % (f+1), "actual Game, new 640px arc 1x through BossFx, native 320px body, frozen controlled warning pose")
    overlay.frame = 1
    overlay.guide = true
    overlay.queue_redraw()
    await _shot("surtr_arc_sector_overlay", "cyan R290 half1.05 geometry, native 1x arc; no gameplay approval")
    overlay.queue_free()
    await get_tree().process_frame
    for god in ["freyja", "baldr", "ran", "skadi"]:
        overlay = load("res://tools/m_art_overlay.gd").new()
        overlay.effect = "aid_" + god
        overlay.radius = 140.0 if god == "freyja" else (110.0 if god == "baldr" else 130.0)
        overlay.z_index = 31
        overlay.position = _player.position if god == "freyja" else Vector2(35,0)
        _game.add_child(overlay)
        for f in 8:
            overlay.frame = f
            overlay.guide = false
            overlay.queue_redraw()
            await _shot("%s_f%d" % [overlay.effect, f+1], "actual Game backdrop; 10 frozen enemies, actual Surtr orange warning; aid pixels rendered native1x with review-only renderer; production dispatch pending")
        overlay.frame = 4
        overlay.guide = true
        overlay.queue_redraw()
        await _shot("%s_radius" % overlay.effect, "green dashed ring = requested gameplay radius; review-only overlay")
        overlay.queue_free()
        await get_tree().process_frame
    var file = FileAccess.open(_out.path_join("captures.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify({"scope":"controlled visual review in isolated actual Game; aid uses explicit review renderer, no automatic triggering or full-play QA", "captures":_shots}, "  "))
    file.close()
    _game.queue_free()
    await get_tree().process_frame
    var audio = Audio._instance
    if is_instance_valid(audio):
        for tween in audio._tweens.values(): tween.kill()
        for child in audio.get_children():
            if child is AudioStreamPlayer:
                child.stop()
                child.stream = null
        audio._streams.clear()
        audio.free()
        Audio._instance = null
    await get_tree().process_frame
    get_tree().quit()

func _quiet_player() -> void:
    _game.pause_menu.close()
    _game.pause_menu.free()
    _game.set_process_unhandled_input(false)
    for weapon in [_player.katana, _player.revolver, _player.blades, _player.nova]:
        if weapon: weapon.process_mode = Node.PROCESS_MODE_DISABLED
    for power in _player.gods.values():
        power.process_mode = Node.PROCESS_MODE_DISABLED
        power.visible = false
    if is_instance_valid(FxLayer.instance):
        for field in ["_numbers", "_particles", "_marks", "_rings", "_boss_effects"]:
            FxLayer.instance.get(field).clear()
        FxLayer.instance.queue_redraw()

func _shot(name: String, note: String) -> void:
    if is_instance_valid(_game.pause_menu):
        _game.pause_menu.close()
        _game.pause_menu.hide()
    get_tree().paused = false
    await super._shot(name, note)
