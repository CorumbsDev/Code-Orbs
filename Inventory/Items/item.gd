extends Node2D

@onready var value_label: Label = $ColorRect/value_label
@onready var cylinder_visual: Node2D = $CylinderVisual

# Enum para identificar o tipo de dado do orb
enum DataType {INT, FLOAT, STRING, OPERATOR, DOUBLE, BINARY, SHORT_INT, FP8, FP16, RAW}

var item_ID : String
var data_type: DataType = DataType.INT  # Tipo padrão é INT
var value : int = 0
var value_float : float = 0.0
var value_string : String = ""
var value_double : float = 0.0  # Precisão dupla (ocupa 2 slots)
var value_short : int = 0
var value_binary : String = "00000000"  # Representação binária em string
var binary_bits : int = 8  # Quantidade de bits para o tipo BINARY
var operator : String = ""
var selected = false:
	set(v):
		var prev: bool = bool(selected)
		selected = bool(v)
		if prev != selected and BGMManager != null and BGMManager.has_method("play_orb_sfx"):
			BGMManager.play_orb_sfx()
var item_grids := [Vector2(0,0)]
var grid_anchor = null
var is_hovered = false  # Nova variável para rastrear hover

var fp_exp_bits: int = -1
var fp_mant_bits: int = -1

## Literal original do orbe RAW (ex.: "5", "5.0", "0.0") e posição em initial_raw_values.
var raw_literal: String = ""
var raw_index: int = -1

## Valor original (float64 exato) do orbe, usado para medir erro de conversão. Definido uma vez na criação.
var source_value: float = 0.0
var has_source_value: bool = false

## Degradação sofrida pelo orbe: "", "precision", "underflow" ou "overflow" (marca visual no próprio orbe).
var degradation_kind: String = ""
var _degradation_badge: Node2D = null
const DegradationBadgeScript = preload("res://Inventory/Items/degradation_badge.gd")

## Registra (e mostra no orbe) uma degradação. Mapeia truncamento/absorção para "precision".
## Aproximações em FP8/FP16 não recebem marca (esses tipos existem para aproximar);
## overflow e underflow sempre recebem. A marca é persistente e o estado mais grave prevalece.
func mark_degradation(kind: String) -> void:
	var k := kind
	match kind:
		"truncation", "precision", "absorption":
			k = "precision"
		"overflow", "underflow":
			k = kind
		_:
			return
	if k == "precision" and (data_type == DataType.FP8 or data_type == DataType.FP16):
		return
	var rank := {"": 0, "precision": 1, "underflow": 2, "overflow": 3}
	if int(rank[k]) <= int(rank.get(degradation_kind, 0)):
		return
	degradation_kind = k
	if _degradation_badge == null or not is_instance_valid(_degradation_badge):
		_degradation_badge = Node2D.new()
		_degradation_badge.set_script(DegradationBadgeScript)
		add_child(_degradation_badge)
	_degradation_badge.set_kind(degradation_kind)

var _preview_active: bool = false
var _preview_original_type: int = -1
var _preview_original_value_float: float = 0.0
var _preview_original_value: int = 0
var _preview_original_value_str: String = ""
var _preview_original_op: String = ""

## Tamanho visual de um slot na grade (deve bater com slot.gd).
const SLOT_PX := 64
const ORB_SLOT_MARGIN := 12

# Signal para notificar quando o mouse entra/sai
signal mouse_entered_item(item)
signal mouse_exited_item(item)

func _process(delta):
	if selected:
		global_position = lerp(global_position, get_global_mouse_position(), 25 * delta)
	
	check_mouse_hover()

func check_mouse_hover():
	if selected:
		if is_hovered:
			is_hovered = false
			mouse_exited_item.emit(self)
		return
	if hit_test_global(get_global_mouse_position()):
		if not is_hovered:
			is_hovered = true
			mouse_entered_item.emit(self)
	else:
		if is_hovered:
			is_hovered = false
			mouse_exited_item.emit(self)

## Hit-test em coordenadas globais (hover e clique usam a mesma área).
func hit_test_global(global_pos: Vector2) -> bool:
	return get_item_rect().has_point(to_local(global_pos))

