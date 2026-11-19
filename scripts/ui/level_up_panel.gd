class_name LevelUpPanel
extends CanvasLayer
## 升级四选一界面：显示卡牌，鼠标点击或按 1/2/3/4 选择
## 卡是一块符文石碑：上部拱形窗里是插画，下部石面上是文字。品质（普通白、稀有蓝、史诗紫、传说金）决定刻纹的颜色和特效，
## 品质越高越华丽；神明的技能、质变、觉醒、融合技用神明自己的颜色。鼠标移上去时石碑浮起，不改颜色。
## 同一个面板也用来选神、选质变、觉醒和融合技（见 game.gd 的 _pending_rewards）

signal chosen(offer: Dictionary)
signal reroll_requested

const STELE_DIR := "res://assets/sprites/ui/stele/"  # 石碑素材：底图、刻纹 / 插画窗 / 符文蒙版，640 × 1100，彼此对齐
const STELE_SIZE := Vector2(640, 1100)
const CARD_SIZE := Vector2(290, 498)
const WINDOW := Rect2(113, 109, 412, 512)    # 插画窗（素材像素，和 stele_window_mask 一致）
const TEXT_RECT := Rect2(92, 668, 456, 316)   # 文字区（素材像素）
const NUMBER_AT := Vector2(320, 626)         # 按键数字的圆心，在分隔结饰上
const ART_DIR := "res://assets/sprites/cards/"  # 卡面插画：<神明 id>.png、<神明 id>_awaken.png、<角色 id>.png（基础武器）、general.png（通用属性）；质变、觉醒、融合技有 <卡牌 id>.png 时优先用它
const NEUTRAL_COLOR := Color(0.75, 0.78, 0.85)
const IVORY := Color(0.93, 0.9, 0.82)
const ART_SHADER := preload("res://scripts/ui/stele/stele_art.gdshader")
const GLOW_SHADER := preload("res://scripts/ui/stele/stele_glow.gdshader")
const AURA_SHADER := preload("res://scripts/ui/stele/stele_aura.gdshader")
## 每档特效：刻纹亮度、呼吸、上行光带、符文、石面高光、背后光晕、光芒、飘起的光点数
const TIER_FX := [
	{"strength": 0.22, "pulse": 0.0, "sweep": 0.0, "runes": 0.0, "shimmer": 0.0, "aura": 0.0, "rays": 0.0, "motes": 0},
	{"strength": 0.5, "pulse": 1.0, "sweep": 0.0, "runes": 0.0, "shimmer": 0.0, "aura": 0.0, "rays": 0.0, "motes": 10},
	{"strength": 0.7, "pulse": 1.0, "sweep": 0.8, "runes": 0.0, "shimmer": 0.5, "aura": 0.5, "rays": 0.0, "motes": 22},
	{"strength": 0.9, "pulse": 1.0, "sweep": 1.0, "runes": 1.0, "shimmer": 1.0, "aura": 0.9, "rays": 1.0, "motes": 40},
]
const STONE_TINT := Color(0.6, 0.65, 0.76)  # 素材是中性灰，压成偏冷的深灰蓝，文字更清楚
const HOVER_LIFT := 14.0
const HOVER_SCALE := 1.035

var _title: Label
var _cards: HBoxContainer
var _offers: Array[Dictionary] = []
var _reroll: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 游戏暂停时也要能操作
	layer = 10
	visible = false

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.theme = UiKit.theme()
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	box.add_child(_title)

	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 16)
	box.add_child(_cards)

	_reroll = Button.new()
	_reroll.focus_mode = Control.FOCUS_NONE
	_reroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll.custom_minimum_size = Vector2(220, 40)
	_reroll.pressed.connect(func() -> void: reroll_requested.emit())
	box.add_child(_reroll)

	var hint := Label.new()
	hint.text = tr("点击卡牌或按数字键选择")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.5)
	box.add_child(hint)


## entry 是 game.gd 里的一次奖励：kind = level / god / path / awaken / fusion
func open(offers: Array[Dictionary], player: Player, entry: Dictionary) -> void:
	_offers = offers
	_title.text = _title_for(entry, player)
	_reroll.visible = player.rerolls > 0 and ["level", "god"].has(entry.kind)
	_reroll.text = tr("重抽选项（剩余 %d 次）  [R]") % player.rerolls
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for i in offers.size():
		_cards.add_child(_make_card(i, offers[i], player))
	visible = true


