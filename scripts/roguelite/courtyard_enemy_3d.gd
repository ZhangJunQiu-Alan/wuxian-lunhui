extends Node3D
## 中庭里的 3D 敌人（尸鬼、冰霜精魂）：跟随 CourtFoe 的状态播放招式、转向、受击闪白和压扁，死后被击飞、倒地、风化消散。
## 模型和动作来自 assets/source/敌人3D/04_绑骨/（阶段 4），动作里的时间点在 Blender 里量过（见 05_接入/说明.md）。

const INK := preload("res://scripts/roguelite/courtyard_ink_actor.gdshader")
const XRAY := preload("res://scripts/roguelite/courtyard_actor_xray.gdshader")
const MODELS := {
	"draugr": preload("res://assets/models/enemies/draugr/draugr.glb"),
	"ice_spirit": preload("res://assets/models/enemies/ice_spirit/ice_spirit.glb"),
}
const MODEL_HEIGHT := 2.03  # 两个模型在 Blender 里头顶都在 2.03 m
const HEIGHTS := {"draugr": 1.62, "ice_spirit": 1.45}  # 世界单位；剑士 1.5
const LIFT := 0.25  # 精魂离地悬浮
const WALK_REFERENCE := 1.25  # 尸鬼走路原速下脚着地时的地面速度（Blender 里量的，m/s）
const TURN_RATE := 9.0
const BLEND := 0.15
const ICE := Color("#9ddff7")
## 一次性动作截取的片段：[起点 s, 终点 s, 播放速度]
const CLIPS := {
	"draugr": {
		"attack": [0.30, 1.95, 1.8],  # 0.3–0.6 回抽蓄力，0.95 起往前送，1.33 刺到最远，1.9 收回
		"sweep": [0.40, 1.75, 1.2],  # 0.4–1.0 把矛甩到左后方，1.07 低扫过正前方，1.5 矛尖落地
		"kneel": [0.30, 2.15, 1.85],  # 0.33–0.67 跪下，停到 1.53，2.07 站直；按 1.85 倍速正好 1 s
		"hit": [0.45, 1.25, 2.0],
		"death": [0.0, 3.0, 1.3],  # 1.83 倒地
	},
	"ice_spirit": {
		"cast": [0.50, 2.60, 2.0],  # 1.35 双手推出，按 2 倍速正好在聚能 0.45 s 后出手
		"hit": [0.05, 0.95, 2.0],
		"death": [0.0, 2.63, 1.4],  # 0.93 落地
	},
}
const THRUST_PEAK := 1.33  # 突刺动作里矛尖刺到最远的时刻
const LUNGE_START := 0.95  # 突刺动作里身体开始往前送的时刻，垫步从这里开始
const SWEEP_HIT := 1.067  # 横扫动作里矛扫过正前方的时刻
## 横扫是从左后方扫到右前方（-105° → +28°），出招时身体右转 20°，让扫过的扇形对准目标；扫过正前方时矛尖离身体 1.9 m
const SWEEP_YAW := 0.35
const SWEEP_TIP := 1.9
const CAST_RELEASE := 1.35  # 施法动作里双手推出的时刻
## 刺到最远时矛尖的位置（Blender 里逐帧量矛的顶点，模型米）：向前 2.26、向左 0.78、高 1.32。
## 突刺是斜着往左前方刺的，所以出招时身体右转 19°，让矛尖正对目标；矛尖离身体中心 2.39 m
const THRUST_TIP := Vector2(0.78, 2.26)
const THRUST_YAW := 0.3325  # atan(0.78 / 2.26)
const Game3D_SCALE := 0.01  # 2D 像素 → 3D 世界单位（和 fimbulwinter_courtyard_stage.SCALE 一致）
const SPEAR_RELEASE := 1.72  # 尸鬼死亡动作里快着地时松手
const LANDED := {"draugr": 1.83, "ice_spirit": 0.93}  # 死亡动作里身体砸到地面的时刻
const CORPSE_HOLD := 0.5  # 死亡动作播完后尸体停多久再开始风化
const WITHER_TIME := 0.4  # 先褪成墨灰
const DISSOLVE_TIME := 1.5  # 再从贴地处往上一块块化开，同时冒雪尘

