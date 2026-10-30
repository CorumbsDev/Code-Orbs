extends "res://Inventory/fases/phase_base.gd"

var config: TypeBoxPhaseConfig

var type_boxes: Dictionary = {} # { DataType : { container: HBoxContainer, slots: Array, used_bytes: int } }
var global_capacity: int = 8

var pending_raw_values: int = 0
var all_slots: Array = []
## Marcado quando o jogador tenta tipar valor incompatível (conquista square_peg).
var _square_peg_triggered: bool = false

@onready var boxes_vbox = VBoxContainer.new()

func _ready():
	super._ready()
	
	# Pega o config do PhaseRunner
	if PhaseRunner.has_method("take_type_box_config_if_any"):
		config = PhaseRunner.take_type_box_config_if_any()
		
	if not config:
		config = TypeBoxPhaseConfig.new()
		config.initial_raw_values = PackedStringArray(["250", "3.14", "1"])
		config.capacity_bytes = 8
		config.slots_int = 2
		config.slots_float = 3
		config.slots_short = 0
		config.randomize_values = false
		config.apply_constraints()
		
	global_capacity = config.capacity_bytes
	
	# Limpa a área da mochila para colocar nossas caixas
	for child in backpack_container.get_parent().get_children():
		if child == backpack_container:
			child.queue_free()
			
	all_slots.clear()
	
	boxes_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boxes_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	$HBox/BackpackPanel/MarginContainer/VBoxContainer/ScrollContainer.add_child(boxes_vbox)
	
	_create_boxes()
	_populate_pool()
	_update_bytes_label()
	_update_hint()
	call_deferred("_apply_panel_art")

func _process(delta):
	if _is_finishing:
		return
		
	# Detect mouse hover manually
	var new_current = null
	var mouse_pos = get_global_mouse_position()
	for slot in all_slots:
		if slot.get_global_rect().has_point(mouse_pos):
			new_current = slot
			break
			
	if current_slot != new_current:
		if current_slot:
			_on_box_slot_exited(current_slot)
		if new_current:
			if new_current.has_meta("is_type_box"):
				_on_box_slot_entered(new_current)
			elif new_current.has_meta("is_pool"):
				_on_pool_slot_entered(new_current)

	if item_held:
		item_held.global_position = lerp(item_held.global_position, get_global_mouse_position(), 25 * delta)
		if Input.is_action_just_pressed("select_item"):
			if _click_blocked_by_ui():
				return
			if current_slot and can_place:
				_place_item()
	else:
		if Input.is_action_just_pressed("select_item"):
			if _click_blocked_by_ui():
				return
			if current_slot and current_slot.item_stored != null:
				_pick_item()
func _tutorial_intro_id() -> String:
	return "type_box_phase_intro"

func _get_phase_config():
	return config

