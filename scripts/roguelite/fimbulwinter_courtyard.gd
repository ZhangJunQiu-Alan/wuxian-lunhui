extends Game

const Stage := preload("res://scripts/roguelite/fimbulwinter_courtyard_stage.gd")
const CourtPlayer := preload("res://scripts/roguelite/fimbulwinter_courtyard_player.gd")
const Layout := preload("res://scripts/roguelite/fimbulwinter_courtyard_layout.gd")
const START := Vector2(-2625, 91)
const APPROACH_TRIGGER := -2325.0
const APPROACH_LIMIT := -1710.0
const ENTRANCE := Vector2(-672, -165)
const ENCOUNTER_X := -600.0
const SEALED_EDGE := -642.0
const CLOSED_EDGE := 808.0 + Layout.EAST_SHIFT
const FOES := [
	["draugr", Vector2(-195, -470)], ["draugr", Vector2(350, 420)],
	["draugr", Vector2(905, 100)], ["ice_spirit", Vector2(545, -556)],
]
const APPROACH_FOES := [
	["draugr", Vector2(-2138, -140)], ["draugr", Vector2(-1990, 157)],
	["ice_spirit", Vector2(-1825, -132)],
]

enum Phase { ENTRY, APPROACH_FIGHT, COURT_ENTRY, BATTLE, REWARD, EXIT, COMPLETE }

var phase := Phase.ENTRY
var stage: Stage
var _objective: Label
var _reward_delay := 0.0


func _ready() -> void:
	level_id = "midgard"
	level_data = {"name": tr("芬布尔之冬 · 冻石庭院"), "max_enemies": FOES.size(),
		"enemy_growth": {"hp_linear": 0.0, "hp_square": 0.0, "damage_per_minute": 0.0}}
	view_bounds = Rect2(-2770, -1030, 4340 + Layout.EAST_SHIFT, 2060)
	bounds = Rect2(-2720, -390, APPROACH_LIMIT + 2720.0, 818)
	MapLayer.obstacles.clear()
	Enemy.crit_chance = 0.0
	GodPower.fusions.clear()
	add_child(FxLayer.new())
	FxLayer.instance.hide()
	Audio.music("midgard")

	player = CourtPlayer.new()
	player.character_id = "swordsman"
	player.swordsman_kit_override = "katana"
	player.dash_through_obstacles = false
	player.position = START
	add_child(player)
	player.hide()
	player._camera.enabled = false
	player.died.connect(_on_player_died)
	(player as CourtPlayer).foot_moved.connect(_on_foot_moved)
	player.xp_to_next = 1000
	player.katana.cooldown = 0.40
	player.katana.reach = 86.0
	player.katana.damage = 22.0
	player.swordsman_weapon.manual_attack = true
	player.swordsman_weapon._timer = 0.0

	stage = Stage.new()
	stage.player = player
	add_child(stage)
	player.swordsman_weapon.swung.connect(stage.show_slash)
	_setup_interface()
	hud.restart_scene = scene_file_path
	hud._xp_bar.hide()
	hud._ult_bar.hide()
	hud._ult_label.hide()
	hud._level_label.hide()
	UiKit.style_bar(hud._hp_bar, Color("#a85048"))
	_objective = _caption(tr("沿雪崖前行"), 52, true, 17, Color("#e4eaf4"))
	_caption(tr("芬布尔之冬 · 冻石庭院"), 21, true, 20, Color("#ffda9d"))
	_caption(tr("WASD 移动    鼠标左键挥砍    空格闪避    Esc 暂停"), -34, false, 13, Color("#dfecf8"))


