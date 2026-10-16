class_name MapLayer
extends Node2D
## 固定地图的地面和物件。具体关卡继承它，在 _layout() 里铺地面、摆物件、画边界
## 地面是 64×64 的地块（TileMapLayer），物件和贴花是 Sprite2D，物件图片的底边中点就是摆放位置
## 物件统一画在角色下面，所以不会挡住玩家和怪物；大物件有圆形碰撞，玩家和怪物都走不过去
## 每次生成用同一个随机种子，所以每一局的地图都一样
##
## 有过渡块的地面（edges 里的，例如冰面、踩实的雪）铺在单独的图层上，用「错开半格」的方式拼边缘：
## 图层整体往左上挪半格，每个显示格的四个角各对应一个地图格，按四个角里有几个是这种地面选过渡块
## 过渡块命名：<前缀>_n/e/s/w 是露出的那条边，_outer_ne 是凸出的外角，_inner_ne 是凹进去的内角
## 没有自己过渡块的地面写在 edge_masks 里，借另一套过渡块的轮廓（只取透明度），开局时生成
## overlay 里的地块半透明地叠在底下，alpha 是不透明度
## 素材还没到的地块、物件、边界，写在 placeholders 里（名字 -> [颜色, 尺寸]），先用纯色块代替，素材放进来后自动换上

const TILE := 64
const OBSTACLE_CELL := 128.0  # 碰撞查询的网格大小，要大于 最大碰撞半径 + 最大敌人半径
const FOOT := 20.0            # 角色的位置在身体中间，脚比位置低这么多；用脚去碰撞
## 显示格四个角（左上 1、右上 2、左下 4、右下 8）里有哪些是这种地面 -> 用哪些过渡块
## 对角两格（9、6）没有专门的块，用两个外角叠起来
const EDGE_TILES := {
	12: ["n"], 5: ["e"], 3: ["s"], 10: ["w"],
	4: ["outer_ne"], 8: ["outer_nw"], 1: ["outer_se"], 2: ["outer_sw"],
	13: ["inner_ne"], 14: ["inner_nw"], 7: ["inner_se"], 11: ["inner_sw"],
	9: ["outer_se", "outer_nw"], 6: ["outer_sw", "outer_ne"],
}

## 格子坐标 -> 该格里的碰撞圆 Vector3(x, y, 半径)
static var obstacles := {}
static var current: MapLayer

var map: Dictionary
var ground_dir := ""
var props_dir := ""
var decals_dir := ""
var borders_dir := ""
var edges := {}         # 有过渡块的地块名 -> 过渡块前缀，先写的画在下面
var edge_masks := {}    # 地块名 -> 借用哪套过渡块的轮廓，例如 "snow_thin" -> "path_edge"
var variants := {}      # 地块名 -> 铺满时随机换用的变化（例如另一种冰裂纹），连同原地块一起随机
var overlay := {}       # 地块名 -> 不透明度
var placeholders := {}  # 名字 -> [颜色, 尺寸]
var rng := RandomNumberGenerator.new()
var _cells := {}        # 格子 -> 地块名，_layout() 写好后一次性铺到 TileMapLayer
var _overlay_cells := {}  # 格子 -> 叠加的地块名
var _terrain := {}      # 有过渡块的地块名 -> {格子: true}
var _reserved := {}     # 小路经过的格子，散布装饰物时避开
var _sources := {}      # 地块名 -> TileSet 里的 source id
var _tiles: TileSet
var _ground: TileMapLayer
var _decals: Node2D
var _borders: Node2D
var _props: Node2D


