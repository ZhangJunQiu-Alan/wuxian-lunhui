class_name MapLayer
extends Node2D
## 固定地图的地面和物件。具体关卡继承它，在 _layout() 里铺地面、摆物件
## 地面是 64×64 的地块（TileMapLayer），物件是 Sprite2D，图片的底边中点就是摆放位置
## 物件统一画在角色下面，所以不会挡住玩家和怪物；大物件有圆形碰撞，玩家和怪物都走不过去
## 每次生成用同一个随机种子，所以每一局的地图都一样
## overlay 里的地块（例如踩实的雪）半透明地叠在底下的地块上，边缘不会显得一格一格的

const TILE := 64
const OBSTACLE_CELL := 128.0  # 碰撞查询的网格大小，要大于 最大碰撞半径 + 最大敌人半径
const FOOT := 20.0            # 角色的位置在身体中间，脚比位置低这么多；用脚去碰撞
const EDGE_TINT := Color(0.5, 0.55, 0.65)  # 屏障带压暗，看得出走不过去
const BORDER_LINE := Color(0.75, 0.85, 1.0, 0.25)

## 格子坐标 -> 该格里的碰撞圆 Vector3(x, y, 半径)
static var obstacles := {}

var map: Dictionary
var ground_dir := ""
var props_dir := ""
var overlay := {}       # 地块名 -> 不透明度
var rng := RandomNumberGenerator.new()
var _cells := {}        # 格子 -> 地块名，_layout() 写好后一次性铺到 TileMapLayer
var _overlay_cells := {}  # 格子 -> 叠加的地块名
var _reserved := {}     # 小路经过的格子，散布装饰物时避开
var _sources := {}      # 地块名 -> TileSet 里的 source id
var _ground: TileMapLayer
var _edge: TileMapLayer
var _props: Node2D


func _ready() -> void:
	z_index = -10  # 画在所有东西下面，包括支线的篝火、标记（它们是 -1）
	rng.seed = 20261016
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	for file in ResourceLoader.list_directory(ground_dir):
		if file.ends_with(".png"):
			var source := TileSetAtlasSource.new()
			source.texture = load(ground_dir + file)
			source.texture_region_size = Vector2i(TILE, TILE)
			source.create_tile(Vector2i.ZERO)
			_sources[file.get_basename()] = tiles.add_source(source)
	_ground = TileMapLayer.new()
	_ground.tile_set = tiles
	_edge = TileMapLayer.new()
	_edge.tile_set = tiles
	_edge.modulate = EDGE_TINT
	_props = Node2D.new()
	add_child(_ground)
	var overlays := {}
	for tile: String in overlay:
		overlays[tile] = TileMapLayer.new()
		overlays[tile].tile_set = tiles
		overlays[tile].modulate.a = overlay[tile]
		add_child(overlays[tile])
	add_child(_edge)
	var line := Line2D.new()
	line.points = PackedVector2Array([Game.bounds.position, Vector2(Game.bounds.end.x, Game.bounds.position.y),
			Game.bounds.end, Vector2(Game.bounds.position.x, Game.bounds.end.y)])
	line.closed = true
	line.width = 3.0
	line.default_color = BORDER_LINE
	add_child(line)
	add_child(_props)
	_layout()
	for cell: Vector2i in _cells:
		var inside := Game.bounds.has_point(Vector2(cell * TILE) + Vector2.ONE * TILE * 0.5)
		(_ground if inside else _edge).set_cell(cell, _sources[_cells[cell]], Vector2i.ZERO)
	for cell: Vector2i in _overlay_cells:
		if Game.bounds.has_point(Vector2(cell * TILE) + Vector2.ONE * TILE * 0.5):
			overlays[_overlay_cells[cell]].set_cell(cell, _sources[_overlay_cells[cell]], Vector2i.ZERO)


## 子类实现：铺地面、摆物件
func _layout() -> void:
	pass


## 镜头能看到的所有格子
func all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var from := Vector2i((Game.view_bounds.position / TILE).floor())
	var to := Vector2i((Game.view_bounds.end / TILE).ceil())
	for x in range(from.x, to.x):
		for y in range(from.y, to.y):
			cells.append(Vector2i(x, y))
	return cells


