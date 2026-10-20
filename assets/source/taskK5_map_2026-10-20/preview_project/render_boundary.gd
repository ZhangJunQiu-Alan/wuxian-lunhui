extends SceneTree

class View extends Node2D:
	var tex: Texture2D
	var phase := 0
	var points := PackedVector2Array()
	var normals := PackedVector2Array()
	func _ready() -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		tex=ImageTexture.create_from_image(Image.load_from_file("res://inputs/firewall.png"))
		var corners := [Vector2(584,136),Vector2(584,344),Vector2(184,344),Vector2(184,136)]
		for c in 4:
			for j in 25:
				var angle := (-PI/2+c*PI/2)+j*PI/48
				var normal := Vector2.from_angle(angle)
				points.append(corners[c]+normal*64)
				normals.append(normal)
	func _draw() -> void:
		if tex==null:return
		var distance := 0.0
		for i in points.size():
			var j := (i+1)%points.size()
			var a := points[i];var b := points[j]
			var length := a.distance_to(b)
			var pieces := maxi(1,ceili(length/8))
			for k in pieces:
				var f0 := float(k)/pieces;var f1 := float(k+1)/pieces
				var p0 := a.lerp(b,f0);var p1 := a.lerp(b,f1)
				var n0 := normals[i].lerp(normals[j],f0).normalized();var n1 := normals[i].lerp(normals[j],f1).normalized()
				var u0 := pingpong((distance+length*f0)/64,1.0);var u1 := pingpong((distance+length*f1)/64,1.0)
				var uv := PackedVector2Array([Vector2((phase+u0)/4,0),Vector2((phase+u1)/4,0),Vector2((phase+u1)/4,1),Vector2((phase+u0)/4,1)])
				draw_polygon(PackedVector2Array([p0+n0*32,p1+n1*32,p1-n1*32,p0-n0*32]),PackedColorArray([Color.WHITE]),uv,tex)
			distance+=length
var view: View
func _initialize() -> void:
	root.size=Vector2i(768,480);root.transparent_bg=true
	view=View.new();root.add_child.call_deferred(view);run.call_deferred()
func run() -> void:
	await process_frame
	await process_frame
	root.size=Vector2i(768,480);root.content_scale_size=Vector2i(768,480)
	await process_frame
	await process_frame
	var results := []
	for i in 4:
		view.phase=i;view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "captures/boundary_%02d.png"%i
		results.append({"file":path,"save_error":root.get_texture().get_image().save_png("res://"+path)})
	var f := FileAccess.open("res://captures/boundary_result.json",FileAccess.WRITE);f.store_string(JSON.stringify(results,"  "));quit()
