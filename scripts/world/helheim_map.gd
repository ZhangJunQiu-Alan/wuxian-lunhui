class_name HelheimMap
extends MapLayer
## 第 2 关「亡者之船」的地图，布局和各地标的细节见 docs/地图设计_第2关.md
## 冥河横贯北部，只能从吉欧尔桥和结冰的浅滩过河；敌人隔着河追玩家时会先绕到过河点
## 任务 E 的素材还没到的部分先用 placeholders 的纯色块代替

const STONE := ["stone_01", "stone_01", "stone_02", "stone_02", "stone_03", "stone_04"]
const CLEAR_SPAWN := 300.0
const RIVER_STEP := 50.0  # 冥河碰撞圆的间距

var _river: Dictionary


func _init() -> void:
	ground_dir = "res://assets/sprites/ground/helheim/"
	props_dir = "res://assets/sprites/props/helheim/"
	decals_dir = "res://assets/sprites/decals/helheim/"
	borders_dir = "res://assets/sprites/borders/helheim/"
	var t := Vector2i(TILE, TILE)
	placeholders = {
		"river_01": [Color(0.07, 0.08, 0.11), t], "river_ice": [Color(0.42, 0.5, 0.56), t],
		"bridge_deck": [Color(0.45, 0.36, 0.2), t], "bone_path": [Color(0.24, 0.25, 0.26), t],
		"plaza": [Color(0.2, 0.2, 0.23), t],
		"dark_sea_01": [Color(0.04, 0.05, 0.07), Vector2i(256, 192)],
		"hel_wall_01": [Color(0.13, 0.11, 0.15), Vector2i(192, 256)],
		"fog_abyss_01": [Color(0.72, 0.75, 0.77), Vector2i(192, 256)],
		"ice_cliff_01": [Color(0.24, 0.25, 0.28), Vector2i(256, 192)],
		"border_corner_ne": [Color(0.09, 0.08, 0.11), Vector2i(192, 192)],
		"border_corner_nw": [Color(0.3, 0.32, 0.35), Vector2i(192, 192)],
		"border_corner_se": [Color(0.18, 0.17, 0.2), Vector2i(192, 192)],
		"border_corner_sw": [Color(0.45, 0.47, 0.5), Vector2i(192, 192)],
		"naglfar": [Color(0.62, 0.56, 0.4), Vector2i(640, 320)],
		"soul_lamp": [Color(0.3, 0.45, 0.42), Vector2i(32, 96)],
		"hall_pillar": [Color(0.12, 0.11, 0.14), Vector2i(64, 192)],
		"empty_throne": [Color(0.22, 0.18, 0.24), Vector2i(64, 96)],
		"long_table": [Color(0.3, 0.22, 0.16), Vector2i(160, 64)],
		"world_root_arch": [Color(0.28, 0.22, 0.16), Vector2i(384, 192)],
		"nail_heap_01": [Color(0.7, 0.64, 0.46), Vector2i(96, 80)],
		"workbench": [Color(0.38, 0.28, 0.18), Vector2i(96, 64)],
		"small_cave": [Color(0.1, 0.1, 0.12), Vector2i(128, 96)],
		"gnipa_cave": [Color(0.06, 0.06, 0.07), Vector2i(256, 192)],
	}


func _layout() -> void:
	_river = map.river
	var lm := {}
	for landmark: Dictionary in map.landmarks:
		lm[landmark.id] = landmark
	for cell in all_cells():
		set_ground(cell, STONE[rng.randi() % STONE.size()])
	border("dark_sea_01", "hel_wall_01", "ice_cliff_01", "fog_abyss_01")
	var y0: float = _river.y
	var h: float = _river.half
	var bridge: Vector2 = _river.crossings[0]
	var ford: Vector2 = _river.crossings[1]
	# 小路：南岸从广场通往各处，北岸从桥通往港口和工坊；浅滩连着工坊和沼泽
	for to in [Vector2(0, y0 + h), lm.hall.pos, lm.root.pos, lm.cave.pos]:
		paint_path(Vector2.ZERO, to, rng.randf_range(-200.0, 200.0), 80.0, "bone_path")
	paint_path(Vector2(0, y0 - h), lm.harbor.pos, 120.0, 80.0, "bone_path")
	paint_path(lm.harbor.pos, lm.workshop.pos, -150.0, 70.0, "bone_path")
	paint_path(lm.workshop.pos, Vector2((ford.x + ford.y) / 2.0, y0 - h), 80.0, 70.0, "bone_path")
	paint_path(Vector2((ford.x + ford.y) / 2.0, y0 + h), lm.marsh.pos, -60.0, 70.0, "bone_path")
	paint_path(lm.marsh.pos, lm.root.pos, 150.0, 70.0, "bone_path")
	paint_path(lm.hall.pos, lm.cave.pos, -120.0, 70.0, "bone_path")
	_paint_river(y0, h, bridge, ford)
	_plaza(lm.plaza.pos)
	_bridge(Vector2(0, y0), h, bridge)
	_harbor(lm.harbor.pos)
	_marsh(lm.marsh.pos)
	_hall(lm.hall.pos)
	_root(lm.root.pos)
	_cave(lm.cave.pos)
	_workshop(lm.workshop.pos)
	_scatter()


