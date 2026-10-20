extends SceneTree

class Review extends Node2D:
	var phase := "idle"
	var index := 0
	var textures := {}
	var count := 4
	var transparent_pass := false
	var binding := false
	var contact_data := []

	func load_image(name: String) -> Texture2D:
		return ImageTexture.create_from_image(Image.load_from_file("res://inputs/"+name+".png"))

	func _ready() -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
		for name: String in ["ground","player","fenrir_idle_v01","fenrir_move_v02","fenrir_windup_v02","fenrir_attack_v01","fenrir_swallow_v01","fenrir_maw_upper_v01","fenrir_maw_lower_v01","fenrir_bind_link_v01","gleipnir_fragment_v01","vidar_v01","vidar_idle_v01","vidar_pry_v01"]:
			textures[name]=load_image(name)

	func actor(name: String, n: int, i: int, pos: Vector2) -> void:
		var t: Texture2D=textures[name]
		var size := Vector2(t.get_width()/n,t.get_height())
		draw_texture_rect_region(t,Rect2(pos,size),Rect2(Vector2(i*size.x,0),size))

	func bind_ring(origin: Vector2) -> void:
		var points := 144
		for j in points:
			var t0 := float(j)/points
			var t1 := float(j+1)/points
			var a0 := t0*TAU
			var a1 := t1*TAU
			var p0 := origin+Vector2(cos(a0)*82,sin(a0)*84)
			var p1 := origin+Vector2(cos(a1)*82,sin(a1)*84)
			var n0 := Vector2(cos(a0),sin(a0))
			var n1 := Vector2(cos(a1),sin(a1))
			var u0 := t0*32
			var u1 := t1*32
			var v0 := pingpong(u0,1.0)
			var v1 := pingpong(u1,1.0)
			var tint := Color(1.1,1.1,1.0) if posmod(j-index*36,144)<8 else Color.WHITE
			draw_polygon(PackedVector2Array([p0-n0*4,p1-n1*4,p1+n1*4,p0+n0*4]),PackedColorArray([tint]),PackedVector2Array([Vector2(v0,0),Vector2(v1,0),Vector2(v1,1),Vector2(v0,1)]),textures["fenrir_bind_link_v01"])

	func _draw() -> void:
		if textures.is_empty():return
		if transparent_pass:
			if binding:bind_ring(Vector2(96,96))
			else:
				actor("fenrir_maw_upper_v01",4,index,Vector2(0,16))
				actor("fenrir_maw_lower_v01",4,index,Vector2(0,208))
			return
		for y in range(0,720,64):
			for x in range(0,1280,64):draw_texture(textures.ground,Vector2(x,y))
		draw_rect(Rect2(0,0,1280,80),Color("121721"))
		draw_string(ThemeDB.fallback_font,Vector2(20,28),"K2 isolated asset review / %s frame %d"%[phase,index],HORIZONTAL_ALIGNMENT_LEFT,-1,20)
		draw_string(ThemeDB.fallback_font,Vector2(20,56),"Not the Game scene. No targeting, damage, escape timer or fate conditions tested.",HORIZONTAL_ALIGNMENT_LEFT,-1,16)
		if phase in ["idle","move","windup","attack","swallow"]:
			var version := "v02" if phase in ["move","windup"] else "v01"
			actor("fenrir_"+phase+"_"+version,count,index,Vector2(150,230))
			draw_line(Vector2(140,420),Vector2(355,420),Color(0.6,0.9,0.8),1)
			actor("player",1,0,Vector2(440,356))
		elif phase in ["ally_idle","ally_pry"]:
			actor("vidar_"+("idle" if phase=="ally_idle" else "pry")+"_v01",count,index,Vector2(220,326))
			draw_line(Vector2(190,420),Vector2(345,420),Color(0.6,0.9,0.8),1)
		elif phase=="maw":
			actor("fenrir_maw_upper_v01",4,index,Vector2(135,116))
			actor("fenrir_maw_lower_v01",4,index,Vector2(135,308))
			draw_rect(Rect2(231,244,112,64),Color(0.4,0.9,0.8),false,1)
			actor("player",1,0,Vector2(245,245))
		elif phase=="binding":
			actor("fenrir_idle_v01",4,index,Vector2(150,230))
			bind_ring(Vector2(246,326))
			draw_rect(Rect2(206,284,80,84),Color(0.4,0.9,0.8),false,1)
			actor("gleipnir_fragment_v01",1,0,Vector2(420,390))
		elif phase=="contact":
			var hands := [Vector2(82,8),Vector2(79,6),Vector2(80,5)]
			var boots := [Vector2(78,92),Vector2(78,92),Vector2(79,92)]
			var local_index := index-2
			var origin := Vector2(255,260)
			var hand: Vector2 = origin+hands[local_index]
			var boot: Vector2 = origin+boots[local_index]
			var upper: Texture2D=textures.fenrir_maw_upper_v01
			var lower: Texture2D=textures.fenrir_maw_lower_v01
			var xi := 195
			var yu := 0
			var yl := 128
			var ui := upper.get_image()
			var li := lower.get_image()
			for y in 128:
				if ui.get_pixel(xi,y).a>0:yu=y
				if li.get_pixel(xi,y).a>0:yl=mini(yl,y)
			var upos: Vector2 = hand-Vector2(xi,yu)
			var lpos: Vector2 = boot-Vector2(xi,yl)
			actor("fenrir_maw_upper_v01",4,0,upos)
			actor("fenrir_maw_lower_v01",4,0,lpos)
			actor("vidar_pry_v01",6,index,origin)
			draw_circle(hand,2,Color(0.4,0.9,0.8))
			draw_circle(boot,2,Color(0.4,0.9,0.8))
			contact_data.append({"frame":index,"hand":hand,"boot":boot,"upper_origin":upos,"lower_origin":lpos,"scope":"illustrative contact registration only, no active player or damage"})
		draw_rect(Rect2(720,100,540,520),Color("121721"))
		actor("fenrir_idle_v01",4,0,Vector2(750,130))
		actor("vidar_v01",1,0,Vector2(1010,224))
		draw_string(ThemeDB.fallback_font,Vector2(750,360),"1x scale and dark-background reference",HORIZONTAL_ALIGNMENT_LEFT,-1,16)

var view: Review

func _initialize() -> void:
	root.size=Vector2i(1280,720)
	view=Review.new()
	root.add_child.call_deferred(view)
	run.call_deferred()

func capture(name: String) -> int:
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().save_png("res://captures/"+name+".png")

func run() -> void:
	await process_frame
	await process_frame
	var out := []
	for row: Array in [["idle",4],["move",6],["windup",3],["attack",4],["swallow",6],["ally_idle",4],["ally_pry",6],["maw",4],["binding",4],["contact",3]]:
		view.phase=row[0]
		view.count=row[1]
		for i in int(row[1]):
			view.index=i+2 if row[0]=="contact" else i
			var name := "%s_%02d"%[view.phase,view.index]
			out.append({"file":"captures/"+name+".png","save_error":await capture(name)})
	root.transparent_bg=true
	view.transparent_pass=true
	for mode: String in ["maw","binding"]:
		view.binding=mode=="binding"
		for i in 4:
			view.index=i
			var name := "alpha_%s_%02d"%[mode,i]
			out.append({"file":"captures/"+name+".png","save_error":await capture(name)})
	var file := FileAccess.open("res://captures/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"captures":out,"contacts":view.contact_data,"scope":"isolated asset fixture only"},"  "))
	quit()
