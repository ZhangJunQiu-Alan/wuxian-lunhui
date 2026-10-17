class_name Hel
extends Boss
## 海拉 · 冥界女王（篇章一 第 2 关 14:00，本关大 Boss）
## 技能：
##   生死二相：以她登场的位置为界，场地左边是「生」、右边是「死」。她站在生之侧时治疗身边的敌人，
##            站在死之侧时不断召唤亡者；每隔一段时间瞬移到另一侧
##   亡者大军：从玩家四周的地面召唤一圈亡者
##   冥火：朝玩家射出一扇冥火
##   死亡领域：安全区从大圈慢慢缩小，圈外持续掉血
##   第二阶段（30% 血量）：纳吉尔法尔的虚影停到场地北边，海拉登船，从船上发射指甲弹幕

const CHASE_TIME := 2.2
const CAST_WINDUP := 0.8
const CAST_SHOTS := 5
const CAST_SPREAD := 0.5
const CAST_DAMAGE := 10.0
const ARMY_WINDUP := 1.2
const ARMY_COUNT := 14
const ARMY_RADIUS := 260.0
const SWITCH_EVERY := 12.0
const SIDE_OFFSET := 320.0      # 瞬移到另一侧时离分界线多远
const HEAL_EVERY := 1.5
const HEAL_RADIUS := 450.0
const HEAL_RATIO := 0.15
const SUMMON_EVERY := 3.0
const SUMMON_COUNT := 3
const DOMAIN_START := 1000.0
const DOMAIN_END := 380.0
const DOMAIN_TIME := 100.0      # 多少秒缩到最小
const DOMAIN_DAMAGE := 0.03     # 圈外每秒掉最大生命的比例
const PHASE2_AT := 0.3
const SHIP_OFFSET := Vector2(0, -360)
const BARRAGE_EVERY := 2.2
const BARRAGE_SHOTS := 9
const BARRAGE_SPREAD := 0.9
const BARRAGE_DAMAGE := 9.0
const BARRAGE_SPEED := 260.0
const SHIP_PATH := "res://assets/sprites/props/helheim/naglfar_sail.png"
const NAIL_PATH := "res://assets/sprites/effects/nail_bolt.png"
const LIFE := Color(0.75, 0.85, 0.55)
const DEATH := Color(0.45, 0.3, 0.6)

var barrage_mult := 1.0  # 支线「指甲堆」完成后减少弹幕
var _anchor := Vector2.ZERO
var _cast_dir := Vector2.RIGHT
var _switch_timer := SWITCH_EVERY
var _side_timer := 0.0
var _rounds := 0
var _fight_time := 0.0
var _phase2 := false
var _barrage_timer := 1.0
var _ship: Node2D
var _field: Node2D
var _nail: Texture2D


func _init() -> void:
	intro_line = tr("海拉 · 冥界女王 —— 纳吉尔法尔即将起航")
	defeat_line = tr("「父亲……你说过……我们会赢的……」")


func init_stats(hp_scale: float) -> void:
	setup_boss("hel", tr("海拉"), tr("冥界女王"), 1600.0, hp_scale, 44.0, 80.0, 18.0)
	color = Color(0.5, 0.45, 0.55)
	reward_points = 300
	state_actions = {"army_windup": &"summon", "army": &"summon", "cast_windup": &"windup", "ship": &"idle"}


func _ready() -> void:
	super._ready()
	_anchor = position
	if ResourceLoader.exists(NAIL_PATH):
		_nail = load(NAIL_PATH)
	_field = Node2D.new()
	_field.z_index = -1
	_field.draw.connect(_draw_field)
	get_parent().add_child.call_deferred(_field)
	change_state("chase")


func _on_life_side() -> bool:
	return global_position.x < _anchor.x


func _domain_radius() -> float:
	return lerpf(DOMAIN_START, DOMAIN_END, minf(1.0, _fight_time / DOMAIN_TIME))


func _update_state(delta: float) -> void:
	_fight_time += delta
	if is_instance_valid(_field):
		_field.queue_redraw()
	if target.global_position.distance_to(_anchor) > _domain_radius():  # 死亡领域
		target.take_dot(target.max_hp * DOMAIN_DAMAGE * delta)
	_update_side(delta)
	if not _phase2 and hp < max_hp * PHASE2_AT:
		_enter_phase2()
	if _phase2:
		_barrage_timer -= delta
		if _barrage_timer <= 0.0:
			_barrage_timer = BARRAGE_EVERY
			_barrage()
		return  # 登船后不再走动，只在船上放技能
	match state:
		"chase":
			chase(delta)
			if state_time >= CHASE_TIME:
				_rounds += 1
				change_state("army_windup" if _rounds % 3 == 0 else "cast_windup")
		"cast_windup":
			_cast_dir = global_position.direction_to(target.global_position)
			if state_time >= CAST_WINDUP:
				_fan(_cast_dir, CAST_SHOTS, CAST_SPREAD, CAST_DAMAGE, 200.0, null, DEATH.lightened(0.4))
				change_state("cast")
		"cast":
			if state_time >= 0.4:
				change_state("recover")
		"army_windup":
			if state_time >= ARMY_WINDUP:
				_raise_army()
				change_state("army")
		"army":
			if state_time >= 0.6:
				change_state("recover")
		"recover":
			if state_time >= 0.8:
				change_state("chase")


