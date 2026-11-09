class_name SwordsmanWeapon
extends Katana

const FOUR := ["zhu", "lu", "xian", "jue"]
const IAI_CHARGE := 4.0
const LINK_LENGTH := 450.0
const ACTIVE_SKILLS := ["qinglong", "higekiri", "excalibur", "ganjiang_moye", "riyue", "chunyang"]
const STATUS_ICONS := {
	"higekiri": "higekiri_oni_gauge", "excalibur": "excalibur_charge",
}

var kit_id := "katana"
var art: SwordsmanArt
var fx: SwordsmanEffects

var _clock := 0.0
var _skill_cd := 0.0
var _windup := 0.0
var _strike := Callable()
var _strike_action := &"attack"
var _variant := ""
var _next_variant := ""
var _off_turn := false
var _chain := 0
var _chain_time := 0.0
var _thirst := 0.0
var _oni := 0.0
var _oni_time := 0.0
var _exhaust := 0.0
var _spin := 0.0
var _spinning := false
var _spin_audio: AudioStreamPlayer
var _spin_tick := 0.0
var _avatar := 0.0
var _iai := -1.0
var _drinks := 0
var _drink_time := 0.0
var _dodge_cd := 0.0
var _moye_state := ""
var _moye_time := 0.0
var _moye_at := Vector2.ZERO
var _moye_from := Vector2.ZERO
var _moye_to := Vector2.ZERO
var _moye_sprite: Sprite2D
var _areas: Array[Dictionary] = []
var _waves: Array[Dictionary] = []
var _bleeds: Array[Dictionary] = []
var _skill_keys := {}
var _overlay: Node2D


func _ready() -> void:
	super._ready()
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx = SwordsmanEffects.new()
	fx.z_index = 2
	add_child(fx)
	_overlay = Node2D.new()
	_overlay.z_index = 3
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_variant = "sun" if kit_id == "riyue" else ("zhu" if kit_id == "zhuxian" else "")
	_next_variant = _variant
	if kit_id == "qinglong":
		_spin_audio = AudioStreamPlayer.new()
		_spin_audio.bus = &"SFX"
		_spin_audio.volume_db = -10.0
		var source := load(Audio.SFX_DIR + "qinglong_spin_loop.wav") as AudioStreamWAV
		if source:
			var loop := source.duplicate() as AudioStreamWAV
			loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
			_spin_audio.stream = loop
		add_child(_spin_audio)
	if kit_id == "ganjiang_moye":
		_moye_sprite = Sprite2D.new()
		_moye_sprite.z_index = 2
		_moye_sprite.hide()
		add_child(_moye_sprite)
	sync_art()


func sync_art() -> void:
	if art:
		var spin_angle := _spin * (250.0 + _spin * 90.0) if _spinning else _clock * 460.0
		art.render(_variant, _moye_state != "", _chain >= 3 or _thirst > 0.0 or _oni_time > 0.0 or _iai >= IAI_CHARGE, spin_angle)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_skill_keys.clear()
		_stop_spin()


func _stop_spin() -> void:
	if _spinning:
		_spinning = false
		_spin_audio.stop()


func _process(delta: float) -> void:
	if player.is_dead or player.is_hurt():
		_stop_spin()
	if player.is_dead:
		if is_instance_valid(_moye_sprite):
			_moye_sprite.hide()
		queue_redraw()
		_overlay.queue_redraw()
		return
	_clock += delta
	_timer -= delta
	_skill_cd = maxf(0.0, _skill_cd - delta)
	_tick_states(delta)
	_tick_areas(delta)
	_tick_projectiles(delta)
	if _strike.is_valid():
		_windup -= delta
		if (player.is_hurt() and _strike_action != &"iai_dash") or (player.is_dashing() and _strike_action not in [&"iai_dash", &"thrust"]):
			_strike = Callable()
		elif _windup <= 0.0:
			var resolve := _strike
			_strike = Callable()
			resolve.call()
	if _timer <= 0.0 and not _strike.is_valid() and not _spinning and kit_id != "excalibur" \
			and not player.is_hurt() and not player.is_dashing() and not player.weapon_pose_active():
		_auto_attack()
	sync_art()
	queue_redraw()
	_overlay.queue_redraw()