func get_item_rect() -> Rect2:
	"""Retorna o retângulo do item para detecção de hover / clique baseado no visual real."""
	var rect := Rect2()
	if cylinder_visual and cylinder_visual.visible:
		var min_dim := float(SLOT_PX) * 0.75
		if grid_anchor is TextureRect and is_instance_valid(grid_anchor) and _slot_item_count(grid_anchor) > 1:
			min_dim = 16.0
		var w = maxf(cylinder_visual.draw_size.x, min_dim)
		var h = maxf(cylinder_visual.draw_size.y, min_dim)
		rect = Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h))
	else:
		var icon: TextureRect = get_node_or_null("Icon") as TextureRect
		if icon and icon.visible and icon.size.x > 1.0:
			rect = Rect2(icon.position, icon.size)
		elif value_label and value_label.visible:
			var cr = value_label.get_parent() as ColorRect
			if cr and cr.size.x > 1.0:
				rect = Rect2(cr.position, cr.size)
			else:
				rect = Rect2(value_label.position, value_label.size)
		else:
			var half: float = SLOT_PX * 0.5
			rect = Rect2(Vector2(-half, -half), Vector2(SLOT_PX, SLOT_PX))
	# Garante área mínima clicável (~um slot, ou sub-slot quando empilhado em palavra de 4B).
	var min_s := float(SLOT_PX) * 0.85
	if grid_anchor is TextureRect and is_instance_valid(grid_anchor) and _slot_item_count(grid_anchor) > 1:
		min_s = 16.0
	if rect.size.x < min_s or rect.size.y < min_s:
		var cx := rect.position.x + rect.size.x * 0.5
		var cy := rect.position.y + rect.size.y * 0.5
		var nw := maxf(rect.size.x, min_s)
		var nh := maxf(rect.size.y, min_s)
		rect = Rect2(Vector2(cx - nw * 0.5, cy - nh * 0.5), Vector2(nw, nh))
	return rect

func get_item_info() -> Dictionary:
	return ItemData.get_item_info(self)

func load_item(a_ItemID: String) -> void:
	# Não usar get_node("/root/...") aqui: o item ainda pode estar fora da árvore.
	ItemData.load_item(self, a_ItemID, DataHandler)
	_ensure_source_value()
	update_label_display()

func set_value_directly(new_value: int):
	value = new_value
	value_float = float(new_value)
	value_string = ""
	operator = ""
	data_type = DataType.INT
	item_ID = "item_number_" + str(new_value)
	_ensure_source_value()
	update_label_display()

func set_value_by_type(new_value, tipo: DataType):
	ItemData.set_value_by_type(self, new_value, tipo)
	_ensure_source_value()
	update_label_display()

## Valor numérico atual do orbe (conforme o tipo). Não numéricos retornam 0.0.
func get_numeric_value() -> float:
	match data_type:
		DataType.INT:
			return float(value)
		DataType.SHORT_INT:
			return float(value_short)
		DataType.DOUBLE:
			return value_double
		DataType.FLOAT, DataType.FP8, DataType.FP16, DataType.RAW:
			return value_float
		_:
			return 0.0

func _ensure_source_value() -> void:
	if has_source_value:
		return
	if data_type in [DataType.STRING, DataType.OPERATOR, DataType.BINARY]:
		return
	source_value = get_numeric_value()
	has_source_value = true

func show_typing_preview(target_type: DataType, preview_value: float, has_warning: bool) -> void:
	if not _preview_active:
		_preview_original_type = data_type
		_preview_original_value = value
		_preview_original_value_float = value_float
		_preview_original_value_str = value_string
		_preview_original_op = operator
		_preview_active = true
	
	ItemData.set_value_by_type(self, preview_value, target_type)
	update_label_display()
	
	if has_warning:
		modulate = Color(1.0, 0.4, 0.4, 0.9)
	else:
		modulate = Color(0.6, 1.0, 0.6, 0.9)

func hide_typing_preview() -> void:
	if not _preview_active:
		return
	_preview_active = false
	var restore_val: Variant
	if _preview_original_type in [DataType.FLOAT, DataType.DOUBLE, DataType.FP8, DataType.FP16, DataType.RAW]:
		restore_val = _preview_original_value_float
	else:
		restore_val = _preview_original_value
	ItemData.set_value_by_type(self, restore_val, _preview_original_type)
	if _preview_original_type == DataType.STRING:
		ItemData.set_value_by_type(self, _preview_original_value_str, _preview_original_type)
	elif _preview_original_type == DataType.OPERATOR:
		ItemData.set_value_by_type(self, _preview_original_op, _preview_original_type)
	update_label_display()
	modulate = Color(1, 1, 1, 1)

func get_value_as_string() -> String:
	return OrbValueFormat.full_value_string(self)

