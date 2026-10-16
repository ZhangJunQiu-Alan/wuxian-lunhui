class_name Revolver
extends Node2D
## 枪手的左轮手枪：快速射击射程内最近的敌人，每打完一个弹匣要换弹
## 被动「纸牌神射」：每个弹匣的最后一发必定暴击（伤害 ×3），命中后分裂成两发
## 大招「狂野西部秀」期间：射速 ×4、不用换弹、子弹额外穿透

const RANGE := 460.0
const BULLET_SPEED := 760.0
const CRIT_MULT := 3.0
const FRENZY_RATE := 4.0
const FRENZY_PIERCE := 2
const COLOR := Color(1.0, 0.75, 0.45)

var damage := 7.0
var fire_interval := 0.28
var magazine := 6
var reload_time := 1.0
var pierce := 1
var twin := false  # 双枪：每次同时射出两发
var player: Player
var _ammo := 6
var _timer := 0.0
var _reloading := 0.0


func _ready() -> void:
	player = get_parent() as Player
	_ammo = magazine


func _process(delta: float) -> void:
	var frenzy := player.frenzy_time > 0.0
	if _reloading > 0.0 and not frenzy:
		_reloading -= delta
		if _reloading <= 0.0:
			_ammo = magazine
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var target := _nearest_in_range()
	if target == null:
		return  # 射程内没有敌人就不开枪
	_timer = fire_interval * player.cooldown_mult / (FRENZY_RATE if frenzy else 1.0)

	var last_shot := _ammo == 1 and not frenzy
	var dir := global_position.direction_to(target.global_position)
	player.play_attack(dir, 2.0, _timer)
	var spread := [-0.08, 0.08] if twin else [0.0]
	for angle in spread:
		var p := Projectile.new()
		p.global_position = global_position
		p.direction = dir.rotated(angle)
		p.speed = BULLET_SPEED
		p.damage = damage * player.damage_mult * (CRIT_MULT if last_shot else 1.0)
		p.pierce = pierce + (FRENZY_PIERCE if frenzy else 0)
		p.color = COLOR
		p.size = 0.8
		p.crit = last_shot
		p.split_on_hit = last_shot
		get_tree().current_scene.add_child(p)

	if not frenzy:
		_ammo -= 1
		if _ammo <= 0:
			_reloading = reload_time * player.cooldown_mult


## 换弹进度（0~1），没在换弹时返回 -1。用来在玩家身边画换弹圈
func reload_progress() -> float:
	if _reloading <= 0.0:
		return -1.0
	return 1.0 - _reloading / (reload_time * player.cooldown_mult)


func _nearest_in_range() -> Node2D:
	var nearest: Node2D = null
	var best := RANGE * RANGE
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		var d := global_position.distance_squared_to(enemy.global_position)
		if d < best:
			best = d
			nearest = enemy
	return nearest