## 冥河：整条河铺河水，桥下铺桥面，浅滩铺冰；除了两处过河点，沿河排一串碰撞圆
func _paint_river(y0: float, h: float, bridge: Vector2, ford: Vector2) -> void:
	var from := cell_at(Vector2(Game.view_bounds.position.x, y0 - h))
	var to := cell_at(Vector2(Game.view_bounds.end.x, y0 + h - 1.0))
	for x in range(from.x, to.x + 1):
		for y in range(from.y, to.y + 1):
			var cx := x * TILE + TILE * 0.5
			var tile := "river_01"
			if cx > bridge.x and cx < bridge.y:
				tile = "bridge_deck"
			elif cx > ford.x and cx < ford.y:
				tile = "river_ice"
			set_ground(Vector2i(x, y), tile)
	var x := Game.bounds.position.x
	while x <= Game.bounds.end.x:
		if not _in_crossing(x, h):
			add_obstacle(Vector2(x, y0), h)
		x += RIVER_STEP


## 碰撞圆的圆心离过河点至少一个半径，免得圆鼓进过河点里
func _in_crossing(x: float, r: float) -> bool:
	for c: Vector2 in _river.crossings:
		if x > c.x - r and x < c.y + r:
			return true
	return false


## 敌人和玩家隔着冥河时，先走到最近的过河点，过了河再追
func waypoint(from: Vector2, to: Vector2) -> Vector2:
	var y0: float = _river.y
	var h: float = _river.half
	var from_north := from.y < y0
	if from_north == (to.y < y0):
		return to
	var best: Vector2 = _river.crossings[0]
	for c: Vector2 in _river.crossings:
		var mid := (c.x + c.y) / 2.0
		if absf(from.x - mid) + absf(mid - to.x) < absf(from.x - (best.x + best.y) / 2.0) + absf((best.x + best.y) / 2.0 - to.x):
			best = c
	var cx := (best.x + best.y) / 2.0
	var side := -1.0 if from_north else 1.0
	var in_column := from.x > best.x + 12.0 and from.x < best.y - 12.0
	if in_column and absf(from.y - y0) < h + 30.0:
		return Vector2(cx, y0 - side * (h + 40.0))  # 已经在过河点上：直接走到对岸
	return Vector2(cx, y0 + side * (h + 20.0))


## ⓪ 亡者广场：破碎的石板，四角四盏熄灭的磷火灯柱，一列列朝北的脚印，亡者丢下的东西
func _plaza(c: Vector2) -> void:
	fill_disc(c, 230.0, "plaza", 0.15)
	for corner in [Vector2(-170, -150), Vector2(170, -150), Vector2(-170, 170), Vector2(170, 170)]:
		prop("soul_lamp", c + corner, 8.0)
	prop("broken_headstone", c + Vector2(-60, 110), 0.0, true)
	prop("bone_pile", c + Vector2(90, 60))


## ① 吉欧尔桥：桥面两侧一排栏杆
func _bridge(c: Vector2, h: float, crossing: Vector2) -> void:
	var y := c.y - h + 24.0
	while y < c.y + h + 24.0:
		prop("gjoll_railing", Vector2(crossing.x + 4.0, y)).rotation = PI / 2
		prop("gjoll_railing", Vector2(crossing.y - 4.0, y)).rotation = PI / 2
		y += 90.0
	prop("chain_pillar", Vector2(crossing.x - 40.0, c.y + h + 70.0), 10.0)
	prop("chain_pillar", Vector2(crossing.y + 40.0, c.y + h + 70.0), 10.0, true)