func set_operator_directly(new_operator: String):
	operator = new_operator
	data_type = DataType.OPERATOR
	value = 0
	value_float = 0.0
	value_string = ""
	item_ID = "item_operator_" + new_operator
	update_label_display()

func update_label_display():
	if not value_label:
		value_label = get_node_or_null("ColorRect/value_label")
	if not value_label:
		value_label = get_node_or_null("ValueLabel")
	if not value_label:
		var cr = get_node_or_null("ColorRect")
		if cr:
			value_label = cr.get_node_or_null("value_label")
	if not value_label:
		push_error("Nenhuma Label encontrada no item!")
		return

	if cylinder_visual == null:
		cylinder_visual = get_node_or_null("CylinderVisual") as Node2D

	var color_rect = value_label.get_parent() if value_label.get_parent() is ColorRect else null
	var icon = get_node_or_null("Icon") as TextureRect

	ItemVisuals.update_label_display(self, value_label, icon, cylinder_visual, color_rect)
	call_deferred("_ensure_centered_in_slot_parent")

func operator_display_label() -> String:
	return ItemVisuals.operator_display_label(self)

func _ensure_centered_in_slot_parent() -> void:
	if selected:
		return
	var mount: TextureRect = null
	if grid_anchor is TextureRect:
		mount = grid_anchor
	else:
		var p := get_parent()
		if p is TextureRect and p.is_in_group("slot"):
			mount = p
	if mount:
		position = position_in_slot(mount)

func _slot_item_count(slot: TextureRect) -> int:
	var n := 0
	for it in slot.items_stored:
		if it != null:
			n += 1
	return n

func shrink_orb_for_tool_slot() -> void:
	if cylinder_visual == null:
		cylinder_visual = get_node_or_null("CylinderVisual") as Node2D
	var color_rect = value_label.get_parent() if value_label else null
	ItemVisuals.shrink_orb_for_tool_slot(self, value_label, cylinder_visual, color_rect)

func restore_orb_layout() -> void:
	update_label_display()

## Slot unitário (conversor / inspetor / calc / caixa de tipagem): centro sem span da mochila.
func is_tool_slot(slot: TextureRect) -> bool:
	if slot == null or not is_instance_valid(slot):
		return false
	if slot.has_meta("is_tool_slot") or slot.has_meta("is_calc_result") \
			or slot.has_meta("is_type_box") or slot.has_meta("is_type_station"):
		return true
	# slot_ID é do script do Slot; get() evita erro de tipo em TextureRect.
	var sid: Variant = slot.get("slot_ID")
	if sid != null and int(sid) >= 900:
		return true
	return false

func center_in_slot(slot: TextureRect) -> Vector2:
	if slot == null:
		return Vector2.ZERO
	var side_x: float = slot.size.x if slot.size.x > 1.0 else float(SLOT_PX)
	var side_y: float = slot.size.y if slot.size.y > 1.0 else float(SLOT_PX)
	return Vector2(side_x, side_y) * 0.5