## 生死二相：每隔一段时间瞬移到分界线另一侧；生之侧治疗敌人，死之侧召唤亡者
func _update_side(delta: float) -> void:
	_side_timer -= delta
	if not _phase2:
		_switch_timer -= delta
		if _switch_timer <= 0.0:
			_switch_timer = SWITCH_EVERY
			FxLayer.burst(global_position, DEATH if _on_life_side() else LIFE, 30, 220.0, 4.0)
			var x := _anchor.x + (SIDE_OFFSET if _on_life_side() else -SIDE_OFFSET)
			position = MapLayer.push_out(Game.clamp_to_map(Vector2(x, position.y), radius), radius)
			FxLayer.burst(global_position, LIFE if _on_life_side() else DEATH, 30, 220.0, 4.0)
			Audio.sfx("boss_windup")
	if _side_timer > 0.0:
		return
	if _on_life_side():
		_side_timer = HEAL_EVERY
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy != self and enemy.hp < enemy.max_hp and enemy.global_position.distance_to(global_position) < HEAL_RADIUS:
				enemy.hp = minf(enemy.max_hp, enemy.hp + enemy.max_hp * HEAL_RATIO)
				FxLayer.burst(enemy.global_position, LIFE, 3, 60.0, 2.0)
	else:
		_side_timer = SUMMON_EVERY
		for i in SUMMON_COUNT:
			spawner.call("dead", Game.clamp_to_map(global_position + Vector2.from_angle(randf() * TAU) * randf_range(60.0, 140.0), 40.0))


func _raise_army() -> void:
	target.shake(6.0, 0.3)
	Audio.sfx("boss_slam", -4.0)
	for i in ARMY_COUNT:
		var pos := Game.clamp_to_map(target.global_position + Vector2.from_angle(TAU * i / ARMY_COUNT) * ARMY_RADIUS, 40.0)
		FxLayer.burst(pos, Color(0.4, 0.38, 0.35), 6, 90.0, 3.0)
		spawner.call("dead", pos)


func _fan(dir: Vector2, shots: int, spread: float, damage: float, speed_px: float, texture: Texture2D, tint: Color, from: Vector2 = global_position) -> void:
	for i in shots:
		var angle := -spread + spread * 2.0 * i / maxf(1.0, shots - 1)
		var shot := EnemyProjectile.spawn(get_parent(), from, dir.rotated(angle), damage)
		shot.texture = texture
		shot.tint = tint
		shot.speed = speed_px


## 第二阶段：纳吉尔法尔的虚影停到北边，海拉登船
func _enter_phase2() -> void:
	_phase2 = true
	var deck := MapLayer.push_out(Game.clamp_to_map(_anchor + SHIP_OFFSET, radius), radius)
	_ship = Node2D.new()
	_ship.position = deck + Vector2(0, 60)
	_ship.z_index = -1
	if ResourceLoader.exists(SHIP_PATH):
		var sprite := Sprite2D.new()
		sprite.texture = load(SHIP_PATH)
		sprite.offset = Vector2(0, -sprite.texture.get_height() * 0.5)
		sprite.modulate = Color(1, 1, 1, 0.85)
		_ship.add_child(sprite)
	else:
		_ship.draw.connect(func() -> void:
			_ship.draw_colored_polygon(PackedVector2Array([Vector2(-300, 0), Vector2(300, 0), Vector2(240, 60), Vector2(-240, 60)]), Color(0.62, 0.56, 0.4, 0.8))
			_ship.draw_rect(Rect2(-8, -220, 16, 220), Color(0.3, 0.25, 0.2, 0.8))
			_ship.draw_colored_polygon(PackedVector2Array([Vector2(8, -210), Vector2(160, -150), Vector2(8, -40)]), Color(0.75, 0.7, 0.62, 0.8)))
	get_parent().add_child(_ship)
	FxLayer.burst(global_position, DEATH, 40, 260.0, 4.0)
	position = deck
	target.shake(10.0, 0.5)
	Audio.sfx("boss_warning")
	change_state("ship")
	var game := get_tree().current_scene
	if game.get("hud"):
		game.hud.announce(tr("海拉登上了纳吉尔法尔！船帆展开，指甲如雨落下"))


func _barrage() -> void:
	var count := maxi(3, roundi(BARRAGE_SHOTS * barrage_mult))
	_fan(global_position.direction_to(target.global_position), count, BARRAGE_SPREAD, BARRAGE_DAMAGE, BARRAGE_SPEED, _nail, Color(0.85, 0.8, 0.6))
	play_once(&"attack")


func _die() -> void:
	for node in [_ship, _field]:
		if is_instance_valid(node):
			node.queue_free()
	super._die()


## 场地：生死两侧的底色、分界线、死亡领域的安全圈（圈外压暗）
func _draw_field() -> void:
	var r := _domain_radius()
	var h := 2600.0
	_field.draw_rect(Rect2(_anchor.x - h, _anchor.y - h, h, h * 2.0), Color(LIFE, 0.05))
	_field.draw_rect(Rect2(_anchor.x, _anchor.y - h, h, h * 2.0), Color(DEATH, 0.07))
	_field.draw_line(Vector2(_anchor.x, _anchor.y - r), Vector2(_anchor.x, _anchor.y + r), Color(0.9, 0.9, 0.95, 0.25), 3.0)
	_field.draw_arc(_anchor, r + 1500.0, 0.0, TAU, 96, Color(0.05, 0.02, 0.08, 0.45), 3000.0)
	_field.draw_arc(_anchor, r, 0.0, TAU, 96, Color(DEATH.lightened(0.3), 0.8), 3.0)


func _draw_telegraph() -> void:
	match state:
		"cast_windup":
			for i in CAST_SHOTS:
				var dir := _cast_dir.rotated(-CAST_SPREAD + CAST_SPREAD * 2.0 * i / (CAST_SHOTS - 1))
				draw_line(dir * radius, dir * (radius + 160.0 * state_time / CAST_WINDUP), Color(DEATH.lightened(0.4), 0.6), 2.0)
		"army_windup":
			draw_circle_telegraph(self, target.global_position - global_position, ARMY_RADIUS, state_time / ARMY_WINDUP, DEATH)
