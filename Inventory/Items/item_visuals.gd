class_name ItemVisuals
extends RefCounted

const SLOT_PX := 64
const ORB_SLOT_MARGIN := 12

static func update_label_display(item, value_label: Label, icon: TextureRect, cylinder_visual: Node2D, color_rect: ColorRect) -> void:
	if not value_label:
		return
	
	value_label.visible = true
	
	if color_rect:
		if item.data_type == item.DataType.RAW:
			color_rect.color = Color(0.5, 0.5, 0.5, 1)
		else:
			color_rect.color = Color(0.24, 0.17, 0.08, 1)
		color_rect.z_index = -1
	
	match item.data_type:
		item.DataType.OPERATOR:
			value_label.add_theme_color_override("font_color", Color(1, 0.85, 0.35, 1))
			value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.DataType.INT:
			value_label.add_theme_color_override("font_color", Color.BLUE)
		item.DataType.FLOAT:
			value_label.add_theme_color_override("font_color", Color.RED)
		item.DataType.STRING:
			value_label.add_theme_color_override("font_color", Color.YELLOW)
		item.DataType.DOUBLE:
			value_label.add_theme_color_override("font_color", Color.MAGENTA)
		item.DataType.BINARY:
			value_label.add_theme_color_override("font_color", Color.LIME)
		item.DataType.SHORT_INT:
			value_label.add_theme_color_override("font_color", Color.CYAN)
		item.DataType.FP8:
			value_label.add_theme_color_override("font_color", Color.VIOLET)
		item.DataType.FP16:
			value_label.add_theme_color_override("font_color", Color.GOLD)
		item.DataType.RAW:
			value_label.add_theme_color_override("font_color", Color.WHITE)
		_:
			value_label.add_theme_color_override("font_color", Color.BLACK)
			
	if item.data_type == item.DataType.OPERATOR:
		value_label.text = operator_display_label(item)
	elif item.data_type == item.DataType.BINARY:
		value_label.text = item.value_binary
	else:
		value_label.text = OrbValueFormat.compact_label_string(item)
		
	var dims := _compute_orb_dimensions(item, value_label.text)
	var has_orb_art := false
	_resize_visual(item, color_rect, dims, value_label)
	has_orb_art = _apply_orb_sprite(item, dims, icon, cylinder_visual, color_rect, value_label)
	_apply_label_fit(item, value_label)
	
	if has_orb_art and value_label:
		value_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		
	if OrbValueFormat.should_compact(item):
		value_label.tooltip_text = "Valor exato: " + OrbValueFormat.full_value_string(item)
	else:
		value_label.tooltip_text = ""
		
	if item.data_type == item.DataType.OPERATOR:
		value_label.tooltip_text = "Operador: " + item.operator
		
	value_label.queue_redraw()

static func operator_display_label(item) -> String:
	match item.operator:
		"+": return "+"
		"++": return "++"
		"to_int": return "int"
		"to_float": return "flt"
		"to_short": return "sh"
	if item.operator.begins_with("to_") and item.operator.length() > 3:
		return item.operator.substr(3)
	if item.operator.length() <= 5:
		return item.operator
	return item.operator.substr(0, 5)

static func shrink_orb_for_tool_slot(item, value_label: Label, cylinder_visual: Node2D, color_rect: ColorRect) -> void:
	if not _uses_wide_visual(item):
		return
	var dims := Vector2(SLOT_PX * 0.48, SLOT_PX * 0.48)
	if color_rect:
		_resize_visual(item, color_rect, dims, value_label)
		_apply_double_cylinder(item, dims, null, cylinder_visual, color_rect, value_label)
		_apply_label_fit(item, value_label)

static func get_color_for_type(item) -> Color:
	match item.data_type:
		item.DataType.INT: return Color.BLUE
		item.DataType.FLOAT: return Color.RED
		item.DataType.STRING: return Color.YELLOW
		item.DataType.DOUBLE: return Color.MAGENTA
		item.DataType.BINARY: return Color.LIME
		item.DataType.SHORT_INT: return Color.CYAN
		item.DataType.FP8: return Color.VIOLET
		item.DataType.FP16: return Color.GOLD
		item.DataType.RAW: return Color.WHITE
		item.DataType.OPERATOR: return Color(1, 0.85, 0.35, 1)
		_: return Color.GRAY

static func _grid_span_cells(item) -> int:
	var span_x := 0
	if item.get("item_grids") == null:
		return 1
	for g in item.item_grids:
		span_x = maxi(span_x, int(g.x))
	return maxi(span_x + 1, 1)


