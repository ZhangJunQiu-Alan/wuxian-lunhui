extends Node2D

const FONTSIZE = 21
const PLAYER = Vector2(453, 365)
const TARGETS = [Vector2(540, 365), Vector2(615, 365), Vector2(666, 401)]
const GROUNDS = [
	"sprites/ground/midgard/snow_trampled.png",
	"sprites/ground/helheim/fog_ground.png",
	"sprites/ground/vigrid/scorched_01.png"]
const BG = [Color("#d4dbe0"), Color("#a2b4b9"), Color("#b5a8aa")]
const ACCENT = Color("#8ad7c1")
const STILL_TIMES = [1.13, 1.61, 2.88, 0.99, 1.73, 1.83, 4.20, 5.84, 5.3, 1.74, 3.73]

var batch: String
var asset_root: String
var data: Dictionary
var reels: Array
var fx: Dictionary
var cache: Dictionary
var stage := 0
var selected_stage := -1
var frame := 0
var time := 0.0
var capture := false
var still_dir := ""
var frames_dir := ""
var drawn_frame := -1
var stills: Dictionary
var scene_t := 0.0
var cue: Dictionary
var cue_age := 0.0
var current_sound := ""
var audio: AudioStreamPlayer
var spin_audio: AudioStreamPlayer

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var args := OS.get_cmdline_user_args()
	batch = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var i := args.find("--batch")
	if i >= 0:
		batch = args[i + 1]
	asset_root = batch.path_join("../..").simplify_path()
	data = JSON.parse_string(FileAccess.get_file_as_string(batch.path_join("manifest.json")))
	reels = JSON.parse_string(FileAccess.get_file_as_string("res://timelines.json"))
	capture = args.has("--record")
	if capture:
		get_tree().auto_accept_quit = false
	var single := args.find("--weapon")
	if single>=0 and single+1<args.size():
		for index in range(reels.size()):
			if reels[index].id==args[single+1]:
				selected_stage = index
				reels = [reels[index]]
				break
		if selected_stage<0:
			push_error("Unknown preview weapon: "+args[single+1])
			get_tree().quit(1)
			return
	var sequence := args.find("--frames")
	if sequence>=0 and sequence+1<args.size():
		frames_dir = args[sequence+1]
	var output := args.find("--stills")
	if output >= 0:
		still_dir = args[output+1]
	if capture and frames_dir.is_empty():
		RenderingServer.frame_post_draw.connect(record_frame)
	elif not capture and not still_dir.is_empty():
		RenderingServer.frame_post_draw.connect(save_still)
	audio = AudioStreamPlayer.new()
	add_child(audio)
	spin_audio = AudioStreamPlayer.new()
	add_child(spin_audio)
	for e in data.effects:
		fx[e.id] = e
	for a in data.actions:
		texture("sprites/characters/swordsman_bare_%s.png" % a)
	for p in GROUNDS:
		texture(p)
	if capture:
		print("S-SW recording begins. Runtime never opens save or settings files.")

func _input(e: InputEvent) -> void:
	if capture:
		return
	if e.is_action_pressed("ui_right"):
		stage = (stage + 1) % reels.size()
		time = 0
		current_sound = ""
	if e.is_action_pressed("ui_left"):
		stage = (stage + reels.size() - 1) % reels.size()
		time = 0
		current_sound = ""

func _process(delta: float) -> void:
	if capture:
		time = frame / 24.0
		stage = 0
		for r in reels:
			if time < float(r.seconds):
				break
			time -= float(r.seconds)
			stage += 1
		if stage == reels.size():
			print("S-SW cue sequence completed.")
			get_tree().quit()
			return
	else:
		time = fmod(time + delta, float(reels[stage].seconds))
	var item: Dictionary = reels[stage]
	scene_t = time
	cue = item.cues[0]
	for next in item.cues:
		if time + 0.0001 >= float(next.start):
			cue = next
	cue_age = time - float(cue.start)
	var sound_key := str(stage) + "/" + str(cue.start)
	if current_sound != sound_key:
		current_sound = sound_key
		if cue.has("sound"):
			play_sound(cue.sound)
		if not cue.get("spin", false) and spin_audio.playing:
			spin_audio.stop()
	queue_redraw()
	if capture and not frames_dir.is_empty():
		render_capture.call_deferred()

