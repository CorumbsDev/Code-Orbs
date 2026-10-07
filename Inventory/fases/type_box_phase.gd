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
		config.box_slot_count = 5
		config.randomize_values = false
		config.allow_int = true
		config.allow_float = true
		config.allow_short = true
		
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
	const BOX_TITLE_WIDTH := 136
	var types = []
	if config.allow_int: types.append({"type": ItemRef.DataType.INT, "name": "Int", "color": Color.BLUE})
	if config.allow_short: types.append({"type": ItemRef.DataType.SHORT_INT, "name": "Short", "color": Color.CYAN})
	if config.allow_float: types.append({"type": ItemRef.DataType.FLOAT, "name": "Float", "color": Color.RED})
	if config.allow_double: types.append({"type": ItemRef.DataType.DOUBLE, "name": "Double", "color": Color.MAGENTA})
	if config.allow_fp8: types.append({"type": ItemRef.DataType.FP8, "name": "FP8", "color": Color.VIOLET})
	if config.allow_fp16: types.append({"type": ItemRef.DataType.FP16, "name": "FP16", "color": Color.GOLD})
	
	for t in types:
		var box_container = HBoxContainer.new()
		box_container.add_theme_constant_override("separation", 8)
		
		var title_holder := Control.new()
		title_holder.custom_minimum_size = Vector2(BOX_TITLE_WIDTH, 32)
		title_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var title = Label.new()
		title.text = "Caixa " + t.name
		title.add_theme_color_override("font_color", t.color)
		title.set_anchors_preset(Control.PRESET_FULL_RECT)
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.clip_text = true
		title_holder.add_child(title)
		box_container.add_child(title_holder)
		
		var slot_container = GridContainer.new()
		slot_container.columns = min(config.box_slot_count, 8) # Quebra linha após 8
		box_container.add_child(slot_container)
		
		# Criar slots base para cada caixa usando a configuração
		var slots = []
		for i in range(config.box_slot_count):
			var slot = preload("res://Inventory/slots/slot.tscn").instantiate()
			slot.modulate = t.color
			slot.self_modulate = Color(1.2, 1.2, 1.2) # Realça um pouco
			
			# Usamos meta para identificar a caixa e o tipo
			slot.set_meta("is_type_box", true)
			slot.set_meta("box_type", t.type)
			slot.set_meta("box_name", t.name)
			slot.item_stored = null
			
			slot_container.add_child(slot)
			slots.append(slot)
			all_slots.append(slot)
			
		type_boxes[t.type] = {
			"container": box_container,
			"slots": slots,
			"used_bytes": 0,
			"type_name": t.name
		}
		
		boxes_vbox.add_child(box_container)

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
	
	for raw_val_str in values_to_spawn:
		var slot = preload("res://Inventory/slots/slot.tscn").instantiate()
		slot.set_meta("is_pool", true)
		slot.item_stored = null
		
		var item = preload("res://Inventory/Items/Item.tscn").instantiate()
		item.data_type = ItemRef.DataType.RAW
		item.value_float = float(raw_val_str)
		item.update_label_display()
		
		slot.add_child(item)
		item.position = Vector2(32, 32) # center
		slot.item_stored = item
		
		pool_grid_node.add_child(slot)
		all_slots.append(slot)
		pending_raw_values += 1

func _on_box_slot_entered(slot):
	current_slot = slot
	can_place = _can_place_in_slot(slot)
	if can_place and item_held and slot.has_meta("is_type_box"):
		_show_typing_preview(slot)

func _on_pool_slot_entered(slot):
	current_slot = slot
	can_place = _can_place_in_slot(slot)

