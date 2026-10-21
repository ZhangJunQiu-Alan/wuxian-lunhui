class_name MidgardMap
extends MapLayer
## 第 1 关「芬布尔之冬」的地图，布局和各地标的细节见 docs/地图设计_第1关.md
## 地标核心（半径的 45% 以内）不放挡路的物件，支线标记会出现在那里

const SNOW := ["snow_01", "snow_01", "snow_01", "snow_02", "snow_02", "snow_03", "snow_04"]
const CLEAR_SPAWN := 300.0  # 出生点周围留空


func _init() -> void:
	ground_dir = "res://assets/sprites/ground/midgard/"
	props_dir = "res://assets/sprites/props/midgard/"
	decals_dir = "res://assets/sprites/decals/midgard/"
	borders_dir = "res://assets/sprites/borders/midgard/"
	edges = {"snow_trampled": "path_edge", "ice": "ice_edge"}
	edge_masks = {"snow_thin": "path_edge"}
	variants = {"ice": ["ice_02"]}
	overlay = {"snow_trampled": 0.4, "snow_thin": 0.45}


func _layout() -> void:
	var lm := {}
	for landmark: Dictionary in map.landmarks:
		lm[landmark.id] = landmark
	for cell in all_cells():
		set_ground(cell, SNOW[rng.randi() % SNOW.size()])
	border("cliff_ice_01", "frozen_sea_01", "rock_wall_01", "dead_forest_01")
	# 十字路口通向每个地标，地标之间再连成一圈：任意两处之间至少有两条路
	for id in ["village", "harbor", "stones", "mounds", "lake"]:
		var road := paint_path(Vector2.ZERO, lm[id].pos, rng.randf_range(-250.0, 250.0), 90.0, "snow_trampled")
		for i in range(5, 16, 2):  # 十字路口附近的车辙
			if rng.randf() < 0.7:
				_trace("cart_ruts", road[i], road[i + 1] - road[i - 1])
		for i in range(16, road.size() - 8, 3):  # 往外走的脚印
			if rng.randf() < 0.25:
				_trace("human_tracks", road[i] + Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20)), road[i + 1] - road[i - 1])
	for pair in [["village", "harbor"], ["harbor", "lake"], ["lake", "mounds"], ["mounds", "stones"], ["stones", "village"]]:
		var road := paint_path(lm[pair[0]].pos, lm[pair[1]].pos, rng.randf_range(-300.0, 300.0), 70.0, "snow_trampled")
		for i in range(12, road.size() - 12, 4):
			if rng.randf() < 0.2:
				_trace("wolf_tracks", road[i] + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30)), road[i + 1] - road[i - 1])
	_crossroads(lm.crossroads.pos)
	_village(lm.village.pos)
	_harbor(lm.harbor.pos)
	_stones(lm.stones.pos)
	_mounds(lm.mounds.pos)
	_lake(lm.lake.pos)
	_scatter()


## 沿着方向 dir 贴一处痕迹。车辙 _01 是竖直的（横着走时转 90 度），其余素材都是「/」方向，「\」方向时左右翻转
func _trace(kind: String, at: Vector2, dir: Vector2) -> void:
	if kind == "cart_ruts" and absf(dir.x) < absf(dir.y) * 0.5:
		decal("cart_ruts_01", at)
	elif kind == "cart_ruts" and absf(dir.y) < absf(dir.x) * 0.5:
		decal("cart_ruts_01", at).rotation = PI / 2
	else:
		var file := "cart_ruts_02" if kind == "cart_ruts" else "%s_0%d" % [kind, rng.randi_range(1, 2)]
		decal(file, at, (dir.x > 0.0) == (dir.y > 0.0))


## ⓪ 十字路口：刻着符文的路标石，翻倒的手推车和散落的货物，路边歪斜的木桩路标
func _crossroads(c: Vector2) -> void:
	fill_disc(c, 200.0, "snow_trampled")
	prop("runestone_01", c + Vector2(70, -40), 10.0)
	prop("rock_01", c + Vector2(95, -20))
	prop("cart_overturned", c + Vector2(-165, -55), 16.0)
	prop("barrel_01", c + Vector2(-122, -38))
	prop("barrel_02", c + Vector2(-190, -18), 0.0, true)
	prop("sack_01", c + Vector2(-140, -14))
	prop("sack_02", c + Vector2(-205, -78), 0.0, true)
	prop("signpost_01", c + Vector2(150, 95))
	prop("signpost_02", c + Vector2(-95, 160), 0.0, true)
	prop("signpost_02", c + Vector2(30, -170))
	prop("rock_01", c + Vector2(-110, 70), 0.0, true)
	prop("snowdrift_01", c + Vector2(-150, -130))
	prop("snowdrift_02", c + Vector2(160, 120))
	decal("human_tracks_02", c + Vector2(-60, 30))