func _create_boxes():
	for child in boxes_vbox.get_children():
		child.queue_free()
		
	var type_list = [
		{"type": ItemRef.DataType.INT, "name": "Int", "color": Color(0.3, 0.8, 1.0), "slots": config.slots_int},
		{"type": ItemRef.DataType.SHORT_INT, "name": "Short", "color": Color(0.5, 0.9, 1.0), "slots": config.slots_short},
		{"type": ItemRef.DataType.FLOAT, "name": "Float", "color": Color(1.0, 0.45, 0.35), "slots": config.slots_float},
		{"type": ItemRef.DataType.DOUBLE, "name": "Double", "color": Color(0.9, 0.4, 0.9), "slots": config.slots_double},
		{"type": ItemRef.DataType.FP8, "name": "FP8", "color": Color.WHITE, "slots": config.slots_fp8},
		{"type": ItemRef.DataType.FP16, "name": "FP16", "color": Color(1.0, 0.85, 0.3), "slots": config.slots_fp16}
	]
	
	var row_idx := 0
	for t in type_list:
		var slot_count: int = t.slots
		if slot_count <= 0:
			continue
			
		var row_container = HBoxContainer.new()
		row_container.add_theme_constant_override("separation", 10)
		row_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var title_holder := Control.new()
		title_holder.custom_minimum_size = Vector2(100, 48)
		title_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var title = Label.new()
		title.text = "Linha %s:" % t.name
		title.set_anchors_preset(Control.PRESET_FULL_RECT)
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.add_theme_color_override("font_color", t.color)
		title.add_theme_font_size_override("font_size", 16)
		title_holder.add_child(title)
		row_container.add_child(title_holder)
		
		var slot_container = HBoxContainer.new()
		slot_container.add_theme_constant_override("separation", 8)
		row_container.add_child(slot_container)
		
		for c in range(slot_count):
			var slot = preload("res://Inventory/slots/slot.tscn").instantiate()
			slot.set_meta("is_type_box", true)
			slot.set_meta("is_tool_slot", true) # mesmo centro/encolhe do Conversor
			slot.set_meta("box_type", t.type)
			slot.set_meta("box_name", t.name)
			slot.set_meta("row_index", row_idx)
			slot.set_meta("col_index", c)
			slot.item_stored = null
			
			slot_container.add_child(slot)
			all_slots.append(slot)
			
		boxes_vbox.add_child(row_container)
		row_idx += 1

func _populate_pool():
	# Criamos um InventoryGrid dinâmico para o Pool se não existir, ou usamos o base
	var pool_grid_node = pool_container
	# Limpar itens do pool
	for child in pool_grid_node.get_children():
		child.queue_free()
		
	pending_raw_values = 0
	
	var values_to_spawn = []
	if config.randomize_values:
		# Gera 4 valores desafiadores aleatórios
		for r in range(4):
			var case_type = randi() % 4
			match case_type:
				0: values_to_spawn.append("%.4f" % randf_range(-1.0, 1.0)) # Exige float ou double (muita precisão)
				1: values_to_spawn.append(str(randi_range(33000, 50000))) # Estoura short_int, exige int
				2: values_to_spawn.append(str(randi_range(0, 1)))
				3: values_to_spawn.append("%.1f" % randf_range(100.0, 1000.0)) # Float comum
	else:
		values_to_spawn = config.initial_raw_values
	
	for raw_idx in range(values_to_spawn.size()):
		var raw_val_str = values_to_spawn[raw_idx]
		var slot = preload("res://Inventory/slots/slot.tscn").instantiate()
		slot.set_meta("is_pool", true)
		slot.item_stored = null
		
		var item = preload("res://Inventory/Items/Item.tscn").instantiate()
		var s := str(raw_val_str).strip_edges()
		item.raw_index = raw_idx
		if s.ends_with("_i") or s.ends_with("_f") or s.ends_with("_d") or s.ends_with("_s") \
				or s.ends_with("_fp8") or s.ends_with("_fp16") or s.ends_with("_q") or s.ends_with("_h") \
				or s.begins_with("item_"):
			item.load_item(s)
			item.raw_literal = OrbValueFormat.compact_label_string(item)
		else:
			var clean_s := s.trim_suffix("_r")
			item.data_type = ItemRef.DataType.RAW
			item.value_float = float(clean_s)
			item.raw_literal = clean_s
		item.update_label_display()
		
		slot.add_child(item)
		item.position = Vector2(32, 32) # center
		slot.item_stored = item
		
		pool_grid_node.add_child(slot)
		all_slots.append(slot)
		if item.data_type == ItemRef.DataType.RAW:
			pending_raw_values += 1
		_wire_orb(item)

	call_deferred("_wire_typebox_hover")

func _wire_typebox_hover() -> void:
	# Garante que a barra "Passe o mouse..." atualiza com os orbes desta fase.
	for slot in all_slots:
		if slot == null or not is_instance_valid(slot):
			continue
		if slot.item_stored != null:
			_wire_orb(slot.item_stored)
	_anchor_orb_hover_above_pool()

