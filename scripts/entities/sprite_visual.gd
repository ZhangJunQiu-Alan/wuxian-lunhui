class_name SpriteVisual
## 素材接入：按约定的路径找图片，找到就用图片代替占位图形，找不到就继续用占位图形
##
## 约定：给出不带扩展名的路径，例如 res://assets/sprites/enemies/draugr，会依次查找
##   draugr.tres  序列帧动画（SpriteFrames），自动播放 "move" 动画，没有就播放 "default"
##   draugr.png   静态图片
## 所以美术只要把文件按名字放进对应文件夹，不需要改任何代码

const EXTENSIONS := [".tres", ".png", ".webp"]


## 创建图片节点，并按 height 自动缩放（让图片高度等于 height 像素）。找不到素材返回 null
static func create(base_path: String, height: float) -> Node2D:
	for ext in EXTENSIONS:
		var path: String = base_path + ext
		if not ResourceLoader.exists(path):
			continue
		var res := load(path)
		if res is SpriteFrames:
			var frames := res as SpriteFrames
			var anim_name := &"move" if frames.has_animation(&"move") else &"default"
			var anim := AnimatedSprite2D.new()
			anim.sprite_frames = frames
			anim.play(anim_name)
			anim.scale = Vector2.ONE * height / frames.get_frame_texture(anim_name, 0).get_height()
			return anim
		if res is Texture2D:
			var sprite := Sprite2D.new()
			sprite.texture = res
			sprite.scale = Vector2.ONE * height / sprite.texture.get_height()
			return sprite
	return null
