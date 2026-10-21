class_name Darkness
extends CanvasLayer
## 画面变暗效果（斯库尔的「吞日」）：屏幕四周变暗，只剩玩家附近一圈能看清
## 改 target_level（0 = 正常，1 = 最暗），视野迅速压缩、平滑恢复；回到 0 后自动删除自己

const SHADER_CODE := """
shader_type canvas_item;
uniform float level = 0.0;      // 0 = 正常，1 = 最暗
uniform vec2 aspect = vec2(1.778, 1.0);

void fragment() {
	vec2 p = (UV - 0.5) * aspect;
	float radius = mix(1.2, 0.32, level);   // 可见范围随暗度缩小
	float edge = smoothstep(radius, radius + 0.25, length(p));
	float a = max(edge, 0.3) * level;       // 圈外全黑，圈内也略微变暗
	COLOR = vec4(0.0, 0.0, 0.03, a);
}
"""

var target_level := 0.0
var _level := 0.0
var _started := false  # 真正变暗过之后，才会在恢复光明时删除自己
var _material: ShaderMaterial


func _ready() -> void:
	layer = 1  # 盖在游戏画面上，但在界面（HUD 是 5）下面
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	var rect := ColorRect.new()
	rect.material = _material
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


func _process(delta: float) -> void:
	_level = move_toward(_level, target_level, delta * (8.0 if target_level > _level else 0.8))
	_material.set_shader_parameter("level", _level)
	if _level > 0.0:
		_started = true
	elif _started and target_level <= 0.0:
		queue_free()
