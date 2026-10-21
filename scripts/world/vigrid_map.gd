class_name VigridMap
extends MapLayer
## 第 3 关「最后之战」的地图：维格利德平原。布局来自 K0（assets/source/taskK0_vigrid_plan_2026-10-20/layout.json）
## 5120×5120，四周 256 的屏障带；出生点 384 内不摆任何物件，中央 1280 内不放有碰撞的物件
## 地面复用 6 张维格利德地块；焦草的过渡块借第 1 关 path_edge 的轮廓，开局时显式从 midgard 目录加载
## 屏障带不画专门的边界图：铺焦土、散一些残骸，叠一层烟雾，可走范围的边线上烧一圈苏尔特的火墙条带（上半朝外）
## 北侧远景是神与巨人交战的剪影，只是背景：不能走进去，不能打，不会被锁定

const BASE := ["scorched_01", "scorched_01", "scorched_03", "scorched_03", "scorched_04"]
const ROUTE := "ash_road"
const ROUTE_WIDTH := 80.0       # paint_path 的宽度参数：路面半宽约 128，即 256 宽的通道
const CLEAR_SPAWN := 384.0
const NO_BLOCK_RADIUS := 1280.0
const EDGE_PARTS := ["n", "e", "s", "w", "outer_ne", "outer_nw", "outer_se", "outer_sw", "inner_ne", "inner_nw", "inner_se", "inner_sw"]
const MASK_DIR := "res://assets/sprites/ground/midgard/"
const FIRE_PATCH := "res://assets/sprites/effects/gods/loki_fire_patch.png"
const DISTANT := "res://assets/sprites/effects/environment/vigrid/distant_battle.png"
const DISTANT_FRAMES := 4
const BAND_ID := "surtr_firewall_band"
const BAND_TILE := 64.0
const HAZE := Color(0.06, 0.03, 0.03, 0.55)
## K0 的样例摆位：[文件, 位置, 碰撞半径]
const PROP_SAMPLES := [
	["bifrost_fragment", Vector2(-1756, -1268), 20.0], ["broken_weapons", Vector2(-1316, -1268), 0.0],
	["giant_remains", Vector2(1756, -1140), 20.0], ["fallen_shield", Vector2(1316, -1140), 0.0],
	["giant_remains", Vector2(-1756, 1164), 20.0], ["broken_weapons", Vector2(-1316, 1164), 0.0],
	["burning_wreckage", Vector2(1316, 1420), 0.0], ["fallen_shield", Vector2(1756, 1420), 0.0],
	["broken_weapons", Vector2(-220, 1932), 0.0], ["fallen_shield", Vector2(220, 1932), 0.0],
]
## 地标 -> 再散布的物件：[文件, 碰撞半径]
const SCATTER := {
	"bifrost": [["bifrost_fragment", 20.0], ["broken_weapons", 0.0], ["fallen_shield", 0.0]],
	"giant_graveyard": [["giant_remains", 20.0], ["fallen_shield", 0.0], ["broken_weapons", 0.0]],
	"frost_remnants": [["giant_remains", 20.0], ["broken_weapons", 0.0]],
	"muspel_edge": [["burning_wreckage", 0.0], ["broken_weapons", 0.0], ["giant_remains", 20.0]],
	"dead_march": [["broken_weapons", 0.0], ["fallen_shield", 0.0]],
}

static var fire_material: ShaderMaterial  # 洛基的绿火只在这一份材质里改成橙红（色相 0.04，饱和度 / 明度 / 透明度不变）

var _distant: Texture2D
var _time := 0.0
var _border_fx: Node2D
var _horizon: Node2D


func _init() -> void:
	ground_dir = "res://assets/sprites/ground/vigrid/"
	props_dir = "res://assets/sprites/props/vigrid/"
	decals_dir = "res://assets/sprites/decals/vigrid/"
	for part: String in EDGE_PARTS:
		extra_tiles["path_edge_" + part] = MASK_DIR + "path_edge_%s.png" % part
	edges["ash_road"] = "ash_road_edge"
	edge_masks = {"burnt_grass_02": "path_edge"}


