class_name IcePillar
extends StaticBody2D
## 冰柱：实心障碍物，玩家无法穿过（敌人可以），持续一段时间后碎裂

const PILLAR := preload("res://assets/sprites/effects/ice_pillar.png")  # 4 帧升起，停在最后一帧
const RADIUS := 18.0
const COLOR := Color(0.6, 0.88, 1.0)

var _life := 3.0
var _age := 0.0


## 物理帧中途不能直接添加碰撞体，所以延迟到帧末添加
static func spawn(parent: Node, pos: Vector2, duration: float) -> void:
	var pillar := IcePillar.new()
	pillar.position = pos
	Audio.sfx("ice_pillar")
	pillar._life = duration
	parent.add_child.call_deferred(pillar)


func _ready() -> void:
	collision_layer = 1  # 和玩家同一层，玩家会被挡住；敌人是 Area2D，不受影响
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)


func _process(delta: float) -> void:
	_age += delta
	_life -= delta
	if _age < 0.3:
		queue_redraw()
	if _life <= 0.0:
		if not BossFx.play("hrym_ice_break", global_position + Vector2(0, RADIUS * 0.6)):
			FxLayer.burst(global_position, COLOR, 8, 120.0)
		queue_free()


func _draw() -> void:
	SpriteVisual.draw_frame(self, PILLAR, 4, mini(3, int(_age * 16.0)), Vector2(0, RADIUS * 0.6), Vector2(24, 62))
