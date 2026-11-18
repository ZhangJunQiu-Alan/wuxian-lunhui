extends SceneTree

const STAGE_PATH := "res://scripts/roguelite/fimbulwinter_courtyard_stage.gd"
const DEST := "res://assets/source/midgard_courtyard/v5_painted/引导/"
const SIZE := Vector2i(4032, 2688)
const CAMERA_HEIGHT := 16.0
const CENTER := Vector3(2.25, 0, .25)
const GROUPS := {
	"ground": Color("#373f49"),
	"water": Color("#647784"),
	"longhouse": Color("#df394a"),
	"walls": Color("#e59429"),
	"gate_jambs": Color("#44bd80"),
	"gate_lintel": Color("#38bef4"),
	"gate_shutter": Color("#5856ed"),
	"entrance": Color("#ad64d8"),
	"entrance_shutter": Color("#d9aed9"),
	"scree": Color("#eed769"),
	"standing_stones": Color("#e185b1"),
	"landmarks": Color("#90c347"),
}

var export_extension := false
var export_approach := false
var stage_constants: Dictionary
var viewport: SubViewport
var site: Node3D
var camera: Camera3D
var environment: Environment
var parts: Dictionary[MeshInstance3D, String] = {}
var materials: Dictionary[MeshInstance3D, Material] = {}
var dormant: Node3D
var restored: Node3D
var failed := false


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("The whitebox export needs a rendering device")
		quit(1)
		return
	var stage: Script = load(STAGE_PATH)
	stage_constants = stage.get_script_constant_map()
	viewport = SubViewport.new()
	export_extension = "--edge-guide" in OS.get_cmdline_user_args()
	export_approach = "--approach-guide" in OS.get_cmdline_user_args()
	viewport.size = Vector2i(6048, 4032) if export_extension else SIZE
	if export_approach:
		viewport.size = Vector2i(8064, 5376)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24.0 if export_extension else CAMERA_HEIGHT
	if export_approach:
		camera.size = 32.0
	camera.position = CENTER + stage_constants.CAMERA_OFFSET
	viewport.add_child(camera)
	camera.look_at(CENTER)
	if export_approach:
		camera.position += camera.basis.x * -18.0 + camera.basis.y * -4.0

	var background := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#444e56")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#e5ecff")
	environment.ambient_light_energy = .62
	background.environment = environment
	viewport.add_child(background)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -36, 0)
	key.light_energy = 1.0
	key.shadow_enabled = true
	viewport.add_child(key)

	site = stage_constants.HEADLAND.instantiate()
	viewport.add_child(site)
	dormant = site.find_child("DormantGate*", true, false) as Node3D
	restored = site.find_child("AwakenedGate*", true, false) as Node3D
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(122, 104)
	sea.mesh = plane
	sea.position = Vector3(-5.0, -5.22, 2.0)
	viewport.add_child(sea)

	for piece: MeshInstance3D in site.find_children("*", "MeshInstance3D", true, false):
		parts[piece] = classify(piece)
	parts[sea] = "water"

	var terrain := ShaderMaterial.new()
	terrain.shader = Shader.new()
	terrain.shader.code = """
shader_type spatial;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.)).xyz; }
void fragment() {
	vec2 p = world.xz;
	float curve = sin((p.x + 1.2) * .48) * 1.12 + .43;
	curve = mix(curve, -1.65, smoothstep(-13.0, -6.8, p.x) * (1.0 - smoothstep(-5.7, -2.8, p.x)));
	curve = mix(curve, 1.24, smoothstep(6.1, 10.3, p.x));
	float arena = (length((p - vec2(.41, -.15)) / vec2(6.45, 5.75)) - 1.0) * 4.2;
	float road = abs(p.y - curve) - 1.28;
	float snow = smoothstep(-.08, .25, min(road, arena));
	vec2 tile = vec2(p.x / .61, p.y / .43);
	tile.x += .5 * mod(floor(tile.y), 2.0);
	vec2 seam = abs(fract(tile) - .5);
	float grout = smoothstep(.48, .495, max(seam.x, seam.y));
	vec3 slabs = mix(vec3(.45, .48, .53), vec3(.36, .39, .43), grout * .66);
	vec3 top = mix(slabs, vec3(.76, .80, .86), snow);
	ALBEDO = mix(vec3(.32, .37, .43), top, smoothstep(-.15, .0, world.y));
	ROUGHNESS = 1.;
}
"""
	for piece in parts:
		var group := parts[piece]
		var color := Color("#909ca9")
		if group == "longhouse" or group == "gate_lintel" or group == "gate_shutter":
			color = Color("#8c8077")
		elif group == "scree":
			color = Color("#a2acb9")
		elif group == "water":
			color = Color("#4f738b")
		materials[piece] = terrain if group == "ground" else flat(color, group == "water")
		piece.material_override = materials[piece]

	var entrance_shutter := site.find_child("EntranceShutter*", true, false) as Node3D
	entrance_shutter.hide()
	restored.hide()
	if export_approach:
		await capture("approach-whitebox")
		await export_layers("approach")
		for piece in parts:
			piece.visible = parts[piece] in ["ground", "water"]
			piece.material_override = materials[piece]
		environment.background_color = Color("#444e56")
		await capture("approach-ground-only")
		await export_depth("approach-ground")
		quit(int(failed))
		return
	if export_extension:
		await capture("edge-whitebox")
		for piece in parts:
			piece.visible = parts[piece] in ["ground", "water"]
		await export_depth("edge-ground")
		quit(int(failed))
		return
	await capture("whitebox-dormant")
	dormant.hide()
	restored.show()
	await capture("whitebox-restored")
	await export_layers("restored")
	dormant.show()
	restored.hide()
	await export_layers("dormant")

	for piece in parts:
		piece.visible = parts[piece] in ["ground", "water"]
		piece.material_override = materials[piece]
	environment.background_color = Color("#444e56")
	await capture("ground-only")
	await export_depth("ground")
	for piece in parts:
		piece.visible = true
	entrance_shutter.show()
	await export_layers("sealed")
	write_projection()
	quit(int(failed))


