extends SceneTree

class Review extends Node2D:
	var textures := {}
	var asset_id := "fire_giant_move"
	var frames := 6
	var index := 0

	func _ready() -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		for id: String in ["ground","player","fire_giant","frost_veteran","dead_move","residual","fire_giant_move","fire_giant_attack","frost_veteran_move","frost_veteran_attack","frost_veteran_charge","frost_veteran_shield","wolf_berserker","wolf_berserker_move","wolf_berserker_attack","wolf_berserker_rage","fire_giant_explosion"]:
			var img := Image.load_from_file("res://inputs/"+id+".png")
			if id=="residual":
				for y in img.get_height():
					for x in img.get_width():
						var c := img.get_pixel(x,y)
						if c.a>0:img.set_pixel(x,y,Color.from_hsv(0.04,c.s,c.v,c.a))
			textures[id]=ImageTexture.create_from_image(img)

	func actor(id: String,n: int,i: int,pos: Vector2,anchor: Vector2) -> void:
		var t: Texture2D=textures[id]
		var size := Vector2(t.get_width()/n,t.get_height())
		draw_texture_rect_region(t,Rect2(pos-anchor,size),Rect2(Vector2(i*size.x,0),size))

	func _draw() -> void:
		if textures.is_empty():return
		for y in range(0,720,64):
			for x in range(0,1280,64):draw_texture(textures.ground,Vector2(x,y))
		draw_rect(Rect2(0,0,1280,80),Color("121721"))
		draw_string(ThemeDB.fallback_font,Vector2(20,30),"K4 isolated asset rendering / %s frame%d"%[asset_id,index],HORIZONTAL_ALIGNMENT_LEFT,-1,20)
		draw_string(ThemeDB.fallback_font,Vector2(20,58),"Not Game scene; no AI, shield damage, rage stats or explosion damage tested.",HORIZONTAL_ALIGNMENT_LEFT,-1,16)
		var size := 64 if asset_id.begins_with("wolf_") else 96
		var anchor := Vector2(size/2,size-2)
		if asset_id!="fire_giant_explosion":actor(asset_id,frames,index,Vector2(230,360),anchor)
		actor("player",1,0,Vector2(365,360),Vector2(32,62))
		draw_line(Vector2(160,360),Vector2(410,360),Color(0.5,0.9,0.8),1)
		if asset_id=="frost_veteran_shield" or asset_id=="frost_veteran_charge":
			draw_circle(Vector2(300,315),3,Color("d19b6f"))
			draw_circle(Vector2(160,315),3,Color("76b3ae"))
			draw_string(ThemeDB.fallback_font,Vector2(100,420),"front/right shield; left/back visible; dots are QA guides",HORIZONTAL_ALIGNMENT_LEFT,-1,15)
		if asset_id=="fire_giant_explosion":
			actor("residual",1,0,Vector2(230,360),Vector2(32,32))
			actor(asset_id,frames,index,Vector2(230,330),Vector2(48,48))
		draw_rect(Rect2(650,100,610,540),Color("121721"))
		actor("fire_giant",1,0,Vector2(750,260),Vector2(48,94))
		actor("frost_veteran",1,0,Vector2(900,260),Vector2(48,94))
		actor("wolf_berserker",1,0,Vector2(1040,260),Vector2(32,62))
		actor("dead_move",6,index%6,Vector2(1170,260),Vector2(32,62))
		draw_string(ThemeDB.fallback_font,Vector2(675,300),"original96px giants / new64px human / existing dead reused",HORIZONTAL_ALIGNMENT_LEFT,-1,15)
		for y in 4:
			for x in 4:
				var id: String=["fire_giant_move","frost_veteran_move","wolf_berserker_move","dead_move"][(x+y)%4]
				var s := 64 if id.begins_with("wolf_") or id=="dead_move" else 96
				actor(id,6,index%6,Vector2(710+x*135,390+y*76),Vector2(s/2,s-2))

var review: Review

func _initialize() -> void:
	root.size=Vector2i(1280,720)
	review=Review.new()
	root.add_child.call_deferred(review)
	run.call_deferred()

func run() -> void:
	await process_frame
	await process_frame
	var out := []
	for row: Array in [["fire_giant_move",6],["fire_giant_attack",4],["frost_veteran_move",6],["frost_veteran_attack",4],["frost_veteran_charge",4],["frost_veteran_shield",3],["wolf_berserker_move",6],["wolf_berserker_attack",4],["wolf_berserker_rage",3],["fire_giant_explosion",4]]:
		review.asset_id=row[0];review.frames=row[1]
		for i in int(row[1]):
			review.index=i;review.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var filename := "captures/%s_%02d.png"%[row[0],i]
			out.append({"file":filename,"save_error":root.get_texture().get_image().save_png("res://"+filename)})
	var file := FileAccess.open("res://captures/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"captures":out,"scope":"isolated asset rendering only; not Game scene"},"  "))
	quit()
