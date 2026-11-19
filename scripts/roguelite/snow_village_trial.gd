extends Game

const Stage := preload("res://scripts/roguelite/snow_village_stage.gd")
const MAP_SIZE := Vector2(2320, 1240)
const START := Vector2(-890, 0)
const VILLAGE := Vector2(-540, 0)
const SHRINE := Vector2(10, 0)
const LAKE := Vector2(510, 0)
const BOSS_ENTRY := Vector2(810, -125)
const WOLVES := 3
const VILLAGE_ENEMIES := [
	["draugr", Vector2(-420, -95)], ["draugr", Vector2(-395, 90)],
	["draugr", Vector2(-315, 12)], ["ice_spirit", Vector2(-220, -100)],
]
const LAKE_ENEMIES := [
	["wolf", Vector2(585, -135)], ["wolf", Vector2(670, 100)],
	["draugr", Vector2(560, 55)], ["ice_spirit", Vector2(745, -100)],
	["ice_spirit", Vector2(795, 135)],
]
enum Step { VILLAGE_GATE, VILLAGE_FIGHT, SHRINE, BLESSING, LAKE_GATE, LAKE_FIGHT, BOSS, COMPLETE }

var step := Step.VILLAGE_GATE
var stage: Stage
var _objective: Label


func _ready() -> void:
	level_id = "midgard"
	level_data = {"name": tr("米德加尔特 · 雪村突围"), "max_enemies": 6,
		"enemy_growth": {"hp_linear": 0.0, "hp_square": 0.0, "damage_per_minute": 0.0}}
	view_bounds = Rect2(-MAP_SIZE / 2.0, MAP_SIZE)
	_limit_route(-155.0)
	MapLayer.obstacles.clear()
	Enemy.crit_chance = 0.0
	GodPower.fusions.clear()
	add_child(FxLayer.new())
	FxLayer.instance.hide()
	Audio.music("midgard")

	player = Player.new()
	player.character_id = "swordsman"
	player.swordsman_kit_override = "katana"
	player.dash_through_obstacles = false
	player.position = START
	add_child(player)
	player.hide()
	player._camera.enabled = false
	player.died.connect(_on_player_died)
	player.xp_to_next = 1000
	player.katana.cooldown = 0.40
	player.katana.reach = 84.0
	player.katana.damage = 22.0
	player.aim_point = func(screen: Vector2) -> Vector2: return stage.ground_at(screen)  # 鼠标投到 3D 地面上
	player.swordsman_weapon._timer = 0.0

	stage = Stage.new()
	stage.player = player
	add_child(stage)
	stage.mark_route_limit(bounds.end.x, true)
	player.died.connect(stage.show_death)
	player.swordsman_weapon.swung.connect(stage.show_slash)
	_setup_interface()
	hud.restart_scene = scene_file_path
	hud._xp_bar.hide()
	hud._ult_bar.hide()
	hud._ult_label.hide()
	_objective = _label(tr("前往雪村"), Vector2(0, 9), true)
	var controls := _label(tr("WASD 移动    鼠标左键挥砍    空格闪避    Esc 暂停"), Vector2(0, -49), false)
	controls.add_theme_font_size_override("font_size", 16)
	stage.mark_objective(VILLAGE)


func _label(message: String, at: Vector2, top: bool) -> Label:
	var label := UiKit.outlined(Label.new(), 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP if top else Control.PRESET_CENTER_BOTTOM)
	label.offset_left = at.x - 360.0
	label.offset_right = at.x + 360.0
	label.offset_top = at.y
	label.offset_bottom = at.y + 34.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = message
	label.add_theme_font_size_override("font_size", 21)
	hud.add_child(label)
	return label


func _limit_route(right_edge: float) -> void:
	bounds = view_bounds.grow(-95.0)
	bounds.end.x = minf(bounds.end.x, right_edge)
	if stage:
		stage.mark_route_limit(bounds.end.x, right_edge < view_bounds.end.x)