func _on_box_slot_entered(slot):
	current_slot = slot
	can_place = _can_place_in_slot(slot)
	if item_held and can_place and slot.has_meta("box_type"):
		var target_type: int = slot.get_meta("box_type")
		var target_name := _get_type_name(target_type)
		var val_to_convert := TypeConversionSystem.value_for_conversion(item_held)
		var deg = TypeConversionSystem.check_degradation(target_name, val_to_convert, config)
		if item_held.has_method("show_typing_preview"):
			item_held.show_typing_preview(target_type, deg.degraded_value, deg.has_warning)

func _on_pool_slot_entered(slot):
	current_slot = slot
	can_place = _can_place_in_slot(slot)

func _can_place_in_slot(slot) -> bool:
	if not item_held or not is_instance_valid(item_held):
		return false
	if slot.has_meta("is_type_box"):
		return slot.item_stored == null
	if slot.has_meta("is_pool"):
		return slot.item_stored == null
	return false

func _byte_size_for_type(target_type, val: float) -> int:
	var probe := preload("res://Inventory/Items/Item.tscn").instantiate()
	probe.set_value_by_type(val, target_type)
	var size_bytes: int = int(probe.get_size_bytes()) if probe.has_method("get_size_bytes") else 0
	probe.queue_free()
	return size_bytes

func _projected_bytes_if_typed(target_type, val: float) -> int:
	return total_bytes_used() + _byte_size_for_type(target_type, val)

func _show_capacity_dialog(used: int, add: int) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Capacidade excedida"
	var pool_left := _count_pool_items()
	if item_held != null and is_instance_valid(item_held):
		pool_left += 1
	var extra := ""
	if used >= global_capacity and pool_left > 0:
		extra = (
			"\n\nAinda falta usar %d orbe(s) da bancada. Os bytes já estão no limite — "
			% pool_left
			+ "retire um orbe das caixas e escolha o tipo certo (Int para inteiros, Float para decimais)."
		)
	dlg.dialog_text = (
		"Não cabe nesta fase!\n\n"
		+ "Você tem %d / %d bytes nas caixas.\n" % [used, global_capacity]
		+ "Este orbe tipado ocuparia mais %d bytes.\n\n" % add
		+ "Use o tipo adequado ao valor ou tire um orbe das caixas."
		+ extra
	)
	add_child(dlg)
	dlg.popup_centered(Vector2(420, 180))
	await _wait_accept_dialog(dlg)
	dlg.queue_free()

func _on_box_slot_exited(slot):
	if current_slot == slot:
		if item_held and item_held.has_method("hide_typing_preview"):
			item_held.hide_typing_preview()
		current_slot = null
		can_place = false
		_update_hint()

func _count_type_in_all_boxes(t: int) -> int:
	var count := 0
	for s in all_slots:
		if is_instance_valid(s) and s.has_meta("is_type_box"):
			var it = s.item_stored
			if it and is_instance_valid(it) and it.data_type == t:
				count += 1
	return count