func cell_at(pos: Vector2) -> Vector2i:
	return Vector2i((pos / TILE).floor())


func set_ground(cell: Vector2i, tile: String) -> void:
	if overlay.has(tile):
		_overlay_cells[cell] = tile
	else:
		_cells[cell] = tile
		_overlay_cells.erase(cell)


## 铺一片边缘参差的圆形区域。ragged 是边缘起伏的比例
func fill_disc(center: Vector2, r: float, tile: String, ragged: float = 0.2) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.8 / r
	var from := cell_at(center - Vector2.ONE * r * (1.0 + ragged))
	var to := cell_at(center + Vector2.ONE * r * (1.0 + ragged))
	for x in range(from.x, to.x + 1):
		for y in range(from.y, to.y + 1):
			var p := Vector2(x, y) * TILE + Vector2.ONE * TILE * 0.5
			if p.distance_to(center) < r * (1.0 + ragged * noise.get_noise_2dv(p)):
				set_ground(Vector2i(x, y), tile)


## 一条弯曲的小路：从 from 到 to 的二次贝塞尔曲线，bend 是中点往旁边弯出去多远
## core 是路中间的地块，shoulder 是两旁被踩过的雪
func paint_path(from: Vector2, to: Vector2, bend: float, width: float, core: String, shoulder: String) -> void:
	var mid := (from + to) / 2.0 + (to - from).orthogonal().normalized() * bend
	var steps := int(from.distance_to(to) / (TILE * 0.5))
	for i in steps + 1:
		var t := float(i) / steps
		var p := from.lerp(mid, t).lerp(mid.lerp(to, t), t)
		var w := width * (0.8 + 0.4 * rng.randf())
		var c := cell_at(p)
		var reach := int(ceilf(w * 1.6 / TILE))
		for x in range(c.x - reach, c.x + reach + 1):
			for y in range(c.y - reach, c.y + reach + 1):
				var cell := Vector2i(x, y)
				var d := (Vector2(cell) * TILE + Vector2.ONE * TILE * 0.5).distance_to(p)
				if d < w * 0.5:
					set_ground(cell, core)
				elif d < w * 1.6 and _cells.get(cell, "") != core and _overlay_cells.get(cell, "") != core:
					set_ground(cell, shoulder)
				if d < w * 1.6:
					_reserved[cell] = true


## 摆一个物件，pos 是图片底边中点。block 是碰撞半径（0 = 只是装饰，可以穿过）
func prop(file: String, pos: Vector2, block: float = 0.0, flip := false) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(props_dir + file + ".png")
	sprite.offset = Vector2(0, -sprite.texture.get_height() * 0.5)
	sprite.position = pos.round()
	sprite.flip_h = flip
	_props.add_child(sprite)
	if block > 0.0:
		add_obstacle(pos + Vector2(0, -block * 0.5), block)
	return sprite


func add_obstacle(center: Vector2, r: float) -> void:
	var cell := Vector2i((center / OBSTACLE_CELL).floor())
	if not obstacles.has(cell):
		obstacles[cell] = []
	obstacles[cell].append(Vector3(center.x, center.y, r))


## 这个位置放半径 r 的东西会不会碰到已有的碰撞物或小路
func is_free(pos: Vector2, r: float) -> bool:
	if _reserved.has(cell_at(pos)):
		return false
	return push_out(pos - Vector2(0, FOOT), r) == pos - Vector2(0, FOOT)


## 把一个半径 margin 的角色推出所有碰撞物，返回推完的位置
static func push_out(pos: Vector2, margin: float) -> Vector2:
	if obstacles.is_empty():
		return pos
	var foot := pos + Vector2(0, FOOT)
	var cell := Vector2i((foot / OBSTACLE_CELL).floor())
	for x in range(cell.x - 1, cell.x + 2):
		for y in range(cell.y - 1, cell.y + 2):
			for o: Vector3 in obstacles.get(Vector2i(x, y), []):
				var center := Vector2(o.x, o.y)
				var away := foot - center
				var min_dist := o.z + margin
				if away.length_squared() < min_dist * min_dist:
					foot = center + (away.normalized() if away != Vector2.ZERO else Vector2.DOWN) * min_dist
	return foot - Vector2(0, FOOT)
