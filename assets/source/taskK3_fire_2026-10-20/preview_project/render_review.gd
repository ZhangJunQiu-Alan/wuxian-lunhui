extends SceneTree

class Review extends Node2D:
	var textures := {}
	var phase := "idle"
	var frame := 0
	var count := 4
	var angle := 0.0
	var radius := 240.0
	var alpha_mode := false
	var safe_cells := [Vector2i(3,2),Vector2i(6,4)]

	func _ready() -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
		for name: String in ["surtr_idle","surtr_move","surtr_windup","surtr_attack","surtr_plant","surtr_summon","surtr_sword_arc","surtr_gate","surtr_firewall_band","surtr_final_fire","surtr_safe_rune","freyr","freyr_idle","freyr_heal","ground","player","surtr_static","fire_giant","freyr_field","residual"]:
			var img := Image.load_from_file("res://inputs/"+name+".png")
			if name=="residual":
				for y in img.get_height():
					for x in img.get_width():
						var c := img.get_pixel(x,y)
						if c.a>0:img.set_pixel(x,y,Color.from_hsv(0.04,c.s,c.v,c.a))
			textures[name]=ImageTexture.create_from_image(img)

	func actor(name: String,n: int,i: int,pos: Vector2,anchor: Vector2=Vector2.ZERO,rotation: float=0.0) -> void:
		var t: Texture2D=textures[name]
		var size := Vector2(t.get_width()/n,t.get_height())
		draw_set_transform(pos,rotation)
		draw_texture_rect_region(t,Rect2(-anchor,size),Rect2(Vector2(i*size.x,0),size))
		draw_set_transform(Vector2.ZERO)

	func firewall(center: Vector2) -> void:
		for i in 160:
			var t0 := float(i)/160
			var t1 := float(i+1)/160
			var a0 := t0*TAU
			var a1 := t1*TAU
			var n0 := Vector2.from_angle(a0)
			var n1 := Vector2.from_angle(a1)
			var p0 := center+n0*radius
			var p1 := center+n1*radius
			var u0 := pingpong(t0*32,1.0)
			var u1 := pingpong(t1*32,1.0)
			var uv := PackedVector2Array([Vector2((frame+u0)/4,0),Vector2((frame+u1)/4,0),Vector2((frame+u1)/4,1),Vector2((frame+u0)/4,1)])
			draw_polygon(PackedVector2Array([p0+n0*32,p1+n1*32,p1-n1*32,p0-n0*32]),PackedColorArray([Color.WHITE]),uv,textures.surtr_firewall_band)

	func grid(pos: Vector2,fire_only: bool=false) -> void:
		for y in range(6):
			for x in range(9):
				var cell := Vector2i(x,y)
				var point := pos+Vector2(cell*64)
				if cell in safe_cells:
					if not fire_only:actor("surtr_safe_rune",1,0,point)
				else:actor("surtr_final_fire",4,frame,point)
		if not fire_only:actor("player",1,0,pos+Vector2(3*64,2*64))

	func _draw() -> void:
		if textures.is_empty():return
		if alpha_mode:
			if phase=="wall":firewall(Vector2(350,350))
			elif phase=="grid":grid(Vector2.ZERO,true)
			elif phase=="gate":actor("surtr_gate",4,frame,Vector2.ZERO)
			elif phase=="arc":actor("surtr_sword_arc",4,frame,Vector2(150,150),Vector2(64,64),angle)
			return
		for y in range(0,720,64):
			for x in range(0,1280,64):draw_texture(textures.ground,Vector2(x,y))
		if phase in ["idle","move","windup","attack","plant","summon"]:
			actor("surtr_"+phase,count,frame,Vector2(240,490),Vector2(160,318))
			draw_line(Vector2(100,490),Vector2(390,490),Color(0.5,0.9,0.8),1)
			if phase=="attack":actor("surtr_sword_arc",4,frame,Vector2(300,430),Vector2(64,64),0.0)
			if phase=="plant" and frame>=2:actor("residual",1,0,Vector2(275,460))
		elif phase=="gate":
			actor("surtr_gate",4,frame,Vector2(210,400),Vector2(64,126))
			actor("fire_giant",1,0,Vector2(210,420),Vector2(48,94))
			draw_rect(Rect2(186,320,48,70),Color(0.5,0.9,0.8),false,1)
		elif phase=="arc":
			actor("surtr_sword_arc",4,frame,Vector2(240,340),Vector2(64,64),angle)
			actor("player",1,0,Vector2(208,308))
			draw_arc(Vector2(240,340),32,0,TAU,64,Color(0.5,0.9,0.8),1)
		elif phase=="wall":
			firewall(Vector2(350,350))
			draw_arc(Vector2(350,350),radius,0,TAU,128,Color(0.5,0.9,0.8),1)
			actor("player",1,0,Vector2(318,318))
		elif phase=="grid":grid(Vector2(60,180))
		elif phase in ["freyr_idle","freyr_heal"]:
			actor("freyr_field",1,0,Vector2(220,415),Vector2(64,64))
			actor(phase,4,frame,Vector2(220,440),Vector2(32,62))
			actor("player",1,0,Vector2(300,378))
		draw_rect(Rect2(0,0,1280,75),Color("121721"))
		draw_string(ThemeDB.fallback_font,Vector2(20,28),"K3 isolated asset rendering / %s frame%d R%.0f angle%.0f"%[phase,frame,radius,rad_to_deg(angle)],HORIZONTAL_ALIGNMENT_LEFT,-1,19)
		draw_string(ThemeDB.fallback_font,Vector2(20,55),"Not Game scene: no damage, phase thresholds, healing or fate condition tested.",HORIZONTAL_ALIGNMENT_LEFT,-1,16)
		draw_rect(Rect2(760,110,500,490),Color("121721"))
		actor("surtr_static",1,0,Vector2(900,420),Vector2(96,190))
		actor("freyr",1,0,Vector2(1070,420),Vector2(32,62))
		draw_string(ThemeDB.fallback_font,Vector2(790,475),"Existing192px boss / new64px world ally / 1x",HORIZONTAL_ALIGNMENT_LEFT,-1,15)