func classify(piece: MeshInstance3D) -> String:
	var path := String(piece.get_path()).to_lower().replace(" ", "_")
	if "/terrain/" in path:
		return "ground"
	if "longhouse_ruin" in path:
		return "longhouse"
	if "low_wall" in path:
		return "walls"
	if dormant.is_ancestor_of(piece) or restored.is_ancestor_of(piece):
		if "gate_jamb" in path:
			return "gate_jambs"
		if "gateshutter" in path:
			return "gate_shutter"
		return "gate_lintel"
	if "entranceshutter" in path:
		return "entrance_shutter"
	if "entrancegate" in path:
		return "entrance"
	if "rune_stone" in path:
		return "standing_stones"
	if "fjord_landmarks" in path or "wrecked_keel" in path:
		return "landmarks"
	return "scree"


func export_layers(state: String) -> void:
	environment.background_color = Color.BLACK
	var ids: Dictionary[String, StandardMaterial3D] = {}
	for group: String in GROUPS:
		ids[group] = flat(GROUPS[group], true)
	for piece in parts:
		piece.material_override = ids[parts[piece]]
	await capture("mask-groups-" + state)
	await export_depth(state)


func export_depth(state: String) -> void:
	var depth := ShaderMaterial.new()
	depth.shader = Shader.new()
	depth.shader.code = """
shader_type spatial;
render_mode unshaded, shadows_disabled;
void fragment() {
	float encoded = round(clamp((-VERTEX.z - 7.) / 23., 0., 1.) * 65535.);
	ALBEDO = vec3(floor(encoded / 256.), mod(encoded, 256.), 0.) / 255.;
}
"""
	for piece in parts:
		piece.material_override = depth
	await capture("depth-" + state)


func flat(color: Color, unlit: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if unlit:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var result := image.save_png(DEST + label + ".png")
	failed = failed or result != OK
	print("GUIDE ", label, " ", image.get_size(), " ", error_string(result))


func write_projection() -> void:
	var data := {
		"size_px": [SIZE.x, SIZE.y],
		"center_world": vector(CENTER),
		"eye_world": vector(camera.position),
		"basis_x": vector(camera.basis.x),
		"basis_y": vector(camera.basis.y),
		"basis_z": vector(camera.basis.z),
		"pixels_per_world_unit": SIZE.y / CAMERA_HEIGHT,
		"groups_rgb": GROUPS.keys().map(func(group: String) -> Array:
			return [group, "#" + GROUPS[group].to_html(false)]),
		"depth_decode": "7 + 23 * (256*R + G)/65535, R and G are PNG bytes",
		"collision_anchors": [],
		"brazier_bases_px": [],
	}
	for anchor: Node3D in site.find_children("Collider_*", "Node3D", true, false):
		var pos := anchor.global_position
		var pixel := camera.unproject_position(pos)
		data.collision_anchors.append({"world": vector(pos), "pixel": [pixel.x, pixel.y],
			"radius_world": anchor.global_basis.get_scale().x})
	for point: Vector2 in stage_constants.FIRES:
		var pixel := camera.unproject_position(Vector3(point.x, 0, point.y) * stage_constants.SCALE)
		data.brazier_bases_px.append([pixel.x, pixel.y])
	var file := FileAccess.open(DEST + "projection.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t") + "\n")


func vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
