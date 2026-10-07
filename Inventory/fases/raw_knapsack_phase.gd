extends "res://Inventory/fases/phase_base.gd"

const GRID_SCENE := preload("res://Inventory/InventoryGrid.tscn")
const ITEM_SCENE := preload("res://Inventory/Items/Item.tscn")

var config: RawKnapsackPhaseConfig
var type_station_slots: Array = []
var pending_raw_count: int = 0
var _typing_row: HFlowContainer = null


func _get_phase_config():
	return config


func _ready() -> void:
	super()
	if PhaseRunner.has_method("take_raw_knapsack_config_if_any"):
		config = PhaseRunner.take_raw_knapsack_config_if_any()
	if config == null:
		config = RawKnapsackPhaseConfig.new()
	config.apply_constraints()
	if config.initial_raw_values.is_empty() and not config.randomize_values:
		config.initial_raw_values = PackedStringArray(["7", "3.14", "42"])

	_setup_backpack_grid()
	_setup_bancada()
	call_deferred("_finalize_layout")


func _finalize_layout() -> void:
	call_deferred("_apply_panel_art")
	if pool_grid and pool_grid.slots_array.is_empty():
		await get_tree().process_frame
	_populate_raw_pool()
	if pool_grid:
		await get_tree().process_frame
		pool_grid.refresh_item_positions()
	_update_bytes_label()
	_update_hint()
	_update_next_button_state()


func _setup_backpack_grid() -> void:
	var bp_scroll = backpack_container.get_parent()
	var bp_vbox = bp_scroll.get_parent()
	bp_vbox.remove_child(bp_scroll)
	bp_scroll.queue_free()
	var backpack: InventoryGrid = GRID_SCENE.instantiate()
	backpack.capacity_bytes = config.capacity_bytes
	backpack.slot_bytes = config.slot_bytes
	backpack.grid_columns = config.grid_columns
	backpack.number_of_slots = config.backpack_slot_count
	backpack.clear_initial_items()
	bp_vbox.add_child(backpack)
	backpack.custom_minimum_size = Vector2(0, 0)
	backpack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	backpack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backpack_container = backpack
	backpack.clear_all_items()


func _setup_bancada() -> void:
	var pl_vbox: VBoxContainer = pool_container.get_parent()
	pl_vbox.remove_child(pool_container)
	pool_container.queue_free()
	var hover_bar := pl_vbox.get_node_or_null("OrbHoverBar") as OrbHoverBar
	if hover_bar == null:
		hover_bar = OrbHoverBar.make_in(pl_vbox)
	_register_orb_hover_bar(hover_bar)
	var typing_box := VBoxContainer.new()
	typing_box.name = "TypingSection"
	typing_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	typing_box.add_theme_constant_override("separation", 6)
	_typing_row = HFlowContainer.new()
	_typing_row.add_theme_constant_override("h_separation", 10)
	_typing_row.add_theme_constant_override("v_separation", 8)
	typing_box.add_child(_typing_row)
	_create_type_stations()
	pl_vbox.add_child(typing_box)
	
	var pool: InventoryGrid = GRID_SCENE.instantiate()
	pool.capacity_bytes = 999999
	pool.grid_columns = config.pool_grid_columns
	pool.slot_bytes = config.slot_bytes
	pool.number_of_slots = config.pool_slot_count
	pool.clear_initial_items()
	pl_vbox.add_child(pool)
	pool.custom_minimum_size = Vector2(0, 0)
	pool.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pool.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pool_container = pool
	pool.clear_all_items()
	setup_grids(backpack_container, pool_container)
	_disconnect_base_slot_signals()


func _anchor_orb_hover_above_pool() -> void:
	var bar := _get_orb_hover_bar()
	var vbox := get_node_or_null("HBox/BancadaPanel/MarginContainer/VBoxContainer") as VBoxContainer
	if bar == null or vbox == null:
		return
	var target_idx := 0
	var header := vbox.get_node_or_null("BancadaTitle")
	if header:
		target_idx = header.get_index() + 1
	if bar.get_index() != target_idx:
		vbox.move_child(bar, target_idx)