func _ready() -> void:
	current = self
	z_index = -10  # 画在所有东西下面，包括支线的篝火、标记（它们是 -1）
	rng.seed = 20261016
	_tiles = TileSet.new()
	_tiles.tile_size = Vector2i(TILE, TILE)
	for file in ResourceLoader.list_directory(ground_dir):
		if file.ends_with(".png"):
			_add_source(file.get_basename(), load(ground_dir + file))
	for tile: String in placeholders:
		if not _sources.has(tile) and placeholders[tile][1] == Vector2i(TILE, TILE):
			_add_source(tile, _texture(ground_dir, tile))
	for tile: String in edge_masks:
		_make_edges(tile, edge_masks[tile])
	for tile: String in edges:
		_terrain[tile] = {}
	_ground = _tile_layer(1.0)
	_decals = Node2D.new()
	_borders = Node2D.new()
	_props = Node2D.new()
	_layout()
	for cell: Vector2i in _cells:
		_ground.set_cell(cell, _sources[_cells[cell]], Vector2i.ZERO)
	for tile: String in overlay:
		if not edges.has(tile):
			var layer := _tile_layer(overlay[tile])
			for cell: Vector2i in _overlay_cells:
				if _overlay_cells[cell] == tile:
					layer.set_cell(cell, _sources[tile], Vector2i.ZERO)
	for tile: String in edges:
		_paint_edges(tile)
	add_child(_decals)
	add_child(_borders)
	add_child(_props)


func _add_source(tile: String, texture: Texture2D) -> void:
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	source.create_tile(Vector2i.ZERO)
	_sources[tile] = _tiles.add_source(source)


## 用 mask 那套过渡块的轮廓，把 tile 裁成 <tile>_edge_* 过渡块
func _make_edges(tile: String, mask: String) -> void:
	var fill: Image = _tiles.get_source(_sources[tile]).texture.get_image()
	fill.convert(Image.FORMAT_RGBA8)
	for parts: Array in EDGE_TILES.values():
		for part: String in parts:
			var shape: Image = _tiles.get_source(_sources["%s_%s" % [mask, part]]).texture.get_image()
			shape.convert(Image.FORMAT_RGBA8)
			var image := fill.duplicate() as Image
			for y in TILE:
				for x in TILE:
					if shape.get_pixel(x, y).a < 0.5:
						image.set_pixel(x, y, Color.TRANSPARENT)
			_add_source("%s_edge_%s" % [tile, part], ImageTexture.create_from_image(image))
	edges[tile] = tile + "_edge"


func _tile_layer(alpha: float) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = _tiles
	layer.modulate.a = alpha
	add_child(layer)
	return layer


## 把一种有过渡块的地面画到错开半格的图层上；对角的情况要叠两块，所以用两个图层
func _paint_edges(tile: String) -> void:
	var cells: Dictionary = _terrain[tile]
	var alpha: float = overlay.get(tile, 1.0)
	var layers: Array[TileMapLayer] = [_tile_layer(alpha), _tile_layer(alpha)]
	for layer in layers:
		layer.position = -Vector2.ONE * TILE * 0.5
	var fills: Array = [tile] + variants.get(tile, [])
	var seen := {}
	for cell: Vector2i in cells:
		for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var at: Vector2i = cell + corner
			if seen.has(at):
				continue
			seen[at] = true
			var mask := int(cells.has(at + Vector2i(-1, -1))) | int(cells.has(at + Vector2i(0, -1))) << 1 \
					| int(cells.has(at + Vector2i(-1, 0))) << 2 | int(cells.has(at)) << 3
			if mask == 15:
				layers[0].set_cell(at, _sources[fills[rng.randi() % fills.size()]], Vector2i.ZERO)
				continue
			var parts: Array = EDGE_TILES[mask]
			for i in parts.size():
				layers[i].set_cell(at, _sources["%s_%s" % [edges[tile], parts[i]]], Vector2i.ZERO)


func _exit_tree() -> void:
	if current == self:
		current = null


## 子类实现：铺地面、摆物件
func _layout() -> void:
	pass


## 敌人从 from 去追 to 时下一步往哪走。有冥河这类只能从几处通过的障碍时，子类改成先走到过河点
func waypoint(_from: Vector2, to: Vector2) -> Vector2:
	return to


## 素材有就加载，没有就按 placeholders 生成一张带深色边框的纯色图
func _texture(dir: String, file: String) -> Texture2D:
	var path := dir + file + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	var info: Array = placeholders.get(file, [Color.MAGENTA, Vector2i(32, 32)])
	var color: Color = info[0]
	var size: Vector2i = info[1]
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	if size != Vector2i(TILE, TILE):  # 物件加边框，地块不加（要能无缝平铺）
		var edge := color.darkened(0.5)
		for x in size.x:
			image.set_pixel(x, 0, edge)
			image.set_pixel(x, size.y - 1, edge)
		for y in size.y:
			image.set_pixel(0, y, edge)
			image.set_pixel(size.x - 1, y, edge)
	else:
		for i in 40:  # 地块撒一点噪点，免得一大片纯色
			image.set_pixel(rng.randi() % TILE, rng.randi() % TILE, color.lightened(0.08) if i % 2 else color.darkened(0.08))
	return ImageTexture.create_from_image(image)


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
	if edges.has(tile):
		_terrain[tile][cell] = true
	elif overlay.has(tile):
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