func _place_item():
	if not can_place or not current_slot: return
	
	if item_held and item_held.has_method("hide_typing_preview"):
		item_held.hide_typing_preview()
	
	var prev_source = _source_slot
	
	if current_slot.has_meta("is_type_box"):
		if current_slot.item_stored != null:
			return
			
		var target_type: int = current_slot.get_meta("box_type")
		var was_raw: bool = item_held.data_type == ItemRef.DataType.RAW
		var target_name := _get_type_name(target_type)
		var val_to_convert := TypeConversionSystem.value_for_conversion(item_held)
		var deg = TypeConversionSystem.check_degradation(target_name, val_to_convert, config)
		if deg.has_warning:
			_square_peg_triggered = true
			if AchievementManager:
				AchievementManager.note_runtime_event("square_peg")
			var dlg = AcceptDialog.new()
			dlg.dialog_text = "FALHA NA CONVERSÃO!\n" + deg.message + "\n\nO valor " + str(val_to_convert) + " não é adequado para " + target_name + "."
			dlg.title = "Erro de Tipagem"
			add_child(dlg)
			dlg.popup_centered(Vector2(400, 150))
			await _wait_accept_dialog(dlg)
			dlg.queue_free()
			return
		
		var final_val = deg.degraded_value
		item_held.set_value_by_type(final_val, target_type)
		_mount_orb_in_single_slot(current_slot, item_held)
		current_slot.item_stored = item_held
		_wire_orb(current_slot.item_stored)
		item_held = null
		can_place = false
		if was_raw:
			pending_raw_values = maxi(0, pending_raw_values - 1)
		
		_update_bytes_label()
		_update_hint()
		_update_next_button_state()
		
	elif current_slot.has_meta("is_pool"):
		if current_slot.item_stored != null:
			return
			
		if item_held.data_type != ItemRef.DataType.RAW:
			item_held.set_value_by_type(item_held.value_float, ItemRef.DataType.RAW)
			pending_raw_values += 1
			if item_held.has_method("restore_orb_layout"):
				item_held.restore_orb_layout()
			else:
				item_held.update_label_display()
			
		_mount_orb_in_single_slot(current_slot, item_held)
		current_slot.item_stored = item_held
		_wire_orb(current_slot.item_stored)
		item_held = null
		can_place = false
		
		_update_bytes_label()
		_update_hint()
		_update_next_button_state()
		
	if item_held == null and prev_source != current_slot:
		moves_count += 1


## Centraliza (e encolhe double) no slot unitário — igual Conversor/Inspecionar.
func _mount_orb_in_single_slot(slot: TextureRect, item: Node) -> void:
	if slot == null or item == null or not is_instance_valid(item):
		return
	item.set("grid_anchor", slot)
	if item.get_parent() != slot:
		if item.get_parent():
			item.get_parent().remove_child(item)
		slot.add_child(item)
	item.set("selected", false)
	if item.has_method("snap_to_slot"):
		item.snap_to_slot(slot)
	elif item.has_method("center_in_slot"):
		if item.has_method("shrink_orb_for_tool_slot"):
			item.shrink_orb_for_tool_slot()
		item.position = item.center_in_slot(slot)
	else:
		item.position = Vector2(32, 32)

		
func _pick_item():
	var slot = current_slot
	_source_slot = slot
	var mouse_pos := get_global_mouse_position()
	if slot.has_method("pop_item_for_drag"):
		item_held = slot.pop_item_for_drag(mouse_pos, self)
	else:
		item_held = slot.pick_item_at(mouse_pos) if slot.has_method("pick_item_at") else slot.item_stored
		if item_held:
			item_held.selected = true
			if item_held.get_parent():
				item_held.get_parent().remove_child(item_held)
			add_child(item_held)
			item_held.global_position = mouse_pos
			if item_held.has_method("restore_orb_layout"):
				item_held.restore_orb_layout()
			if slot.has_method("set_item"):
				slot.set_item(null)
			slot.item_stored = null
			slot.state = slot.States.FREE
	if not item_held:
		return
	_update_bytes_label()
	_update_hint()
	_update_next_button_state()

func _byte_limit_enabled() -> bool:
	return false

func _all_typed_backpack_items() -> Array:
	var items: Array = []
	for slot in all_slots:
		if is_instance_valid(slot) and slot.has_meta("is_type_box"):
			var it = slot.item_stored
			if it and is_instance_valid(it) and it.data_type != ItemRef.DataType.RAW:
				items.append(it)
	return items

func total_bytes_used() -> int:
	var total = 0
	for item in _all_typed_backpack_items():
		if is_instance_valid(item) and item.has_method("get_size_bytes"):
			total += item.get_size_bytes()
	return total

func _update_bytes_label():
	if bytes_label:
		bytes_label.text = "Coloque os orbes e escolha o tipo correto."
	_update_hint()

func _count_pool_items() -> int:
	var count := 0
	for s in all_slots:
		if is_instance_valid(s) and s.has_meta("is_pool"):
			if s.item_stored != null and is_instance_valid(s.item_stored):
				count += 1
	return count