## ① 被雪掩埋的村庄：一圈长屋（积雪的、只剩木框架的、只露屋脊的），南北两侧的栅栏被撞断好几处
## 村子中间是冻住的水井、晾鱼架、劈柴墩、空羊圈和熄灭的篝火；村口散落着盾牌、刀剑和血迹：这里打过仗
func _village(c: Vector2) -> void:
	fill_disc(c, 430.0, "snow_trampled", 0.3)
	var houses := ["longhouse_snow", "longhouse_frame", "longhouse_ridge", "longhouse_snow", "collapsed_cabin", "longhouse_frame", "longhouse_ridge"]
	for i in houses.size():
		var angle := TAU * i / houses.size() + rng.randf_range(-0.2, 0.2)
		var at := c + Vector2.from_angle(angle) * rng.randf_range(400.0, 480.0)
		match houses[i]:
			"longhouse_ridge":
				wide_prop(houses[i], at, 70.0, 18.0, rng.randf() < 0.5)
			"collapsed_cabin":
				prop(houses[i], at, 34.0, rng.randf() < 0.5)
			_:
				wide_prop(houses[i], at, 100.0, 26.0, rng.randf() < 0.5)
	for side in [-1, 1]:
		var x := -520.0
		while x < 520.0:
			var at := c + Vector2(x, side * 580.0 + rng.randf_range(-8, 8))
			if absf(x) < 40.0:
				prop("fence_gate", at)
			elif absf(x) > 100.0 and rng.randf() > 0.15:  # 村口两边留空，其他地方随机断开
				prop("fence" if rng.randf() > 0.25 else "fence_broken_0%d" % rng.randi_range(1, 2), at, 0.0, rng.randf() < 0.5)
			x += 62.0
		# 村口打过仗
		for i in 3:
			decal("blood_0%d" % rng.randi_range(1, 3), c + Vector2(rng.randf_range(-120, 120), side * rng.randf_range(480.0, 640.0)), rng.randf() < 0.5)
		prop("broken_shield_0%d" % rng.randi_range(1, 2), c + Vector2(rng.randf_range(-140, -60), side * rng.randf_range(500.0, 640.0)))
		prop("weapons_in_snow", c + Vector2(rng.randf_range(60, 150), side * rng.randf_range(500.0, 640.0)), 0.0, rng.randf() < 0.5)
	prop("frozen_well", c + Vector2(-200, -60))
	prop("fish_rack", c + Vector2(180, -150), 0.0, true)
	prop("chopping_block", c + Vector2(230, 40))
	prop("sheep_pen", c + Vector2(-60, 250))
	prop("campfire_unlit", c + Vector2(20, -20))
	prop("barrel_02", c + Vector2(-240, -40))
	prop("sack_01", c + Vector2(205, -128), 0.0, true)
	for i in 8:
		prop("snowdrift_0%d" % rng.randi_range(1, 3), c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(200.0, 560.0))
	for i in 6:
		prop("rock_01", c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(160.0, 520.0), 0.0, rng.randf() < 0.5)
	for i in 6:
		_trace("human_tracks", c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(80.0, 380.0), Vector2.from_angle(rng.randf() * TAU))


## ② 峡湾码头：东北边是冰封的海，木码头伸进冰里、尽头被冰挤碎；两条长船残骸冻在冰里
## 岸边一排系船木桩，晾着渔网，翻倒的小船和堆在岸边的木箱
func _harbor(c: Vector2) -> void:
	fill_disc(c + Vector2(260, -380), 430.0, "ice", 0.25)
	fill_disc(c + Vector2(-60, 60), 260.0, "snow_trampled", 0.3)
	for ship: Array in [[Vector2(220, -300), false], [Vector2(-140, -360), true]]:
		var at: Vector2 = c + ship[0]
		prop("longship_wreck", at, 0.0, ship[1])
		add_obstacle(at + Vector2(-64, -32), 48.0)
		add_obstacle(at + Vector2(64, -32), 48.0)
	var pier := _shore(c + Vector2(40, 0)) + Vector2(0, TILE)
	for i in 6:  # 码头从岸上往北伸进冰海，可以走上去
		prop("pier_straight_0%d" % (i % 2 + 1), pier - Vector2(0, i * TILE))
	prop("pier_broken", pier - Vector2(0, 6 * TILE)).flip_v = true
	var x := -120.0
	while x < 340.0:  # 沿着岸线一排系船木桩
		if absf(x - 40.0) > 50.0:
			prop("mooring_post_0%d" % rng.randi_range(1, 2), _shore(c + Vector2(x, 0)) + Vector2(0, 28), 0.0, rng.randf() < 0.5)
		x += 85.0
	prop("fishing_net_01", c + Vector2(-190, 10))
	prop("fishing_net_02", c + Vector2(-60, 200), 0.0, true)
	prop("boat_overturned", c + Vector2(-320, -60), 0.0, true)
	add_obstacle(c + Vector2(-370, -100), 40.0)
	add_obstacle(c + Vector2(-270, -100), 40.0)
	prop("crate_stack_01", c + Vector2(300, 160), 18.0)
	prop("crate_stack_02", c + Vector2(350, 100), 18.0, true)
	prop("barrel_01", c + Vector2(270, 190))
	prop("sack_02", c + Vector2(330, 200))
	for i in 8:
		prop("rock_0%d" % rng.randi_range(1, 2), c + Vector2(rng.randf_range(-380, -140), rng.randf_range(-260, -120)), 0.0, rng.randf() < 0.5)
	for i in 4:
		prop("snowdrift_0%d" % rng.randi_range(1, 3), c + Vector2(rng.randf_range(-400, 300), rng.randf_range(0, 300)))