func _start_pose(action: StringName, aim: Vector2, hit: Callable, delay: float) -> void:
	player.play_attack(aim, 7.0, maxf(0.0, _timer), action)
	_strike_action = action
	_windup = delay / player.weapon_pose_speed()
	_strike = hit
	sync_art()


func _auto_attack() -> void:
	var effect_id := kit_id + "_slash"
	var action := &"attack"
	match kit_id:
		"qinglong":
			effect_id = "qinglong_sweep_360" if _avatar > 0.0 else "qinglong_sweep"
		"higekiri":
			if _oni_time > 0.0:
				effect_id = "higekiri_oni_slash"
		"zhuxian":
			effect_id = "zhuxian_slash_" + _next_variant
		"ganjiang_moye":
			effect_id = "moye_slash" if _off_turn and _moye_state == "" else "ganjiang_slash"
			action = &"off_attack" if effect_id == "moye_slash" else &"attack"
		"riyue":
			effect_id = "riyue_moon_thrust" if _next_variant == "moon" else "riyue_sun_sweep"
			action = &"thrust" if _next_variant == "moon" else &"attack"
	var radius := _radius(effect_id)
	var aim := _nearest_aim(radius)
	if aim == Vector2.ZERO:
		return
	var interval := 1.0
	match kit_id:
		"muramasa":
			interval = 1.0 / (1.0 + _chain * 0.18) if _thirst <= 0.0 else 1.28
		"monohoshizao", "qinglong":
			interval = 1.22
		"higekiri":
			interval = 1.3 if _exhaust > 0.0 else (0.85 if _oni_time > 0.0 else 1.0)
		"chunyang":
			interval = 0.8 if _drinks >= 2 else 1.0
	_timer = cooldown * player.weapon_cooldown() * interval
	if kit_id == "zhuxian":
		_variant = _next_variant
		_next_variant = FOUR[(FOUR.find(_variant) + 1) % FOUR.size()]
	elif kit_id == "riyue":
		if _variant != _next_variant:
			_swap(_next_variant)
		_next_variant = "moon" if _variant == "sun" else "sun"
	elif kit_id == "ganjiang_moye" and _moye_state == "":
		_off_turn = not _off_turn
	_start_pose(action, aim, _normal_strike.bind(effect_id, aim, radius), 0.10)


func _radius(id: String) -> float:
	return float(SwordsmanArt.effects()[id].radius) * reach / 110.0


func _nearest_aim(radius: float) -> Vector2:
	var target: Enemy
	var best := INF
	for enemy in Enemy.query_radius(global_position, radius):
		var distance := enemy.global_position.distance_to(global_position) - enemy.radius
		if distance < best:
			best = distance
			target = enemy
	if not target:
		return Vector2.ZERO
	var aim := global_position.direction_to(target.global_position)
	return player.facing if aim == Vector2.ZERO else aim


func _manual_aim(radius: float) -> Vector2:
	var aim := _nearest_aim(radius)
	return player.facing if aim == Vector2.ZERO else aim


func _normal_strike(effect_id: String, aim: Vector2, radius: float) -> void:
	_slash_count += 1
	_niten = _slash_count % 4 == 0
	_sweep_sign = -_sweep_sign
	Audio.sfx("katana_slash", -3.0)
	_fan(effect_id, aim, radius, 2.0 if _niten else 1.0, true)
	if kit_id == "duanshui":
		_areas.append({"at": global_position, "aim": aim, "radius": radius, "age": 0.0, "tick": 0.0})
		fx.play("duanshui_scar", global_position, aim, radius / 110.0, 3.65)
		Audio.sfx("duanshui_scar", -7.0)
	if kit_id == "chunyang" and _drinks >= 1:
		_waves.append({"from": global_position, "aim": aim, "distance": 0.0, "hits": {}})


