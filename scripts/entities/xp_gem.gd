class_name XpGem
extends Node2D
## 经验宝石：玩家进入拾取范围后被吸过去

const GEM := preload("res://assets/sprites/pickups/xp_gem.png")
const BIG_GEM := preload("res://assets/sprites/pickups/xp_gem_large.png")
const FLY_SPEED := 450.0
const MERGE_CELL := 64.0

static var _loose := {}

var value := 1
var big := false  # 精英怪掉落的大宝石
var player: Player
var _attracted := false
var _merged := false
var _cell := Vector2i.ZERO


func _ready() -> void:
	_cell = Vector2i((global_position / MERGE_CELL).floor())
	var existing = _loose.get(_cell)
	if is_instance_valid(existing) and existing.player == player and not existing._attracted and not existing.is_queued_for_deletion():
		existing.value += value
		existing.big = existing.big or big
		existing.queue_redraw()
		_merged = true
		queue_free()
	else:
		_loose[_cell] = self


func _unindex() -> void:
	if _loose.get(_cell) == self:
		_loose.erase(_cell)


func _exit_tree() -> void:
	_unindex()


func _enter_tree() -> void:
	add_to_group("xp_gems")


static func attract_all(owner_player: Player) -> int:
	if not is_instance_valid(owner_player) or not owner_player.is_inside_tree():
		return 0
	var count := 0
	for gem: XpGem in owner_player.get_tree().get_nodes_in_group("xp_gems"):
		if gem.player == owner_player and not gem.is_queued_for_deletion() and not gem._attracted:
			gem._attracted = true
			count += 1
	return count


func _process(delta: float) -> void:
	if _merged or not is_instance_valid(player):
		return
	var dist := global_position.distance_to(player.global_position)
	if dist < player.pickup_radius:
		_attracted = true
		_unindex()
	if _attracted:
		global_position = global_position.move_toward(player.global_position, FLY_SPEED * delta)
		if dist < 12.0:
			player.add_xp(value)
			Audio.sfx("pickup_xp", -6.0, 0.15)
			queue_free()


func _draw() -> void:
	var tex := BIG_GEM if big else GEM
	draw_texture(tex, -tex.get_size() * 0.5)
