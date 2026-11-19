extends Node3D
## 中庭里的 3D 剑士：跟随 2D 玩家的状态播放动作、转向，受击闪色，被遮挡时透出剪影。
## 模型和动作来自 assets/source/characters/swordsman_3d/04_绑骨/（阶段 4）。

const MODEL := preload("res://assets/models/characters/swordsman/swordsman.glb")
const INK := preload("res://scripts/roguelite/courtyard_ink_actor.gdshader")
const XRAY := preload("res://scripts/roguelite/courtyard_actor_xray.gdshader")
const HEIGHT := 1.5        # 世界单位；模型本身 1.8 m
const MODEL_HEIGHT := 1.8
const RUN_REFERENCE := 3.5  # 跑步动作原速下脚着地时的地面速度（在 Blender 里量的 4.2 m/s × 1.5/1.8），用来避免滑步
const TURN_RATE := 16.0
const BLEND := 0.12
const DEATH_FROM := 1.2     # 死亡动作开头一段站着摇晃，跳过，直接从踉跄开始
const DEATH_TO := 3.7       # 之后已经倒地不动

var anim: AnimationPlayer
var model: Node3D
var materials: Array[ShaderMaterial] = []
var dead := false
var _yaw := 0.0
var _swing := 0
var _was_attacking := false
var _was_dashing := false
var _last_attack_time := 0.0
var _flash := 0.0


func _ready() -> void:
	model = MODEL.instantiate() as Node3D
	model.scale = Vector3.ONE * HEIGHT / MODEL_HEIGHT
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for loop: StringName in [&"idle", &"run"]:
		anim.get_animation(loop).loop_mode = Animation.LOOP_LINEAR
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		_ink(mesh)
	_add_weapons()
	anim.play(&"idle")


## 明暗用场景太阳的方向，这样和画出来的光影一致
func light_from(sun: DirectionalLight3D) -> void:
	for material in materials:
		material.set_shader_parameter("key_dir", sun.global_transform.basis.z)


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
		var xray := ShaderMaterial.new()
		xray.shader = XRAY
		xray.render_priority = 12
		ink.next_pass = xray
		mesh.set_surface_override_material(i, ink)
		materials.append(ink)


## 武器还没有 3D 模型（待办里单独做），先放一把程序生成的太刀和刀鞘，让持刀动作看得出来。
## 尺寸和位置按 Blender 里挂点的坐标写（+Y 是刀身/鞘身方向），glTF 导出后那个方向在 Godot 里是 -Z。
func _add_weapons() -> void:
	var hand := model.find_child("weapon_r", true, false) as Node3D
	var hip := model.find_child("sheath_l", true, false) as Node3D
	_part(hand, Vector3(0.020, 0.25, 0.024), Vector3(0, -0.075, 0), Color("#2b2522"))  # 柄
	_part(hand, Vector3(0.075, 0.010, 0.075), Vector3(0, 0.055, 0), Color("#3a3431"))  # 镡
	_part(hand, Vector3(0.007, 0.70, 0.030), Vector3(0, 0.41, 0), Color("#c7d0d8"))    # 刃
	_part(hip, Vector3(0.026, 0.78, 0.040), Vector3(0, 0.24, 0), Color("#221b1e"))     # 鞘


func _part(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> void:
	var unit := parent.global_transform.basis.get_scale().x / model.scale.x  # 挂点在缩放过的骨架下
	var box := BoxMesh.new()
	box.size = Vector3(size.x, size.z, size.y) / unit
	var part := MeshInstance3D.new()
	part.mesh = box
	part.position = Vector3(at.x, at.z, -at.y) / unit
	var ink := ShaderMaterial.new()
	ink.shader = INK
	ink.set_shader_parameter("use_texture", false)
	ink.set_shader_parameter("base_color", color)
	part.material_override = ink
	materials.append(ink)
	parent.add_child(part)


func sync(player: Player, at: Vector3, delta: float) -> void:
	position = at
	if dead:
		return
	var attacking := player.weapon_pose_active()
	var dashing := player.is_dashing()
	var moving := player.velocity.length() > 1.0
	var look := player.weapon_aim() if attacking else (player.velocity if moving else player.facing)
	if look.length_squared() > 0.0001:
		var target := atan2(look.x, look.y)
		_yaw = lerp_angle(_yaw, target, 1.0 - exp(-(TURN_RATE * 2.0 if attacking else TURN_RATE) * delta))
		rotation.y = _yaw
	if dashing:
		if not _was_dashing:
			_play(&"dash", (Player.DASH_TIME + Player.DASH_INVINCIBLE) * 1.2, true)
	elif player.is_hurt():
		if anim.current_animation != "hit":
			_play(&"hit", 0.25 * 1.6, true)
	elif attacking:
		if not _was_attacking or player._attack_time > _last_attack_time + 0.001:
			_swing = (_swing + 1) % 2
			_play(&"attack" if _swing == 0 else &"attack2", maxf(0.28, player._attack_time), true)
	elif moving:
		_loop(&"run", clampf(player.velocity.length() * 0.01 / RUN_REFERENCE, 0.6, 1.6))
	else:
		_loop(&"idle", 1.0)
	_last_attack_time = player._attack_time
	_was_attacking = attacking
	_was_dashing = dashing
	_flash = maxf(_flash - delta * 5.0, 0.55 if player.is_hurt() else 0.0)
	for material in materials:
		material.set_shader_parameter("flash", Color(1.0, 0.62, 0.58, _flash))


## 播放一次性动作，按给定时长加速（游戏里的出招、冲刺都比动作素材短得多）
func _play(action: StringName, duration: float, restart: bool) -> void:
	anim.speed_scale = 1.0
	var speed := clampf(anim.get_animation(action).length / duration, 1.0, 6.0)
	anim.play(action, BLEND * 0.5, speed)
	if restart:
		anim.seek(0.0, true)


## 循环动作；跑步的播放速度跟着实际移动速度走
func _loop(action: StringName, speed: float) -> void:
	if anim.current_animation != String(action):
		anim.play(action, BLEND)
	anim.speed_scale = speed


## 倒地：游戏会立刻暂停，所以动作要在暂停时继续播；整段压进 duration 秒里
func die(duration: float) -> void:
	dead = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	var span := DEATH_TO - DEATH_FROM
	anim.speed_scale = 1.0
	anim.play(&"death", 0.08, span / maxf(0.4, duration))
	anim.seek(DEATH_FROM, true)


func revive() -> void:
	dead = false
	process_mode = Node.PROCESS_MODE_INHERIT
	anim.play(&"idle", BLEND)