func _fan(id: String, aim: Vector2, radius: float, strength: float, normal := false) -> void:
	var effect: Dictionary = SwordsmanArt.effects()[id]
	var half := deg_to_rad(float(effect.angle) * 0.5)
	var ratio := radius / float(effect.radius)
	fx.play(id, global_position, aim, ratio, 0.0, 0.0, null, 0.0, _sweep_sign < 0.0)
	var both := normal and (back_slash or _niten) and half < PI
	if both:
		fx.play(id, global_position, -aim, ratio, 0.0, 0.0, null, 0.0, _sweep_sign > 0.0)
	var killed := 0
	var hit_any := false
	for enemy in Enemy.query_radius(global_position, radius):
		var offset := enemy.global_position - global_position
		if offset != Vector2.ZERO and absf(aim.angle_to(offset)) > half and (not both or absf((-aim).angle_to(offset)) > half):
			continue
		var hit_strength := strength
		if normal:
			hit_strength *= _normal_modifier(enemy, offset.length(), radius)
		_hit(enemy, hit_strength, offset.normalized(), normal and _niten)
		if normal and _oni_time > 0.0 and is_instance_valid(enemy) and enemy.hp > 0.0:
			_hit(enemy, hit_strength * 0.65, offset.normalized(), _niten)
		if enemy.hp <= 0.0:
			killed += 1
		hit_any = true
	if normal and kit_id == "muramasa" and killed > 0:
		_chain = mini(5, _chain + killed)
		_chain_time = 2.8
		_thirst = 0.0
	if normal and kit_id == "higekiri" and hit_any and _oni_time <= 0.0 and _exhaust <= 0.0:
		_oni = minf(1.0, _oni + 0.25)


func _normal_modifier(enemy: Enemy, distance: float, radius: float) -> float:
	var at := enemy.global_position
	match kit_id:
		"monohoshizao":
			if distance >= radius * 2.0 / 3.0:
				fx.play("monohoshizao_tip", at)
				Audio.sfx("monohoshizao_tip", -3.0)
				return 1.35
			return 0.65
		"zhuxian":
			match _variant:
				"zhu":
					return 1.4
				"lu":
					_bleeds.append({"enemy": enemy, "ticks": 4, "wait": 0.5})
					fx.play("zhuxian_bleed", at, Vector2.RIGHT, 1.0, 2.0, 0.0, enemy)
				"xian":
					enemy.freeze(0.5)
					fx.play("zhuxian_talisman", at, Vector2.RIGHT, 1.0, 0.5, 0.0, enemy)
					Audio.sfx("zhuxian_xian", -4.0)
				"jue":
					if not enemy is Boss and enemy.hp <= enemy.max_hp * 0.22:
						fx.play("zhuxian_execute", at)
						Audio.sfx("zhuxian_jue", -4.0)
						return maxf(1.0, enemy.hp / maxf(0.01, damage * player.damage_mult) + 0.01)
	return 1.0


func _hit(enemy: Enemy, strength: float, direction: Vector2, critical := false, push := 1.0) -> void:
	enemy.take_damage(damage * player.damage_mult * strength, direction * knockback * push, critical)
	if hamstring > 0.0 and enemy.hp > 0.0:
		enemy.apply_slow(hamstring, HAMSTRING_TIME)


func _tick_areas(delta: float) -> void:
	for i in range(_areas.size() - 1, -1, -1):
		var area := _areas[i]
		area.age += delta
		area.tick -= delta
		if area.age >= 3.4:
			_areas.remove_at(i)
			continue
		if area.tick > 0.0:
			continue
		area.tick = 0.45
		for enemy in Enemy.query_radius(area.at, area.radius + 8.0):
			var offset: Vector2 = enemy.global_position - area.at
			if absf(offset.length() - area.radius) <= 8.0 + enemy.radius and absf(area.aim.angle_to(offset)) <= PI / 3.0:
				_hit(enemy, 0.42, Vector2.ZERO)
				fx.play("duanshui_splash", enemy.global_position)
	for i in range(_bleeds.size() - 1, -1, -1):
		var bleed := _bleeds[i]
		if not is_instance_valid(bleed.enemy) or bleed.enemy.hp <= 0.0 or bleed.ticks <= 0:
			_bleeds.remove_at(i)
			continue
		bleed.wait -= delta
		if bleed.wait <= 0.0:
			bleed.wait += 0.5
			bleed.ticks -= 1
			_hit(bleed.enemy, 0.18, Vector2.ZERO)


