extends SceneTree

class View extends Node2D:
	var textures := {}
	var phase := 0

	func _ready() -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		for id: String in ["vidar_pry","freyr_heal","fire_attack","frost_attack","sword_arc","heal_field"]:
			var img := Image.load_from_file("res://inputs/"+id+".png")
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x,y)
					if c.a>0:img.set_pixel(x,y,Color.from_hsv(0.07,minf(c.s,0.18),c.v,c.a))
			textures[id]=ImageTexture.create_from_image(img)

	func actor(id: String,n: int,i: int,pos: Vector2,mirror: bool=false) -> void:
		var t: Texture2D=textures[id]
		var size := Vector2(t.get_width()/n,t.get_height())
		draw_set_transform(pos,0,Vector2(-0.5 if mirror else 0.5,0.5))
		draw_texture_rect_region(t,Rect2(Vector2(-size.x/2,-size.y+2),size),Rect2(Vector2(i*size.x,0),size),Color(0.75,0.70,0.63,0.82))
		draw_set_transform(Vector2.ZERO)

	func _draw() -> void:
		if textures.is_empty():return
		actor("vidar_pry",6,[0,1,2,5][phase],Vector2(65,101))
		actor("fire_attack",4,phase,Vector2(116,101),true)
		actor("freyr_heal",4,phase,Vector2(237,92))
		actor("heal_field",1,0,Vector2(237,111))
		actor("frost_attack",4,phase,Vector2(291,100),true)
		actor("vidar_pry",6,[0,1,2,5][phase],Vector2(407,113))
		actor("fire_attack",4,phase,Vector2(459,113),true)
		actor("sword_arc",4,phase,Vector2(89,81))

var view: View

func _initialize() -> void:
	root.size=Vector2i(512,128);root.transparent_bg=true
	view=View.new();root.add_child.call_deferred(view)
	run.call_deferred()

func run() -> void:
	await process_frame
	await process_frame
	var out := []
	for i in 4:
		view.phase=i;view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var filename := "captures/distant_%02d.png"%i
		out.append({"file":filename,"save_error":root.get_texture().get_image().save_png("res://"+filename)})
	var file := FileAccess.open("res://captures/distant_result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(out,"  "))
	quit()
