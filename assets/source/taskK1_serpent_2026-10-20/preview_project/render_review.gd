extends SceneTree

class Review extends Node2D:
	var phase := "idle"
	var frame := 0
	var radius := 240.0
	var body: Texture2D
	var tail: Texture2D
	var ground: Texture2D
	var breath: Texture2D
	var player: Texture2D
	var heads := {}
	var head_point := Vector2.ZERO
	var show_poison := false

	func image(path: String) -> Texture2D:
		return ImageTexture.create_from_image(Image.load_from_file(path))

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		body = image("res://inputs/jormungandr_body.png")
		tail = image("res://inputs/jormungandr_tail.png")
		ground = image("res://inputs/ground.png")
		breath = image("res://inputs/breath.png")
		player = image("res://inputs/player.png")
		for action: String in ["idle", "windup", "attack"]:
			heads[action] = image("res://inputs/head_%s.png" % action)

	func at(angle: float) -> Vector2:
		return Vector2(580, 365) + Vector2.from_angle(angle) * radius

	func draw_actor(texture: Texture2D, count: int, index: int, pos: Vector2, anchor: Vector2, angle: float = 0.0) -> void:
		var size := Vector2(texture.get_width() / count, texture.get_height())
		draw_set_transform(pos, angle)
		draw_texture_rect_region(texture, Rect2(-anchor, size), Rect2(Vector2(index * size.x, 0), size))
		draw_set_transform(Vector2.ZERO)

	func _draw() -> void:
		if not body:
			return
		for y in range(0, 720, 64):
			for x in range(0, 1280, 64):
				draw_texture(ground, Vector2(x,y))
		draw_rect(Rect2(0,0,1280,66), Color("121721"))
		draw_string(ThemeDB.fallback_font, Vector2(22,26), "K1 / isolated Godot asset review / %s frame %d / R%.0f" % [phase,frame,radius], HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		draw_string(ThemeDB.fallback_font, Vector2(22,52), "Not the actual third level. Curved existing body; new head; shared clipping preview.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		var end := -PI / 2.0
		var start := end - 4.5
		var count := 180
		var cycles := roundf(4.5 * radius / 64.0)
		for i in count:
			var t0 := float(i) / count
			var t1 := float(i+1) / count
			var a0 := lerpf(start,end,t0)
			var a1 := lerpf(start,end,t1)
			var p0 := at(a0)
			var p1 := at(a1)
			var n0 := Vector2.from_angle(a0 + PI)
			var n1 := Vector2.from_angle(a1 + PI)
			var quad := PackedVector2Array([p0 - n0*30.0,p1-n1*30.0,p1+n1*34.0,p0+n0*34.0])
			var uv := PackedVector2Array([Vector2(t0*cycles,0),Vector2(t1*cycles,0),Vector2(t1*cycles,1),Vector2(t0*cycles,1)])
			draw_polygon(quad,PackedColorArray([Color.WHITE]),uv,body)
		draw_actor(tail,1,0,at(start),Vector2(64,30),start+PI/2.0)
		head_point = at(end)
		draw_actor(heads[phase],3 if phase=="windup" else 4,frame,head_point,Vector2(0,62))
		draw_actor(player,1,0,Vector2(570,390),Vector2(32,60))
		draw_arc(Vector2(580,365),radius-38,0,TAU,96,Color(0.5,0.9,0.8,0.5),1)
		if show_poison:
			var mouth := head_point+Vector2(108,4)
			var clip := PackedVector2Array([mouth])
			for i in range(25):
				clip.append(mouth+Vector2.from_angle(deg_to_rad(-35+70.0*i/24))*235)
			var rect := PackedVector2Array([mouth+Vector2(-10,-48),mouth+Vector2(230,-48),mouth+Vector2(230,48),mouth+Vector2(-10,48)])
			for poly in Geometry2D.intersect_polygons(rect,clip):
				var uv := PackedVector2Array()
				for point in poly:
					var local: Vector2=(point-mouth)/Vector2(2.5,1.5)+Vector2(4,32)
					uv.append(Vector2((frame*96+local.x)/384,local.y/64))
				draw_polygon(poly,PackedColorArray([Color.WHITE]),uv,breath)
			draw_polyline(clip,Color(0.6,0.9,0.4,0.8),1)
		draw_rect(Rect2(0,660,1280,60),Color("121721"))
		draw_string(ThemeDB.fallback_font,Vector2(22,689),"Texture effects do not define damage; target registration and real encounter behavior are NOT tested here.",HORIZONTAL_ALIGNMENT_LEFT,-1,15)

var view: Review

func _initialize() -> void:
	root.size = Vector2i(1280,720)
	view=Review.new()
	root.add_child.call_deferred(view)
	run.call_deferred()

func run() -> void:
	await process_frame
	await process_frame
	var output := []
	for radius: float in [240.0,128.0]:
		view.radius=radius
		for phase: String in ["idle","windup","attack"]:
			var count := 3 if phase=="windup" else 4
			for i in count:
				view.phase=phase
				view.frame=i
				view.show_poison=phase=="attack"
				view.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var name := "captures/r%d_%s_%02d.png" % [int(radius),phase,i]
				var result := root.get_texture().get_image().save_png("res://"+name)
				output.append({"file":name,"save_error":result,"scope":"isolated asset fixture, not actual Game scene"})
	var file := FileAccess.open("res://captures/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"  "))
	file.close()
	quit()