func render_capture() -> void:
	if drawn_frame!=frame:
		return
	RenderingServer.force_draw(true)
	record_frame()

func record_frame() -> void:
	if drawn_frame!=frame:
		return
	if not frames_dir.is_empty():
		var image := get_viewport().get_texture().get_image()
		if image.save_png(frames_dir.path_join("%05d.png" % frame)) != OK:
			push_error("Could not save Godot frame %d" % frame)
			get_tree().quit(1)
			return
	if not still_dir.is_empty():
		save_still()
	frame += 1

func save_still() -> void:
	if stage>=reels.size() or stills.has(stage) or scene_t<float(STILL_TIMES[selected_stage if selected_stage>=0 else stage]):
		return
	stills[stage] = true
	var im := get_viewport().get_texture().get_image()
	if im.save_png(still_dir.path_join(str(reels[stage].id)+".png")) != OK:
		push_error("Could not save 1x screenshot: "+str(reels[stage].id))

func play_sound(id: String) -> void:
	var src := AudioStreamWAV.load_from_file(asset_root.path_join("audio/sfx/"+id+".wav"))
	if src:
		if id == "qinglong_spin_loop":
			src.loop_mode = AudioStreamWAV.LOOP_FORWARD
			src.loop_end = round(1.2 * 44100.0)
			spin_audio.stream = src
			spin_audio.play()
		else:
			audio.stream = src
			audio.play()

func texture(path: String) -> Texture2D:
	if not cache.has(path):
		var im := Image.load_from_file(asset_root.path_join(path))
		if im == null or im.is_empty():
			push_error("Could not read: " + path)
			return null
		cache[path] = ImageTexture.create_from_image(im)
	return cache[path]

func vec(v: Array) -> Vector2:
	return Vector2(float(v[0]), float(v[1]))

func pos(v: Dictionary) -> Vector2:
	return Vector2(float(v.x), float(v.y))

func part(ref: Dictionary, sock: Dictionary, center: Vector2) -> void:
	var tex := texture("sprites/weapons/" + str(ref.file))
	if not tex:
		return
	var grip := vec(ref.grip)
	var deg := deg_to_rad(float(sock.get("deg", 0)) - float(ref.get("base_deg", 0)))
	draw_set_transform(center+pos(sock)+Vector2(0.5,0.5), deg)
	var size := Vector2(float(ref.get("clip",tex.get_width())),tex.get_height())
	draw_texture_rect_region(tex,Rect2(-grip-Vector2(0.5,0.5),size),Rect2(Vector2.ZERO,size))
	draw_set_transform(Vector2.ZERO)

func effect(id: String, center: Vector2, age: float, force_loop := false, tile_length := 0.0, cap := "", rate := 1.0) -> void:
	if id.is_empty() or not fx.has(id) or age < 0:
		return
	var e: Dictionary = fx[id]
	var n := floori(age * float(e.fps) * rate)
	if e.play == "phased":
		if age > 3.4:
			n = 6 + mini(1,floori((age-3.4)*16))
		elif n > 1:
			n = 2 + (n - 2) % 4
	elif force_loop or e.play == "loop":
		n %= int(e.frames)
	elif n >= int(e.frames):
		return
	var tex := texture(e.file)
	if not tex:
		return
	var sz := vec(e.size)
	var dst := center - vec(e.anchor)
	var src := Rect2(Vector2(n * sz.x,0),sz)
	if tile_length > 0:
		for x in range(0,int(tile_length),int(sz.x)-1):
			var width := minf(sz.x, tile_length-x)
			draw_texture_rect_region(tex,Rect2(dst+Vector2(x,0),Vector2(width,sz.y)),Rect2(src.position,Vector2(width,sz.y)))
		if not cap.is_empty():
			effect(cap,center+Vector2(tile_length-6,0),age)
			draw_set_transform(center+Vector2(6,0),0,Vector2(-1,1))
			effect(cap,Vector2.ZERO,age)
			draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect_region(tex,Rect2(dst,sz),src)

func shifted(point: Dictionary, adjustment: Dictionary) -> Dictionary:
	var result := point.duplicate()
	result.merge(adjustment,true)
	result.x = float(result.x)+float(result.get("dx",0))
	result.y = float(result.y)+float(result.get("dy",0))
	return result

func waist_frame(action: String, n: int) -> Dictionary:
	var frames: Array = data.waistFrames.get(action,[])
	return frames[n] if n<frames.size() else {}