func position_in_slot(slot: TextureRect) -> Vector2:
	if slot == null:
		return Vector2.ZERO
	var anchor: TextureRect = slot
	if grid_anchor is TextureRect and is_instance_valid(grid_anchor):
		anchor = grid_anchor
	# Usa o tamanho real do slot (após layout); fallback SLOT_PX.
	var side_x: float = anchor.size.x if anchor.size.x > 1.0 else float(SLOT_PX)
	var side_y: float = anchor.size.y if anchor.size.y > 1.0 else float(SLOT_PX)
	var center: Vector2 = Vector2(side_x, side_y) * 0.5
	# Ferramentas / caixas de tipagem / pool unitário: sempre o centro do slot.
	if is_tool_slot(anchor) or anchor.has_meta("is_pool"):
		return center
	var item_bytes: int = get_size_bytes() if has_method("get_size_bytes") else 4
	var sb := MemoryLayout.WORD_BYTES
	if anchor.get("slot_bytes") != null:
		sb = MemoryLayout.normalize_slot_bytes(int(anchor.get("slot_bytes")))
	elif has_meta("slot_bytes"):
		sb = MemoryLayout.normalize_slot_bytes(int(get_meta("slot_bytes")))

	# Quando o item ocupa múltiplos slots na grade (slot de 1B ou DOUBLE em slot de 4B),
	# posiciona no centro geométrico exato de todos os slots que ele ocupa.
	if item_grids.size() > 1 or sb == MemoryLayout.BYTE_SLOT:
		var span_x := 0
		var span_y := 0
		for g in item_grids:
			span_x = maxi(span_x, int(g.x))
			span_y = maxi(span_y, int(g.y))
		if span_x >= 1 or span_y >= 1:
			var sep_x := 4.0
			var sep_y := 4.0
			var gp: Node = anchor.get_parent()
			if gp is GridContainer:
				var gc: GridContainer = gp as GridContainer
				sep_x = float(gc.get_theme_constant("h_separation"))
				sep_y = float(gc.get_theme_constant("v_separation"))
			var total_w := float(span_x + 1) * side_x + float(span_x) * sep_x
			var total_h := float(span_y + 1) * side_y + float(span_y) * sep_y
			return Vector2(total_w * 0.5, total_h * 0.5)
		return center

	if data_type == DataType.OPERATOR or data_type == DataType.RAW or item_bytes >= 4:
		return center
	var current_grid: Array = [null, null, null, null]
	var my_pos: int = 0
	for it in anchor.items_stored:
		var sz: int = it.get_size_bytes() if it.has_method("get_size_bytes") else 4
		var pos_found: int = 0
		if sz >= 4:
			current_grid[0] = it
			current_grid[1] = it
			current_grid[2] = it
			current_grid[3] = it
			pos_found = 0
		elif sz == 2:
			if current_grid[0] == null and current_grid[1] == null:
				current_grid[0] = it
				current_grid[1] = it
				pos_found = 0
			elif current_grid[2] == null and current_grid[3] == null:
				current_grid[2] = it
				current_grid[3] = it
				pos_found = 2
		elif sz <= 1:
			for i in range(4):
				if current_grid[i] == null:
					current_grid[i] = it
					pos_found = i
					break
		if it == self:
			my_pos = pos_found
			break
	var quarter: float = maxf(anchor.size.x, SLOT_PX) * 0.25
	var offset := Vector2.ZERO
	if item_bytes <= 1:
		match my_pos:
			0: offset = Vector2(-quarter * 1.5, 0)
			1: offset = Vector2(-quarter * 0.5, 0)
			2: offset = Vector2(quarter * 0.5, 0)
			3: offset = Vector2(quarter * 1.5, 0)
	elif item_bytes == 2:
		offset = Vector2(-quarter, 0) if my_pos == 0 else Vector2(quarter, 0)
	return center + offset

func install_in_slot(slot: TextureRect) -> void:
	if slot == null:
		return
	grid_anchor = slot
	snap_to_slot(slot)

func snap_to_slot(slot: TextureRect) -> void:
	if slot == null:
		return
	# Sempre usa o slot pedido como âncora (senão o orbe volta pro slot antigo
	# e some no Inspecionar/Calculadora/Conversor).
	grid_anchor = slot
	var mount: TextureRect = slot
	if get_parent() != mount:
		var p := get_parent()
		if p:
			p.remove_child(self)
		mount.add_child(self)
	selected = false
	# Recalcula visual (span ↔ largura) antes de medir o centro.
	if has_method("update_label_display"):
		update_label_display()
	var target := Vector2.ZERO
	if is_tool_slot(mount):
		# update_label_display reabre a cápsula larga — reencolhe e centra no slot único.
		shrink_orb_for_tool_slot()
		target = center_in_slot(mount)
		if mount.size.x <= 1.0 or mount.size.y <= 1.0:
			position = target
			call_deferred("_deferred_tool_recenter", mount)
			return
	else:
		target = position_in_slot(mount)
	position = target
	var tween := create_tween()
	tween.tween_property(self, "position", target, 0.08).set_trans(Tween.TRANS_SINE)


func _deferred_tool_recenter(slot: TextureRect) -> void:
	if slot == null or not is_instance_valid(slot) or not is_instance_valid(self):
		return
	if get_parent() != slot:
		return
	shrink_orb_for_tool_slot()
	position = center_in_slot(slot)

func _snap_to(_destination_global: Vector2) -> void:
	if grid_anchor != null and grid_anchor is TextureRect:
		snap_to_slot(grid_anchor)
		return
	selected = false

func int_to_binary(val: int, bits: int) -> String:
	return ItemData.int_to_binary(val, bits)

func binary_to_int(bin_str: String) -> int:
	return ItemData.binary_to_int(bin_str)

func get_size_bytes() -> int:
	return ItemData.get_size_bytes(self)

func get_binary_explanation(bin_str: String) -> String:
	return ItemData.get_binary_explanation(bin_str)
