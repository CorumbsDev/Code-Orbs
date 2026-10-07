extends Control

const ItemRef = preload("res://Inventory/Items/item.gd")

@onready var btn_voltar = $TopBar/BtnVoltar
@onready var btn_help = get_node_or_null("TopBar/BtnHelp")
@onready var btn_proxima = get_node_or_null("TopBar/BtnProxima")
@onready var phase_title = get_node_or_null("TopBar/PhaseTitle")
@onready var btn_spawn = $TopBar/BtnSpawn
@onready var bytes_label = $HBox/BackpackPanel/MarginContainer/VBoxContainer/PhaseInfoBar/MarginContainer/VBoxContainer/BytesLabel
@onready var hint_label = $HBox/BackpackPanel/MarginContainer/VBoxContainer/PhaseInfoBar/MarginContainer/VBoxContainer/HintLabel

@onready var backpack_container = $HBox/BackpackPanel/MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var pool_container = $HBox/BancadaPanel/MarginContainer/VBoxContainer/GridContainer

var backpack_grid: InventoryGrid = null
var pool_grid: InventoryGrid = null
var converter_slot: TextureRect = null
var converter_option_btn: OptionButton = null
var double_slot: TextureRect = null
var short_slot: TextureRect = null
var calc_slot_1: TextureRect = null
var calc_slot_2 = null
var calc_slot_result: TextureRect = null
var calc_op_btn = null
var inspect_slot: TextureRect = null

var item_held = null
var current_slot = null
var can_place := false
var inspector_modal = null
var _orb_hover_bar: OrbHoverBar = null

var moves_count: int = 0
var _source_slot = null
var _is_finishing: bool = false

var calculator: CalculatorTool = null
var converter: ConverterTool = null

var _custom_tutorial_title: String = ""
var _custom_tutorial_text: String = ""
var _uses_custom_tutorial: bool = false
var _earned_stars: int = 0

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	if PhaseRunner.has_custom_tutorial():
		_uses_custom_tutorial = true
		var t := PhaseRunner.take_tutorial_if_any()
		_custom_tutorial_title = t["title"]
		_custom_tutorial_text = t["body"]
	
	if btn_voltar:
		btn_voltar.text = "Voltar"
		btn_voltar.pressed.connect(_on_voltar_pressed)
	if btn_help:
		btn_help.pressed.connect(_on_help_pressed)
	if btn_proxima:
		btn_proxima.visible = PhaseRunner.should_show_next_button()
		btn_proxima.disabled = true # só libera quando is_phase_success()
		btn_proxima.pressed.connect(_on_proxima_pressed)
		call_deferred("_update_next_button_state")
	if btn_spawn:
		btn_spawn.pressed.connect(_on_spawn_pressed)
	if phase_title:
		phase_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	PhaseRunner.phase_advance_blocked.connect(_on_phase_advance_blocked)
	call_deferred("_try_show_intro")
	call_deferred("_update_phase_title")
	
	# Wait one frame to let subclasses assign the tool slots
	call_deferred("_initialize_tools")

func _initialize_tools():
	if calc_slot_1 and calc_slot_2 and calc_slot_result and calc_op_btn:
		calculator = CalculatorTool.new(self, calc_slot_1, calc_slot_2, calc_slot_result, calc_op_btn)
	
	if converter_slot:
		converter = ConverterTool.new(self, converter_slot, converter_option_btn)

func _tutorial_intro_id() -> String:
	return ""

func _update_phase_title() -> void:
	if phase_title:
		phase_title.text = "Fase"

func _try_show_intro() -> void:
	if _uses_custom_tutorial:
		TutorialOverlay.open(self, "custom", _custom_tutorial_title, _custom_tutorial_text, false)
		return

	var tid := _tutorial_intro_id()
	if tid.is_empty():
		return
	# Sempre abre o tutorial ao começar a fase (não pula se já viu).
	TutorialOverlay.open(self, tid, TutorialTexts.title_for(tid), TutorialTexts.body_for(tid), false)