func stow_point(w: Dictionary, sockets: Dictionary, action: String, n: int) -> Dictionary:
	var sock: Dictionary = sockets[w.stow].duplicate()
	if w.has("sheath_file"):
		sock.merge(waist_frame(action,n).get("hip",{}),true)
	return shifted(sock,w.get("stow_socket_adjust",{}))

func off_point(w: Dictionary, sockets: Dictionary, action: String) -> Dictionary:
	return shifted(sockets.off,w.get("off_idle_adjust",{}) if action in ["idle","move"] else {})

func held_refs(w: Dictionary, sockets: Dictionary, action: String, n: int, active: Dictionary, hand: Dictionary) -> Array:
	var out: Array = []
	var main: Dictionary = shifted(sockets.main,w.get("idle_main_adjust",{}) if action=="idle" else {})
	if w.has("flight_px") and active.get("flight",false):
		var phase: float = [0.0,.52,1.0,.77,.36,0.0][n]
		var reach := float(w.flight_px)-float(hand.tip[0])+float(hand.grip[0])
		main.x = lerpf(float(main.x),32.0+reach,phase)
		main.y = lerpf(float(main.y),31.0,phase)
		main.deg = 0.0 if n<3 else 180.0
		main.z = "front"
	if active.get("spin",false):
		main.deg = fposmod(cue_age * (250 + cue_age * 90) * float(active.get("speed",1.0)),360.0)
		main.z = "back" if float(main.deg)>180 else "front"
	var feed = waist_frame(action,n).get("feed_px") if w.has("sheath_file") else null
	if feed!=null:
		main = stow_point(w,sockets,action,n)
		var angle := deg_to_rad(float(main.deg))
		main.x = float(main.x)-float(feed)*cos(angle)
		main.y = float(main.y)-float(feed)*sin(angle)
		hand = hand.duplicate()
		hand.clip = minf(float(hand.tip[0])+1,float(hand.grip[0])+float(feed)+1)
	if not hand.is_empty():
		out.append([hand,main,2 if main.z=="back" else 4])
	if w.id == "zhuxian":
		var idx := 0
		for v in w.variants.values():
			if v.file == hand.file:
				continue
			var offset := vec(w.reserve_offsets[idx])
			var sock: Dictionary = sockets.back.duplicate()
			sock.x = float(sock.x)+offset.x
			sock.y = float(sock.y)+offset.y
			sock.deg = -90
			out.append([v,sock,1])
			idx += 1
	if w.id == "riyue":
		out.append([w.variants.sun if active.get("variant","sun") == "moon" else w.variants.moon,off_point(w,sockets,action),2])
	elif w.has("off") and not active.get("hide_off",false):
		out.append([w.off,off_point(w,sockets,action),4 if action=="off_attack" else 2])
	if active.get("glow",false) and hand.has("glow"):
		var g := hand.duplicate()
		g.file = hand.glow
		out.append([g,main,5])
	return out