func _disconnect_base_slot_signals() -> void:
	# phase_base trata RAW como item de 0 byte e liberaria drop direto na mochila.
	for grid in [backpack_grid, pool_grid]:
		if grid == null:
			continue
		if grid.slot_entered.is_connected(_on_slot_entered):
			grid.slot_entered.disconnect(_on_slot_entered)
		if grid.slot_exited.is_connected(_on_slot_exited):
			grid.slot_exited.disconnect(_on_slot_exited)


func _on_slot_entered(_slot) -> void:
	pass


func _on_slot_exited(_slot) -> void:
	pass


func _create_type_stations() -> void:
	type_station_slots.clear()
	var types: Array = _allowed_types()
	for t in types:
		@warning_ignore("shadowed_global_identifier")
		var wrap := VBoxContainer.new()
		wrap.custom_minimum_size = Vector2(72, 0)
		var title := Label.new()
		title.text = t.name
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_color_override("font_color", t.color)
		wrap.add_child(title)
		var slot = preload("res://Inventory/slots/slot.tscn").instantiate()
		slot.set_meta("is_type_station", true)
		slot.set_meta("box_type", t.type)
		slot.set_meta("box_name", t.name)
		slot.set_meta("item_stored", null)
		slot.modulate = t.color
		wrap.add_child(slot)
		_typing_row.add_child(wrap)
		type_station_slots.append(slot)


func _allowed_types() -> Array:
	var types: Array = []
	if config.allow_int:
		types.append({"type": ItemRef.DataType.INT, "name": "Int", "color": Color.BLUE})
	if config.allow_short:
		types.append({"type": ItemRef.DataType.SHORT_INT, "name": "Short", "color": Color.CYAN})
	if config.allow_float:
		types.append({"type": ItemRef.DataType.FLOAT, "name": "Float", "color": Color.RED})
	if config.allow_double:
		types.append({"type": ItemRef.DataType.DOUBLE, "name": "Double", "color": Color.MAGENTA})
	if config.allow_fp8:
		types.append({"type": ItemRef.DataType.FP8, "name": "FP8", "color": Color.VIOLET})
	if config.allow_fp16:
		types.append({"type": ItemRef.DataType.FP16, "name": "FP16", "color": Color.GOLD})
	return types


func _populate_raw_pool() -> void:
	if pool_grid == null:
		push_warning("RawKnapsackPhase: pool_grid ausente.")
		return
	pool_grid.clear_all_items()
	pending_raw_count = 0
	var values: PackedStringArray = PackedStringArray()
	if config.randomize_values:
		for _i in range(4):
			match randi() % 3:
				0: values.append("%.2f" % randf_range(0.1, 99.9))
				1: values.append(str(randi_range(1, 120)))
				2: values.append(str(randi_range(0, 1)))
	else:
		values = config.initial_raw_values
	for raw_str in values:
		var s := str(raw_str).strip_edges()
		if s.is_empty():
			continue
		var item: Node2D = ITEM_SCENE.instantiate()
		item.set_value_by_type(float(s), ItemRef.DataType.RAW)
		item.update_label_display()
		if not pool_grid.try_place_item_automatically(item):
			item.queue_free()
			continue
		pending_raw_count += 1
		_wire_orb(item)
	_update_phase_title()


@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	if _is_finishing:
		return
		
	var mouse_pos := get_global_mouse_position()
	var new_slot = _slot_under_mouse(mouse_pos)
	if current_slot != new_slot:
		if current_slot:
			_on_custom_slot_exited(current_slot)
		current_slot = new_slot
		if current_slot:
			_on_custom_slot_entered(current_slot)
	if item_held:
		item_held.global_position = get_global_mouse_position()
		if Input.is_action_just_pressed("select_item"):
			if _click_blocked_by_ui():
				return
			if current_slot and can_place:
				_place_item_custom()
			else:
				var mpos := get_global_mouse_position()
				if backpack_grid and backpack_grid.get_global_rect().has_point(mpos):
					if item_held.data_type == ItemRef.DataType.RAW:
						_show_raw_backpack_blocked_feedback()
					else:
						var free_slot = backpack_grid.find_first_free_anchor_for(item_held)
						if free_slot:
							var need = item_held.get_size_bytes() if item_held.has_method("get_size_bytes") else 1
							var used = backpack_grid.total_bytes_used()
							if used + need <= backpack_grid.capacity_bytes:
								current_slot = free_slot
								can_place = true
								_place_item_custom()
							else:
								_show_not_ready_modal("Não cabe na mochila!\nEste tipo usa %d byte(s). Capacidade: %d | Em uso: %d." % [need, config.capacity_bytes, used])
				elif pool_grid and pool_grid.get_global_rect().has_point(mpos):
					var free_slot = pool_grid.find_first_free_anchor_for(item_held)
					if free_slot:
						current_slot = free_slot
						can_place = true
						_place_item_custom()
	else:
		if Input.is_action_just_pressed("select_item"):
			if _click_blocked_by_ui():
				return
			if current_slot and _slot_has_item(current_slot):
				_pick_item_custom()