static var spears_dropped := 0  # 测试用：一共有几只尸鬼松手掉了矛

var type_id := ""
var model: Node3D
var anim: AnimationPlayer
var materials: Array[ShaderMaterial] = []
var dying := false
var loose_spear: MeshInstance3D
var _scale := 1.0
var _yaw := 0.0
var _action := ""  # 正在播放的一次性动作
var _action_left := 0.0
var _last_position := Vector3.INF
var _velocity := Vector3.ZERO
var _foe_action := ""
var _was_kneeling := false
var _glow: MeshInstance3D
var _shards: Node3D
var _mist: CPUParticles3D
var _clock := randf() * 10.0


func setup(id: String, sun: DirectionalLight3D) -> void:
	type_id = id
	_scale = HEIGHTS[id] / MODEL_HEIGHT
	model = (MODELS[id] as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * _scale
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for loop: StringName in [&"idle", &"walk"]:
		if anim.has_animation(loop):
			anim.get_animation(loop).loop_mode = Animation.LOOP_LINEAR
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		_ink(mesh)
	for material in materials:
		material.set_shader_parameter("key_dir", sun.global_transform.basis.z)
	if id == "ice_spirit":
		model.position.y = LIFT
		_spirit_effects()
	anim.play(&"idle")
	anim.seek(randf() * anim.current_animation_length, true)  # 错开待机节奏


## 招式的时长、出手时刻和距离按动作来：动作里刺到最远、扫过正前方、双手推出的那一刻才判定
func configure(foe: CourtFoe) -> void:
	if type_id != "draugr":
		return
	var clip: Array = CLIPS.draugr.attack
	var thrust: Dictionary = foe.moves.thrust
	thrust.reach = THRUST_TIP.length() * _scale / Game3D_SCALE
	thrust.time = (clip[1] - clip[0]) / clip[2]
	thrust.strike = (THRUST_PEAK - clip[0]) / clip[2]
	thrust.lunge = Vector2((LUNGE_START - clip[0]) / clip[2], thrust.strike)
	clip = CLIPS.draugr.sweep
	foe.moves.sweep.time = (clip[1] - clip[0]) / clip[2]
	foe.moves.sweep.strike = (SWEEP_HIT - clip[0]) / clip[2]
	foe.moves.sweep.radius = SWEEP_TIP * _scale / Game3D_SCALE


func has_model() -> bool:
	return model != null


func head_height() -> float:
	return HEIGHTS[type_id] + (LIFT if type_id == "ice_spirit" else 0.0)


func _ink(mesh: MeshInstance3D) -> void:
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in mesh.mesh.get_surface_count():
		var source := mesh.mesh.surface_get_material(i) as BaseMaterial3D
		var ink := ShaderMaterial.new()
		ink.shader = INK
		if source and source.albedo_texture:
			ink.set_shader_parameter("albedo_tex", source.albedo_texture)
		else:
			ink.set_shader_parameter("use_texture", false)
		if type_id == "ice_spirit":  # 冰的身体：暗部不压那么深，轮廓透出冷光
			ink.set_shader_parameter("desaturate", 0.1)
			ink.set_shader_parameter("shade_color", Color(0.62, 0.72, 0.9))
			ink.set_shader_parameter("rim_glow", Color(0.55, 0.85, 1.0, 0.9))
		var xray := ShaderMaterial.new()
		xray.shader = XRAY
		xray.render_priority = 12
		ink.next_pass = xray
		mesh.set_surface_override_material(i, ink)
		materials.append(ink)


func sync(foe: CourtFoe, at: Vector3, delta: float) -> void:
	if dying:  # 2D 敌人在被删掉前的这一帧还会同步一次
		return
	_clock += delta
	var moved := Vector3.ZERO if _last_position == Vector3.INF else at - _last_position
	_last_position = at
	position = at
	# 2D 敌人按物理帧移动，画面帧更密时多数帧位移为 0，所以速度要按时间平滑
	if delta > 0.0:
		_velocity = _velocity.lerp(Vector3(moved.x, 0.0, moved.z) / delta, 1.0 - exp(-8.0 * delta))
	var velocity := _velocity
	var look := Vector2.ZERO
	if foe.action != "":
		look = foe.aim
	elif is_instance_valid(foe.target) and (foe.drift > 0.0 or foe.stagger > 0.0 or velocity.length() < 0.1):
		look = foe.global_position.direction_to(foe.target.global_position)  # 往后飘时也盯着玩家
	elif velocity.length() >= 0.1:
		look = Vector2(velocity.x, velocity.z)
	if look.length_squared() > 0.0001:
		var striking := _action == "attack" or _action == "sweep"
		var aim := atan2(look.x, look.y) + (THRUST_YAW if _action == "attack" else (SWEEP_YAW if _action == "sweep" else 0.0))
		_yaw = lerp_angle(_yaw, aim, 1.0 - exp(-TURN_RATE * (2.0 if striking else 1.0) * delta))
		rotation.y = _yaw

	_action_left -= delta * (0.0 if foe.is_frozen() else 1.0)
	if foe.action != _foe_action and foe.action != "":
		match foe.action:
			"thrust":
				_play(&"attack")
			"sweep":
				_play(&"sweep")
			_:  # 冰锥、冰刺都用施法动作，按出手时刻调速：双手推出的那一刻正好出手
				var clip: Array = CLIPS.ice_spirit.cast
				_play(&"cast", (CAST_RELEASE - clip[0]) / foe.moves[foe.action].strike)
	elif foe.kneeling and not _was_kneeling:
		_play(&"kneel")
		_action_left = CourtFoe.KNEEL_TIME
	elif _action_left <= 0.0 and not foe.kneeling:
		_action = ""
		var speed := velocity.length()
		if type_id == "draugr" and speed > 0.15:
			_loop(&"walk", clampf(speed / (WALK_REFERENCE * _scale), 0.5, 1.6))
		else:
			_loop(&"idle", 1.0)
	_foe_action = foe.action
	_was_kneeling = foe.kneeling
	anim.speed_scale = 0.0 if foe.is_frozen() else 1.0  # 被定住时动作也停住

	var squash := foe.hit_squash()  # 2D 的压扁回弹减半用在 3D 上
	var s := Vector2.ONE + (squash - Vector2.ONE) * 0.5
	model.scale = Vector3(s.x, s.y, s.x) * _scale
	var flash := foe.hit_flash()
	for material in materials:
		material.set_shader_parameter("flash", Color(1.0, 0.97, 0.92, flash * 0.85))
	if type_id == "ice_spirit":
		_animate_spirit(foe, velocity, delta)


## 受击：截取受击动作里最猛的一段快速播一遍；正在出招时不打断（霸体），只闪白
func react() -> void:
	if dying or _action in ["attack", "sweep", "cast", "kneel"]:
		return
	_play(&"hit")


func _play(action: StringName, speed := 0.0) -> void:
	var clip: Array = CLIPS[type_id][String(action)]
	speed = speed if speed > 0.0 else clip[2]
	_action = String(action)
	_action_left = (clip[1] - clip[0]) / speed
	var name := action if anim.has_animation(action) else ({&"sweep": &"attack", &"kneel": &"hit"} as Dictionary)[action] as StringName
	anim.play(name, BLEND * (1.0 if action in [&"sweep", &"kneel"] else 0.5), speed)
	anim.seek(clip[0], true)


func _loop(action: StringName, speed: float) -> void:
	anim.play(action, BLEND * 2.0, speed)  # 同一个动作再调 play 不会从头播，只更新速度


## 敌人死了，2D 节点马上就会被删掉；3D 模型留下来播完倒地，然后原地风化成雪尘消散
## （2026-11-21 和 Gemini、Codex 讨论后定的：不再往地下沉——地面是画出来的平面，往下移会被一刀切出硬直线）
func die(direction: Vector2, landing: Vector3) -> void:
	dying = true
	var flight := create_tween()  # 被一刀砍飞：先快后慢滑出去，和倒地动作一起播
	flight.tween_property(self, "position", landing, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if direction.length_squared() > 0.0001:  # 面朝砍过来的方向倒下
		_yaw = atan2(-direction.x, -direction.y)
		rotation.y = _yaw
	model.scale = Vector3.ONE * _scale
	for material in materials:
		material.set_shader_parameter("flash", Color(1.0, 0.97, 0.92, 0.0))
	var clip: Array = CLIPS[type_id]["death"]
	anim.play(&"death", 0.06, clip[2])
	anim.seek(clip[0], true)
	var fall: float = (clip[1] - clip[0]) / clip[2]
	var thud := create_tween()
	thud.tween_interval((LANDED[type_id] - clip[0]) / clip[2])
	thud.tween_callback(_snow_puff)
	var tween := create_tween()
	if type_id == "draugr":
		tween.tween_interval((SPEAR_RELEASE - clip[0]) / clip[2])
		tween.tween_callback(_drop_spear)
		tween.tween_interval(fall - (SPEAR_RELEASE - clip[0]) / clip[2])
	else:
		_spirit_death(fall)
		tween.tween_interval(fall)
	tween.tween_interval(CORPSE_HOLD)
	tween.tween_callback(_fade)


## 风化：褪成墨灰 → 噪声化开（着色器里 discard，仍按不透明物体画，不会有透明排序和自身叠影发黑）
func _fade() -> void:
	for material in materials:
		material.next_pass = null  # 化开时不要再透出被遮挡的剪影
	var dust := _corpse_particles(28, 0.9, 1.0)
	var tween := create_tween()
	tween.tween_method(_set_fade.bind("wither"), 0.0, 1.0, WITHER_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: dust.emitting = true)
	tween.tween_method(_set_fade.bind("dissolve"), 0.0, 1.0, DISSOLVE_TIME)
	tween.tween_callback(func() -> void: dust.emitting = false)
	tween.tween_interval(dust.lifetime)
	tween.tween_callback(queue_free)


func _set_fade(amount: float, parameter: String) -> void:
	for material in materials:
		material.set_shader_parameter(parameter, amount)


## 倒地那一下扬起一小团雪
func _snow_puff() -> void:
	var puff := _corpse_particles(12, 0.45, 0.5)
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.initial_velocity_min = 0.25
	puff.initial_velocity_max = 0.6
	puff.direction = Vector3(0, 0.6, 0)
	puff.spread = 80.0
	puff.emitting = true
	get_tree().create_timer(puff.lifetime + 0.1).timeout.connect(puff.queue_free)


## 沿着倒地的身体（向后倒，躯干在脚后方）铺一片柔边雪尘
func _corpse_particles(count: int, life: float, size: float) -> CPUParticles3D:
	var air := CPUParticles3D.new()
	air.emitting = false
	air.local_coords = false
	air.position = Vector3(0, 0.12, -0.3 if type_id == "draugr" else -0.2)
	air.amount = count
	air.lifetime = life
	air.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	air.emission_box_extents = Vector3(0.28, 0.08, 0.45)
	air.direction = Vector3(0.3, 1.0, 0.1)
	air.spread = 35.0
	air.gravity = Vector3(0.13, 0.07, 0.0)  # 和场景里篝火飘尘的风向一致
	air.initial_velocity_min = 0.08
	air.initial_velocity_max = 0.3
	air.scale_amount_min = 0.6
	air.scale_amount_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	air.color_ramp = fade
	var mote := QuadMesh.new()
	mote.size = Vector2.ONE * 0.16 * size
	var material := soft_material(Color(0.88, 0.93, 1.0, 0.8), false)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	mote.material = material
	air.mesh = mote
	add_child(air)
	return air


## 尸鬼松手：长矛从蒙皮的骨骼上换成一根独立的矛，翻倒平躺在地上，弹一下
func _drop_spear() -> void:
	var skinned := model.find_child("spear", true, false) as MeshInstance3D
	var skeleton := skinned.get_parent() as Skeleton3D if skinned else null
	if skeleton == null:
		return
	var bone := -1
	var bind := -1
	for i in skinned.skin.get_bind_count():
		if skinned.skin.get_bind_name(i).begins_with("spear"):
			bind = i
			bone = skeleton.find_bone(skinned.skin.get_bind_name(i))
	if bone < 0:
		return
	var start := skeleton.global_transform * skeleton.get_bone_global_pose(bone) * skinned.skin.get_bind_pose(bind)
	skinned.hide()
	spears_dropped += 1
	loose_spear = MeshInstance3D.new()
	loose_spear.name = "LooseSpear"
	loose_spear.mesh = skinned.mesh
	loose_spear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in skinned.mesh.get_surface_count():
		loose_spear.set_surface_override_material(i, skinned.get_surface_override_material(i))
	add_child(loose_spear)
	loose_spear.global_transform = start
	# 矛杆方向（骨骼 +Y）放平，矛的中点落到地面上方一点
	var shaft := (start.basis * skinned.skin.get_bind_pose(bind).basis.inverse() * Vector3.UP).normalized()
	var flat := Vector3(shaft.x, 0.0, shaft.z)
	if flat.length_squared() < 0.01:
		flat = global_transform.basis.x
	flat = flat.normalized()
	var turn := Quaternion(shaft, flat)
	var center := _mesh_center(loose_spear)
	var rest := Transform3D(Basis(turn) * start.basis, Vector3.ZERO)
	var rest_center := rest * loose_spear.mesh.get_aabb().get_center()
	rest.origin = Vector3(center.x, global_position.y + 0.035, center.z) - rest_center + flat * 0.12
	var top := loose_spear.transform
	var landed := global_transform.affine_inverse() * rest
	var bounce := landed
	bounce.origin.y += 0.06
	var tween := loose_spear.create_tween()
	tween.tween_method(func(k: float) -> void: loose_spear.transform = top.interpolate_with(landed, k), 0.0, 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: Audio.sfx("enemy_hit", -14.0))
	tween.tween_property(loose_spear, "transform", bounce, 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(loose_spear, "transform", landed, 0.1).set_ease(Tween.EASE_IN)


func _mesh_center(mesh: MeshInstance3D) -> Vector3:
	return mesh.global_transform * mesh.mesh.get_aabb().get_center()


# ———— 冰霜精魂：胸口冰光、身边的碎冰、冰尾下的雪雾 ————

func _spirit_effects() -> void:
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var chest := BoneAttachment3D.new()
	chest.bone_name = "mixamorig_Spine2"
	skeleton.add_child(chest)
	_glow = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.42 / (_scale * skeleton.get_parent_node_3d().scale.x)  # 挂在缩放过的骨架下
	_glow.mesh = quad
	var glow := soft_material(Color(0.6, 0.88, 1.0, 0.75), true)
	glow.billboard_keep_scale = true  # 不然公告板会丢掉骨架的缩放，变得满屏大
	_glow.material_override = glow
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chest.add_child(_glow)

	_shards = Node3D.new()
	_shards.position.y = LIFT + 0.95
	add_child(_shards)
	for i in 4:
		var shard := MeshInstance3D.new()
		var prism := CylinderMesh.new()
		prism.top_radius = 0.0
		prism.bottom_radius = 0.028
		prism.height = 0.15 + 0.04 * (i % 2)
		prism.radial_segments = 4
		prism.rings = 1
		shard.mesh = prism
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.25, 1.55, 1.8) if i % 2 else Color(0.85, 1.1, 1.35)
		shard.material_override = material
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shards.add_child(shard)

	_mist = CPUParticles3D.new()  # 冰尾下面贴地的一层淡雪雾，向四周慢慢散开
	_mist.position.y = 0.06
	_mist.amount = 10
	_mist.lifetime = 2.4
	_mist.preprocess = 2.4
	_mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_mist.emission_box_extents = Vector3(0.32, 0.02, 0.32)
	_mist.direction = Vector3(0, 0.25, 0)
	_mist.spread = 180.0
	_mist.gravity = Vector3(0.05, 0.03, 0.0)
	_mist.initial_velocity_min = 0.05
	_mist.initial_velocity_max = 0.16
	var curve := Curve.new()  # 慢慢鼓起再收掉（不用颜色渐变：粒子顶点色在这里会把雪雾染成黑团）
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.35, 0.85))
	curve.add_point(Vector2(0.7, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	_mist.scale_amount_curve = curve
	var puff := QuadMesh.new()
	puff.size = Vector2.ONE * 0.55
	var haze := soft_material(Color(0.84, 0.93, 1.0, 0.14), false)
	haze.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff.material = haze
	_mist.mesh = puff
	add_child(_mist)


func _animate_spirit(foe: CourtFoe, velocity: Vector3, delta: float) -> void:
	model.position.y = LIFT + sin(_clock * 2.2) * 0.04
	var lean := clampf(velocity.length() * 0.18, 0.0, 0.2)  # 飘动时身子往前倾，往后飘时往后仰
	if foe.drift > 0.0:
		lean = -0.3
	model.rotation.x = lerpf(model.rotation.x, lean, 1.0 - exp(-6.0 * delta))
	_mist.initial_velocity_max = 0.5 if foe.drift > 0.0 else 0.16
	var charge := foe.charge() if not foe._struck else 0.0
	var pulse := 1.0 + 0.12 * sin(_clock * 5.0) + charge * 0.7  # 聚能时胸口的冰光变大变亮
	_glow.scale = Vector3.ONE * pulse
	(_glow.material_override as StandardMaterial3D).albedo_color = Color(0.6, 0.88, 1.0, 0.5 + 0.3 * charge)
	_shards.rotation.y += delta * (1.1 + charge * 6.0)
	var radius := 0.42 - charge * 0.18
	for i in _shards.get_child_count():
		var shard := _shards.get_child(i) as Node3D
		var angle := TAU * i / _shards.get_child_count()
		shard.position = Vector3(cos(angle) * radius, sin(_clock * 1.7 + i * 1.9) * 0.08, sin(angle) * radius)
		shard.rotation = Vector3(0.5 + 0.3 * sin(_clock + i), _clock * 0.6 + i, 0.35)


## 精魂倒下：碎冰炸开、雪雾一下涌出来，身子边落边沉到地面
func _spirit_death(fall: float) -> void:
	_mist.amount = 16
	_mist.initial_velocity_max = 0.45
	var tween := create_tween().set_parallel(true)
	tween.tween_property(model, "position:y", 0.0, fall * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(model, "rotation:x", 0.0, 0.2)
	tween.tween_property(_glow, "scale", Vector3.ONE * 2.0, 0.12)
	tween.chain().tween_property(_glow, "scale", Vector3.ZERO, 0.4)
	for shard: Node3D in _shards.get_children():
		var out := shard.position.normalized() * 0.9 + Vector3(0, -0.85, 0)
		tween.tween_property(shard, "position", shard.position + out, 0.45).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "scale", Vector3.ZERO, 0.5).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void: _mist.emitting = false)


## 柔边圆点（雪雾、冰光、冰棱尾迹共用）
static func soft_material(color: Color, additive: bool) -> StandardMaterial3D:
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	var falloff := Gradient.new()
	falloff.set_color(0, Color.WHITE)
	falloff.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = falloff
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = dot
	material.albedo_color = color
	material.no_depth_test = additive
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return material