func character(w: Dictionary, action: String, n: int, at: Vector2, active: Dictionary) -> void:
	var stationary: bool = w.has("flight_px") and active.get("flight",false)
	var sockets: Dictionary = data.sockets.idle[0] if stationary else data.sockets[action][n]
	var lay: Array = []
	var visible: bool = sockets.mode!="none"
	var holding: bool = (w.idle_hold=="held" or sockets.mode=="held") and visible
	if visible and w.has("stow_file") and (not holding or w.has("sheath_file")):
		var sock := stow_point(w,sockets,action,n)
		var file: String = w.sheath_file if holding else w.stow_file
		lay.append([{"file":file,"grip":w.stow_grip,"base_deg":w.stow_base_deg},sock,4 if sock.z=="front" else 1])
		if not holding and w.has("stow_keeper"):
			lay.append([{"file":w.stow_keeper,"grip":w.stow_grip,"base_deg":w.stow_base_deg},sock,4])
		if not holding and active.get("glow",false) and w.has("stow_glow"):
			lay.append([{"file":w.stow_glow,"grip":w.stow_grip,"base_deg":w.stow_base_deg},sock,5])
	if holding:
		var hand: Dictionary = w.get("main", {})
		if w.has("variants"):
			var v: Dictionary = w.variants
			hand = v.get(active.get("variant",""),hand if not hand.is_empty() else v.values()[0])
		lay.append_array(held_refs(w,sockets,action,n,active,hand))
	if visible and w.has("props"):
		var gourd: Dictionary = w.props.gourd
		var g: Dictionary = sockets.off if action=="drink" else shifted(sockets.hip,gourd.hip_adjust)
		if action!="drink":
			g.deg = 0
		lay.append([gourd,g,4])
	var origin := at.round()-Vector2(32,32)
	for z in [1,2]:
		for ref in lay:
			if ref[2]==z:
				part(ref[0],ref[1],origin)
	var body_file: String = data.actions.idle.file if stationary else data.actions[action].file
	if w.has("sheath_file"):
		body_file = data.waistBodies.get(action,body_file)
	var tex := texture(body_file.trim_prefix("../../"))
	draw_texture_rect_region(tex,Rect2(origin,Vector2(64,64)),Rect2(Vector2(0 if stationary else n*64,0),Vector2(64,64)))
	for z in [4,5]:
		for ref in lay:
			if ref[2]==z:
				part(ref[0],ref[1],origin)
	if active.get("horns",false):
		effect("higekiri_oni_horns",origin+pos(sockets.head),cue_age,true)
	if active.has("overlay"):
		var id: String = active.overlay
		effect(id,origin+pos(sockets.head) if fx[id].layer==6 else at,cue_age,true)

func enemy(target: Vector2, i: int, hit := false) -> void:
	var tex := texture("sprites/enemies/draugr_move.png")
	if tex:
		var n := (floori(scene_t*8)+i)%int(tex.get_width()/64.0)
		var tint := Color("#fae7bf") if hit else Color("#bac2be")
		draw_texture_rect_region(tex,Rect2(target-Vector2(32,32),Vector2(64,64)),Rect2(Vector2(n*64,0),Vector2(64,64)),tint)