## Cápsula larga só para DOUBLE (2 palavras). Int em slot 1B ocupa 4 células na grade,
## mas o desenho continua orb redondo na célula âncora.
static func _uses_wide_visual(item) -> bool:
	if item == null:
		return false
	if item.data_type == item.DataType.DOUBLE:
		return true
	if item.has_method("get_size_bytes") and int(item.get_size_bytes()) >= 8:
		return true
	return false


static func _compute_orb_dimensions(item, text: String) -> Vector2:
	var item_bytes: int = item.get_size_bytes() if item.has_method("get_size_bytes") else 4
	var uses_cylinder: bool = _uses_wide_visual(item)
	if item.data_type == item.DataType.OPERATOR:
		return Vector2(SLOT_PX * 0.9, SLOT_PX * 0.45) if uses_cylinder else Vector2(SLOT_PX - ORB_SLOT_MARGIN*2, SLOT_PX - ORB_SLOT_MARGIN*2)
		
	if uses_cylinder:
		if item_bytes >= 8:
			return _double_capsule_size()
		elif item_bytes >= 4:
			return Vector2(SLOT_PX * 0.9, SLOT_PX * 0.45)
		elif item_bytes == 2:
			return Vector2(SLOT_PX * 0.45, SLOT_PX * 0.45)
		else:
			return Vector2(SLOT_PX * 0.22, SLOT_PX * 0.45)

	var char_count := maxi(text.length(), 1)
	var base_scale := _base_type_slot_scale(item)
	var max_side := SLOT_PX - ORB_SLOT_MARGIN * 2.0
	var max_w := SLOT_PX - 4.0
	var visual_scale := base_scale
	
	if item_bytes >= 4:
		if char_count >= 7:
			visual_scale = 1.0
		elif char_count >= 5:
			visual_scale = maxf(base_scale, 0.75)
		elif char_count >= 4:
			visual_scale = maxf(base_scale, 0.55)
		
	var min_bound := 22.0
	if item_bytes <= 1:
		min_bound = 14.0
	elif item_bytes == 2:
		min_bound = 28.0
		
	var side := clampf(SLOT_PX * visual_scale, min_bound, max_side)
	
	if item_bytes <= 1:
		side = 14.0
	elif item_bytes == 2:
		side = 28.0
	else:
		side = clampf(SLOT_PX * visual_scale - ORB_SLOT_MARGIN * 2.0, 22.0, max_side)

	if item_bytes >= 4 and char_count >= 6:
		var width := clampf(char_count * 6.8 + 6.0, side, max_w)
		var height := clampf(side, 24.0, max_side)
		return Vector2(width, height)
	return Vector2(side, side)

static func _base_type_slot_scale(item) -> float:
	match item.data_type:
		item.DataType.FP8:
			return 0.25
		item.DataType.SHORT_INT, item.DataType.FP16:
			return 0.5
		item.DataType.DOUBLE:
			return 2.0
		_:
			return 1.0

static func _apply_orb_sprite(item, dims: Vector2, icon: TextureRect, cylinder_visual: Node2D, color_rect: ColorRect, value_label: Label) -> bool:
	if dims == Vector2.ZERO:
		dims = _compute_orb_dimensions(item, value_label.text if value_label else "")
	var uses_cylinder: bool = _uses_wide_visual(item)
	if uses_cylinder:
		return _apply_double_cylinder(item, dims, icon, cylinder_visual, color_rect, value_label)

	if icon == null:
		return false
	if cylinder_visual:
		cylinder_visual.visible = false
	icon.visible = true
	var path := ""
	match item.data_type:
		item.DataType.INT:
			path = "res://Inventory/Art/Orbs/orb_int.png"
		item.DataType.FLOAT:
			path = "res://Inventory/Art/Orbs/orb_float.png"
		item.DataType.BINARY:
			path = "res://Inventory/Art/Orbs/orb_binary.png"
		item.DataType.OPERATOR:
			path = "res://Inventory/Art/Orbs/orb_operator.png"
		item.DataType.RAW:
			path = "res://Inventory/Art/Orbs/orb_raw.png"
		item.DataType.SHORT_INT:
			path = "res://Inventory/Art/Orbs/orb_int.png"
		item.DataType.FP8, item.DataType.FP16:
			path = "res://Inventory/Art/Orbs/orb_float.png"
	var tex: Texture2D = null
	if not path.is_empty() and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	elif item.data_type == item.DataType.BINARY and ResourceLoader.exists("res://Inventory/Sprites/Item_binary.png"):
		tex = load("res://Inventory/Sprites/Item_binary.png") as Texture2D
	icon.texture = tex
	_fit_visual_rect(item, icon, dims, value_label)
	
	if color_rect:
		if tex:
			color_rect.color = Color(0, 0, 0, 0)
		elif item.data_type == item.DataType.RAW:
			color_rect.color = Color(0.5, 0.5, 0.5, 1)
		else:
			color_rect.color = Color(0.24, 0.17, 0.08, 1)
	return tex != null