func _slot_under_mouse(mouse_pos: Vector2):
	for slot in type_station_slots:
		if slot.get_global_rect().has_point(mouse_pos):
			return slot
	if backpack_grid:
		for slot in backpack_grid.slots_array:
			if slot.get_global_rect().has_point(mouse_pos):
				return slot
	if pool_grid:
		for slot in pool_grid.slots_array:
			if slot.get_global_rect().has_point(mouse_pos):
				return slot
	return null


func _slot_has_item(slot) -> bool:
	if slot.has_meta("is_type_station"):
		return slot.get_meta("item_stored") != null
	return slot.item_stored != null


func _on_custom_slot_entered(slot) -> void:
	current_slot = slot
	if not item_held:
		return
	if slot.has_meta("is_type_station"):
		can_place = slot.get_meta("item_stored") == null
		if can_place:
			_show_typing_preview(slot)
	elif slot in backpack_grid.slots_array:
		if item_held.data_type == ItemRef.DataType.RAW:
			can_place = false
		else:
			can_place = backpack_grid.can_place_item(item_held, slot)
			var need: int = item_held.get_size_bytes() if item_held.has_method("get_size_bytes") else 1
			var used := backpack_grid.total_bytes_used()
			if can_place and used + need > backpack_grid.capacity_bytes:
				can_place = false
	elif slot in pool_grid.slots_array:
		can_place = pool_grid.can_place_item(item_held, slot)
	
	if backpack_grid and backpack_grid.has_method("show_placement_preview"):
		backpack_grid.clear_placement_preview()
		if slot in backpack_grid.slots_array:
			backpack_grid.show_placement_preview(item_held, slot)
	if pool_grid and pool_grid.has_method("show_placement_preview"):
		pool_grid.clear_placement_preview()
		if slot in pool_grid.slots_array:
			pool_grid.show_placement_preview(item_held, slot)
			
	_update_bytes_label()


func _on_custom_slot_exited(_slot) -> void:
	if item_held and item_held.has_method("hide_typing_preview"):
		item_held.hide_typing_preview()
	can_place = false
	if backpack_grid and backpack_grid.has_method("clear_placement_preview"):
		backpack_grid.clear_placement_preview()
	if pool_grid and pool_grid.has_method("clear_placement_preview"):
		pool_grid.clear_placement_preview()
	_update_hint()

func _show_typing_preview(slot) -> void:
	if not item_held or not item_held.has_method("show_typing_preview"):
		return
	var target_name: String = slot.get_meta("box_name")
	var target_type = slot.get_meta("box_type")
	var val := TypeConversionSystem.value_for_conversion(item_held)
	var deg := TypeConversionSystem.check_degradation(target_name, val, config)
	item_held.show_typing_preview(target_type, deg.degraded_value, deg.has_warning)


func _place_item_custom() -> void:
	if not current_slot or not item_held:
		return
		
	if item_held.has_method("hide_typing_preview"):
		item_held.hide_typing_preview()
		
	var prev_source = _source_slot
	
	if current_slot.has_meta("is_type_station"):
		_place_on_type_station(current_slot)
	elif current_slot in backpack_grid.slots_array:
		_place_on_backpack(current_slot)
	elif current_slot in pool_grid.slots_array:
		_place_on_pool(current_slot)
		
	if item_held == null and prev_source != current_slot:
		moves_count += 1