## 从 from 往南 300 像素处往北找，第一块冰面的南边缘（岸线）
func _shore(from: Vector2) -> Vector2:
	var cell := cell_at(from + Vector2(0, 300))
	while not _terrain.ice.has(cell) and cell.y > cell_at(from).y - 12:
		cell.y -= 1
	return Vector2(from.x, (cell.y + 1) * TILE)


## ③ 奥丁的符文石阵：一圈立石围着石砌祭坛，祭坛上摆着角杯和干枯的槲寄生，立石之间散落着渡鸦的羽毛；这里的雪很薄
func _stones(c: Vector2) -> void:
	fill_disc(c, 320.0, "snow_thin", 0.3)
	for i in 10:
		var at := c + Vector2.from_angle(TAU * i / 10.0 + 0.15) * 230.0
		prop("runestone_0%d" % (i % 3 + 1), at, 10.0, i % 4 == 0)
	prop("altar_01", c + Vector2(0, 16), 22.0)
	prop("drinking_horn_01", c + Vector2(-14, -10))
	prop("mistletoe_02", c + Vector2(15, -12))
	prop("drinking_horn_02", c + Vector2(-34, 24), 0.0, true)
	prop("mistletoe_01", c + Vector2(30, 26))
	for i in 7:
		prop("raven_feathers", c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(120.0, 300.0), 0.0, rng.randf() < 0.5)


## ④ 古老的墓丘：一圈隆起的墓丘，好几座裂开露出黑洞，有拖痕从墓里一直拖出来：尸鬼就是从这里来的
## 中间是小立石排成船形的石阵墓，四周散落倒下的墓碑、生锈的陪葬剑和骨堆
func _mounds(c: Vector2) -> void:
	var mounds := ["burial_mound_open", "burial_mound", "burial_mound_collapsed", "burial_mound_open", "burial_mound", "burial_mound_collapsed"]
	for i in mounds.size():
		var at := c + Vector2.from_angle(TAU * i / mounds.size() + rng.randf_range(-0.3, 0.3)) * rng.randf_range(400.0, 560.0)
		if mounds[i] == "burial_mound":
			wide_prop(mounds[i], at, 48.0, 26.0, rng.randf() < 0.5)
		else:
			wide_prop(mounds[i], at, 72.0, 28.0, rng.randf() < 0.5)
		fill_disc(at.lerp(c, 0.35), 70.0, "snow_trampled", 0.5)
		if mounds[i] == "burial_mound_open":  # 从墓里爬出来的拖痕
			for k in 3:
				var p := at.lerp(c, 0.12 + 0.12 * k)
				_trace("drag_mark", p + Vector2(0, 20), c - at)
	for i in 20:  # 船形石阵：两头尖的椭圆
		var angle := TAU * i / 20.0
		var at := c + Vector2(cos(angle) * 190.0, sin(angle) * 60.0 * (1.0 - 0.4 * absf(cos(angle)))) + Vector2(0, 40)
		prop("grave_stone_small_0%d" % rng.randi_range(1, 2), at, 6.0, rng.randf() < 0.5)
	var scattered := ["headstone_fallen_01", "headstone_fallen_02", "burial_sword_01", "burial_sword_02", "bone_pile_01", "bone_pile_02"]
	for i in 14:
		prop(scattered[i % scattered.size()], c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(260.0, 640.0), 0.0, rng.randf() < 0.5)
	for i in 10:
		prop("rock_01", c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(250.0, 650.0), 0.0, rng.randf() < 0.5)


