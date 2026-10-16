class_name MidgardMap
extends MapLayer
## 第 1 关「芬布尔之冬」的地图，布局和各地标的细节见 docs/地图设计_第1关.md
## 地标核心（半径的 45% 以内）不放挡路的物件，支线标记会出现在那里

const SNOW := ["snow_01", "snow_01", "snow_01", "snow_02", "snow_02", "snow_03", "snow_04"]
const CLEAR_SPAWN := 300.0  # 出生点周围留空


func _init() -> void:
	ground_dir = "res://assets/sprites/ground/midgard/"
	props_dir = "res://assets/sprites/props/midgard/"
	overlay = {"snow_trampled": 0.4}


func _layout() -> void:
	var lm := {}
	for landmark: Dictionary in map.landmarks:
		lm[landmark.id] = landmark
	for cell in all_cells():
		set_ground(cell, SNOW[rng.randi() % SNOW.size()])
	_border()
	# 十字路口通向每个地标，地标之间再连成一圈：任意两处之间至少有两条路
	for id in ["village", "harbor", "stones", "mounds", "lake"]:
		paint_path(Vector2.ZERO, lm[id].pos, rng.randf_range(-250.0, 250.0), 90.0, "snow_trampled", "snow_trampled")
	for pair in [["village", "harbor"], ["harbor", "lake"], ["lake", "mounds"], ["mounds", "stones"], ["stones", "village"]]:
		paint_path(lm[pair[0]].pos, lm[pair[1]].pos, rng.randf_range(-300.0, 300.0), 70.0, "snow_trampled", "snow_trampled")
	_crossroads(lm.crossroads.pos)
	_village(lm.village.pos)
	_harbor(lm.harbor.pos)
	_stones(lm.stones.pos)
	_mounds(lm.mounds.pos)
	_lake(lm.lake.pos)
	_scatter()


## 屏障带：北边峡湾、东边冰海是冰面，南边山脚是冻土和乱石，西边是密密的枯松
func _border() -> void:
	var b := Game.bounds
	var v := Game.view_bounds
	for cell in all_cells():
		var p := Vector2(cell * TILE) + Vector2.ONE * TILE * 0.5
		if p.y < b.position.y or p.x > b.end.x:
			set_ground(cell, "ice")
		elif p.y > b.end.y:
			set_ground(cell, "frozen_dirt")
	var y := v.position.y
	while y < v.end.y:
		for x in range(int(v.position.x) + 16, int(b.position.x) + 24, 36):
			var pine := prop("dead_pine_0%d" % rng.randi_range(1, 2), Vector2(x + rng.randf_range(-10, 10), y), 0.0, rng.randf() < 0.5)
			pine.modulate = EDGE_TINT.darkened(0.2 * rng.randf())
		y += rng.randf_range(26.0, 38.0)
	var x := b.position.x
	while x < v.end.x:
		for row in 3:
			var rock := prop("rock_0%d" % rng.randi_range(2, 3), Vector2(x + rng.randf_range(-12, 12), b.end.y + 40 + row * 55 + rng.randf_range(-10, 10)), 0.0, rng.randf() < 0.5)
			rock.modulate = EDGE_TINT
		x += rng.randf_range(40.0, 60.0)


## ⓪ 十字路口：刻着符文的路标石，散落的石头
func _crossroads(c: Vector2) -> void:
	fill_disc(c, 200.0, "snow_trampled")
	prop("runestone_01", c + Vector2(70, -40), 10.0)
	prop("rock_01", c + Vector2(95, -20))
	prop("rock_01", c + Vector2(-110, 70), 0.0, true)
	prop("snowdrift_01", c + Vector2(-150, -110))
	prop("snowdrift_02", c + Vector2(160, 120))


## ① 被雪掩埋的村庄：一圈塌陷的长屋，南北两侧的栅栏被撞断好几处
func _village(c: Vector2) -> void:
	fill_disc(c, 430.0, "snow_trampled", 0.3)
	for i in 7:
		var angle := TAU * i / 7.0 + rng.randf_range(-0.25, 0.25)
		prop("collapsed_cabin", c + Vector2.from_angle(angle) * rng.randf_range(330.0, 470.0), 34.0, rng.randf() < 0.5)
	for side in [-1, 1]:
		var x := -520.0
		while x < 520.0:
			if rng.randf() > 0.25 and absf(x) > 70.0:  # 中间是村口，其他地方随机断开
				prop("fence", c + Vector2(x, side * 580.0 + rng.randf_range(-8, 8)), 0.0, rng.randf() < 0.5)
			x += 62.0
	for i in 8:
		prop("snowdrift_0%d" % rng.randi_range(1, 2), c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(200.0, 560.0))
	for i in 6:
		prop("rock_01", c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(160.0, 520.0), 0.0, rng.randf() < 0.5)