func _on_help_pressed() -> void:
	if _uses_custom_tutorial:
		TutorialOverlay.open(self, "custom", _custom_tutorial_title, _custom_tutorial_text, false)
		return

	var tid := _tutorial_intro_id()
	if tid.is_empty():
		return
	TutorialOverlay.open(self, tid, TutorialTexts.title_for(tid), TutorialTexts.body_for(tid), false)

func setup_grids(backpack: InventoryGrid, pool: InventoryGrid):
	backpack_grid = backpack
	pool_grid = pool
	backpack_grid.slot_entered.connect(_on_slot_entered)
	backpack_grid.slot_exited.connect(_on_slot_exited)
	backpack_grid.item_changed.connect(_on_slot_item_changed)
	pool_grid.slot_entered.connect(_on_slot_entered)
	pool_grid.slot_exited.connect(_on_slot_exited)
	pool_grid.item_changed.connect(_on_slot_item_changed)
	_update_bytes_label()
	_update_hint()
	call_deferred("_apply_panel_art")
	call_deferred("_wire_all_orbs")
	call_deferred("_anchor_orb_hover_above_pool")

func _get_phase_config():
	return null

func _solution_types_valid() -> bool:
	return true

func _apply_panel_art() -> void:
	var bp := get_node_or_null("HBox/BackpackPanel") as Control
	var bn := get_node_or_null("HBox/BancadaPanel") as Control
	if bp:
		PanelArtLoader.apply_zone_chrome(bp)
	if bn:
		PanelArtLoader.apply_zone_chrome(bn)
	_style_phase_labels()
	PanelArtLoader.skin_all_buttons(self)
	PanelArtLoader.apply_background(self)

func _style_phase_labels() -> void:
	var bar := get_node_or_null("HBox/BackpackPanel/MarginContainer/VBoxContainer/PhaseInfoBar")
	if bar is PhaseInfoBar:
		return
	if bytes_label:
		OrbHoverBar.apply_info_label(bytes_label)
	if hint_label:
		OrbHoverBar.apply_info_label(hint_label)

func _wire_all_orbs() -> void:
	for grid in [backpack_grid, pool_grid]:
		if grid == null:
			continue
		for slot in grid.slots_array:
			for it in slot.items_stored:
				_wire_orb(it)
			if not slot.item_changed.is_connected(_on_orb_slot_changed):
				slot.item_changed.connect(_on_orb_slot_changed)

func _on_orb_slot_changed(slot) -> void:
	for it in slot.items_stored:
		_wire_orb(it)

func _wire_orb(item: Node) -> void:
	var bar := _get_orb_hover_bar()
	if bar:
		bar.wire_orb(item)

func _get_orb_hover_bar() -> OrbHoverBar:
	if _orb_hover_bar != null and is_instance_valid(_orb_hover_bar):
		return _orb_hover_bar
	for path in [
		"HBox/BancadaPanel/MarginContainer/VBoxContainer/OrbHoverBar",
		"HBox/BancadaPanel/MarginContainer/VBoxContainer/OrbHoverPanel",
	]:
		var n := get_node_or_null(path)
		if n is OrbHoverBar:
			_orb_hover_bar = n
			return _orb_hover_bar
	return null

func _register_orb_hover_bar(bar: OrbHoverBar) -> void:
	_orb_hover_bar = bar

func _anchor_orb_hover_above_pool() -> void:
	var bar := _get_orb_hover_bar()
	if bar == null or pool_grid == null:
		return
	var parent := pool_grid.get_parent()
	if parent == null:
		return
	parent.move_child(bar, pool_grid.get_index())

func _open_orb_inspector(item: Node) -> void:
	var cfg = _get_phase_config()
	if cfg == null or item == null:
		return
	if not inspector_modal:
		inspector_modal = preload("res://Inventory/fases/inspector_modal.gd").new()
		add_child(inspector_modal)
	inspector_modal.open(cfg, item)