func _title_for(entry: Dictionary, player: Player) -> String:
	match entry.kind:
		"god":
			return tr("选择你的第一位神") if player.faith.is_empty() else tr("等级 %d：选择第 %d 位神") % [player.level, player.faith.size() + 1]
		"path":
			return tr("%s的信仰达到 %d：选择一条道路") % [tr(Gods.ALL[entry.god].name), UpgradeDB.FAITH_PATH]
		"awaken":
			return tr("%s的信仰达到 %d：神之觉醒") % [tr(Gods.ALL[entry.god].name), UpgradeDB.FAITH_AWAKEN]
		"fusion":
			return tr("两位神同时觉醒：融合技")
	var title: String = entry.get("title", "")
	return title if title != "" else tr("升级！等级 %d") % player.level


func choose(index: int) -> void:
	if not visible or index >= _offers.size():
		return
	visible = false
	Audio.sfx("card_pick")
	chosen.emit(_offers[index])


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_4:
		choose(key.keycode - KEY_1)
		get_viewport().set_input_as_handled()
	elif key and key.pressed and not key.echo and key.keycode == KEY_R and _reroll.visible:
		reroll_requested.emit()
		get_viewport().set_input_as_handled()


func _make_card(index: int, offer: Dictionary, player: Player) -> Button:
	var id: String = offer.id
	var rarity: int = offer.rarity
	var info := UpgradeDB.get_info(id)
	var is_awaken: bool = info.kind == "awaken" or info.kind == "fusion"
	var color := NEUTRAL_COLOR
	var tag := tr("通用属性")
	var art := ART_DIR + "general.png"
	var art2 := ""  # 融合技：右半边画第二位神
	if info.has("god"):
		var god: Dictionary = Gods.ALL[info.god]
		color = god.color
		art = ART_DIR + info.god + ".png"
		match info.kind:
			"skill":
				tag = tr("神明 · %s · %s") % [tr(god.name), tr(god.title)]
			"boon":
				tag = tr("%s · 强化") % tr(god.name)
			"path":
				tag = tr("%s · 质变") % tr(god.name)
			"awaken":
				tag = tr("%s · 觉醒") % tr(god.name)
				if ResourceLoader.exists(ART_DIR + info.god + "_awaken.png"):
					art = ART_DIR + info.god + "_awaken.png"
			"fusion":
				tag = tr("融合技 · %s + %s") % [tr(god.name), tr(Gods.ALL[info.gods[1]].name)]
				art2 = ART_DIR + info.gods[1] + ".png"
	elif info.kind == "weapon":
		color = Color(0.85, 0.92, 1.0)
		tag = tr("基础武器 · ") + tr(CharacterDB.ALL[player.character_id].weapon)
		art = ART_DIR + player.character_id + ".png"
	if info.kind in ["path", "awaken", "fusion"] and ResourceLoader.exists(ART_DIR + id + ".png"):  # 有专属插画就用它
		art = ART_DIR + id + ".png"
		art2 = ""
	var edge := color
	if rarity >= 0:  # 有品质的卡按品质上色，神明技能、质变、觉醒、融合技用神明的颜色
		edge = UpgradeDB.RARITY_COLORS[rarity]
	var fx: Dictionary = TIER_FX[_tier(info.kind, rarity)]
	var k := CARD_SIZE.x / STELE_SIZE.x

	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed"]:
		card.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	card.set_meta("silent", true)
	card.pressed.connect(choose.bind(index))

	if fx.aura > 0.0:  # 背后的光晕画在石碑下面，不随悬停移动
		var aura := ColorRect.new()
		aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		aura.offset_left = -48; aura.offset_right = 48; aura.offset_top = -40; aura.offset_bottom = 30
		aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aura.material = _shader(AURA_SHADER, {"glow_color": edge, "strength": fx.aura, "rays": fx.rays,
			"aspect": (CARD_SIZE.x + 96.0) / (CARD_SIZE.y + 70.0)})
		card.add_child(aura)

	if fx.motes > 0:  # 光点从石碑背后升起，只在石碑两侧和上方露出来，不压文字
		card.add_child(_motes(edge, fx.motes))

	var body := Control.new()  # 石碑本体：悬停时整块浮起
	body.name = "Body"
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.pivot_offset = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(body)

	var window := Control.new()
	window.position = WINDOW.position * k
	window.size = WINDOW.size * k
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(window)
	var picture := _card_art(art, info, color)
	if art2 != "":  # 融合技：两位神的画像左右各一半
		picture = _split_art(picture, _card_art(art2, info, Gods.ALL[info.gods[1]].color))
		window.clip_contents = true
	elif picture is TextureRect:
		var image := picture as TextureRect
		image.stretch_mode = TextureRect.STRETCH_SCALE  # 裁切在着色器里做
		var art_size := image.texture.get_size()
		var visible_height := minf(1.0, (WINDOW.size.y / WINDOW.size.x) * (art_size.x / art_size.y))
		image.material = _shader(ART_SHADER, {"window_mask": _stele("stele_window_mask"),
			"window_rect": Vector4(WINDOW.position.x / STELE_SIZE.x, WINDOW.position.y / STELE_SIZE.y,
				WINDOW.size.x / STELE_SIZE.x, WINDOW.size.y / STELE_SIZE.y),
			"visible_height": visible_height, "crop_top": minf(0.03, 1.0 - visible_height)})
	else:
		window.clip_contents = true
	window.add_child(picture)

	var stone := _layer(_stele("stele_base"))
	stone.self_modulate = STONE_TINT
	body.add_child(stone)
	var glow := _layer(_stele("stele_inlay_mask"))
	glow.material = _shader(GLOW_SHADER, {"runes_mask": _stele("stele_runes_mask"), "stone": _stele("stele_base"),
		"glow_color": edge, "strength": fx.strength, "pulse": fx.pulse, "sweep": fx.sweep, "runes": fx.runes,
		"shimmer": fx.shimmer, "phase": index * 1.7})
	body.add_child(glow)


	var text_top := TEXT_RECT.position.y * k
	var text_bottom := TEXT_RECT.end.y * k
	var backing := Panel.new()  # 字多时文字区向上长，压住插画下沿，垫一层暗底
	var backing_style := StyleBoxFlat.new()
	backing_style.bg_color = Color(0.05, 0.06, 0.09, 0.86)
	backing_style.set_corner_radius_all(6)
	backing.add_theme_stylebox_override("panel", backing_style)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.visible = false
	body.add_child(backing)
	var box := VBoxContainer.new()
	box.position = Vector2(TEXT_RECT.position.x * k, text_top)
	box.size = Vector2(TEXT_RECT.size.x * k, text_bottom - text_top)
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(box)
	box.minimum_size_changed.connect(func() -> void:
		var need := box.get_combined_minimum_size().y
		box.position.y = minf(text_top, text_bottom - need)
		box.size.y = text_bottom - box.position.y
		backing.visible = box.position.y < text_top - 1.0
		backing.position = box.position - Vector2(6, 6)
		backing.size = box.size + Vector2(12, 10))

	var number := Label.new()  # 分隔饰上的按键提示
	number.text = str(index + 1)
	number.size = Vector2(30, 30)
	number.position = NUMBER_AT * k - number.size * 0.5
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 17)
	number.add_theme_constant_override("outline_size", 5)
	number.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	number.modulate = edge.lerp(Color.WHITE, 0.25)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(number)

	_add_line(box, tag + ("" if rarity < 0 else "  ·  " + tr(UpgradeDB.RARITY_NAMES[rarity])), 12, edge.lerp(Color.WHITE, 0.2))
	_add_line(box, tr(info.name), 22, IVORY if not is_awaken else color.lerp(Color.WHITE, 0.3))
	_add_line(box, UpgradeDB.describe(id, rarity), 13, Color(0.86, 0.87, 0.9))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)

	var current: int = player.upgrade_levels.get(id, 0)
	match info.kind:
		"awaken":
			_add_line(box, tr("★ 神之觉醒 ★"), 13, color)
		"fusion":
			_add_line(box, tr("★ 融合技 ★"), 13, color)
		"path":
			_add_line(box, tr("三条道路只能选一条"), 11, Color(1, 1, 1, 0.6))
		"skill":
			_add_line(box, tr("新的神明（一局最多 %d 位）") % UpgradeDB.MAX_GODS, 11, Color(1, 1, 1, 0.6))
		"boon":
			var now: int = player.faith.get(info.god, 0)
			var next := mini(now + UpgradeDB.faith_gain(rarity), UpgradeDB.FAITH_MAX)
			var hint := ""
			if now < UpgradeDB.FAITH_PATH and next >= UpgradeDB.FAITH_PATH:
				hint = tr("（选择道路）")
			elif now < UpgradeDB.FAITH_AWAKEN and next >= UpgradeDB.FAITH_AWAKEN:
				hint = tr("（觉醒）")
			_add_line(box, tr("信仰 %d → %d / %d") % [now, next, UpgradeDB.FAITH_MAX] + hint, 11, color)
	if info.get("max", 1) > 1:
		_add_line(box, tr("等级 %d → %d / %d") % [current, current + 1, info.max], 11, Color(1, 1, 1, 0.6))

	card.mouse_entered.connect(_hover.bind(body, true))
	card.mouse_exited.connect(_hover.bind(body, false))
	return card