var view: Review

func _initialize() -> void:
	root.size=Vector2i(1280,720)
	view=Review.new()
	root.add_child.call_deferred(view)
	run.call_deferred()

func capture(name: String) -> Dictionary:
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return {"file":"captures/"+name+".png","save_error":root.get_texture().get_image().save_png("res://captures/"+name+".png")}

func run() -> void:
	await process_frame
	await process_frame
	var output := []
	for row: Array in [["idle",4],["move",6],["windup",3],["attack",4],["plant",4],["summon",4],["gate",4],["freyr_idle",4],["freyr_heal",4],["grid",4]]:
		view.phase=row[0];view.count=row[1]
		for i in int(row[1]):
			view.frame=i;output.append(await capture("%s_%02d"%[view.phase,i]))
	for r: float in [240.0,150.0]:
		view.phase="wall";view.radius=r
		for i in 4:
			view.frame=i;output.append(await capture("wall_r%d_%02d"%[int(r),i]))
	view.phase="arc"
	for a: float in [0.0,PI/4,PI/2,PI]:
		view.angle=a
		for i in 4:
			view.frame=i;output.append(await capture("arc_a%d_%02d"%[int(rad_to_deg(a)),i]))
	root.transparent_bg=true;view.alpha_mode=true
	for mode: String in ["wall","grid","gate","arc"]:
		view.phase=mode;view.radius=240;view.angle=0.0
		for i in 4:
			view.frame=i;output.append(await capture("alpha_%s_%02d"%[mode,i]))
	var f := FileAccess.open("res://captures/result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"captures":output,"safe_cells":[[3,2],[6,4]],"scope":"isolated asset fixture only"},"  "))
	quit()