## 一条弯曲的小路：从 from 到 to 的二次贝塞尔曲线，bend 是中点往旁边弯出去多远。返回路中线上的点（每半格一个）
func paint_path(from: Vector2, to: Vector2, bend: float, width: float, tile: String) -> PackedVector2Array:
	var mid := (from + to) / 2.0 + (to - from).orthogonal().normalized() * bend
	var steps := int(from.distance_to(to) / (TILE * 0.5))
	var points := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		var p := from.lerp(mid, t).lerp(mid.lerp(to, t), t)
		points.append(p)
		var w := width * (0.8 + 0.4 * rng.randf())
		var c := cell_at(p)
		var reach := int(ceilf(w * 1.6 / TILE))
		for x in range(c.x - reach, c.x + reach + 1):
			for y in range(c.y - reach, c.y + reach + 1):
				var cell := Vector2i(x, y)
				if (Vector2(cell) * TILE + Vector2.ONE * TILE * 0.5).distance_to(p) < w * 1.6:
					set_ground(cell, tile)
					_reserved[cell] = true
	return points


## 四边的屏障：每边一张能重复拼接的长条（深度等于屏障带），四角各一张转角，文件名前缀 border_corner_
func border(north: String, east: String, south: String, west: String) -> void:
	var v := Game.view_bounds
	var b := Game.bounds
	for side: Array in [[north, Rect2(b.position.x, v.position.y, b.size.x, b.position.y - v.position.y)],
			[south, Rect2(b.position.x, b.end.y, b.size.x, v.end.y - b.end.y)],
			[west, Rect2(v.position.x, b.position.y, b.position.x - v.position.x, b.size.y)],
			[east, Rect2(b.end.x, b.position.y, v.end.x - b.end.x, b.size.y)]]:
		var strip := _border_sprite(side[0], side[1].position)
		strip.region_enabled = true
		strip.region_rect = Rect2(Vector2.ZERO, side[1].size)
		strip.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_border_sprite("border_corner_nw", v.position)
	_border_sprite("border_corner_ne", Vector2(b.end.x, v.position.y))
	_border_sprite("border_corner_sw", Vector2(v.position.x, b.end.y))
	_border_sprite("border_corner_se", b.end)


func _border_sprite(file: String, top_left: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _texture(borders_dir, file)
	sprite.centered = false
	sprite.position = top_left
	_borders.add_child(sprite)
	return sprite


## 摆一个物件，pos 是图片底边中点。block 是碰撞半径（0 = 只是装饰，可以穿过）
func prop(file: String, pos: Vector2, block: float = 0.0, flip := false) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _texture(props_dir, file)
	sprite.offset = Vector2(0, -sprite.texture.get_height() * 0.5)
	sprite.position = pos.round()
	sprite.flip_h = flip
	_props.add_child(sprite)
	if block > 0.0:
		add_obstacle(pos + Vector2(0, -block * 0.5), block)
	return sprite


## 宽物件（长屋、墓丘、倒下的树干）：底边上排一串碰撞圆，width 是从最左到最右的圆心距离
func wide_prop(file: String, pos: Vector2, width: float, block: float, flip := false) -> Sprite2D:
	var sprite := prop(file, pos, 0.0, flip)
	var count := maxi(2, ceili(width / block) + 1)
	for i in count:
		add_obstacle(pos + Vector2(-width * 0.5 + width * i / (count - 1), -block), block)
	return sprite


## 平贴在地面上的痕迹（车辙、脚印、血迹），pos 是图片中心，画在物件下面
func decal(file: String, pos: Vector2, flip := false) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _texture(decals_dir, file)
	sprite.position = pos.round()
	sprite.flip_h = flip
	_decals.add_child(sprite)
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