func _update_hint() -> void:
	if not hint_label:
		return
	if is_phase_success():
		hint_label.text = "Objetivo concluído! Todos os orbes da bancada foram utilizados."
		hint_label.visible = true
	else:
		var pool_left := _count_pool_items()
		if item_held != null and is_instance_valid(item_held):
			pool_left += 1
		if pool_left > 0:
			hint_label.text = "Falta usar %d orbe(s) da bancada." % pool_left
			hint_label.visible = true
		else:
			hint_label.visible = false
	_update_next_button_state()

func _update_next_button_state() -> void:
	if not btn_proxima:
		return
	var success = is_phase_success()
	btn_proxima.disabled = not success

	if phase_progress_label:
		if success:
			phase_progress_label.text = "Fase Concluída! Você pode avançar."
			phase_progress_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			var pool_left := _count_pool_items()
			if item_held != null and is_instance_valid(item_held):
				pool_left += 1
			if pool_left > 0:
				phase_progress_label.text = "Falta usar %d orbe(s) da bancada." % pool_left
				phase_progress_label.add_theme_color_override("font_color", Color.YELLOW)
			else:
				phase_progress_label.text = "Posicione os orbes nas caixas de tipos correspondentes."
				phase_progress_label.add_theme_color_override("font_color", Color.LIGHT_CORAL)

func is_phase_success() -> bool:
	if moves_count <= 0:
		return false
	if item_held != null and is_instance_valid(item_held):
		return false
	if _count_pool_items() > 0:
		return false
	if _all_typed_backpack_items().is_empty():
		return false
	for t_idx in [ItemRef.DataType.INT, ItemRef.DataType.SHORT_INT, ItemRef.DataType.FLOAT, ItemRef.DataType.DOUBLE, ItemRef.DataType.FP8, ItemRef.DataType.FP16]:
		if _count_type_in_all_boxes(t_idx) > config.get_slots_for_type(t_idx):
			return false
	return true

func _typed_items_in_boxes() -> Array:
	return _all_typed_backpack_items()

func _item_numeric_value(item) -> float:
	if item.data_type in [ItemRef.DataType.FLOAT, ItemRef.DataType.DOUBLE, ItemRef.DataType.FP8, ItemRef.DataType.FP16, ItemRef.DataType.RAW]:
		return float(item.value_float)
	return float(item.value)

func _raw_values_match(item_val: float, target_str: String) -> bool:
	var clean := target_str.trim_suffix("_i").trim_suffix("_f").trim_suffix("_d").trim_suffix("_s").trim_suffix("_fp8").trim_suffix("_fp16").trim_suffix("_r")
	var target := float(clean)
	if is_equal_approx(item_val, target):
		return true
	var tolerance: float = maxf(0.0001, absf(target) * 1e-4)
	return absf(item_val - target) <= tolerance

func _parse_expected_type(type_str: String) -> int:
	match type_str.strip_edges().to_lower():
		"int":
			return ItemRef.DataType.INT
		"short", "short_int":
			return ItemRef.DataType.SHORT_INT
		"float":
			return ItemRef.DataType.FLOAT
		"double":
			return ItemRef.DataType.DOUBLE
		"fp8":
			return ItemRef.DataType.FP8
		"fp16":
			return ItemRef.DataType.FP16
		_:
			return -1