## 品质档：神明的技能、质变按史诗的特效，觉醒、融合技按传说；其他看稀有度
static func _tier(kind: String, rarity: int) -> int:
	match kind:
		"awaken", "fusion":
			return 3
		"skill", "path":
			return 2
	return clampi(rarity, 0, 3)


## 悬停：石碑浮起并轻轻上下飘，移开时落回原位；只动位置和大小，不改颜色
func _hover(body: Control, on: bool) -> void:
	if body.has_meta("tween"):
		(body.get_meta("tween") as Tween).kill()
	var tween := body.create_tween()
	body.set_meta("tween", tween)
	if on:
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(body, "position:y", -HOVER_LIFT, 0.2)
		tween.parallel().tween_property(body, "scale", Vector2.ONE * HOVER_SCALE, 0.2)
		tween.chain().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_loops()
		tween.tween_property(body, "position:y", -HOVER_LIFT + 4.0, 0.9)
		tween.tween_property(body, "position:y", -HOVER_LIFT, 0.9)
	else:
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(body, "position:y", 0.0, 0.16)
		tween.parallel().tween_property(body, "scale", Vector2.ONE, 0.16)


func _motes(color: Color, amount: int) -> CPUParticles2D:
	var motes := CPUParticles2D.new()
	motes.amount = amount
	motes.lifetime = 3.2
	motes.preprocess = 3.2
	motes.position = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y * 0.7)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(CARD_SIZE.x * 0.6, CARD_SIZE.y * 0.3)
	motes.direction = Vector2.UP
	motes.spread = 12.0
	motes.gravity = Vector2(0, -10)
	motes.initial_velocity_min = 40.0
	motes.initial_velocity_max = 90.0
	motes.scale_amount_min = 0.12
	motes.scale_amount_max = 0.26
	motes.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(color, 0.0), Color(color.lerp(Color.WHITE, 0.4), 0.9), Color(color, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	motes.color_ramp = gradient
	var dot := GradientTexture2D.new()
	dot.width = 32
	dot.height = 32
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var falloff := Gradient.new()
	falloff.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	dot.gradient = falloff
	motes.texture = dot
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	motes.material = add
	return motes


func _layer(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _shader(shader: Shader, params: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	for key: String in params:
		material.set_shader_parameter(key, params[key])
	return material


static func _stele(part: String) -> Texture2D:
	return load(STELE_DIR + part + ".png")


## 两张插画左右各显示一半
func _split_art(left: Control, right: Control) -> Control:
	var holder := HBoxContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_theme_constant_override("separation", 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part in [left, right]:
		var half := Control.new()
		half.clip_contents = true
		half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		half.mouse_filter = Control.MOUSE_FILTER_IGNORE
		half.add_child(part)
		holder.add_child(half)
	return holder


## 卡面插画：assets/sprites/cards/ 里有就用；基础武器卡没有插画时用角色的大招特写；都没有就画一张神明颜色的占位
func _card_art(path: String, info: Dictionary, color: Color) -> Control:
	var texture: Texture2D
	var smooth := true  # 插画不是像素画，缩放时要平滑
	if ResourceLoader.exists(path):
		texture = load(path)
	elif info.kind == "weapon" and ResourceLoader.exists(path.replace(ART_DIR, CharacterDB.CUTIN_DIR).replace(".png", "_cutin.png")):
		texture = load(path.replace(ART_DIR, CharacterDB.CUTIN_DIR).replace(".png", "_cutin.png"))
		smooth = false
	if texture:
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if smooth else CanvasItem.TEXTURE_FILTER_NEAREST
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return image
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := tr(Gods.ALL[info.god].name if info.has("god") else "通用属性").substr(0, 1)
	holder.draw.connect(func() -> void:
		var size := holder.size
		var top := Color(color.darkened(0.55), 1.0)
		var mid := Color(color.darkened(0.8), 1.0)
		holder.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
			PackedColorArray([top, top, mid, mid]))
		var center := Vector2(size.x * 0.5, size.y * 0.5)
		for i in 3:
			holder.draw_arc(center, 54.0 + i * 16.0, 0.0, TAU, 64, Color(color, 0.25 - i * 0.07), 2.0)
		var font := holder.get_theme_default_font()
		var w := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
		holder.draw_string(font, center + Vector2(-w * 0.5, 22.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(color, 0.55)))
	return holder


func _add_line(parent: Control, text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # 中文按字、英文按词换行
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)


static func faith_bar(points: int) -> String:
	points = mini(points, UpgradeDB.FAITH_MAX)
	return "■".repeat(points) + "□".repeat(UpgradeDB.FAITH_MAX - points)


## 一位神的信仰一行：「托尔 ■■■■■■■□□□□□ 雷暴云」，觉醒后带 ★
static func faith_line(player: Player, god_id: String) -> String:
	var god: Dictionary = Gods.ALL[god_id]
	var text := "%s %s" % [TranslationServer.translate(god.name), faith_bar(player.faith[god_id])]
	var power: GodPower = player.gods.get(god_id)
	if power and power.path != "":
		text += " " + TranslationServer.translate(UpgradeDB.UPGRADES[power.path].name)
		if power.awakened:
			text += " ★"
	return text
