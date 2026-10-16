class_name LightningStrike
extends Node2D
## 托尔·落雷：周期性劈向附近随机敌人，造成范围伤害。觉醒后会连锁跳向附近的敌人

const RANGE := 450.0         # 只劈这个距离内的敌人
const BLAST_RADIUS := 60.0   # 落点爆炸半径
const CHAIN_RANGE := 220.0   # 连锁能跳多远

var damage := 20.0
var cooldown := 2.0
var strikes := 1  # 每次劈几道
var chain := 0    # 每道雷连锁几个敌人（觉醒后为 3）
var player: Player
var _timer := 0.5


func _ready() -> void:
	player = get_parent() as Player


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	var candidates: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.global_position.distance_to(global_position) < RANGE:
			candidates.append(enemy)
	if candidates.is_empty():
		return
	_timer = cooldown * player.cooldown_mult
	candidates.shuffle()
	for i in mini(strikes, candidates.size()):
		_strike(candidates[i].global_position)


func _strike(pos: Vector2) -> void:
	var dmg := damage * player.damage_mult
	Enemy.damage_in_radius(get_tree(), pos, BLAST_RADIUS, dmg, 180.0)
	var sky := pos + Vector2(randf_range(-40.0, 40.0), -420.0)
	LightningFx.spawn(get_tree().current_scene, sky, pos, BLAST_RADIUS)
	Audio.sfx("lightning")

	if chain <= 0:
		return
	# 连锁：从落点跳向最近的几个（不在爆炸范围内的）敌人
	var others: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		var d := enemy.global_position.distance_to(pos)
		if d > BLAST_RADIUS and d < CHAIN_RANGE:
			others.append(enemy)
	others.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_squared_to(pos) < b.global_position.distance_squared_to(pos))
	for enemy in others.slice(0, chain):
		LightningFx.spawn(get_tree().current_scene, pos, enemy.global_position, 0.0)
		enemy.take_damage(dmg * 0.6)