func _tick_states(delta: float) -> void:
	_thirst = maxf(0.0, _thirst - delta)
	_exhaust = maxf(0.0, _exhaust - delta)
	_avatar = maxf(0.0, _avatar - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	if _chain > 0:
		_chain_time -= delta
		if _chain_time <= 0.0:
			_chain = 0
			_thirst = 1.9
			Audio.sfx("muramasa_thirst")
	if _oni_time > 0.0:
		_oni_time = maxf(0.0, _oni_time - delta)
		if _oni_time <= 0.0:
			_end_oni()
	if _drinks > 0:
		_drink_time -= delta
		if _drink_time <= 0.0:
			_drinks = 0
	if _iai >= 0.0 and _iai < IAI_CHARGE and not player.weapon_pose_active() and not player.is_hurt():
		_iai = minf(IAI_CHARGE, _iai + delta)
		if _iai >= IAI_CHARGE:
			sync_art()
			fx.play("excalibur_charge_full", art.socket_world("mouth_of_sheath"), Vector2.RIGHT, 1.0, 0.0, 0.0, player)
			Audio.sfx("excalibur_charge_full")
	if _spinning:
		_spin = minf(3.0, _spin + delta)
		_spin_audio.pitch_scale = 1.0 + _spin * 0.14
		_spin_tick -= delta
		if _spin_tick <= 0.0:
			_spin_tick = lerpf(0.45, 0.22, _spin / 3.0)
			for enemy in Enemy.query_radius(global_position, _radius("qinglong_spin")):
				_hit(enemy, 0.32, global_position.direction_to(enemy.global_position), false, 0.2)


func stance() -> StringName:
	if _spinning:
		return &"spin"
	if _iai >= 0.0 and player.velocity.is_zero_approx():
		return &"iai_stance"
	return &""


func defensive_multiplier() -> float:
	return 0.75 if _iai >= 0.0 and not player.weapon_pose_active() else 1.0


func try_drunken_dodge() -> bool:
	if _drinks != 3 or _dodge_cd > 0.0:
		return false
	_dodge_cd = 2.0
	player.weapon_afterimage()
	fx.play("chunyang_dodge", global_position + Vector2(0, 22))
	return true


func input_skill(source: String, pressed: bool) -> void:
	if kit_id not in ACTIVE_SKILLS:
		return
	var was_pressed := not _skill_keys.is_empty()
	if pressed:
		_skill_keys[source] = true
	else:
		_skill_keys.erase(source)
	if not pressed:
		if _spinning and _skill_keys.is_empty():
			_release_spin()
		return
	if was_pressed or _skill_cd > 0.0 or player.is_dead or player.is_hurt() or player.is_dashing():
		return
	if player.weapon_pose_active() and kit_id == "excalibur":
		return
	var aim := _manual_aim(165.0)
	match kit_id:
		"qinglong":
			_strike = Callable()
			player.cancel_weapon_pose()
			_spin = 0.0
			_spin_tick = 0.0
			_spinning = true
			_spin_audio.pitch_scale = 1.0
			if _spin_audio.stream:
				_spin_audio.play()
		"higekiri":
			if _oni_time > 0.0:
				_end_oni()
			elif _oni >= 1.0:
				_oni = 0.0
				_oni_time = 4.5
				Audio.sfx("higekiri_oni_on")
		"excalibur":
			_excalibur(aim)
		"ganjiang_moye":
			_moye(aim)
		"riyue":
			_riyue(aim)
		"chunyang":
			_skill_cd = 0.55
			_start_pose(&"drink", aim, _drink, 0.24)


func _release_spin() -> void:
	_stop_spin()
	if player.is_dead or player.is_hurt() or player.is_dashing():
		return
	var aim := _manual_aim(_radius("qinglong_heavy"))
	_skill_cd = 1.2
	_start_pose(&"heavy", aim, _heavy.bind(aim, _spin), 0.17)


func _heavy(aim: Vector2, hold: float) -> void:
	_fan("qinglong_heavy", aim, _radius("qinglong_heavy"), 1.2 + hold * 0.45)
	Audio.sfx("qinglong_heavy")
	if hold >= 2.0:
		_avatar = 5.0
		Audio.sfx("qinglong_avatar")


func _end_oni() -> void:
	_oni_time = 0.0
	_exhaust = 2.0
	Audio.sfx("higekiri_oni_off")
	Audio.sfx("higekiri_exhaust", -4.0)


func _excalibur(aim: Vector2) -> void:
	if _iai < 0.0:
		_skill_cd = 0.35
		_start_pose(&"attack", aim, _normal_strike.bind("excalibur_slash", aim, _radius("excalibur_slash")), 0.10)
		return
	if _iai < IAI_CHARGE:
		return
	_iai = -1.0
	_skill_cd = 0.8
	var from := global_position
	var to := player.weapon_dash(aim, 300.0)
	_start_pose(&"iai_dash", aim, _iai_burst.bind(from, to, aim), 0.3)
	Audio.sfx("excalibur_iai")
	var length := from.distance_to(to)
	if length > 0.0:
		fx.play("excalibur_dash_trail", from, aim, 1.0, 0.0, length)


func _iai_burst(from: Vector2, to: Vector2, aim: Vector2) -> void:
	var length := from.distance_to(to)
	if length <= 0.0:
		return
	for enemy in Enemy.query_line(from, to, 48.0):
		_hit(enemy, 3.5, aim, true)
	fx.play("excalibur_line_burst", from, aim, 1.0, 0.0, length)
	fx.play("excalibur_line_cap", from, -aim)
	fx.play("excalibur_line_cap", to, aim)


func pose_finished(action: StringName) -> void:
	if kit_id != "excalibur" or _iai >= 0.0:
		return
	if action == &"attack" or action == &"iai_dash":
		player.play_attack(player.weapon_aim(), 0.0, 0.0, &"sheathe")
		Audio.sfx("excalibur_sheathe")
	elif action == &"sheathe":
		_iai = 0.0


func _swap(variant: String) -> void:
	_variant = variant
	sync_art()
	fx.play("riyue_swap", art.socket_world("main"), Vector2.RIGHT, 1.0, 0.0, 0.0, player)
	Audio.sfx("riyue_swap", -5.0)


func _riyue(aim: Vector2) -> void:
	_swap("moon" if _variant == "sun" else "sun")
	_next_variant = "moon" if _variant == "sun" else "sun"
	_skill_cd = 1.3
	if _variant == "sun":
		_start_pose(&"spin", aim, _fan.bind("riyue_sun_wheel", aim, _radius("riyue_sun_wheel"), 1.65), 0.10)
	else:
		var from := global_position
		var to := player.weapon_dash(aim, 120.0)
		_start_pose(&"thrust", aim, _moon_lunge.bind(from, to, aim), 0.14)
		fx.play("riyue_moon_lunge", from, aim, 1.0, 0.0, 0.0, null, 0.0, false,
			0.7 if from.distance_to(to) < 60.0 else 1.0)


func _moon_lunge(from: Vector2, to: Vector2, aim: Vector2) -> void:
	for enemy in Enemy.query_line(from, to, 40.0):
		_hit(enemy, 1.65, aim)


func _drink() -> void:
	_drinks = mini(3, _drinks + 1)
	_drink_time = 20.0
	fx.play("chunyang_drink", art.socket_world("head") + Vector2(0, 8), Vector2.RIGHT, 1.0, 0.0, 0.0, player)
	Audio.sfx("chunyang_drink")


func _moye(aim: Vector2) -> void:
	if _moye_state == "planted":
		_recall()
	elif _moye_state.is_empty():
		_skill_cd = 0.3
		_start_pose(&"throw", aim, _launch_moye.bind(aim), 0.13)


func _launch_moye(aim: Vector2) -> void:
	_moye_state = "out"
	_moye_time = 0.0
	_moye_from = art.socket_world("off")
	_moye_at = _moye_from
	_moye_to = Game.clamp_to_map(global_position + aim * 255.0, 0.0)
	Audio.sfx("moye_throw")


func _recall() -> void:
	_moye_state = "return"
	_moye_time = 0.0
	_moye_from = _moye_at
	Audio.sfx("moye_return")


func _tick_projectiles(delta: float) -> void:
	for i in range(_waves.size() - 1, -1, -1):
		var wave := _waves[i]
		var start: Vector2 = wave.from + wave.aim * wave.distance
		wave.distance = minf(260.0, wave.distance + 420.0 * delta)
		var end: Vector2 = wave.from + wave.aim * wave.distance
		for enemy in Enemy.query_line(start, end, 24.0):
			if not wave.hits.has(enemy.get_instance_id()):
				wave.hits[enemy.get_instance_id()] = true
				_hit(enemy, 0.55, wave.aim)
		if wave.distance >= 260.0:
			_waves.remove_at(i)
	if _moye_state.is_empty():
		return
	_moye_time += delta
	match _moye_state:
		"out":
			_moye_at = _moye_from.lerp(_moye_to, minf(1.0, _moye_time / 0.34))
			_show_moye(art.weapon.off, _moye_from.angle_to_point(_moye_to))
			if _moye_time >= 0.34:
				_moye_state = "planted"
				_moye_time = 0.0
				_spin_tick = 0.0
				Audio.sfx("ganjiang_link")
		"planted":
			_show_moye(art.weapon.planted, 0.0)
			_spin_tick -= delta
			if _moye_time >= 2.4 or global_position.distance_to(_moye_at) > LINK_LENGTH:
				_recall()
			elif _spin_tick <= 0.0:
				_spin_tick = 0.32
				for enemy in Enemy.query_line(global_position, _moye_at, 18.0):
					_hit(enemy, 0.5, Vector2.ZERO)
		"return":
			var hand := art.socket_world("off")
			_moye_at = _moye_from.lerp(hand, minf(1.0, _moye_time / 0.35))
			_show_moye(art.weapon.off, _moye_from.angle_to_point(hand))
			if _moye_time >= 0.35:
				_moye_state = ""
				_moye_sprite.hide()


func _show_moye(ref: Dictionary, angle: float) -> void:
	var image := SwordsmanArt.texture(SwordsmanArt.WEAPON_DIR + str(ref.file))
	_moye_sprite.texture = image
	_moye_sprite.centered = false
	_moye_sprite.offset = -SwordsmanArt.vec(ref.grip)
	_moye_sprite.global_position = _moye_at
	_moye_sprite.rotation = angle
	_moye_sprite.show()


func _draw() -> void:
	if not fx or player.is_dead:
		return
	if _spinning:
		_draw_fx("qinglong_spin", global_position, _spin * (1.0 + _spin), 0.0, reach / 110.0)
	if _avatar > 0.0:
		_draw_fx("qinglong_avatar", global_position, _clock)
	if _thirst > 0.0:
		_draw_fx("muramasa_thirst", global_position, _clock)
	if _iai >= 0.0 and not player.weapon_pose_active():
		_draw_fx("excalibur_guard", global_position, _clock)
	if _oni_time > 0.0:
		_draw_fx("higekiri_oni_aura", global_position, _clock)
	if _moye_state == "planted":
		_draw_fx("moye_planted_ring", _moye_at, _moye_time)
		var link := _moye_at - global_position
		_draw_fx("ganjiang_link", global_position, _moye_time, link.angle(), 1.0, minf(LINK_LENGTH, link.length()))
	elif _moye_state in ["out", "return"]:
		_draw_fx("moye_trail", _moye_at, _moye_time, _moye_sprite.rotation + PI)
	for wave in _waves:
		_draw_fx("chunyang_qi", wave.from + wave.aim * wave.distance, _clock, wave.aim.angle(),
			1.0, 0.0, 1.0 - wave.distance / 285.0)


func _draw_fx(id: String, at: Vector2, age: float, angle := 0.0, ratio := 1.0, length := 0.0, opacity := 1.0) -> void:
	fx.frame_on(self, id, at, age, angle, ratio, length, false, opacity)


func _draw_overlay() -> void:
	if player.is_dead:
		return
	if _oni_time > 0.0:
		fx.frame_on(_overlay, "higekiri_oni_horns", art.socket_world("head"), _clock)
	if _drinks >= 2:
		fx.frame_on(_overlay, "chunyang_tipsy", art.socket_world("head"), _clock)
	if _exhaust > 0.0:
		fx.frame_on(_overlay, "higekiri_exhaust", global_position, _clock)
	var id: String = STATUS_ICONS.get(kit_id, "")
	var gauge := -1.0
	match kit_id:
		"zhuxian":
			id = "zhuxian_next_" + _next_variant
		"chunyang":
			id = "chunyang_gourd_" + str(_drinks)
		"higekiri":
			gauge = _oni_time / 4.5 if _oni_time > 0.0 else _oni
		"excalibur":
			gauge = maxf(0.0, _iai) / IAI_CHARGE
	if id.is_empty():
		return
	var icon := SwordsmanArt.texture(SwordsmanArt.ICON_DIR + id + ".png")
	_overlay.draw_texture(icon, Vector2(-6 if gauge < 0.0 else -17, -41))
	if gauge >= 0.0:
		_overlay.draw_rect(Rect2(-3, -36, 24, 3), Color(0.1, 0.12, 0.15))
		_overlay.draw_rect(Rect2(-3, -36, roundf(24.0 * gauge), 3),
			Color("#da5374") if kit_id == "higekiri" else Color("#a7dfff"))
