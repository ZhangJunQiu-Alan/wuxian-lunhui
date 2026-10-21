class_name VigridBattle
extends Node2D
## 第 3 关战场上的神明援助（game.gd 在有 fates 的关卡里创建）
##   一般周期援助：信仰的神就在附近交战（玩家身边敌人够多，或 Boss 就在附近）时，每隔一段时间轮流请一位神出手
##     复用各位神已有的神术效果，不新增人物；和下面两种改写命运的援助是两套条件
##   托尔：耶梦加得战里托尔获救（thor_saved）后，苏尔特战中每隔几秒向苏尔特落雷
##   弗雷：信仰弗蕾亚并且弗蕾亚觉醒时，苏尔特战中弗雷出现在玩家身边持续治疗（实际开始援助时记 freyr_assisted）
## 每次实际发生的援助都记一条事件（god_id / world_position / source_encounter / aid_kind / event_id），只请求没发生不算
## 援助人物和远景都不进敌人组，不会被锁定，也不会自己造成伤害；数值见 VigridTuning

const AID_KINDS := {"thor": "lightning", "odin": "einherjar", "loki": "wildfire", "freyja": "feathers",
	"baldr": "light", "ran": "net", "freyr": "harvest", "skadi": "frost"}
const FREYR_IDLE := "res://assets/sprites/allies/freyr_idle.png"  # 64×64 4 帧，脚锚 (32,62)
const FREYR_HEAL := "res://assets/sprites/allies/freyr_heal.png"  # 64×64 4 帧 16 帧/秒
const FREYR_FOOT := Vector2(32, 62)
const FREYR_OFFSET := Vector2(-46, 6)

var game: Node
var player: Player
var events: Array[Dictionary] = []  # 实际发生的援助
var freyr_active := false
var _aid_timer := 0.0
var _aid_index := 0
var _sequence := 0
var _thor_timer := 0.0
var _thor_announced := false
var _freyr_timer := 0.0
var _freyr_heal_t := -1.0  # >= 0：正在播放治疗动作
var _freyr_pos := Vector2.ZERO
var _time := 0.0
var _freyr_idle: Texture2D
var _freyr_heal: Texture2D


func _ready() -> void:
	z_index = 0
	_freyr_idle = load(FREYR_IDLE) if ResourceLoader.exists(FREYR_IDLE) else null
	_freyr_heal = load(FREYR_HEAL) if ResourceLoader.exists(FREYR_HEAL) else null


func _process(delta: float) -> void:
	if not game.is_running() or not is_instance_valid(player):
		return
	_time += delta
	_tick_aid(delta)
	var surtr := game.boss as Surtr if is_instance_valid(game.boss) else null
	if surtr and not surtr._dead:
		_tick_thor(delta, surtr)
		_tick_freyr(delta)
	elif freyr_active:
		freyr_active = false  # 苏尔特倒下，弗雷退场
	queue_redraw()


func _encounter() -> String:
	return game.boss.type_id if is_instance_valid(game.boss) else "battlefield"


## 「附近交战」：玩家身边 AID_NEAR 内至少 AID_MIN_ENEMIES 个敌人，或者 Boss 在 AID_BOSS_NEAR 内
func nearby_combat() -> bool:
	if is_instance_valid(game.boss) and game.boss.global_position.distance_to(player.global_position) < VigridTuning.AID_BOSS_NEAR:
		return true
	return Enemy.query_radius(player.global_position, VigridTuning.AID_NEAR).size() >= VigridTuning.AID_MIN_ENEMIES


func _record(god_id: String, at: Vector2, kind: String) -> Dictionary:
	_sequence += 1
	var event := {"god_id": god_id, "world_position": at, "source_encounter": _encounter(), "aid_kind": kind, "event_id": "vigrid_aid_%d" % _sequence}
	events.append(event)
	return event


func _tick_aid(delta: float) -> void:
	_aid_timer += delta
	if _aid_timer < VigridTuning.AID_EVERY or player.faith.is_empty():
		return
	if not nearby_combat():
		_aid_timer = VigridTuning.AID_EVERY - 1.0  # 附近没有交战：一秒后再看
		return
	_aid_timer = 0.0
	var gods: Array = player.faith.keys()
	var god_id: String = gods[_aid_index % gods.size()]
	_aid_index += 1
	request_aid(god_id)