## ② 峡湾码头：东北边是冰封的海，两条长船残骸冻在冰里，岸边一排系船木桩
func _harbor(c: Vector2) -> void:
	fill_disc(c + Vector2(260, -380), 430.0, "ice", 0.25)
	fill_disc(c + Vector2(-60, 60), 260.0, "snow_trampled", 0.3)
	for ship: Array in [[Vector2(220, -300), false], [Vector2(-140, -360), true]]:
		var at: Vector2 = c + ship[0]
		prop("longship_wreck", at, 0.0, ship[1])
		add_obstacle(at + Vector2(-32, -16), 24.0)
		add_obstacle(at + Vector2(32, -16), 24.0)
	var x := -260.0
	while x < 300.0:
		if rng.randf() > 0.3:
			prop("fence", c + Vector2(x, -150 + rng.randf_range(-6, 6)), 0.0, rng.randf() < 0.5)
		x += 70.0
	for i in 8:
		prop("rock_0%d" % rng.randi_range(1, 2), c + Vector2(rng.randf_range(-380, 380), rng.randf_range(-200, -110)), 0.0, rng.randf() < 0.5)
	for i in 4:
		prop("snowdrift_0%d" % rng.randi_range(1, 2), c + Vector2(rng.randf_range(-400, 300), rng.randf_range(0, 300)))


## ③ 奥丁的符文石阵：一圈立石围着石砌祭坛
func _stones(c: Vector2) -> void:
	fill_disc(c, 340.0, "snow_trampled", 0.15)
	for i in 10:
		var at := c + Vector2.from_angle(TAU * i / 10.0 + 0.15) * 230.0
		prop("runestone_0%d" % (i % 2 + 1), at, 10.0, i % 3 == 0)
	prop("rock_03", c + Vector2(0, 16), 22.0)


## ④ 古老的墓丘：一圈隆起的墓丘，中间是立石排成船形的石阵墓，地上有拖痕
func _mounds(c: Vector2) -> void:
	for i in 6:
		var at := c + Vector2.from_angle(TAU * i / 6.0 + rng.randf_range(-0.3, 0.3)) * rng.randf_range(380.0, 560.0)
		prop("burial_mound", at, 0.0, rng.randf() < 0.5)
		add_obstacle(at + Vector2(-24, -18), 26.0)
		add_obstacle(at + Vector2(24, -18), 26.0)
		fill_disc(at.lerp(c, 0.35), 70.0, "snow_trampled", 0.5)  # 从墓里爬出来的拖痕
	for i in 12:  # 船形石阵：两头尖的椭圆
		var angle := TAU * i / 12.0
		var at := c + Vector2(cos(angle) * 190.0, sin(angle) * 60.0 * (1.0 - 0.4 * absf(cos(angle)))) + Vector2(0, 40)
		prop("runestone_02", at, 8.0, i % 2 == 0)
	for i in 10:
		prop("rock_01", c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(250.0, 650.0), 0.0, rng.randf() < 0.5)


## ⑤ 冰湖：开阔的冰面，湖边一圈石头和雪堆，湖面上没有障碍
func _lake(c: Vector2) -> void:
	fill_disc(c, 520.0, "ice", 0.18)
	for i in 16:
		var at := c + Vector2.from_angle(TAU * i / 16.0 + rng.randf_range(-0.15, 0.15)) * rng.randf_range(580.0, 650.0)
		if i % 3 == 0:
			prop("snowdrift_0%d" % rng.randi_range(1, 2), at)
		else:
			prop("rock_0%d" % rng.randi_range(1, 2), at, 12.0 if i % 3 == 2 else 0.0, rng.randf() < 0.5)


## 地标之间：一丛丛枯松、零散的岩石和雪堆。留出大片空地给玩家走位
func _scatter() -> void:
	var inner := Game.bounds.grow(-48.0)
	for i in 50:
		var center := _free_spot(inner, 40.0)
		for j in rng.randi_range(3, 7):
			var at := center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 120.0)
			if center.is_finite() and inner.has_point(at) and _away_from_landmarks(at) and is_free(at, 26.0):
				prop("dead_pine_0%d" % rng.randi_range(1, 2), at, 10.0, rng.randf() < 0.5)
	for i in 70:
		var size := rng.randi_range(1, 3)
		var at := _free_spot(inner, 30.0)
		if at.is_finite():
			prop("rock_0%d" % size, at, [0.0, 0.0, 12.0, 22.0][size], rng.randf() < 0.5)
	for i in 50:
		var at := _free_spot(inner, 30.0)
		if at.is_finite():
			prop("snowdrift_0%d" % rng.randi_range(1, 2), at, 0.0, rng.randf() < 0.5)


## 随机找一处空地，找不到返回 Vector2.INF
func _free_spot(area: Rect2, r: float) -> Vector2:
	for attempt in 30:
		var at := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if _away_from_landmarks(at) and is_free(at, r):
			return at
	return Vector2.INF


func _away_from_landmarks(at: Vector2) -> bool:
	if at.length() < CLEAR_SPAWN:
		return false
	for landmark: Dictionary in map.landmarks:
		if at.distance_to(landmark.pos) < landmark.radius * 0.85:
			return false
	return true
