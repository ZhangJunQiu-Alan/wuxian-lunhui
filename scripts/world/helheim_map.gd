class_name HelheimMap
extends MapLayer
## 第 2 关「亡者之船」的地图，布局和各地标的细节见 docs/地图设计.md
## 冥河横贯北部，只能从吉欧尔桥和结冰的浅滩过河；敌人隔着河追玩家时会先绕到过河点

const STONE := ["stone_01", "stone_01", "stone_02", "stone_02", "stone_03", "stone_04"]
const CLEAR_SPAWN := 300.0
const RIVER_STEP := 50.0  # 冥河碰撞圆的间距
const ARCH_CROWN := 75    # 世界树根拱顶（图片上方这么多像素）画在角色上面，看起来像从根下穿过
const BELONGINGS := ["cane", "straw_hat", "wine_jug", "wooden_horse"]

var _river: Dictionary


func _init() -> void:
	ground_dir = "res://assets/sprites/ground/helheim/"
	props_dir = "res://assets/sprites/props/helheim/"
	decals_dir = "res://assets/sprites/decals/helheim/"
	borders_dir = "res://assets/sprites/borders/helheim/"
	edges = {"bone_path": "bone_path_edge", "marsh": "marsh_edge", "river_01": "river_edge"}
	edge_masks = {"plaza": "bone_path_edge", "river_ice": "river_edge"}  # 浅滩的冰叠在河水上面
	variants = {"river_01": ["river_02"]}


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
	var haul := paint_path(lm.harbor.pos, lm.workshop.pos, -150.0, 70.0, "bone_path")
	paint_path(lm.workshop.pos, Vector2((ford.x + ford.y) / 2.0, y0 - h), 80.0, 70.0, "bone_path")
	paint_path(Vector2((ford.x + ford.y) / 2.0, y0 + h), lm.marsh.pos, -60.0, 70.0, "bone_path")
	paint_path(lm.marsh.pos, lm.root.pos, 150.0, 70.0, "bone_path")
	paint_path(lm.hall.pos, lm.cave.pos, -120.0, 70.0, "bone_path")
	for i in range(4, haul.size() - 4, 5):  # 搬运指甲的拖痕：从工坊一路拖到港口
		decal("drag_mark_01", haul[i]).rotation = (haul[i + 1] - haul[i]).angle() - PI / 2
	_paint_river(y0, h, ford)
	_plaza(lm.plaza.pos)
	_bridge(Vector2(0, y0), h, bridge)
	_harbor(lm.harbor.pos)
	_marsh(lm.marsh.pos)
	_hall(lm.hall.pos)
	_root(lm.root.pos)
	_cave(lm.cave.pos)
	_workshop(lm.workshop.pos)
	_scatter()


## 冥河：整条河铺河水（桥下也是，桥是盖在上面的物件），浅滩再叠一层冰；除了两处过河点，沿河排一串碰撞圆
func _paint_river(y0: float, h: float, ford: Vector2) -> void:
	var from := cell_at(Vector2(Game.view_bounds.position.x, y0 - h))
	var to := cell_at(Vector2(Game.view_bounds.end.x, y0 + h - 1.0))
	for x in range(from.x, to.x + 1):
		for y in range(from.y, to.y + 1):
			set_ground(Vector2i(x, y), "river_01")
			var cx := x * TILE + TILE * 0.5
			if cx > ford.x and cx < ford.y:
				set_ground(Vector2i(x, y), "river_ice")
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
	for column in [-90.0, 0.0, 90.0]:  # 亡者排队的脚印，一列列朝北走向桥
		for row in 4:
			decal("queue_tracks_0%d" % (1 + row % 2), c + Vector2(column + rng.randf_range(-8, 8), 120.0 - row * 72.0))
	for i in 6:
		decal("moss_0%d" % rng.randi_range(1, 2), c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(80.0, 220.0), rng.randf() < 0.5)
	for i in BELONGINGS.size():
		prop(BELONGINGS[i], c + Vector2.from_angle(TAU * i / BELONGINGS.size() + 0.6) * rng.randf_range(140.0, 200.0), 0.0, rng.randf() < 0.5)
	prop("broken_headstone", c + Vector2(-60, 110), 0.0, true)


## ① 吉欧尔桥：金瓦长桥横跨冥河（桥面中间能走），南桥头是守桥人的石亭，两岸沿河一段栏杆
func _bridge(c: Vector2, h: float, crossing: Vector2) -> void:
	prop("gjoll_bridge", Vector2((crossing.x + crossing.y) / 2.0, c.y + 192.0))
	prop("bridge_booth", Vector2(crossing.y + 90.0, c.y + h + 110.0), 30.0)
	for side in [-1.0, 1.0]:
		for i in 2:
			var x: float = (crossing.y + 70.0 + i * 96.0) if side > 0 else (crossing.x - 70.0 - i * 96.0)
			prop("gjoll_railing", Vector2(x, c.y + h + 26.0))
	prop("chain_pillar", Vector2(crossing.x - 40.0, c.y + h + 90.0), 10.0)


## ② 纳吉尔法尔港：岸边停着指甲拼成的巨船，指甲铺的码头
func _harbor(c: Vector2) -> void:
	var shore := Game.bounds.position.y
	for x in range(-6, 7):
		for y in range(0, 4):
			set_ground(cell_at(Vector2(c.x + x * TILE, shore + y * TILE + 4.0)), "nail_deck_0%d" % rng.randi_range(1, 2))
	wide_prop("naglfar", Vector2(c.x, shore + 60.0), 560.0, 40.0)
	prop("nail_pier", Vector2(c.x + 400.0, shore + 300.0))
	for i in 10:  # 岸上堆着指甲筐、木箱、亡者士兵的盾和矛
		var at := c + Vector2(rng.randf_range(-380, 380), rng.randf_range(-40, 260))
		if is_free(at, 22.0):
			var file: String = ["nail_basket", "cargo_crate", "shield_spear", "bone_pile"][i % 4]
			prop(file, at, 16.0 if file == "cargo_crate" else 0.0, rng.randf() < 0.5)