func _place_on_type_station(slot) -> void:
	if slot.get_meta("item_stored") != null:
		_show_not_ready_modal("Esta estação já tem um orbe. Retire-o antes de tipar outro.")
		return
	var was_raw: bool = item_held.data_type == ItemRef.DataType.RAW
	var target_name: String = slot.get_meta("box_name")
	var target_type = slot.get_meta("box_type")
	var val := TypeConversionSystem.value_for_conversion(item_held)
	var deg := TypeConversionSystem.check_degradation(target_name, val, config)
	if deg.has_warning:
		_show_not_ready_modal("FALHA NA TIPAGEM!\n" + deg.message)
		return
	item_held.set_value_by_type(deg.degraded_value, target_type)
	item_held.update_label_display()
	if item_held.get_parent():
		item_held.get_parent().remove_child(item_held)
	slot.add_child(item_held)
	if "grid_anchor" in item_held:
		item_held.grid_anchor = slot
	if item_held.has_method("snap_to_slot"):
		item_held.snap_to_slot(slot)
	else:
		item_held.position = slot.size * 0.5
	slot.set_meta("item_stored", item_held)
	item_held.selected = false
	item_held = null
	can_place = false
	if was_raw:
		pending_raw_count = maxi(0, pending_raw_count - 1)
	_update_bytes_label()
	_update_phase_title()
	_update_hint()
	_update_next_button_state()


func _place_on_backpack(slot) -> void:
	if item_held.data_type == ItemRef.DataType.RAW:
		_show_raw_backpack_blocked_feedback()
		return
	if not backpack_grid.can_place_item(item_held, slot):
		_show_not_ready_modal("Não há espaço neste slot da mochila. Tente outro.")
		return
	var need: int = item_held.get_size_bytes() if item_held.has_method("get_size_bytes") else 1
	var used := backpack_grid.total_bytes_used()
	if used + need > backpack_grid.capacity_bytes:
		_show_not_ready_modal(
			"Não cabe na mochila!\nEste tipo usa %d byte(s). Capacidade: %d | Em uso: %d." % [need, config.capacity_bytes, used]
		)
		return
	backpack_grid.place_item(item_held, slot)
	if backpack_grid.has_method("pack_items_left"):
		backpack_grid.pack_items_left()
	_wire_orb(item_held)
	item_held.selected = false
	item_held = null
	can_place = false
	_update_bytes_label()
	_update_phase_title()
	_update_hint()
	_update_next_button_state()


func _place_on_pool(slot) -> void:
	if slot.item_stored != null:
		return
	if item_held.data_type != ItemRef.DataType.RAW:
		item_held.set_value_by_type(TypeConversionSystem.value_for_conversion(item_held), ItemRef.DataType.RAW)
		item_held.update_label_display()
		pending_raw_count += 1
	pool_grid.place_item(item_held, slot)
	if pool_grid.has_method("pack_items_left"):
		pool_grid.pack_items_left()
	_wire_orb(item_held)
	pool_grid.refresh_item_positions()
	item_held.selected = false
	item_held = null
	can_place = false
	_update_bytes_label()
	_update_phase_title()
	_update_hint()
	_update_next_button_state()


func _pick_item_custom() -> void:
	var slot = current_slot
	_source_slot = slot
	var item = null
	var mouse_pos := get_global_mouse_position()
	if slot.has_meta("is_type_station"):
		item = slot.get_meta("item_stored")
		slot.set_meta("item_stored", null)
		if item:
			item.selected = true
			if item.get_parent():
				item.get_parent().remove_child(item)
			add_child(item)
			item.global_position = mouse_pos
	elif slot in backpack_grid.slots_array:
		item = slot.pick_item_at(mouse_pos) if slot.has_method("pick_item_at") else slot.item_stored
		if item:
			backpack_grid.remove_item(item)
			if backpack_grid.has_method("pack_items_left"):
				backpack_grid.pack_items_left()
			item.selected = true
			if item.get_parent():
				item.get_parent().remove_child(item)
			add_child(item)
			item.global_position = mouse_pos
	elif slot in pool_grid.slots_array:
		item = slot.pick_item_at(mouse_pos) if slot.has_method("pick_item_at") else slot.item_stored
		if item:
			pool_grid.remove_item(item)
			if pool_grid.has_method("pack_items_left"):
				pool_grid.pack_items_left()
			item.selected = true
			if item.get_parent():
				item.get_parent().remove_child(item)
			add_child(item)
			item.global_position = mouse_pos
	if item == null:
		return
	item_held = item
	_wire_orb(item)
	_update_phase_title()
	_update_hint()