func _caption(message: String, y: float, top: bool, size: int, color: Color) -> Label:
	var label := UiKit.outlined(UiKit.label(message, size, color, HORIZONTAL_ALIGNMENT_CENTER), 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP if top else Control.PRESET_CENTER_BOTTOM)
	label.offset_left = -410.0
	label.offset_right = 410.0
	label.offset_top = y
	label.offset_bottom = y + 26.0
	hud.add_child(label)
	return label


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and is_running():
		var aim := player.global_position.direction_to(stage.ground_at(event.position))
		player.swordsman_weapon.request_attack(aim if aim != Vector2.ZERO else player.facing)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_running():
		return
	elapsed += delta
	match phase:
		Phase.ENTRY:
			if player.position.x >= APPROACH_TRIGGER:
				phase = Phase.APPROACH_FIGHT
				stage.set_approach_seal(true)
				_spawn_encounter(APPROACH_FOES)
		Phase.APPROACH_FIGHT:
			var alive := get_tree().get_node_count_in_group("enemies")
			_objective.text = tr("清理雪崖前路 · 剩余 %d") % alive
			if alive == 0:
				phase = Phase.COURT_ENTRY
				bounds.end.x = CLOSED_EDGE
				stage.set_approach_seal(false)
				_objective.text = tr("进入庭院")
		Phase.COURT_ENTRY:
			if player.position.x >= ENCOUNTER_X and absf(player.position.y - ENTRANCE.y) < 87.0:
				phase = Phase.BATTLE
				bounds = Rect2(SEALED_EDGE, -936, CLOSED_EDGE - SEALED_EDGE, 1872)
				stage.seal_entrance()
				_spawn_encounter(FOES)
		Phase.BATTLE:
			var alive := get_tree().get_node_count_in_group("enemies")
			_objective.text = tr("清理庭院 · 剩余 %d") % alive
			if alive == 0:
				phase = Phase.REWARD
				stage.awaken_exit()
				_reward_delay = 0.86
				_objective.text = tr("庭院已清理")
		Phase.REWARD:
			_reward_delay -= delta
			if _reward_delay <= 0.0 and stage.portal_ready:
				_queue_reward({"kind": "god"})
	hud._kills_label.text = tr("击杀 %d") % kills


func _spawn_encounter(foes: Array) -> void:
	for entry in foes:
		var enemy := spawn_enemy(entry[0], entry[1], false, true)
		enemy.hide()
		enemy.max_hp *= 2.7
		enemy.hp = enemy.max_hp
		enemy.xp_value = 0
		stage.track(enemy)


func _offers(entry: Dictionary) -> Array[Dictionary]:
	if phase == Phase.REWARD and entry.kind == "god":
		return [{"id": "thor_skill", "rarity": -1}, {"id": "skadi_skill", "rarity": -1}]
	return super._offers(entry)


func _on_upgrade_chosen(offer: Dictionary) -> void:
	super._on_upgrade_chosen(offer)
	if phase != Phase.REWARD or player.faith.is_empty() or not stage.portal_ready:
		return
	var threshold := stage.exit_threshold
	bounds.end.x = ceilf(maxf(threshold[0].x, threshold[1].x)) + player.RADIUS + 1.0
	phase = Phase.EXIT
	_objective.text = tr("通过拱门离开庭院")


func _on_foot_moved(from: Vector2, to: Vector2) -> void:
	if phase != Phase.EXIT or not is_running():
		return
	var threshold := stage.exit_threshold
	var contact: Variant = Geometry2D.segment_intersects_segment(from, to, threshold[0], threshold[1])
	if contact != null:
		player.position = contact
		stage._sync_hero()
		_show_room_result()


func _show_room_result() -> void:
	phase = Phase.COMPLETE
	_begin_ending()
	_run_state = RunState.ENDED
	Audio.music("victory")
	hud.show_result("victory", level_data.name, tr("冻石庭院已通过。"), _finish_run(true), player)


func _finish_run(_cleared: bool) -> Dictionary:
	return {"elapsed": elapsed, "kills": kills, "level": player.level,
		"reward_points": 0, "reward_total": 0, "loot": []}


func _exit_tree() -> void:
	MapLayer.obstacles.clear()


func _draw() -> void:
	pass
