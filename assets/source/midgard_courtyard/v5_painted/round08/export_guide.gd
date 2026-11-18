extends SceneTree

const Layout := preload("res://scripts/roguelite/fimbulwinter_courtyard_layout.gd")
const Headland := preload("res://assets/models/midgard/courtyard/v4/headland.glb")
const DIR := "res://assets/source/midgard_courtyard/v5_painted/round08/"
const CENTER := Vector3(3.9, 0, -.1)
const OFFSET := Vector3(-8, 14.4, 9.8)

func _initialize() -> void:
	run.call_deferred()

func block(vp: Node, at: Vector3, mesh: Mesh, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.position = at
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	item.material_override = mat
	vp.add_child(item)
	return item

func disc(vp: Node, x: float, z: float, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return block(vp, Vector3(x, height / 2.0, z), mesh, color)

func run() -> void:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(4608, 3072)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 18
	vp.add_child(cam)
	cam.position = CENTER + OFFSET
	cam.look_at(CENTER)
	var site := Headland.instantiate()
	vp.add_child(site)
	site.hide()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(160, 160)
	block(vp, Vector3(0,-.02,0), floor_mesh, Color("#777f94"))
	var ring := TorusMesh.new()
	ring.inner_radius = Layout.RING_RADIUS * .01 - .38
	ring.outer_radius = Layout.RING_RADIUS * .01
	block(vp, Vector3(Layout.RING.x*.01, -.11, Layout.RING.y*.01), ring, Color("#586176"))
	var env := Node3D.new()
	vp.add_child(env)
	var anchor_data := []
	for a in Layout.boundary_anchors(site):
		disc(env, a.x*.01, a.y*.01, a.z*.01, .48, Color("#c5cbd4"))
		anchor_data.append([a.x,a.y,a.z])
	var props := Node3D.new()
	vp.add_child(props)
	var cover_data := []
	for cover in Layout.COVERS:
		disc(props, cover.foot.x*.01, cover.foot.y*.01, cover.radius*.01, cover.height if cover.id != "frozen-well" else .85, Color("#414859"))
		cover_data.append([cover.id,cover.foot.x,cover.foot.y,cover.radius,cover.width,cover.height])
	var f := FileAccess.open(DIR+"layout.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"anchors":anchor_data,"covers":cover_data,"ring":[Layout.RING.x,Layout.RING.y,Layout.RING_RADIUS],"east_shift":Layout.EAST_SHIFT,"depth_ramp":[Layout.DEPTH_RAMP.x,Layout.DEPTH_RAMP.y,Layout.DEPTH_RAMP.z,Layout.DEPTH_RAMP.w]}, "\t"))
	await capture(vp,"whitebox")
	props.hide()
	await capture(vp,"floor-guide")
	env.hide()
	props.show()
	vp.transparent_bg = true
	for child in vp.get_children():
		if child is MeshInstance3D: child.hide()
	await capture(vp,"cover-mask")
	for prop in props.get_children():
		for other in props.get_children():
			other.visible = other == prop
		await capture(vp, "mask-" + str(Layout.COVERS[prop.get_index()].id))
	for child in vp.get_children():
		if child is MeshInstance3D: child.show()
	for prop in props.get_children(): prop.show()
	env.show()
	var depth := ShaderMaterial.new()
	depth.shader = Shader.new()
	depth.shader.code = """
shader_type spatial;
render_mode unshaded, shadows_disabled;
void fragment() {
	float d = round(clamp((-VERTEX.z - 7.0) / 23.0, 0.0, 1.0) * 65535.0);
	ALBEDO = vec3(floor(d / 256.0), mod(d, 256.0), 0.0) / 255.0;
}
"""
	for piece in vp.find_children("*", "MeshInstance3D", true, false):
		if piece.is_visible_in_tree(): piece.material_override = depth
	await capture(vp, "depth-court")
	props.hide()
	env.hide()
	await capture(vp, "depth-floor")
	quit()

func capture(vp: SubViewport, label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var im := vp.get_texture().get_image()
	if im.save_png(DIR+label+".png") != OK:
		quit(1)