## ⑤ 冰湖：开阔的冰面和放射状的冰裂纹，湖心冻着一条小渔船，冰下隐约有鱼和水草；湖边一圈石头和雪堆，湖面上没有障碍
func _lake(c: Vector2) -> void:
	fill_disc(c, 520.0, "ice", 0.18)
	prop("fishing_boat_frozen", c + Vector2(110, -50), 0.0, true)
	for i in 10:
		decal("ice_crack_0%d" % rng.randi_range(1, 3), c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(60.0, 420.0), rng.randf() < 0.5)
	var under := ["underice_fish_01", "underice_fish_02", "underice_weeds_01", "underice_weeds_02"]
	for i in 12:
		prop(under[i % under.size()], c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(80.0, 400.0), 0.0, rng.randf() < 0.5)
	for i in 16:
		var at := c + Vector2.from_angle(TAU * i / 16.0 + rng.randf_range(-0.15, 0.15)) * rng.randf_range(580.0, 650.0)
		if i % 3 == 0:
			prop("snowdrift_0%d" % rng.randi_range(1, 3), at)
		else:
			prop("rock_0%d" % rng.randi_range(1, 2), at, 12.0 if i % 3 == 2 else 0.0, rng.randf() < 0.5)


## 地标之间：一丛丛枯松、零散的岩石和雪堆、灌木和倒下的树干，零散的战场痕迹。留出大片空地给玩家走位
func _scatter() -> void:
	var inner := Game.bounds.grow(-48.0)
	for i in 50:
		var center := _free_spot(inner, 40.0)
		if not center.is_finite():
			continue
		decal("snow_shadow_0%d" % rng.randi_range(1, 2), center, rng.randf() < 0.5)
		for j in rng.randi_range(3, 7):
			var at := center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 120.0)
			if inner.has_point(at) and _on_land(at) and is_free(at, 26.0):
				prop("dead_pine_0%d" % rng.randi_range(1, 3), at, 10.0, rng.randf() < 0.5)
		if rng.randf() < 0.3:
			var at := center + Vector2.from_angle(rng.randf() * TAU) * 140.0
			if inner.has_point(at) and _on_land(at) and is_free(at, 20.0):
				prop("raven_branch", at, 8.0, rng.randf() < 0.5)
	for i in 70:
		var size := rng.randi_range(1, 4)
		var at := _free_spot(inner, 30.0)
		if at.is_finite():
			prop("rock_0%d" % size, at, [0.0, 0.0, 12.0, 22.0, 22.0][size], rng.randf() < 0.5)
	for i in 12:
		var at := _free_spot(inner, 50.0)
		if at.is_finite():
			wide_prop("fallen_log", at, 56.0, 12.0, rng.randf() < 0.5)
	for i in 50:
		var at := _free_spot(inner, 30.0)
		if at.is_finite():
			prop("snowdrift_0%d" % rng.randi_range(1, 3), at, 0.0, rng.randf() < 0.5)
	for i in 40:
		var at := _free_spot(inner, 24.0)
		if at.is_finite():
			prop("bush_0%d" % rng.randi_range(1, 2), at, 0.0, rng.randf() < 0.5)
	# 零散的战场：倒下的马、插在雪里的刀剑、破盾和血迹
	for i in 10:
		var at := _free_spot(inner, 50.0)
		if not at.is_finite():
			continue
		decal("blood_0%d" % rng.randi_range(1, 3), at + Vector2(rng.randf_range(-20, 20), 10), rng.randf() < 0.5)
		match i % 3:
			0:
				prop("frozen_horse", at, 18.0, rng.randf() < 0.5)
			1:
				prop("weapons_in_snow", at, 0.0, rng.randf() < 0.5)
			_:
				prop("broken_shield_0%d" % rng.randi_range(1, 2), at, 0.0, rng.randf() < 0.5)
	for i in 25:
		var at := _free_spot(inner, 20.0)
		if at.is_finite():
			_trace("wolf_tracks", at, Vector2.from_angle(rng.randf() * TAU))


## 随机找一处空地，找不到返回 Vector2.INF
func _free_spot(area: Rect2, r: float) -> Vector2:
	for attempt in 30:
		var at := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if _on_land(at) and is_free(at, r):
			return at
	return Vector2.INF


## 离开出生点和各地标，也不在冰面上
func _on_land(at: Vector2) -> bool:
	if at.length() < CLEAR_SPAWN or _terrain.ice.has(cell_at(at)):
		return false
	for landmark: Dictionary in map.landmarks:
		if at.distance_to(landmark.pos) < landmark.radius * 0.85:
			return false
	return true
