class_name ImpactFrame
extends CanvasLayer
## 重击的冲击帧：画面反色一两帧，再闪一下白褪掉。只给二刀流这类重击用，每刀都用会刺眼。
## 设置里关掉「屏幕震动」时也一起关掉（同样是给怕晃眼的玩家准备的）。

const INVERT_TIME := 0.045  # 现实时间，约两帧
const FLASH_TIME := 0.09
const SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float invert = 1.0;
uniform float flash = 0.0;
void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	c = mix(c, vec3(1.0) - c, invert);
	COLOR = vec4(mix(c, vec3(1.0), flash * 0.55), 1.0);
}
"""

static var _shader: Shader


static func play(node: Node) -> void:
	if Settings.screen_shake <= 0.0 or not node.is_inside_tree():
		return
	var frame := ImpactFrame.new()
	node.get_tree().root.add_child(frame)


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var cover := ColorRect.new()
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = _shader
	cover.material = material
	add_child(cover)
	await get_tree().create_timer(INVERT_TIME, true, false, true).timeout
	material.set_shader_parameter("invert", 0.0)
	material.set_shader_parameter("flash", 1.0)
	var fade := create_tween().set_ignore_time_scale(true)
	fade.tween_property(material, "shader_parameter/flash", 0.0, FLASH_TIME)
	fade.tween_callback(queue_free)