func _process(delta: float) -> void:
	if not is_running():
		return
	elapsed += delta
	var alive := get_tree().get_node_count_in_group("enemies")
	match step:
		Step.VILLAGE_GATE:
			if player.position.x >= VILLAGE.x:
				_start_encounter(Step.VILLAGE_FIGHT, VILLAGE_ENEMIES)
		Step.VILLAGE_FIGHT:
			if alive == 0:
				step = Step.SHRINE
				_limit_route(355.0)
				_objective.text = tr("前往奥丁石阵")
				stage.mark_objective(SHRINE)
		Step.SHRINE:
			if player.position.distance_to(SHRINE) <= 95.0:
				step = Step.BLESSING
				stage.hide_objective()
				_queue_reward({"kind": "god"})
		Step.LAKE_GATE:
			if player.position.x >= LAKE.x:
				_start_encounter(Step.LAKE_FIGHT, LAKE_ENEMIES)
		Step.LAKE_FIGHT:
			if alive == 0:
				_start_boss()
	if step in [Step.VILLAGE_FIGHT, Step.LAKE_FIGHT]:
		_objective.text = tr("%s   ·   剩余 %d") % [tr("雪村遭遇") if step == Step.VILLAGE_FIGHT else tr("冰湖遭遇"),
			get_tree().get_node_count_in_group("enemies")]
	hud._kills_label.text = tr("击杀 %d") % kills


func _start_encounter(next: Step, enemies: Array) -> void:
	step = next
	stage.hide_objective()
	for entry in enemies:
		spawn_enemy(entry[0], entry[1])


func spawn_enemy(type_id: String, pos: Vector2, elite: bool = false, required: bool = false) -> Enemy:
	if step == Step.BOSS and type_id == "wolf" and int(_alive_by_type.get("wolf", 0)) >= WOLVES:
		return null
	var enemy := super.spawn_enemy(type_id, pos, elite, required)
	if enemy:
		enemy.hide()
		enemy.max_hp *= 2.0
		enemy.hp = enemy.max_hp
		enemy.xp_value = 0
		stage.track(enemy)
	return enemy


func _offers(entry: Dictionary) -> Array[Dictionary]:
	if step == Step.BLESSING:
		return [{"id": "thor_skill", "rarity": -1}, {"id": "skadi_skill", "rarity": -1}]
	return super._offers(entry)


func _on_upgrade_chosen(offer: Dictionary) -> void:
	super._on_upgrade_chosen(offer)
	if step == Step.BLESSING and not player.faith.is_empty():
		player.heal(25.0)
		step = Step.LAKE_GATE
		_limit_route(view_bounds.end.x)
		_objective.text = tr("穿过雪原，前往冰湖")
		stage.mark_objective(LAKE)


func _start_boss() -> void:
	step = Step.BOSS
	boss = BossDB.create("skoll", 0.45)
	boss.target = player
	boss.spawner = spawn_enemy
	boss.position = BOSS_ENTRY
	boss.killed.connect(_on_enemy_killed)
	boss.hp_changed.connect(hud.set_boss_hp)
	boss.defeated.connect(_on_boss_defeated)
	add_child(boss)
	boss.hide()
	stage.track(boss)
	_objective.text = tr("击败斯库尔")
	hud.show_boss(boss.display_name, boss.title, boss.max_hp)
	Audio.music("boss")


func _on_boss_defeated(_defeated_boss: Boss) -> void:
	step = Step.COMPLETE
	_begin_ending()
	get_tree().create_timer(0.65).timeout.connect(_on_level_cleared)


func _finish_run(_cleared: bool) -> Dictionary:
	return {"elapsed": elapsed, "kills": kills, "level": player.level, "reward_points": 0, "reward_total": 0, "loot": []}


func _on_level_cleared() -> void:
	_run_state = RunState.ENDED
	Audio.music("victory")
	hud.show_result("victory", level_data.name, tr("雪村的路重新打开了。"), _finish_run(true), player)


func _exit_tree() -> void:
	MapLayer.obstacles.clear()


func _draw() -> void:
	pass
