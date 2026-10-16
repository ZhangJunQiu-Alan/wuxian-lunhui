class_name SpriteVisual
## 素材接入：按约定的路径找图片，找到就用图片代替占位图形，找不到就继续用占位图形
##
## 约定：给出不带扩展名的路径，例如 res://assets/sprites/enemies/draugr，会依次查找
##   draugr.tres       序列帧动画（SpriteFrames），自动播放 "move" 动画，没有就播放 "default"
##   draugr_move.png   横向帧条：每帧是正方形，从左到右排列（4 帧 64×64 就是 256×64），自动切帧播放
##   draugr.png        静态图片
## 所以美术只要把文件按名字放进对应文件夹，不需要改任何代码
## 玩家角色另有多动作约定：<id>_idle / _move / _hurt / _death.png，见 create_actions()
##
## 像素画只按整数倍缩放（1 倍、2 倍……），缩成 0.7 倍这种会丢像素、变糊
## 静态图片没有帧动画时，用 animate() 做程序动画：走路上下颠、左右轻摆、轻微挤压

const EXTENSIONS := [".tres", "_move.png", ".png", ".webp"]
const STRIP_FPS := 8.0  # 帧条的播放速度（帧/秒）


## 依次尝试多个路径，返回第一个找到的素材节点
static func create_first(base_paths: Array[String], height: float) -> Node2D:
	for base_path in base_paths:
		var node := create(base_path, height)
		if node:
			return node
	return null


## 创建图片节点。height 是希望的显示高度，会取最接近的整数倍（至少 1 倍）。找不到素材返回 null
static func create(base_path: String, height: float) -> Node2D:
	for ext in EXTENSIONS:
		var path: String = base_path + ext
		if not ResourceLoader.exists(path):
			continue
		var res := load(path)
		var node: Node2D
		var tex_height := 1.0
		if res is SpriteFrames:
			var frames := res as SpriteFrames
			var anim_name := &"move" if frames.has_animation(&"move") else &"default"
			var anim := AnimatedSprite2D.new()
			anim.sprite_frames = frames
			anim.play(anim_name)
			tex_height = frames.get_frame_texture(anim_name, 0).get_height()
			node = anim
		elif res is Texture2D and ext == "_move.png":
			var anim := AnimatedSprite2D.new()
			anim.sprite_frames = SpriteFrames.new()
			_add_strip(anim.sprite_frames, &"default", res, true)
			anim.play(&"default")
			anim.frame = randi() % anim.sprite_frames.get_frame_count(&"default")  # 随机起始帧，怪物步伐错开
			tex_height = res.get_height()
			node = anim
		elif res is Texture2D:
			var sprite := Sprite2D.new()
			sprite.texture = res
			tex_height = sprite.texture.get_height()
			node = sprite
		else:
			continue
		node.scale = Vector2.ONE * maxf(1.0, roundf(height / tex_height))
		node.set_meta("base_scale", node.scale)
		return node
	return null


## 角色动作：<base>_<动作>.png 每个都是一条横向帧条，合成一个带多个动画的 AnimatedSprite2D
## actions 是 动作名 -> 是否循环，例如 {"idle": true, "move": true, "hurt": false, "death": false}
## 至少要有 idle 或 move 才返回节点，否则返回 null（这时改用 create() 的静态图）
static func create_actions(base_path: String, height: float, actions: Dictionary) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var tex_height := 1.0
	for action: String in actions:
		var path := "%s_%s.png" % [base_path, action]
		if not ResourceLoader.exists(path):
			continue
		var strip: Texture2D = load(path)
		_add_strip(frames, action, strip, actions[action])
		tex_height = strip.get_height()
	if not (frames.has_animation(&"idle") or frames.has_animation(&"move")):
		return null
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = frames
	anim.play(&"idle" if frames.has_animation(&"idle") else &"move")
	anim.scale = Vector2.ONE * maxf(1.0, roundf(height / tex_height))
	anim.set_meta("base_scale", anim.scale)
	return anim


## 把横向帧条切成一帧一帧（每帧是正方形），加成 frames 里名为 anim_name 的动画
static func _add_strip(frames: SpriteFrames, anim_name: StringName, strip: Texture2D, loop: bool) -> void:
	var size := strip.get_height()
	if not frames.has_animation(anim_name):
		frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, STRIP_FPS)
	frames.set_animation_loop(anim_name, loop)
	for i in strip.get_width() / size:
		var frame := AtlasTexture.new()
		frame.atlas = strip
		frame.region = Rect2(i * size, 0, size, size)
		frames.add_frame(anim_name, frame)


## 程序动画。t 是累计时间，amount 是动作幅度（0 = 静止，1 = 全速移动）
static func animate(sprite: Node2D, t: float, amount: float) -> void:
	var base: Vector2 = sprite.get_meta("base_scale", Vector2.ONE)
	var phase := t * 9.0
	sprite.position = Vector2(0, -absf(sin(phase)) * 3.0 * amount)  # 走路上下颠
	sprite.rotation = sin(phase) * 0.05 * amount                   # 左右轻摆
	var squash := 0.03 * sin(phase * 2.0) * amount                 # 落地时轻微挤压
	sprite.scale = Vector2(base.x * (1.0 + squash), base.y * (1.0 - squash))


## Boss 蓄力：颤抖并微微胀大，t 是蓄力已经持续的时间。在有蓄力姿势的帧动画之前先用它
static func windup_tremble(sprite: Node2D, t: float) -> void:
	sprite.position.x = randf_range(-1.5, 1.5)
	sprite.scale *= 1.0 + 0.08 * minf(1.0, t / 0.5)


## 脚下的影子，让图片看起来站在地面上
static func draw_shadow(canvas: CanvasItem, radius: float, tint: Color = Color(0, 0, 0, 0.35)) -> void:
	canvas.draw_set_transform(Vector2(0, radius * 0.9), 0.0, Vector2(1.0, 0.35))
	canvas.draw_circle(Vector2.ZERO, radius * 1.1, tint)
	canvas.draw_set_transform(Vector2.ZERO)
