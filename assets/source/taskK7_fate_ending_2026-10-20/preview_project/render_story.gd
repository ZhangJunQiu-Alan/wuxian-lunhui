extends SceneTree
var data: Dictionary
var font: FontFile
var panel: Control
var body: Label
var head: Label
var foot: Label
func _initialize() -> void:
	data=JSON.parse_string(FileAccess.get_file_as_string("res://inputs/ending_timeline.json"))
	font=FontFile.new();font.load_dynamic_font("res://inputs/font.otf")
	panel=Control.new();root.add_child.call_deferred(panel);run.call_deferred()
func label_at(text: String,rect: Rect2,size: int,color: Color) -> Label:
	var l := Label.new();l.text=text;l.position=rect.position;l.size=rect.size;l.add_theme_font_override("font",font);l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;panel.add_child(l);return l
func setup(s: Vector2i) -> void:
	for c in panel.get_children():c.queue_free()
	var bg := ColorRect.new();bg.color=Color(0.02,0.03,0.05,1);bg.size=s;panel.add_child(bg)
	head=label_at("诸神黄昏 · 篇章结局",Rect2(40,40,s.x-80,60),24,Color(0.85,0.72,0.44))
	body=label_at("",Rect2(80,s.y*.28,s.x-160,s.y*.40),28 if s.x==1280 else 24,Color(0.86,0.8,0.66))
	foot=label_at("",Rect2(40,s.y-120,s.x-80,30),18,Color(0.50,0.55,0.62))
	label_at("继续    /    跳过演出",Rect2(40,s.y-80,s.x-80,40),18,Color(0.7,0.8,0.85))
func run() -> void:
	await process_frame
	await process_frame
	var rows := []
	for size: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size=size;root.content_scale_size=size;setup(size)
		await process_frame
		await process_frame
		for i in 5:
			body.text=data.beats[i].text;foot.text="分镜 %d / 5 · 独立文字预览，正式游戏未接入"%(i+1)
			await process_frame
			await RenderingServer.frame_post_draw
			var path := "captures/story_%dx%d_%02d.png"%[size.x,size.y,i]
			var img := root.get_texture().get_image()
			var missing := []
			for j in body.text.length():
				var code := body.text.unicode_at(j)
				if code>32 and not font.has_char(code):missing.append(code)
			rows.append({"file":path,"save_error":img.save_png("res://"+path),"actual_width":img.get_width(),"actual_height":img.get_height(),"lines":body.get_line_count(),"line_height":font.get_height(body.get_theme_font_size("font_size")),"body_rect_height":body.size.y,"missing_characters":missing})
	var file := FileAccess.open("res://captures/result.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"  "));quit()