func _solution_types_valid() -> bool:
	if config == null or config.expected_solution_types.is_empty():
		return true
	if config.randomize_values:
		return true
	var expected := config.expected_solution_types
	var raw_vals := config.initial_raw_values
	var n := mini(expected.size(), raw_vals.size())
	if n == 0:
		return true
	var placed := _typed_items_in_boxes()
	if placed.size() != n:
		return false
	# Validação por índice: o orbe i precisa estar exatamente na caixa expected_solution_types[i].
	if expected.size() == raw_vals.size():
		var all_indexed := true
		for it in placed:
			if int(it.raw_index) < 0 or int(it.raw_index) >= expected.size():
				all_indexed = false
				break
		if all_indexed:
			for it in placed:
				var t_idx := _parse_expected_type(str(expected[int(it.raw_index)]))
				if t_idx >= 0 and it.data_type != t_idx:
					return false
			return true
	var used_indices: Dictionary = {}
	for i in range(n):
		var target_type := _parse_expected_type(str(expected[i]))
		if target_type < 0:
			continue
		var found := false
		for j in range(placed.size()):
			if used_indices.has(j):
				continue
			var item = placed[j]
			if item.data_type != target_type:
				continue
			if not _raw_values_match(_item_numeric_value(item), str(raw_vals[i])):
				continue
			used_indices[j] = true
			found = true
			break
		if not found:
			return false
	return true

func _wait_accept_dialog(dlg: AcceptDialog) -> void:
	var done := [false]
	dlg.confirmed.connect(func(): done[0] = true)
	dlg.close_requested.connect(func(): done[0] = true)
	if dlg.has_signal("canceled"):
		dlg.canceled.connect(func(): done[0] = true)
	while not done[0]:
		await get_tree().process_frame

func _get_type_name(dt) -> String:
	if dt == ItemRef.DataType.INT: return "Int"
	if dt == ItemRef.DataType.SHORT_INT: return "Short"
	if dt == ItemRef.DataType.FLOAT: return "Float"
	if dt == ItemRef.DataType.DOUBLE: return "Double"
	if dt == ItemRef.DataType.FP8: return "FP8"
	if dt == ItemRef.DataType.FP16: return "FP16"
	return "Desconhecido"

## Tipo esperado (DataType) para o orbe pelo raw_index, ou -1 se não houver expectativa.
func _expected_type_for_item(item) -> int:
	if config == null or config.expected_solution_types.is_empty():
		return -1
	var idx := int(item.raw_index)
	if idx < 0 or idx >= config.expected_solution_types.size():
		return -1
	return _parse_expected_type(str(config.expected_solution_types[idx]))

func _has_integer_in_float_box() -> bool:
	var float_types = [ItemRef.DataType.FLOAT, ItemRef.DataType.DOUBLE, ItemRef.DataType.FP8, ItemRef.DataType.FP16]
	for item in _all_typed_backpack_items():
		if item.data_type not in float_types:
			continue
		if "." in str(item.raw_literal):
			continue
		if _expected_type_for_item(item) == item.data_type:
			continue
		var val = _item_numeric_value(item)
		if is_equal_approx(val, roundf(val)):
			return true
	return false

func _show_victory_overlay():
	var cfg = _get_phase_config()
	var s1 := true
	var s2 := true
	var s3 := true
	var desc := "Movimentos: %d" % moves_count
	if _has_integer_in_float_box():
		s1 = false

	if not cfg or not ("star2_max_moves" in cfg):
		if not s1:
			desc += "\nEstrela 1 perdida: valor inteiro colocado em caixa flutuante."
		_earned_stars = int(s1) + 2
		_present_victory_overlay(s1, true, true, desc)
		return

	# Só chega aqui se is_phase_success() == true (objetivo feito de verdade).
	if cfg.star2_max_moves > 0:
		s2 = moves_count <= cfg.star2_max_moves

	var star3_csv := ""
	if "star3_best_solution_csv" in cfg:
		star3_csv = str(cfg.star3_best_solution_csv).strip_edges()
	if star3_csv != "":
		s3 = _check_star3_solution(star3_csv)
	elif "expected_solution_types" in cfg:
		var expected: PackedStringArray = cfg.expected_solution_types
		if not expected.is_empty():
			s3 = _solution_types_valid()

	if cfg.star2_max_moves > 0:
		desc += " (meta estrela 2: ≤ %d)" % cfg.star2_max_moves
	if not s1:
		desc += "\nEstrela 1 perdida: valor inteiro colocado em caixa flutuante."

	_earned_stars = int(s1) + int(s2) + int(s3)
	_present_victory_overlay(s1, s2, s3, desc)