## ② 纳吉尔法尔港：岸边停着指甲拼成的巨船，指甲铺的码头
func _harbor(c: Vector2) -> void:
	var shore := Game.bounds.position.y
	for x in range(-6, 7):
		for y in range(0, 4):
			set_ground(cell_at(Vector2(c.x + x * TILE, shore + y * TILE + 4.0)), "nail_deck_0%d" % rng.randi_range(1, 2))
	wide_prop("naglfar", Vector2(c.x, shore + 60.0), 560.0, 40.0)
	for i in 5:
		prop("bone_pile", c + Vector2(rng.randf_range(-350, 350), rng.randf_range(0, 250)), 0.0, rng.randf() < 0.5)


## ③ 冥雾沼泽：灰绿的泥地，半沉的枯树
func _marsh(c: Vector2) -> void:
	fill_disc(c, 560.0, "fog_ground", 0.3)
	for i in 14:
		var at := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(120.0, 520.0)
		if is_free(at, 26.0):
			prop("mist_dead_tree", at, 10.0, rng.randf() < 0.5)


## ④ 海拉的大厅：两排黑色石柱，空着的王座和长桌
func _hall(c: Vector2) -> void:
	fill_disc(c, 300.0, "plaza", 0.1)
	for i in 4:
		prop("hall_pillar", c + Vector2(-160, -220 + i * 120), 22.0)
		prop("hall_pillar", c + Vector2(160, -220 + i * 120), 22.0)
	prop("empty_throne", c + Vector2(0, -260), 20.0)
	wide_prop("long_table", c + Vector2(0, 10), 110.0, 16.0)


## ⑤ 世界树之根：拱出地面的巨根，两端挡路，中间可以穿过
func _root(c: Vector2) -> void:
	prop("world_root_arch", c + Vector2(0, 60))
	add_obstacle(c + Vector2(-150, 30), 36.0)
	add_obstacle(c + Vector2(150, 30), 36.0)


## ⑥ 加姆的洞窟：南墙上的洞口，断掉的铁链，满地骨头
func _cave(c: Vector2) -> void:
	var wall := Game.bounds.end.y
	_border_sprite("gnipa_cave", Vector2(c.x - 128.0, wall - 8.0))
	prop("chain_pillar", c + Vector2(-110, 160), 10.0)
	prop("chain_pillar", c + Vector2(110, 160), 10.0, true)
	prop("small_cave", c + Vector2(-300, 330), 30.0)
	for i in 6:
		prop("bone_pile", c + Vector2(rng.randf_range(-200, 200), rng.randf_range(0, 250)), 0.0, rng.randf() < 0.5)


## ⑦ 指甲工坊：指甲堆成的小山、工作台
func _workshop(c: Vector2) -> void:
	for i in 5:
		prop("nail_heap_01", c + Vector2.from_angle(TAU * i / 5.0 + 0.3) * 230.0, 26.0, i % 2 == 0)
	prop("workbench", c + Vector2(-40, 20), 18.0)


func _scatter() -> void:
	var inner := Game.bounds.grow(-48.0)
	for i in 60:
		var at := _free_spot(inner, 30.0)
		if at.is_finite():
			prop("mist_dead_tree", at, 10.0, rng.randf() < 0.5)
	for i in 50:
		var at := _free_spot(inner, 24.0)
		if at.is_finite():
			prop("bone_pile", at, 0.0, rng.randf() < 0.5)
	for i in 30:
		var at := _free_spot(inner, 24.0)
		if at.is_finite():
			prop("broken_headstone", at, 0.0, rng.randf() < 0.5)
	for i in 12:
		var at := _free_spot(inner, 30.0)
		if at.is_finite():
			prop("chain_pillar", at, 10.0, rng.randf() < 0.5)


## 随机找一处空地，找不到返回 Vector2.INF
func _free_spot(area: Rect2, r: float) -> Vector2:
	for attempt in 30:
		var at := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if _on_land(at) and is_free(at, r):
			return at
	return Vector2.INF


## 离开出生点、各地标和冥河
func _on_land(at: Vector2) -> bool:
	if at.length() < CLEAR_SPAWN or absf(at.y - _river.y) < _river.half + 60.0:
		return false
	for landmark: Dictionary in map.landmarks:
		if at.distance_to(landmark.pos) < landmark.radius * 0.85:
			return false
	return true