func _show_raw_backpack_blocked_feedback() -> void:
	_show_not_ready_modal(
		"Este valor ainda não tem tipo!\n\n" +
		"1) Arraste para uma estação (Int, Float, …)\n" +
		"2) Depois coloque o orbe tipado na mochila."
	)


func _on_invalid_drop_attempt() -> void:
	if not item_held or not current_slot:
		return
	if item_held.data_type == ItemRef.DataType.RAW:
		if current_slot in backpack_grid.slots_array:
			_show_raw_backpack_blocked_feedback()
			return
		if current_slot.has_meta("is_type_station") and current_slot.get_meta("item_stored") != null:
			_show_not_ready_modal("Esta estação já tem um orbe. Retire-o ou use outra estação.")
			return
	if current_slot in backpack_grid.slots_array:
		var need: int = item_held.get_size_bytes() if item_held.has_method("get_size_bytes") else 1
		var used := backpack_grid.total_bytes_used()
		if used + need > backpack_grid.capacity_bytes:
			_show_not_ready_modal(
				"Não cabe na mochila!\nEste tipo usa %d byte(s). Restam %d byte(s)." % [need, config.capacity_bytes - used]
			)
		elif not backpack_grid.can_place_item(item_held, current_slot):
			_show_not_ready_modal("Não há espaço neste slot. Tente outro slot da mochila.")


func _random_raw_value_string() -> String:
	match randi() % 3:
		0:
			return "%.2f" % randf_range(0.1, 99.9)
		1:
			return str(randi_range(1, 120))
		_:
			return str(randi_range(0, 1))


func _spawn_raw_in_pool() -> bool:
	if pool_grid == null:
		return false
	var item: Node2D = ITEM_SCENE.instantiate()
	item.set_value_by_type(float(_random_raw_value_string()), ItemRef.DataType.RAW)
	item.update_label_display()
	if not pool_grid.try_place_item_automatically(item):
		item.queue_free()
		return false
	pending_raw_count += 1
	_wire_orb(item)
	pool_grid.refresh_item_positions()
	_update_phase_title()
	_update_hint()
	_update_next_button_state()
	return true


func _on_spawn_pressed() -> void:
	if item_held != null:
		_show_not_ready_modal("Solte o orbe que está na mão antes de gerar outro.")
		return
	if not _spawn_raw_in_pool():
		_show_not_ready_modal("Pool cheio! Use ou tipifique os valores antes de gerar mais.")


func _tutorial_intro_id() -> String:
	return "raw_knapsack_phase_intro"


func _update_bytes_label() -> void:
	if not backpack_grid or not bytes_label:
		return
	var used := backpack_grid.total_bytes_used()
	var cap := config.capacity_bytes
	bytes_label.text = "Mochila: %d / %d bytes" % [used, cap]
	_update_hint()


func _update_hint() -> void:
	if not hint_label:
		return
	if is_phase_success():
		hint_label.text = "Objetivo concluído!"
		hint_label.visible = true
	else:
		hint_label.text = ""
		hint_label.visible = false
	_update_next_button_state()


func is_phase_success() -> bool:
	if moves_count <= 0:
		return false
	if item_held != null and is_instance_valid(item_held) and item_held.data_type == ItemRef.DataType.RAW:
		return false
	if pending_raw_count > 0:
		return false
	if not backpack_grid:
		return false
	# Encher exatamente a capacidade, sem estourar.
	if backpack_grid.total_bytes_used() != config.capacity_bytes:
		return false
	for slot in backpack_grid.slots_array:
		for it in slot.items_stored:
			if it and it.data_type == ItemRef.DataType.RAW:
				return false
	return true