func _can_place_in_slot(slot) -> bool:
	if not item_held or not is_instance_valid(item_held):
		return false
	if slot.has_meta("is_type_box"):
		if slot.item_stored != null:
			return false
		if item_held.data_type == ItemRef.DataType.RAW:
			return true
		return true
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
	var extra := ""
	if used >= global_capacity and pending_raw_values > 0:
		extra = (
			"\n\nAinda falta tipar %d orb(s). Os bytes já estão no limite — "
			% pending_raw_values
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

func _show_typing_preview(slot) -> void:
	if not item_held or not item_held.has_method("show_typing_preview"): return
	var target_type = slot.get_meta("box_type")
	var target_name = slot.get_meta("box_name")
	var val_to_convert := TypeConversionSystem.value_for_conversion(item_held)
	var deg = TypeConversionSystem.check_degradation(target_name, val_to_convert, config)
	item_held.show_typing_preview(target_type, deg.degraded_value, deg.has_warning)

func _place_item():
	if not can_place or not current_slot: return
	
	if item_held and item_held.has_method("hide_typing_preview"):
		item_held.hide_typing_preview()
	
	var prev_source = _source_slot
	
	if current_slot.has_meta("is_type_box"):
		if current_slot.item_stored != null:
			return
			
		var was_raw: bool = item_held.data_type == ItemRef.DataType.RAW
		var target_type = current_slot.get_meta("box_type")
		var target_name = current_slot.get_meta("box_name")
		var val_to_convert := TypeConversionSystem.value_for_conversion(item_held)
		var deg = TypeConversionSystem.check_degradation(target_name, val_to_convert, config)
		if deg.has_warning:
			# FASE FALHA se houver degradação em caixa de tipagem
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
			
			# Retorna item pro pool (simplesmente resetar a posição para o mouse não basta, precisa de um slot do pool)
			# Para simplificar, deixa ele no mouse e não finaliza a colocação
			return
		
		var final_val = deg.degraded_value
		var used_before := total_bytes_used()
		var projected := _projected_bytes_if_typed(target_type, final_val)
		if projected > global_capacity:
			var add_bytes: int = _byte_size_for_type(target_type, final_val)
			await _show_capacity_dialog(used_before, add_bytes)
			return

		item_held.set_value_by_type(final_val, target_type)
		item_held.update_label_display()
		
		if item_held.get_parent() != current_slot:
			item_held.get_parent().remove_child(item_held)
			current_slot.add_child(item_held)
			
		item_held.position = Vector2(32, 32)
		current_slot.item_stored = item_held
		item_held.selected = false
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
			# Reverte para RAW se estava em uma caixa
			item_held.set_value_by_type(item_held.value_float, ItemRef.DataType.RAW)
			pending_raw_values += 1
			
		if item_held.get_parent() != current_slot:
			item_held.get_parent().remove_child(item_held)
			current_slot.add_child(item_held)
			
		item_held.position = Vector2(32, 32)
		current_slot.item_stored = item_held
		item_held.selected = false
		item_held = null
		can_place = false
		
		_update_bytes_label()
		_update_hint()
		_update_next_button_state()
		
	if item_held == null and prev_source != current_slot:
		moves_count += 1
		
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
			slot.set_item(null)
			slot.state = slot.States.FREE
	if not item_held:
		return
	if slot.has_meta("is_type_box"):
		_update_bytes_label()
		_update_hint()
		_update_next_button_state()

func total_bytes_used() -> int:
	var total = 0
	for type_info in type_boxes.values():
		for slot in type_info.slots:
			if not is_instance_valid(slot):
				continue
			var item = slot.item_stored
			if item and is_instance_valid(item) and item.has_method("get_size_bytes"):
				total += item.get_size_bytes()
	return total

func _update_bytes_label():
	var used = total_bytes_used()
	var cap = global_capacity
	if bytes_label:
		bytes_label.text = "Total nas caixas: %d / %d bytes" % [used, cap]
	_update_hint()

func _update_hint() -> void:
	if not hint_label:
		return
	if is_phase_success():
		hint_label.text = "Objetivo concluído!"
		hint_label.visible = true
	else:
		var used := total_bytes_used()
		if pending_raw_values > 0 and used >= global_capacity:
			hint_label.text = (
				"%d / %d bytes, mas ainda falta tipar %d orb(s). "
				% [used, global_capacity, pending_raw_values]
				+ "Clique num orbe nas caixas para devolver ao pool e tipar o que falta."
			)
			hint_label.visible = true
		elif pending_raw_values > 0:
			hint_label.text = "Falta tipar %d orb(s) nas caixas." % pending_raw_values
			hint_label.visible = true
		elif used == global_capacity and pending_raw_values == 0 and not _solution_types_valid():
			hint_label.text = "Bytes corretos, mas algum valor está na caixa errada — use Int nos inteiros e Float no decimal."
			hint_label.visible = true
		elif used > global_capacity:
			hint_label.text = "Capacidade excedida — retire um orbe ou use o tipo certo para cada valor."
			hint_label.visible = true
		else:
			hint_label.visible = false
	_update_next_button_state()

func is_phase_success() -> bool:
	# Precisa tipar todos os RAW, interagir e encher exatamente a capacidade.
	if moves_count <= 0:
		return false
	if pending_raw_values > 0:
		return false
	if item_held != null and is_instance_valid(item_held) and item_held.data_type == ItemRef.DataType.RAW:
		return false
	var used := total_bytes_used()
	if used > global_capacity:
		return false
	if used != global_capacity:
		return false
	return _solution_types_valid()

func _typed_items_in_boxes() -> Array:
	var items: Array = []
	for type_info in type_boxes.values():
		for slot in type_info.slots:
			if not is_instance_valid(slot):
				continue
			var item = slot.item_stored
			if item and is_instance_valid(item) and item.data_type != ItemRef.DataType.RAW:
				items.append(item)
	return items

func _item_numeric_value(item) -> float:
	if item.data_type in [ItemRef.DataType.FLOAT, ItemRef.DataType.DOUBLE, ItemRef.DataType.FP8, ItemRef.DataType.FP16, ItemRef.DataType.RAW]:
		return float(item.value_float)
	return float(item.value)

func _raw_values_match(item_val: float, target_str: String) -> bool:
	var target := float(target_str)
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

func _has_integer_in_float_box() -> bool:
	var float_types = [ItemRef.DataType.FLOAT, ItemRef.DataType.DOUBLE, ItemRef.DataType.FP8, ItemRef.DataType.FP16]
	for dt in type_boxes.keys():
		if dt not in float_types:
			continue
		var info = type_boxes[dt]
		for slot in info.slots:
			if not is_instance_valid(slot): continue
			var item = slot.item_stored
			if item and is_instance_valid(item):
				var val = _item_numeric_value(item)
				if is_equal_approx(val, roundf(val)):
					return true
	return false

func _show_victory_overlay():
	var cfg = _get_phase_config()
	var s1 := true
	if _has_integer_in_float_box():
		s1 = false

	if not cfg or not ("star2_max_moves" in cfg):
		var desc = "Movimentos: %d" % moves_count
		if not s1:
			desc += "\nEstrela 1 perdida: valor inteiro colocado em caixa flutuante."
		_earned_stars = int(s1) + 2
		_present_victory_overlay(s1, true, true, desc)
		return

	# Só chega aqui se is_phase_success() == true (objetivo feito de verdade).
	var s2 := true
	if cfg.star2_max_moves > 0:
		s2 = moves_count <= cfg.star2_max_moves

	
	var s3 := true
	var star3_csv := ""
	if "star3_best_solution_csv" in cfg:
		star3_csv = str(cfg.star3_best_solution_csv).strip_edges()
	if star3_csv != "":
		s3 = _check_star3_solution(star3_csv)
	elif "expected_solution_types" in cfg:
		var expected: PackedStringArray = cfg.expected_solution_types
		if not expected.is_empty():
			s3 = _solution_types_valid()

	var desc = "Movimentos: %d" % moves_count
	if cfg.star2_max_moves > 0:
		desc += " (meta estrela 2: ≤ %d)" % cfg.star2_max_moves
	if not s1:
		desc += "\nEstrela 1 perdida: valor inteiro colocado em caixa flutuante."

	_earned_stars = int(s1) + int(s2) + int(s3)
	_present_victory_overlay(s1, s2, s3, desc)