static func _apply_double_cylinder(item, dims: Vector2, icon: TextureRect, cylinder_visual: Node2D, color_rect: ColorRect, value_label: Label) -> bool:
	if icon:
		icon.visible = false
		icon.texture = null
	if cylinder_visual == null:
		return false
	cylinder_visual.visible = true
	cylinder_visual.position = Vector2.ZERO
	cylinder_visual.z_index = 0
	
	var base_color := get_color_for_type(item)
	var num_bytes: int = item.get_size_bytes() if item.has_method("get_size_bytes") else 4
	
	if cylinder_visual.has_method("set_visual_props"):
		cylinder_visual.set_visual_props(base_color, num_bytes, dims)
	elif "draw_size" in cylinder_visual:
		cylinder_visual.draw_size = dims
		cylinder_visual.queue_redraw()
	if color_rect:
		color_rect.color = Color(0, 0, 0, 0)
		color_rect.z_index = 1
	if value_label:
		value_label.z_index = 2
		value_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		value_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_center_double_label(value_label)
	return true

static func _center_double_label(value_label: Label) -> void:
	value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	value_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	value_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Empurra o centro óptico ~2–3px para baixo (entre os dois aros do cilindro).
	value_label.offset_left = 0
	value_label.offset_right = 0
	value_label.offset_top = 3
	value_label.offset_bottom = -1

static func _double_capsule_size() -> Vector2:
	# Um pouco menor que 2 slots cheios pra não “estourar” a grade.
	var width := SLOT_PX * 1.45
	var height := SLOT_PX * 0.45
	return Vector2(width, height)

static func _fit_visual_rect(item, node: Control, dims: Vector2, value_label: Label) -> void:
	var width := clampf(dims.x, 10.0, SLOT_PX * 4.0)
	var height := clampf(dims.y, 10.0, SLOT_PX * 2.0)
	# Parent do Item é Node2D: position/size, não anchors de Control.
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 0.0
	node.anchor_bottom = 0.0
	node.position = Vector2(-width * 0.5, -height * 0.5)
	node.size = Vector2(width, height)
	node.custom_minimum_size = Vector2(width, height)
	if node is TextureRect:
		var icon := node as TextureRect
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		var wide := width > height * 1.12
		icon.stretch_mode = TextureRect.STRETCH_SCALE if wide else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.z_index = 0
	if value_label and item.data_type != item.DataType.DOUBLE:
		value_label.z_index = 1
		value_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		value_label.offset_left = 0
		value_label.offset_top = 0
		value_label.offset_right = 0
		value_label.offset_bottom = 0

static func _orb_label_fit_size(value_label: Label) -> Vector2:
	var cr = value_label.get_parent() if value_label else null
	if cr is ColorRect and cr.size.x > 1.0:
		return cr.size
	var fallback := SLOT_PX - ORB_SLOT_MARGIN * 2.0
	return Vector2(fallback, fallback)

static func _orb_font_size(text: String, width: float, height: float) -> int:
	var char_count := maxi(text.length(), 1)
	var short_side := minf(width, height)
	var base: int = 15 if short_side < 34.0 else (17 if short_side < 46.0 else 18)
	if char_count <= 3:
		return base
	var by_width := int(width * 0.9 / (char_count * 0.5))
	var by_height := int(height * 0.72)
	return clampi(mini(by_width, by_height), 10, base)

static func _apply_label_fit(item, value_label: Label) -> void:
	if not value_label:
		return
	var dims := _orb_label_fit_size(value_label)
	var fs: int
	var uses_cylinder: bool = _uses_wide_visual(item)
	if item.data_type == item.DataType.OPERATOR:
		fs = 22 if item.operator.length() <= 2 else 13
		fs = mini(fs, _orb_font_size(value_label.text, dims.x, dims.y))
	elif uses_cylinder:
		# Um pouco menor pra caber bem no corpo do cilindro entre os aros.
		fs = clampi(_orb_font_size(value_label.text, dims.x * 0.85, dims.y * 0.55), 11, 16)
	else:
		fs = _orb_font_size(value_label.text, dims.x, dims.y)
	value_label.add_theme_font_size_override("font_size", fs)
	var outline: int = 2 if fs <= 12 else 3
	value_label.add_theme_constant_override("outline_size", outline)
	if uses_cylinder:
		_center_double_label(value_label)

static func _resize_visual(_item, color_rect, dims: Vector2, value_label: Label) -> void:
	var width := dims.x
	var height := dims.y
	if color_rect and color_rect is ColorRect:
		color_rect.position = Vector2(-width * 0.5, -height * 0.5)
		color_rect.size = Vector2(width, height)

	if value_label:
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