## 色相固定为 0.04 的材质，给复用的火焰贴图（洛基的火是绿色的）
static func fire_hue() -> ShaderMaterial:
	if fire_material == null:
		var shader := Shader.new()
		shader.code = """shader_type canvas_item;
uniform float hue = 0.04;
vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1.0e-10)), d / (q.x + 1.0e-10), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
void fragment() {
	vec3 hsv = rgb2hsv(COLOR.rgb);
	COLOR = vec4(hsv2rgb(vec3(hue, hsv.y, hsv.z)), COLOR.a);
}
"""
		fire_material = ShaderMaterial.new()
		fire_material.shader = shader
	return fire_material


func _layout() -> void:
	var lm := {}
	for landmark: Dictionary in map.landmarks:
		lm[landmark.id] = landmark
	for cell in all_cells():
		set_ground(cell, BASE[rng.randi() % BASE.size()])
	for route: Array in map.routes:
		paint_path(route[0], route[1], 0.0, ROUTE_WIDTH, ROUTE)
	fill_disc(lm.frost_remnants.pos, 300.0, "burnt_grass_02", 0.25)
	for i in 5:  # 平原上零星几块没烧尽的草
		var at := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(600.0, 1900.0)
		fill_disc(at, rng.randf_range(90.0, 150.0), "burnt_grass_02", 0.3)
	fill_disc(lm.muspel_edge.pos, 260.0, "cracked_lava_02", 0.3)  # 裂地只是装饰，站上去不掉血
	for sample: Array in PROP_SAMPLES:
		prop(sample[0], sample[1], sample[2], rng.randf() < 0.5)
	for id: String in SCATTER:
		_scatter(lm[id], SCATTER[id], 6)
	for id in ["frost_remnants", "giant_graveyard"]:  # 巨人走过的脚印
		var center: Vector2 = lm[id].pos
		var heading := rng.randf() * TAU
		for i in 5:
			decal("giant_tread", center + Vector2.from_angle(heading) * (i - 2) * 90.0 + Vector2.from_angle(heading + PI / 2) * (40.0 if i % 2 else -40.0)).rotation = heading
	for i in 7:  # 穆斯贝尔前线的残火：只是装饰
		_decor_fire(lm.muspel_edge.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(80.0, 420.0))
	_decor_fire(lm.muspel_edge.pos + Vector2(-220, 140))
	_border_dressing()
	_border_fx = Node2D.new()
	_border_fx.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_border_fx.draw.connect(_draw_border)
	add_child.call_deferred(_border_fx)
	_horizon = Node2D.new()
	_horizon.draw.connect(_draw_horizon)
	if ResourceLoader.exists(DISTANT):
		_distant = load(DISTANT)
	add_child.call_deferred(_horizon)


func _process(delta: float) -> void:
	var before := int(_time * 8.0)
	_time += delta
	if int(_time * 8.0) != before:  # 火墙条带和远景都是 8 帧/秒
		if _border_fx:
			_border_fx.queue_redraw()
		if _horizon:
			_horizon.queue_redraw()


## 在地标范围里散布 count 个物件，避开小路、出生点；有碰撞的物件不进中央 1280
func _scatter(landmark: Dictionary, files: Array, count: int) -> void:
	var placed := 0
	for attempt in count * 8:
		if placed >= count:
			return
		var pick: Array = files[rng.randi() % files.size()]
		var at: Vector2 = landmark.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(60.0, landmark.radius)
		var block: float = pick[1]
		if at.length() < CLEAR_SPAWN or (block > 0.0 and at.length() < NO_BLOCK_RADIUS) or not Game.bounds.grow(-80.0).has_point(at):
			continue
		if not is_free(at, maxf(block, 24.0)):
			continue
		prop(pick[0], at, block, rng.randf() < 0.5)
		placed += 1


func _decor_fire(at: Vector2) -> void:
	if not ResourceLoader.exists(FIRE_PATCH):
		return
	var sprite := Sprite2D.new()
	sprite.texture = load(FIRE_PATCH)
	sprite.material = fire_hue()
	sprite.position = at.round()
	sprite.modulate.a = 0.85
	_decals.add_child(sprite)


