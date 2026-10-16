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
## 静态图片没有帧动画时，用 animate() 做程序动画：按步态（双足、四足、巨人、飘浮）颠步、摇摆、前倾
## 图片的轴心在脚底（不是图片中心），所以前倾、摇摆时脚站得稳，不会滑来滑去

const EXTENSIONS := [".tres", "_move.png", ".png", ".webp"]
const STRIP_FPS := 8.0  # 帧条的播放速度（帧/秒）
const ACTION_FPS := {"attack": 16.0}  # 个别动作播放得更快（出刀要利落）


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
		_pivot_at_feet(node, tex_height)
		return node
	return null


## 把轴心移到脚底：图片往上挪半个高度，节点再往下挪回来，画面位置不变
static func _pivot_at_feet(node: Node2D, tex_height: float) -> void:
	node.set("offset", Vector2(0, -tex_height * 0.5))
	node.position = Vector2(0, tex_height * 0.5 * node.scale.y)
	node.set_meta("base_scale", node.scale)
	node.set_meta("base_pos", node.position)


## 角色动作：<base>_<动作>.png 每个都是一条横向帧条，合成一个带多个动画的 AnimatedSprite2D
## actions 是 动作名 -> 是否循环，例如 {"idle": true, "move": true, "hurt": false, "death": false}
## 没有 idle 和 move 时，用静态图 <base>.png 当作只有一帧的 idle；连静态图也没有，或者一个动作都没有，返回 null
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
	if frames.get_animation_names().is_empty():
		return null
	if not (frames.has_animation(&"idle") or frames.has_animation(&"move")):
		if not ResourceLoader.exists(base_path + ".png"):
			return null
		var still: Texture2D = load(base_path + ".png")
		frames.add_animation(&"idle")
		frames.add_frame(&"idle", still)
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = frames
	anim.play(&"idle" if frames.has_animation(&"idle") else &"move")
	anim.scale = Vector2.ONE * maxf(1.0, roundf(height / tex_height))
	_pivot_at_feet(anim, tex_height)
	return anim


## 把横向帧条切成一帧一帧（每帧是正方形），加成 frames 里名为 anim_name 的动画
static func _add_strip(frames: SpriteFrames, anim_name: StringName, strip: Texture2D, loop: bool) -> void:
	var size := strip.get_height()
	if not frames.has_animation(anim_name):
		frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, ACTION_FPS.get(String(anim_name), STRIP_FPS))
	frames.set_animation_loop(anim_name, loop)
	for i in strip.get_width() / size:
		var frame := AtlasTexture.new()
		frame.atlas = strip
		frame.region = Rect2(i * size, 0, size, size)
		frames.add_frame(anim_name, frame)


## 程序动画。t 是累计时间，amount 是动作幅度（0 = 静止，1 = 全速移动）
## gait 步态：walk 双足、quad 四足奔跑、heavy 巨人重步、float 飘浮
## lean_x 是水平移动方向（-1 ~ 1），身体朝前进方向前倾；offset 是额外位移（攻击前扑）
static func animate(sprite: Node2D, t: float, amount: float, gait: String = "walk", lean_x: float = 0.0, offset: Vector2 = Vector2.ZERO) -> void:
	var base: Vector2 = sprite.get_meta("base_scale", Vector2.ONE)
	var pos: Vector2 = sprite.get_meta("base_pos", Vector2.ZERO) + offset
	var anim := sprite as AnimatedSprite2D
	var has_frames := anim != null and anim.sprite_frames.get_frame_count(anim.animation) > 1  # 有逐帧动画时，只保留前倾和轻微颠步
	var lean := lean_x * 0.1 * amount
	var bob := 0.0
	var sway := 0.0     # 以脚为轴的左右摇摆（换脚）
	var squash := 0.0   # 正数 = 压扁，负数 = 拉长
	match gait:
		"float":  # 慢慢上下浮动，没有步子
			bob = -4.0 - sin(t * 3.0) * 3.0
			sway = sin(t * 1.7) * 0.05
			lean *= 0.5
		"quad":  # 四足奔跑：步频快，身体一伸一缩，头一点一点
			var phase := t * 14.0
			bob = -absf(sin(phase)) * 4.0 * amount
			sway = sin(phase) * 0.07 * amount
			squash = -0.07 * sin(phase * 2.0) * amount
		"heavy":  # 巨人：步子慢而沉，每一步落地都明显压扁
			var phase := t * 5.0
			bob = -absf(sin(phase)) * 2.5 * amount
			sway = sin(phase) * 0.06 * amount
			squash = 0.1 * pow(1.0 - absf(sin(phase)), 4.0) * amount
			lean *= 0.6
		_:  # 双足走路：一颠一颠，左右换脚
			var phase := t * 9.0
			bob = -absf(sin(phase)) * 3.5 * amount
			sway = sin(phase) * 0.1 * amount
			squash = 0.06 * pow(1.0 - absf(sin(phase)), 4.0) * amount - 0.03 * amount
	if has_frames:
		sway = 0.0
		squash = 0.0
		bob *= 0.4
	sprite.position = pos + Vector2(0, bob)
	sprite.rotation = lean
	sprite.skew = sway
	sprite.scale = Vector2(base.x * (1.0 + squash), base.y * (1.0 - squash))


## Boss 蓄力：颤抖并微微胀大，t 是蓄力已经持续的时间。has_pose 表示正在播放蓄力姿势的帧动画，这时只颤抖不胀大
static func windup_tremble(sprite: Node2D, t: float, has_pose: bool = false) -> void:
	sprite.position.x = randf_range(-1.5, 1.5)
	if not has_pose:
		sprite.scale *= 1.0 + 0.08 * minf(1.0, t / 0.5)


## 脚下的影子，让图片看起来站在地面上
static func draw_shadow(canvas: CanvasItem, radius: float, tint: Color = Color(0, 0, 0, 0.35)) -> void:
	canvas.draw_set_transform(Vector2(0, radius * 0.9), 0.0, Vector2(1.0, 0.35))
	canvas.draw_circle(Vector2.ZERO, radius * 1.1, tint)
	canvas.draw_set_transform(Vector2.ZERO)


## 画帧条（横向排列 frames 帧）的第 frame 帧：单帧里的 anchor 点对准 pos，可以旋转、缩放（缩放取负数就是翻转）
static func draw_frame(canvas: CanvasItem, strip: Texture2D, frames: int, frame: int, pos: Vector2, anchor: Vector2, rot := 0.0, scale := Vector2.ONE, tint := Color.WHITE) -> void:
	var size := Vector2(strip.get_width() / frames, strip.get_height())
	canvas.draw_set_transform(pos, rot, scale)
	canvas.draw_texture_rect_region(strip, Rect2(-anchor, size), Rect2(Vector2(size.x * posmod(frame, frames), 0), size), tint)
	canvas.draw_set_transform(Vector2.ZERO)
