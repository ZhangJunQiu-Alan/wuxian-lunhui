class_name FireHazard
extends Node2D
## 第 3 关地上的火：火焰巨人死亡爆炸、苏尔特横扫留下的残火
## 一个节点先（可选）预警 warn 秒 → 爆炸一次（blast_damage，只结算一次）→ 变成持续 life 秒的火焰地面（每秒 dps）
## 圆心 + 半径是唯一的判定几何，预警圈、爆炸贴图和火焰贴图都按它画；火焰贴图复用洛基的火，只在这里改成橙红色
## 场上最多 VigridTuning.HAZARD_MAX 个，超出时最早的先熄灭

const PATCH := "res://assets/sprites/effects/gods/loki_fire_patch.png"
const PATCH_RADIUS := 30.0  # 贴图 64×64，按 1 倍画，火焰覆盖的半径
const BLAST_ID := "fire_giant_explosion"  # 96×96 4 帧 16 帧/秒，中心锚点
const WARN_COLOR := Color(1.0, 0.45, 0.15)

var radius := PATCH_RADIUS
var warn := 0.0
var blast_radius := 0.0
var blast_damage := 0.0
var life := 4.0
var dps := 6.0
var _age := 0.0
var _blasted := false
var _player: Player
var _patch: Sprite2D


## 火焰巨人的死亡爆炸：预警 → 炸一次 → 留下火焰地面
static func blast(parent: Node, pos: Vector2, elite: bool = false) -> FireHazard:
	var hazard := FireHazard.new()
	hazard.position = pos
	hazard.warn = VigridTuning.GIANT_BLAST_WARN
	hazard.blast_radius = VigridTuning.GIANT_BLAST_RADIUS * (1.3 if elite else 1.0)
	hazard.blast_damage = VigridTuning.GIANT_BLAST_DAMAGE * (1.5 if elite else 1.0)
	hazard.life = VigridTuning.GIANT_FIRE_LIFE
	hazard.dps = VigridTuning.GIANT_FIRE_DPS
	parent.add_child.call_deferred(hazard)
	return hazard


## 一块持续燃烧的火焰地面（苏尔特横扫的残火）
static func patch(parent: Node, pos: Vector2, patch_life: float, patch_dps: float) -> FireHazard:
	var hazard := FireHazard.new()
	hazard.position = pos
	hazard.life = patch_life
	hazard.dps = patch_dps
	hazard._blasted = true
	parent.add_child.call_deferred(hazard)
	return hazard


func _ready() -> void:
	z_index = -1  # 画在角色下面
	var existing := get_tree().get_nodes_in_group("vigrid_hazards")
	for i in maxi(0, existing.size() - VigridTuning.HAZARD_MAX + 1):
		existing[i].queue_free()
	add_to_group("vigrid_hazards")
	_player = get_tree().get_first_node_in_group("player") as Player
	if ResourceLoader.exists(PATCH):
		_patch = Sprite2D.new()
		_patch.texture = load(PATCH)
		_patch.material = VigridMap.fire_hue()
		_patch.visible = _blasted
		add_child(_patch)
	if _blasted:
		Audio.sfx("fire_burn", -8.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if not _blasted and _age >= warn:
		_explode()
	if _blasted:
		var burning := _age - (warn if blast_radius > 0.0 else 0.0)
		if burning >= life:
			queue_free()
			return
		if is_instance_valid(_player) and contains(_player.global_position):
			_player.take_dot(dps * delta)
		if _patch:
			_patch.modulate.a = 0.9 * minf(1.0, (life - burning) / 0.6) * minf(1.0, burning / 0.2 + 0.3)
	queue_redraw()


## 火焰地面的判定：玩家位置在圆里
func contains(pos: Vector2) -> bool:
	return pos.distance_to(global_position) < radius


func in_blast(pos: Vector2) -> bool:
	return pos.distance_to(global_position) < blast_radius + Player.RADIUS


func _explode() -> void:
	_blasted = true
	Audio.sfx("big_death", -2.0)
	Audio.sfx("fire_burn", -6.0)
	if is_instance_valid(_player) and in_blast(_player.global_position):
		_player.take_damage(blast_damage)
	if is_instance_valid(_player) and _player.global_position.distance_to(global_position) < 300.0:
		_player.shake(3.0, 0.12)
	if not BossFx.play(BLAST_ID, global_position, 0.0, Vector2.ONE * blast_radius / 44.0, Color.WHITE, false, blast_radius):  # 贴图按判定半径缩放并裁切
		FxLayer.burst(global_position, WARN_COLOR, 24, 220.0, 4.0)
	if _patch:
		_patch.visible = true


func _draw() -> void:
	if not _blasted and warn > 0.0:
		Boss.draw_circle_telegraph(self, Vector2.ZERO, blast_radius, _age / warn, WARN_COLOR)
	elif _blasted:  # 火焰地面：贴图下面再垫一层同半径的底色和边线，一眼能看出烧到哪里
		var alpha: float = _patch.modulate.a if _patch else 0.9
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.35, 0.08, 0.22 * alpha))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(1.0, 0.6, 0.25, 0.55 * alpha), 1.5)
