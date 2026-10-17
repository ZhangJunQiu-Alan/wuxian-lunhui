class_name SoulLampsQuest
extends SideQuest
## 支线「引魂灯」：亡者广场四角的磷火灯柱熄灭了。限时内依次点亮 4 盏灯（在灯旁站 2 秒）
## 每点亮一盏，冥雾就涌过来一次，带着冥雾幽魂
## 奖励：奖励点 +80，本局冥雾伤害减半

const LAMP_OFFSETS := [Vector2(-170, -150), Vector2(170, -150), Vector2(170, 170), Vector2(-170, 170)]  # 和地图上的灯柱一样
const LIGHT_TIME := 2.0
const LIGHT_RADIUS := 55.0
const LIT_PATH := "res://assets/sprites/props/helheim/soul_lamp_lit.png"
const GLOW := Color(0.5, 1.0, 0.85)

var _lamps: Array[Vector2] = []
var _lit := 0
var _charge := 0.0
var _lit_texture: Texture2D


func _init() -> void:
	title = tr("引魂灯")
	offer_text = tr("【主神】支线剧情：广场上的引魂灯熄灭了，亡者找不到路。依次点亮它们")
	time_limit = 60.0
	color = GLOW


func _ready() -> void:
	super._ready()
	for offset: Vector2 in LAMP_OFFSETS:
		_lamps.append(landmark.get("pos", Vector2.ZERO) + offset + Vector2(0, -20))
	if ResourceLoader.exists(LIT_PATH):
		_lit_texture = load(LIT_PATH)


func _on_update(delta: float) -> void:
	var lamp := _lamps[_lit]
	if player.global_position.distance_to(lamp) < LIGHT_RADIUS:
		_charge += delta
		if _charge >= LIGHT_TIME:
			_charge = 0.0
			_lit += 1
			FxLayer.burst(lamp, GLOW, 20, 160.0, 3.0)
			Audio.sfx("quest_start", -4.0)
			for i in 4:  # 冥雾涌来，带着幽魂
				game.spawn_enemy("mist_wraith", Game.clamp_to_map(lamp + Vector2.from_angle(randf() * TAU) * 300.0, 40.0))
			if _lit >= _lamps.size():
				complete(true)
				return
	else:
		_charge = maxf(0.0, _charge - delta)
	objective = tr("点亮引魂灯  %d / %d") % [_lit, _lamps.size()]


func _reward() -> String:
	game.add_reward_points(80)
	if Mist.instance:
		Mist.instance.damage_scale = 0.5
	return tr("奖励点 +80，本局冥雾伤害减半")


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	if _lit < _lamps.size():
		targets.append(_lamps[_lit])
	return targets


func _draw_quest() -> void:
	if state != "active":
		return
	for i in _lamps.size():
		var lamp := _lamps[i]
		if i < _lit:  # 点亮的灯：青绿色的磷火
			if _lit_texture:
				draw_texture(_lit_texture, lamp + Vector2(0, 20) - Vector2(_lit_texture.get_width() / 2.0, _lit_texture.get_height()))
			draw_circle(lamp + Vector2(0, -50), 10.0 + sin(_time * 5.0 + i) * 2.0, Color(GLOW, 0.5))
		elif i == _lit:
			draw_arc(lamp, LIGHT_RADIUS, 0.0, TAU, 32, Color(GLOW, 0.6), 2.0)
			draw_arc(lamp, LIGHT_RADIUS + 6.0, -PI / 2, -PI / 2 + TAU * _charge / LIGHT_TIME, 32, GLOW, 4.0)