## ③ 冥雾沼泽：灰绿的泥地，半沉在泥里的枯树，浮在水面的白骨，迷路亡者丢下的行李
func _marsh(c: Vector2) -> void:
	fill_disc(c, 560.0, "marsh", 0.3)
	for i in 22:
		var at := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(120.0, 520.0)
		if not is_free(at, 26.0):
			continue
		match i % 3:
			0:
				prop("sunken_tree", at, 14.0, rng.randf() < 0.5)
			1:
				prop("floating_bones", at, 0.0, rng.randf() < 0.5)
			2:
				prop("luggage" if i % 2 == 0 else "mist_dead_tree", at, 0.0 if i % 2 == 0 else 10.0, rng.randf() < 0.5)


## ④ 海拉的大厅：两排黑色石柱，南边是倒塌的拱门和门前的长毯，深处是空着的王座和长桌；
## 一串八只蹄的马蹄印从南边一直延伸进大门
func _hall(c: Vector2) -> void:
	fill_disc(c, 300.0, "plaza", 0.1)
	for i in 4:
		prop("hall_pillar", c + Vector2(-160, -220 + i * 120), 22.0)
		prop("hall_pillar", c + Vector2(160, -220 + i * 120), 22.0)
	prop("hall_carpet", c + Vector2(0, 280))  # 平铺在地上的长毯，没有碰撞
	prop("hall_arch_broken", c + Vector2(0, 300))
	add_obstacle(c + Vector2(-80, 280), 24.0)  # 拱门两侧的残柱挡路，中间能走
	add_obstacle(c + Vector2(80, 280), 24.0)
	prop("empty_throne", c + Vector2(0, -260), 20.0)
	wide_prop("long_table", c + Vector2(0, 10), 110.0, 16.0)
	for i in 5:
		decal("hoof_tracks_0%d" % (1 + i % 2), c + Vector2(30.0 + sin(i) * 14.0, 360.0 + i * 80.0))


## ⑤ 世界树之根：拱出地面的巨根，两端挡路，中间可以穿过（拱顶画在角色上面）；根旁有裂缝和发光的蘑菇
func _root(c: Vector2) -> void:
	var arch := prop("world_root_arch", c + Vector2(0, 60))
	var crown := Sprite2D.new()
	crown.texture = arch.texture
	crown.region_enabled = true
	crown.region_rect = Rect2(0, 0, arch.texture.get_width(), ARCH_CROWN)
	crown.centered = false
	crown.position = arch.position - Vector2(arch.texture.get_width() * 0.5, arch.texture.get_height())
	crown.z_index = 20  # 地图整体是 -10，这里算下来比角色高
	add_child(crown)
	add_obstacle(c + Vector2(-150, 30), 36.0)
	add_obstacle(c + Vector2(150, 30), 36.0)
	for i in 4:
		decal("root_crack_0%d" % (1 + i % 2), c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(160.0, 320.0), rng.randf() < 0.5)
	for i in 10:
		var at := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(200.0, 420.0)
		if is_free(at, 12.0):
			prop("glow_mushroom", at, 0.0, rng.randf() < 0.5)


## ⑥ 加姆的洞窟：南墙上的洞口，断掉的铁链，满地骨头
func _cave(c: Vector2) -> void:
	var wall := Game.bounds.end.y
	_border_sprite("gnipa_cave", Vector2(c.x - 128.0, wall - 8.0))
	prop("chain_pillar", c + Vector2(-110, 160), 10.0)
	prop("chain_pillar", c + Vector2(110, 160), 10.0, true)
	prop("small_cave", c + Vector2(-300, 330), 30.0)
	for i in 6:
		prop("bone_pile", c + Vector2(rng.randf_range(-200, 200), rng.randf_range(0, 250)), 0.0, rng.randf() < 0.5)
	for i in 3:
		decal("dried_blood_0%d" % (1 + i % 2), c + Vector2(rng.randf_range(-160, 160), rng.randf_range(160, 320)), rng.randf() < 0.5)
	decal("paw_tracks_01", c + Vector2(-40, 120))
	decal("paw_tracks_01", c + Vector2(50, 40), true)


## ⑦ 指甲工坊：指甲堆成的小山、工作台、半成品的船板、拼到一半倒在地上的指甲傀儡
func _workshop(c: Vector2) -> void:
	for i in 5:
		prop("nail_heap_0%d" % (1 + i % 2), c + Vector2.from_angle(TAU * i / 5.0 + 0.3) * 230.0, 26.0, i % 2 == 0)
	prop("workbench", c + Vector2(-40, 20), 18.0)
	prop("nail_plank", c + Vector2(70, 60))
	prop("nail_plank", c + Vector2(-110, 90), 0.0, true)
	prop("half_golem", c + Vector2(40, -80))


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
	for i in 20:  # 亡者丢下的行李和随身物品
		var at := _free_spot(inner, 20.0)
		if at.is_finite():
			prop("luggage" if i % 3 == 0 else BELONGINGS[i % BELONGINGS.size()], at, 0.0, rng.randf() < 0.5)
	for i in 40:
		var at := _free_spot(inner, 20.0)
		if at.is_finite():
			decal("moss_0%d" % rng.randi_range(1, 2), at, rng.randf() < 0.5)


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