## 屏障带里随手扔几件残骸（不可走，不需要碰撞）
func _border_dressing() -> void:
	var v := Game.view_bounds
	var b := Game.bounds
	var files := ["giant_remains", "broken_weapons", "burning_wreckage", "fallen_shield"]
	for i in 40:
		var at := Vector2(rng.randf_range(v.position.x + 30.0, v.end.x - 30.0), rng.randf_range(v.position.y + 60.0, v.end.y - 10.0))
		if b.grow(40.0).has_point(at) or map.horizon.grow(48.0).has_point(at):
			continue
		prop(files[rng.randi() % files.size()], at, 0.0, rng.randf() < 0.5).modulate = Color(0.7, 0.62, 0.6)


## 屏障带：一层烟雾，可走范围的边线上一圈火墙条带。条带的锚点 (32,32) 压在边线上，上半（火）朝外、下半透明朝里
func _draw_border() -> void:
	var v := Game.view_bounds
	var b := Game.bounds
	for rect: Rect2 in [Rect2(v.position, Vector2(v.size.x, b.position.y - v.position.y)),
			Rect2(Vector2(v.position.x, b.end.y), Vector2(v.size.x, v.end.y - b.end.y)),
			Rect2(Vector2(v.position.x, b.position.y), Vector2(b.position.x - v.position.x, b.size.y)),
			Rect2(Vector2(b.end.x, b.position.y), Vector2(v.end.x - b.end.x, b.size.y))]:
		_border_fx.draw_rect(rect, HAZE)
	var strip := BossFx.texture(BAND_ID)
	if strip == null:
		_border_fx.draw_rect(b, Color(1.0, 0.45, 0.15, 0.6), false, 3.0)
		return
	var corners := [b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]  # 顺时针
	var frame := posmod(int(_time * 8.0), 4)
	var half := strip.get_height() * 0.5
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 4:
		var from: Vector2 = corners[i]
		var to: Vector2 = corners[(i + 1) % 4]
		var along := from.direction_to(to)
		var out := along.orthogonal()  # 顺时针走时，左手边就是外面
		var length := from.distance_to(to)
		var at := 0.0
		while at < length - 0.01:
			var step := minf(BAND_TILE, length - at)
			var a := from + along * at
			var c := a + along * step
			var u0 := frame / 4.0
			var u1 := (frame + step / BAND_TILE) / 4.0
			points.append_array([a + out * half, c + out * half, c - out * half, a - out * half])
			uvs.append_array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)])
			at += step
		# 转角：绕顶点画四分之一扇形（拆成几个三角形），只有朝外的火焰半边，接上两条边
		var next_out: Vector2 = corners[(i + 1) % 4].direction_to(corners[(i + 2) % 4]).orthogonal()
		for k in 6:
			var d0 := out.slerp(next_out, k / 6.0)
			var d1 := out.slerp(next_out, (k + 1) / 6.0)
			points.append_array([to, to + d0 * half, to + d1 * half, to])
			var center_uv := Vector2((frame + 0.5) / 4.0, 0.5)
			uvs.append_array([center_uv, Vector2((frame + 0.15 + 0.7 * k / 6.0) / 4.0, 0.0), Vector2((frame + 0.15 + 0.7 * (k + 1) / 6.0) / 4.0, 0.0), center_uv])
	BossFx.draw_quads(_border_fx, points, uvs, strip)  # 一圈火带一次提交
	_border_fx.draw_rect(b, Color(1.0, 0.6, 0.3, 0.35), false, 2.0)  # 程序边界线：可走范围的真实边缘


## 北侧远景：三段 512×128 的交战剪影并排，4 帧 8 帧/秒循环，按 1 倍画（里面的人物已经是半尺寸）
func _draw_horizon() -> void:
	if _distant == null:
		return
	var rect: Rect2 = map.horizon
	var size := Vector2(_distant.get_width() / DISTANT_FRAMES, _distant.get_height())
	var frame := posmod(int(_time * 8.0), DISTANT_FRAMES)
	var x := rect.position.x
	var i := 0
	while x < rect.end.x - 0.5:
		var offset := posmod(frame + i, DISTANT_FRAMES)  # 三段错开一帧，不会整齐划一
		_horizon.draw_texture_rect_region(_distant, Rect2(Vector2(x, rect.position.y), size), Rect2(Vector2(size.x * offset, 0), size))
		x += size.x
		i += 1