func _draw() -> void:
	if cue.is_empty() or stage>=reels.size():
		return
	drawn_frame = frame
	var r: Dictionary = reels[stage]
	var w: Dictionary = data.weapons[r.id]
	var ground := texture(GROUNDS[int(r.stage)])
	draw_texture_rect(ground,Rect2(0,0,1280,720),true,BG[int(r.stage)])
	draw_rect(Rect2(0,0,1280,117),Color("#101922"))
	draw_rect(Rect2(0,634,1280,86),Color("#101922"))
	draw_rect(Rect2(0,117,1280,1),Color("#4e6370"))
	draw_rect(Rect2(0,634,1280,1),Color("#4e6370"))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(38,34),"EMBER OF WORLDS   /   S–SW WEAPON LAB",HORIZONTAL_ALIGNMENT_LEFT,-1,16,ACCENT)
	draw_string(font,Vector2(38,87),r.title,HORIZONTAL_ALIGNMENT_LEFT,-1,36,Color("#edf4fa"))
	var label := "%02d / 11    |    1x PIXEL SCALE" % [(selected_stage if selected_stage>=0 else stage)+1]
	draw_string(font,Vector2(987,74),label,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("#c6d6de"))
	draw_string(font,Vector2(38,677),cue.text,HORIZONTAL_ALIGNMENT_LEFT,-1,FONTSIZE,Color("#edf4fa"))
	draw_string(font,Vector2(974,677),"ISOLATED GODOT ART PREVIEW",HORIZONTAL_ALIGNMENT_LEFT,-1,16,ACCENT)
	draw_rect(Rect2(38,692,1204,3),Color("#35434a"))
	draw_rect(Rect2(38,692,1204*scene_t/float(r.seconds),3),ACCENT)
	var icon := texture("sprites/weapons/" + str(w.icon))
	draw_texture(icon,Vector2(1193,23))
	var action: String = cue.action
	var live := cue_age <= float(cue.length)
	if not live:
		action = "idle"
	var tick := floori(cue_age * float(data.actions[action].fps) * float(cue.get("speed",1)))
	var count := int(data.actions[action].frames)
	var n := tick % count if action in ["idle","move","spin","iai_stance"] else mini(tick,count-1)
	var at := PLAYER
	var effect_origin := at
	if cue.has("shift"):
		at.x += float(cue.shift)
	if cue.has("dash"):
		at.x += float(cue.dash)*clampf(cue_age/float(cue.length),0.0,1.0)
	var targets: Array = TARGETS.duplicate()
	if r.id=="monohoshizao":
		targets = [PLAYER+Vector2(85,0),PLAYER+Vector2(161,0)]
	elif r.id=="zhuxian":
		targets = [PLAYER+Vector2(72,8),PLAYER+Vector2(99,-2),PLAYER+Vector2(141,35)]
	if cue.get("move_target",false):
		targets[1] = PLAYER+Vector2(95+clampf(cue_age*13,0,30),-17)
	for i in range(targets.size()):
		enemy(targets[i],i,live and (cue.get("focus",-1)==i or i==1 and cue.has("secondary")))
	if cue.has("ranges"):
		for radius in cue.ranges:
			draw_arc(PLAYER,float(radius),-PI/4,PI/4,36,Color("#83a1a9"),1)
		if cue.has("focus") and live:
			draw_string(font,targets[int(cue.focus)]-Vector2(17,35),cue.damage,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#ffe4a4"))
	if cue.get("charge",false):
		draw_rect(Rect2(PLAYER+Vector2(-23,-49),Vector2(46,4)),Color("#274251"))
		draw_rect(Rect2(PLAYER+Vector2(-23,-49),Vector2(46*minf(1,cue_age/4.0),4)),Color("#ffe08a"))
	if cue.has("tipsy"):
		var gourd := texture("sprites/ui/weapons/swordsman/chunyang_gourd_%d.png" % int(cue.tipsy))
		draw_texture(gourd,at+Vector2(-6,-51))
	var projectile: String = cue.get("projectile","")
	var planted := PLAYER+Vector2(209,-4)
	var active := cue.duplicate()
	active.flight = live and cue.get("flight",false)
	var release_at := 2.0/16.0
	var flying_out := projectile=="out" and live and cue_age>=release_at
	var flying_back := projectile=="return" and live
	active.hide_off = flying_out or flying_back or projectile=="plant"
	if flying_out or flying_back:
		var origin := at.round()-Vector2(32,32)
		var release := origin+pos(data.sockets.throw[2].off)
		var receive := off_point(w,data.sockets.idle[n % data.sockets.idle.size()],"idle")
		var grip_target := origin+pos(receive)
		var phase := clampf((cue_age-release_at)/(float(cue.length)-release_at),0,1) if flying_out else clampf(cue_age/float(cue.length),0,1)
		var planted_grip := planted-(vec(w.off.tip)-vec(w.off.grip)).rotated(PI/2)
		var p := release.lerp(planted_grip,phase) if flying_out else planted_grip.lerp(grip_target,phase)
		var angle := lerpf(float(data.sockets.throw[2].off.deg),90.0,phase) if flying_out else lerpf(90.0,float(receive.deg),phase)
		part(w.off,{"x":0,"y":0,"deg":angle},p)
		effect("moye_trail",p+Vector2(-39 if flying_out else 10,0),cue_age,true)
	elif projectile == "plant":
		part(w.planted,{"x":0,"y":0,"deg":0},planted)
		effect("moye_planted_ring",planted,cue_age,true)
		effect("ganjiang_link",at+Vector2(9,0),cue_age,true,194)
	elif projectile == "qi":
		effect("chunyang_qi",effect_origin+Vector2(clampf(cue_age/.74,0,1)*260,0),cue_age,true)
	character(w,action,n,at,active)
	if not cue.fx.is_empty() and projectile.is_empty() and live:
		var o := effect_origin
		if cue.fx == "excalibur_charge_full":
			o = at.round()-Vector2(32,32)+pos(stow_point(w,data.sockets[action][n],action,n))
		elif cue.fx == "chunyang_drink":
			o = at+Vector2(8,-11)
		elif cue.fx == "chunyang_dodge":
			o = at+Vector2(0,24)
		var span := float(cue.get("tile",0))
		if cue.fx == "excalibur_dash_trail":
			span = clampf(at.x-effect_origin.x,0.0,300.0)
		effect(cue.fx,o,cue_age-float(cue.get("delay",0)),cue.get("spin",false),span,cue.get("cap",""),float(cue.get("speed",1)))
	if cue.has("secondary") and live:
		var p: Vector2 = targets[int(cue.get("focus",1))]
		var et := cue_age-.11
		if cue.get("move_target",false):
			et = fmod(cue_age,.86)
		effect(cue.secondary,p,et)