func _on_voltar_pressed():
	PhaseRunner.abort_sequence()
	get_tree().change_scene_to_file("res://Inventory/fases/main_menu.tscn")

func _on_proxima_pressed():
	if _is_finishing:
		return

	_update_next_button_state()
	# Sem interação / objetivo incompleto: nunca avança nem mostra estrelas.
	if moves_count <= 0 or not is_phase_success():
		_show_not_ready_modal(
			"Complete o objetivo da fase antes de avançar.\n(É preciso interagir e cumprir o que a fase pede.)"
		)
		return

	_is_finishing = true
	_show_victory_overlay()

func _present_victory_overlay(s1: bool, s2: bool, s3: bool, desc: String) -> void:
	var overlay = preload("res://Inventory/fases/victory_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_victory(s1, s2, s3, desc)
	overlay.advance_requested.connect(_on_victory_advance_requested)

func _on_victory_advance_requested() -> void:
	_is_finishing = false
	PhaseRunner.advance_from_phase()

func _show_victory_overlay():
	var cfg = _get_phase_config()
	if not cfg or not ("star2_max_moves" in cfg):
		_present_victory_overlay(true, true, true, "Movimentos: %d" % moves_count)
		return

	# Só chega aqui se is_phase_success() == true (objetivo feito de verdade).
	# Estrela 1: sempre, pois completou a fase.
	var s1 := true
	# Estrela 2: se não houver limite configurado (0), conta como ok;
	# se houver (> 0), precisa ter feito em no máximo N movimentos.
	var s2 := true
	if cfg.star2_max_moves > 0:
		s2 = moves_count <= cfg.star2_max_moves
	# Estrela 3: se não houver solução ideal no criador, conta como ok;
	# se houver, o inventário precisa bater com ela.
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

	_earned_stars = int(s1) + int(s2) + int(s3)
	_present_victory_overlay(s1, s2, s3, desc)

func get_earned_stars() -> int:
	return _earned_stars

func _check_star3_solution(target_csv: String) -> bool:
	var target_list = Array(target_csv.split(",", false))
	for i in range(target_list.size()):
		target_list[i] = target_list[i].strip_edges()
	
	var current_list = []
	if backpack_grid:
		for slot in backpack_grid.slots_array:
			if slot.item_stored:
				current_list.append(_item_to_csv_string(slot.item_stored))
	elif "all_slots" in self:
		var all = self.get("all_slots")
		if all and typeof(all) == TYPE_ARRAY:
			for slot in all:
				if slot and "item_stored" in slot and slot.item_stored:
					current_list.append(_item_to_csv_string(slot.item_stored))
				
	if current_list.size() != target_list.size():
		return false
		
	var target_sorted = target_list.duplicate()
	target_sorted.sort()
	current_list.sort()
	
	for i in range(target_sorted.size()):
		if target_sorted[i] != current_list[i]:
			return false
	return true

func _item_to_csv_string(item: Node) -> String:
	if not is_instance_valid(item): return ""
	var v_str = ""
	var t_str = ""
	# DataType enum: INT=0, FLOAT=1, STRING=2, OPERATOR=3, DOUBLE=4, BINARY=5, SHORT_INT=6, FP8=7, FP16=8, RAW=9
	match item.data_type:
		0:
			v_str = str(item.value)
			t_str = "i"
		1:
			v_str = str(item.value_float)
			t_str = "f"
		4:
			v_str = str(item.value_double)
			t_str = "d"
		9:
			v_str = item.value_string if "value_string" in item else str(item.value)
			t_str = "raw"
		6:
			v_str = str(item.value_short)
			t_str = "s"
		7:
			v_str = str(item.value_float)
			t_str = "fp8"
		8:
			v_str = str(item.value_float)
			t_str = "fp16"
		_:
			v_str = str(item.value)
			t_str = "i"
	return v_str + "_" + t_str

func _on_phase_advance_blocked(reason: String):
	_show_not_ready_modal(reason)

func _show_not_ready_modal(custom_message: String = ""):
	var message := custom_message if custom_message != "" else "Você precisa completar o objetivo desta fase antes de avançar. Verifique as instruções e tente novamente."
	var dlg := AcceptDialog.new()
	dlg.dialog_text = message
	add_child(dlg)
	dlg.popup_centered(Vector2(400, 120))

func _update_next_button_state():
	if not btn_proxima:
		return
	var success = is_phase_success()
	if pool_grid and not pool_grid.get_all_items().is_empty():
		success = false
	btn_proxima.disabled = not success

func is_phase_success() -> bool:
	# Default seguro: não permite avançar até a fase sobrescrever a regra.
	return false

func _on_spawn_pressed():
	pass

func _on_slot_entered(slot):
	current_slot = slot
	if not item_held:
		return
	if slot == converter_slot:
		can_place = true
		_update_next_button_state()
	elif slot == calc_slot_result:
		can_place = false
	elif slot == calc_slot_1 or slot == calc_slot_2:
		can_place = slot.item_stored == null
		if can_place:
			_update_next_button_state()
	elif slot == inspect_slot:
		can_place = slot.item_stored == null
		if can_place:
			_update_next_button_state()
	elif backpack_grid and slot in backpack_grid.slots_array:
		can_place = backpack_grid.can_place_item(item_held, slot)
		var need = item_held.get_size_bytes() if item_held.has_method("get_size_bytes") else 1
		var used = backpack_grid.total_bytes_used()
		if can_place and used + need > backpack_grid.capacity_bytes:
			can_place = false
	elif pool_grid and slot in pool_grid.slots_array:
		can_place = pool_grid.can_place_item(item_held, slot)
	else:
		can_place = false

func _on_slot_exited(_slot):
	current_slot = null
	can_place = false
	_update_hint()

func _on_slot_item_changed(_slot):
	_update_bytes_label()
	_update_hint()

func _click_blocked_by_ui() -> bool:
	var c := get_viewport().gui_get_hovered_control()
	if c == null:
		return false
	if c.is_in_group("slot"):
		return false
	var p := c.get_parent()
	if p and p.is_in_group("slot"):
		return false
	return c is BaseButton or c is LineEdit or c is TextEdit or c is OptionButton or c is Slider

func _process(_delta):
	if _is_finishing:
		return
		
	if item_held:
		item_held.global_position = get_global_mouse_position()
		if Input.is_action_just_pressed("select_item"):
			if _click_blocked_by_ui():
				return
			if current_slot and can_place:
				_place_item()
			else:
				var mpos := get_global_mouse_position()
				if backpack_grid and backpack_grid.get_global_rect().has_point(mpos):
					var free_slot = backpack_grid.find_first_free_anchor_for(item_held)
					if free_slot:
						var need = item_held.get_size_bytes() if item_held.has_method("get_size_bytes") else 1
						var used = backpack_grid.total_bytes_used()
						if used + need <= backpack_grid.capacity_bytes:
							current_slot = free_slot
							can_place = true
							_place_item()
				elif pool_grid and pool_grid.get_global_rect().has_point(mpos):
					var free_slot = pool_grid.find_first_free_anchor_for(item_held)
					if free_slot:
						current_slot = free_slot
						can_place = true
						_place_item()
	else:
		if Input.is_action_just_pressed("select_item"):
			if _click_blocked_by_ui():
				return
			if current_slot and current_slot.item_stored:
				_pick_item()

func _place_item():
	if not can_place or not current_slot:
		return
	if not item_held or not is_instance_valid(item_held):
		return
		
	if current_slot == converter_slot and converter:
		var placed := await converter.convert_with_dialog(item_held, true)
		if not placed:
			return
		if _source_slot != current_slot:
			moves_count += 1
		item_held = null
		can_place = false
		_update_bytes_label()
		_update_hint()
		return
		
	if current_slot == calc_slot_1 or current_slot == calc_slot_2 or current_slot == inspect_slot:
		if current_slot == calc_slot_1 or current_slot == calc_slot_2:
			if calculator: calculator.clear_result()
		
		# Using the calculator method to mount if available, else inline logic
		if calculator and (current_slot == calc_slot_1 or current_slot == calc_slot_2):
			calculator.mount_item(current_slot, item_held)
		else:
			if item_held.get_parent() != current_slot:
				if item_held.get_parent():
					item_held.get_parent().remove_child(item_held)
				current_slot.add_child(item_held)
			if item_held.has_method("shrink_orb_for_tool_slot"):
				item_held.shrink_orb_for_tool_slot()
			if item_held.has_method("snap_to_slot"):
				item_held.snap_to_slot(current_slot)
			else:
				item_held.position = current_slot.size * 0.5
			item_held.grid_anchor = current_slot
			item_held.selected = false
			current_slot.item_stored = item_held
			current_slot.state = current_slot.States.TAKEN
		
		item_held = null
		can_place = false
		if calculator: calculator.check_calculator()
		_update_bytes_label()
		_update_hint()
		return
		
	if current_slot in backpack_grid.slots_array:
		backpack_grid.place_item(item_held, current_slot)
		backpack_grid.pack_items_left()
	else:
		pool_grid.place_item(item_held, current_slot)
	
	if _source_slot != current_slot:
		moves_count += 1
		
	item_held.selected = false
	item_held = null
	can_place = false
	_update_bytes_label()
	_update_hint()

func _pick_item():
	var slot = current_slot
	if slot == null or slot.item_stored == null:
		return
	_source_slot = slot
	var mouse_pos := get_global_mouse_position()
	if slot.has_method("pick_item_at"):
		item_held = slot.pick_item_at(mouse_pos)
	else:
		item_held = slot.item_stored
	if not is_instance_valid(item_held):
		item_held = null
		return
	item_held.selected = true
	item_held.get_parent().remove_child(item_held)
	add_child(item_held)
	item_held.global_position = mouse_pos
	
	if slot == converter_slot:
		if converter_slot:
			converter_slot.item_stored = null
		converter_slot.state = converter_slot.States.FREE
	elif slot == inspect_slot:
		inspect_slot.state = inspect_slot.States.FREE
		inspect_slot.item_stored = null
	elif slot == calc_slot_result:
		slot.state = slot.States.FREE
		slot.item_stored = null
		if item_held.has_method("restore_orb_layout"):
			item_held.restore_orb_layout()
	elif slot == calc_slot_1 or slot == calc_slot_2:
		slot.state = slot.States.FREE
		slot.item_stored = null
		if calculator: calculator.clear_result()
		if item_held.has_method("restore_orb_layout"):
			item_held.restore_orb_layout()
	elif backpack_grid and slot in backpack_grid.slots_array:
		backpack_grid.remove_item(item_held)
		backpack_grid.pack_items_left()
	elif pool_grid and slot in pool_grid.slots_array:
		pool_grid.remove_item(item_held)
	_wire_orb(item_held)
	if converter:
		converter.revert_dropdown(item_held.data_type)
	_update_bytes_label()
	_update_hint()

func _update_bytes_label():
	if not backpack_grid:
		return
	var used = backpack_grid.total_bytes_used()
	var cap = backpack_grid.capacity_bytes
	var slot_note := ""
	if backpack_grid.get("slot_bytes") != null and MemoryLayout.normalize_slot_bytes(int(backpack_grid.slot_bytes)) == 1:
		slot_note = "  ·  slot de 1 byte (int = 4 células, short = 2)"
	bytes_label.text = "Mochila: %d / %d bytes%s" % [used, cap, slot_note]
	_update_next_button_state()

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

func _wait_for_dialog(dlg: ConfirmationDialog) -> bool:
	var result = [false]
	var done = [false]
	dlg.confirmed.connect(func(): result[0] = true; done[0] = true)
	dlg.canceled.connect(func(): done[0] = true)
	dlg.close_requested.connect(func(): done[0] = true)
	
	while not done[0]:
		await get_tree().process_frame
		
	return result[0]