## 请一位神出手。返回实际发生的事件（没有这位神的神术节点就什么都不做，返回空字典）
func request_aid(god_id: String) -> Dictionary:
	var power: GodPower = player.gods.get(god_id)
	if power == null:
		return {}
	var at := power.densest_point(player.global_position, VigridTuning.AID_NEAR, 90.0)
	if not at.is_finite():
		at = player.global_position
	var amount: float = power.damage(VigridTuning.AID_DAMAGE) * (1.0 + player.faith.get(god_id, 1) / 12.0)
	var kind: String = AID_KINDS.get(god_id, "blessing")
	if kind == "feathers":
		at = player.global_position
	match kind:
		"lightning":  # 世界观的例子：信仰托尔时，天空额外落雷
			for i in 3:
				power.lightning(at + Vector2.from_angle(TAU * i / 3.0) * 50.0, 70.0, amount)
		"einherjar":
			power.summon_einherjar(12.0, 1.0)
			Audio.sfx_or("rune_detonate", "rune_bolt", -4.0)
		"wildfire":
			var burn := func(enemy: Enemy) -> void:
				enemy.take_damage(amount * 0.35)
				enemy.burn(amount * 0.2, 3.0)
			var patch := power.zone(at, 90.0, 4.0, 0.5, burn, power.color)
			patch.texture = GodPower.art("loki_fire_patch")
			Audio.sfx("fire_burn", -6.0)
		"feathers":
			Enemy.damage_in_radius(get_tree(), player.global_position, 140.0, amount, 160.0)
			player.heal(player.max_hp * 0.05)
			Audio.sfx_or("feather_launch", "feather_hit")
		"light":
			for enemy in Enemy.damage_in_radius(get_tree(), at, 110.0, amount):
				enemy.add_status("light", 4.0)
			Audio.sfx_or("light_burst", "rune_bolt", -4.0)
		"net":
			for enemy in Enemy.damage_in_radius(get_tree(), at, 130.0, amount * 0.6):
				enemy.add_status("drown", 4.0)
				enemy.stun(1.0)
			Audio.sfx_or("net_close", "dash", -4.0)
		"harvest":
			Enemy.damage_in_radius(get_tree(), at, 110.0, amount)
			power.drop_heal(at, 8.0, "apple")
			Audio.sfx_or("sword_hit", "feather_hit", -4.0)
		"frost":
			for enemy in Enemy.damage_in_radius(get_tree(), at, 130.0, amount * 0.7):
				enemy.add_frost(3)
			Audio.sfx_or("ice_shatter", "ice_pillar", -4.0)
	if not FxLayer.play_aid(god_id, at):
		FxLayer.ring(at, {"feathers": 140.0, "light": 110.0, "net": 130.0, "frost": 130.0}.get(kind, 110.0))
		FxLayer.burst(at, power.color, 18, 200.0, 3.0)
	return _record(god_id, at, kind)


## 托尔获救后：苏尔特战中每隔几秒向苏尔特落雷（实际造成伤害），也劈它身边的火焰巨人
func _tick_thor(delta: float, surtr: Surtr) -> void:
	if not game.fates.get("thor_saved", false):
		return
	_thor_timer += delta
	if _thor_timer < VigridTuning.THOR_AID_EVERY:
		return
	_thor_timer = 0.0
	var at := surtr.global_position
	LightningFx.spawn(game, at + Vector2(randf_range(-40.0, 40.0), -420.0), at, 90.0)
	Audio.sfx("lightning")
	surtr.take_damage(surtr.max_hp * VigridTuning.THOR_AID_DAMAGE)
	for enemy in Enemy.query_radius(at, 140.0):
		if enemy != surtr and not enemy._dead:
			enemy.take_damage(VigridTuning.AID_DAMAGE * 2.0)
	_record("thor", at, "fate_thor_strike")
	if not _thor_announced:
		_thor_announced = true
		game.hud.announce(tr("托尔的雷锤劈向了苏尔特！"))


func freyr_condition() -> bool:
	return player.faith.has("freyja") and player.gods.has("freyja") and player.gods.freyja.awakened


## 信仰弗蕾亚并且弗蕾亚觉醒：弗雷参战。只有真的给了治疗才闪光、放声音
func _tick_freyr(delta: float) -> void:
	if not freyr_active:
		if game.fates.get("freyr_assisted", false) or not freyr_condition():
			return
		if not game.confirm_fate("freyr_assisted"):
			return
		freyr_active = true
		_freyr_timer = 0.0
		_freyr_pos = player.global_position + FREYR_OFFSET * 3.0
		_record("freyr", player.global_position, "fate_freyr_arrive")
		game.hud.announce(tr("弗蕾亚的兄长弗雷来到了战场"))
	_freyr_pos = _freyr_pos.lerp(player.global_position + FREYR_OFFSET, minf(1.0, delta * 4.0))
	if _freyr_heal_t >= 0.0:
		_freyr_heal_t += delta
		if _freyr_heal_t >= 0.5:
			_freyr_heal_t = -1.0
	_freyr_timer += delta
	if _freyr_timer >= VigridTuning.FREYR_HEAL_EVERY:
		_freyr_timer = 0.0
		if player.hp < player.max_hp:
			player.heal(player.max_hp * VigridTuning.FREYR_HEAL)
			_freyr_heal_t = 0.0
			Audio.sfx("heal_pickup", -2.0)
			_record("freyr", player.global_position, "fate_freyr_heal")


func _draw() -> void:
	if not freyr_active:
		return
	if _freyr_heal_t >= 0.0:  # 治疗场只在真的治疗时出现
		var field := GodPower.art("freyr_field")
		var fade := 1.0 - _freyr_heal_t / 0.5
		if field:
			draw_texture(field, player.global_position - Vector2(64, 64), Color(1, 1, 1, 0.8 * fade))
		else:
			draw_circle(player.global_position, 60.0, Color(0.6, 0.9, 0.4, 0.3 * fade))
	var strip := _freyr_heal if _freyr_heal_t >= 0.0 and _freyr_heal_t < 0.25 else _freyr_idle
	if strip:
		var frame := int(_freyr_heal_t * 16.0) if strip == _freyr_heal else int(_time * 8.0) % 4
		var feet := _freyr_pos + Vector2(0, MapLayer.FOOT)
		draw_set_transform(feet, 0.0, Vector2(-1.0 if player.global_position.x < _freyr_pos.x else 1.0, 1.0))
		draw_texture_rect_region(strip, Rect2(-FREYR_FOOT, Vector2(64, 64)), Rect2(Vector2(64 * mini(frame, 3), 0), Vector2(64, 64)))
		draw_set_transform(Vector2.ZERO)
