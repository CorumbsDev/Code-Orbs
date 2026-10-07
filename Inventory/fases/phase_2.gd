extends "res://Inventory/fases/phase_base.gd"

const GRID_SCENE := preload("res://Inventory/InventoryGrid.tscn")
const ITEM_SCENE := preload("res://Inventory/Items/Item.tscn")

@export var config: PhaseConfig

func _get_phase_config():
	return config

func _ready():
	super()
	var injected: PhaseConfig = PhaseRunner.take_backpack_config_if_any()
	var cfg := injected if injected != null else config
	if cfg == null:
		cfg = PhaseConfig.new()
		cfg.initial_backpack_csv = "1_i, 2_i, 3_i"
		cfg.pool_slot_count = 12
		cfg.random_pool = PackedStringArray()
	config = cfg
	config.apply_constraints()
	# Remove placeholders velhos e inúteis para não criar Grids duplos (que esmagam o conteúdo)
	var bp_scroll = backpack_container.get_parent()
	var bp_vbox = bp_scroll.get_parent()
	bp_vbox.remove_child(bp_scroll)
	bp_scroll.queue_free()
	
	var pl_vbox = pool_container.get_parent()
	pl_vbox.remove_child(pool_container)
	pool_container.queue_free()
	
	var backpack: InventoryGrid = GRID_SCENE.instantiate()
	var pool: InventoryGrid = GRID_SCENE.instantiate()
	_apply_challenge_exports(backpack)
	_apply_pool_exports(pool)
	
	bp_vbox.add_child(backpack)
	pl_vbox.add_child(pool)
	
	# Atualiza referências e limpa tamanhos travados
	backpack_container = backpack
	pool_container = pool
	
	backpack.custom_minimum_size = Vector2(0, 0)
	backpack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	backpack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pool.custom_minimum_size = Vector2(0, 0)
	pool.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pool.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	backpack.clear_all_items()
	pool.clear_all_items()
	setup_grids(backpack, pool)
	call_deferred("_apply_panel_art")
	call_deferred("_initialize_game", backpack, pool)


func _update_phase_title() -> void:
	if phase_title:
		phase_title.visible = false


func _apply_challenge_exports(grid: InventoryGrid):
	grid.capacity_bytes = config.capacity_bytes
	grid.slot_bytes = config.slot_bytes
	grid.grid_columns = config.grid_columns
	grid.number_of_slots = config.backpack_slot_count
	grid.clear_initial_items()


func _apply_pool_exports(grid: InventoryGrid):
	grid.capacity_bytes = 999999
	grid.slot_bytes = config.slot_bytes
	grid.grid_columns = config.pool_grid_columns
	grid.number_of_slots = config.pool_slot_count
	grid.clear_initial_items()


func _initialize_game(backpack: InventoryGrid, pool: InventoryGrid):
	backpack.clear_all_items()
	pool.clear_all_items()
	
	if converter_slot == null:
		var pool_vbox = pool_container.get_parent()
		if pool_vbox:
			var tools_container = pool_vbox.get_node_or_null("ConvertersContainer")
			var tools_hbox = null
			if not tools_container:
				tools_container = VBoxContainer.new()
				tools_container.name = "ConvertersContainer"
				
				var toggle_btn = Button.new()
				toggle_btn.text = "▼ Conversores"
				
				tools_hbox = HFlowContainer.new()
				tools_hbox.name = "ConvertersHBox"
				tools_hbox.alignment = FlowContainer.ALIGNMENT_CENTER
				tools_hbox.add_theme_constant_override("h_separation", 15)
				tools_hbox.add_theme_constant_override("v_separation", 15)
				
				toggle_btn.pressed.connect(func():
					tools_hbox.visible = not tools_hbox.visible
					toggle_btn.text = "▼ Conversores" if tools_hbox.visible else "▶ Conversores"
				)
				
				tools_container.add_child(toggle_btn)
				tools_container.add_child(tools_hbox)
				
				pool_vbox.add_child(tools_container)
				pool_vbox.move_child(tools_container, pool_container.get_index())
			else:
				tools_hbox = tools_container.get_node("ConvertersHBox")
			
			var panel = PanelContainer.new()
			var vbox = VBoxContainer.new()
			panel.add_child(vbox)
			
			var hbox = HBoxContainer.new()
			hbox.alignment = BoxContainer.ALIGNMENT_CENTER
			vbox.add_child(hbox)
			
			var lbl = Label.new()
			lbl.text = "Para:"
			lbl.add_theme_font_size_override("font_size", 14)
			hbox.add_child(lbl)
			
			converter_option_btn = OptionButton.new()
			converter_option_btn.add_theme_font_size_override("font_size", 14)
			if config.use_converter: converter_option_btn.add_item("Float")
			if config.allow_double: converter_option_btn.add_item("Double")
			if config.allow_short: converter_option_btn.add_item("Short")
			if config.allow_fp8: converter_option_btn.add_item("FP8")
			if config.allow_fp16: converter_option_btn.add_item("FP16")
			converter_option_btn.add_item("Int") # Sempre permitir a volta pro Int
			
			hbox.add_child(converter_option_btn)
			
			var center = CenterContainer.new()
			center.custom_minimum_size = Vector2(64, 64)
			vbox.add_child(center)
			
			converter_slot = preload("res://Inventory/slots/slot.tscn").instantiate()
			converter_slot.slot_ID = 999
			center.add_child(converter_slot)
			
			converter_slot.slot_entered.connect(_on_slot_entered)
			converter_slot.slot_exited.connect(_on_slot_exited)
			
			converter = ConverterTool.new(self, converter_slot, converter_option_btn)
			
			# Só adiciona o painel de conversão se houver mais de uma opção (Int + pelo menos 1 ativado)
			if converter_option_btn.item_count > 1:
				tools_hbox.add_child(panel)
			
			if tools_hbox.get_child_count() == 0:
				tools_container.visible = false
			
	if config.allow_calc:
		_create_calculator_ui()

	# Itens do criador (initial_backpack_csv) e initial_pool_items começam na bancada — igual ao preview do editor.
	for entry in config.get_backpack_entry_list():
		_place_parsed_item_in_pool(pool, entry)
	for entry in config.initial_pool_items:
		if str(entry).strip_edges().is_empty():
			continue
		_place_parsed_item_in_pool(pool, str(entry))
	var min_extra := config.min_bytes_random_pool
	if min_extra <= 0:
		min_extra = max(0, backpack.capacity_bytes - pool.total_bytes_used())
	_generate_extra_pool_items(pool, min_extra)
	_update_bytes_label()
	_update_hint()
	_update_next_button_state()
	call_deferred("_anchor_orb_hover_above_pool")


func _create_calculator_ui():
	var pool_vbox = pool_container.get_parent()
	if not pool_vbox:
		return
		
	# Previne criação duplicada se já existir
	if pool_vbox.has_node("BottomToolsContainer"):
		return
		
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var lbl = Label.new()
	lbl.text = "Calculadora"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(hbox)
	
	var c1 = CenterContainer.new()
	c1.custom_minimum_size = Vector2(64, 64)
	calc_slot_1 = preload("res://Inventory/slots/slot.tscn").instantiate()
	calc_slot_1.slot_ID = 901
	c1.add_child(calc_slot_1)
	hbox.add_child(c1)
	
	calc_op_btn = Button.new()
	calc_op_btn.text = "+"
	calc_op_btn.custom_minimum_size = Vector2(40, 40)
	calc_op_btn.add_theme_font_size_override("font_size", 24)
	calc_op_btn.pressed.connect(func():
		calc_op_btn.text = "-" if calc_op_btn.text == "+" else "+"
		if calculator: calculator.clear_result()
	)
	hbox.add_child(calc_op_btn)
	
	var c2 = CenterContainer.new()
	c2.custom_minimum_size = Vector2(64, 64)
	calc_slot_2 = preload("res://Inventory/slots/slot.tscn").instantiate()
	calc_slot_2.slot_ID = 902
	c2.add_child(calc_slot_2)
	hbox.add_child(c2)
	
	var eq_lbl = Label.new()
	eq_lbl.text = "="
	eq_lbl.custom_minimum_size = Vector2(24, 40)
	eq_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eq_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	eq_lbl.add_theme_font_size_override("font_size", 24)
	hbox.add_child(eq_lbl)
	
	var c3 = CenterContainer.new()
	c3.custom_minimum_size = Vector2(64, 64)
	calc_slot_result = preload("res://Inventory/slots/slot.tscn").instantiate()
	calc_slot_result.slot_ID = 904
	calc_slot_result.set_meta("is_calc_result", true)
	c3.add_child(calc_slot_result)
	hbox.add_child(c3)
	
	for calc_slot in [calc_slot_1, calc_slot_2, calc_slot_result]:
		calc_slot.slot_entered.connect(_on_slot_entered)
		calc_slot.slot_exited.connect(_on_slot_exited)
		
	calculator = CalculatorTool.new(self, calc_slot_1, calc_slot_2, calc_slot_result, calc_op_btn)
	
	var tools_container = VBoxContainer.new()
	tools_container.name = "BottomToolsContainer"
	
	var toggle_btn = Button.new()
	toggle_btn.text = "▲ Ferramentas"
	toggle_btn.custom_minimum_size = Vector2(150, 35) # Força o botão a ter tamanho visível
	
	var tools_hbox = HFlowContainer.new()
	tools_hbox.name = "BottomToolsHBox"
	tools_hbox.alignment = FlowContainer.ALIGNMENT_CENTER
	tools_hbox.add_theme_constant_override("h_separation", 15)
	tools_hbox.add_theme_constant_override("v_separation", 15)
	tools_hbox.visible = false
	
	toggle_btn.pressed.connect(func():
		tools_hbox.visible = not tools_hbox.visible
		toggle_btn.text = "▼ Ferramentas" if tools_hbox.visible else "▲ Ferramentas"
	)
	
	tools_container.add_child(tools_hbox)
	tools_container.add_child(toggle_btn)
	
	pool_vbox.add_child(tools_container)
	# Força a ficar logo abaixo do pool de itens
	pool_vbox.move_child(tools_container, pool_container.get_index() + 1)
	
	var container_para_adicionar = tools_hbox
	
	container_para_adicionar.add_child(panel)
	
	var insp_panel = PanelContainer.new()
	var insp_vbox = VBoxContainer.new()
	insp_panel.add_child(insp_vbox)
	
	var insp_lbl = Label.new()
	insp_lbl.text = "Inspecionar"
	insp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	insp_lbl.add_theme_font_size_override("font_size", 14)
	insp_vbox.add_child(insp_lbl)
	
	var insp_c = CenterContainer.new()
	insp_c.custom_minimum_size = Vector2(64, 64)
	insp_vbox.add_child(insp_c)
	
	inspect_slot = preload("res://Inventory/slots/slot.tscn").instantiate()
	inspect_slot.slot_ID = 903
	insp_c.add_child(inspect_slot)
	
	inspect_slot.slot_entered.connect(_on_slot_entered)
	inspect_slot.slot_exited.connect(_on_slot_exited)
	
	var btn_inspect = Button.new()
	btn_inspect.text = "Ver Detalhes"
	btn_inspect.pressed.connect(_on_btn_inspect_pressed)
	insp_vbox.add_child(btn_inspect)
	
	container_para_adicionar.add_child(insp_panel)


func _clear_container(container: Node):
	for child in container.get_children():
		child.queue_free()


func _make_item_from_entry(entry: String) -> Node2D:
	var e := entry.strip_edges()
	if e.is_empty():
		return null
	if DataHandler and DataHandler.item_data.has(e):
		var by_id: Node2D = ITEM_SCENE.instantiate()
		by_id.load_item(e)
		return by_id
	if e.begins_with("item_"):
		if DataHandler and DataHandler.item_data.has(e):
			var by_id2: Node2D = ITEM_SCENE.instantiate()
			by_id2.load_item(e)
			return by_id2
		push_warning("ID não cadastrado no DataHandler: %s" % e)
		return null
	var parts := e.split("_")
	if parts.size() < 2:
		push_warning("Entrada inválida: %s" % e)
		return null
	var type_str := parts[parts.size() - 1].to_lower()
	var value_str := parts[0]
	for pi in range(1, parts.size() - 1):
		value_str += "_" + parts[pi]
	var shorthand: Node2D = ITEM_SCENE.instantiate()
	if type_str == "i":
		var raw := int(value_str)
		shorthand.set_value_directly(config.clamp_int_value(raw))
	elif type_str == "f":
		if config and not config.allow_float and not config.use_converter:
			# Ainda permite float explícito no CSV da fase (criação manual).
			pass
		shorthand.set_value_by_type(float(value_str), shorthand.DataType.FLOAT)
	elif type_str == "d":
		shorthand.set_value_by_type(float(value_str), shorthand.DataType.DOUBLE)
	elif type_str == "s":
		shorthand.set_value_by_type(int(value_str), shorthand.DataType.SHORT_INT)
	else:
		push_warning("Tipo não suportado no CSV: %s" % type_str)
		shorthand.queue_free()
		return null
	return shorthand


func _entry_type_allowed(dt: int) -> bool:
	# INT sempre; demais tipos se a fase liberou no config.
	if dt == ItemRef.DataType.INT:
		return true
	if config == null:
		return dt == ItemRef.DataType.INT
	if dt == ItemRef.DataType.FLOAT:
		return config.allow_float or config.use_converter
	if dt == ItemRef.DataType.DOUBLE:
		return config.allow_double
	if dt == ItemRef.DataType.SHORT_INT:
		return config.allow_short
	if dt == ItemRef.DataType.FP8:
		return config.allow_fp8
	if dt == ItemRef.DataType.FP16:
		return config.allow_fp16
	return false


func _place_parsed_item_in_pool(grid: InventoryGrid, entry: String) -> void:
	var item := _make_item_from_entry(entry)
	if item == null:
		return
	if not grid.try_place_item_automatically(item):
		item.queue_free()
		push_warning("Bancada: sem espaço para item inicial: %s" % entry)


func _generate_extra_pool_items(pool: InventoryGrid, min_extra_bytes: int):
	var total := 0
	var guard := 0
	while total < min_extra_bytes and guard < pool.number_of_slots * 4:
		guard += 1
		var item: Node2D = ITEM_SCENE.instantiate()
		if config.random_pool.size() > 0:
			var id := str(config.random_pool[randi() % config.random_pool.size()])
			if not DataHandler or not DataHandler.item_data.has(id):
				item.queue_free()
				continue
			item.load_item(id)
		else:
			# Pool extra: INT por padrão; se allow_float, 50% float.
			if config.allow_float and (randi() % 2 == 0):
				item.set_value_by_type(float(randi_range(config.spawn_int_min, config.spawn_int_max)) + 0.5, ItemRef.DataType.FLOAT)
			else:
				item.set_value_directly(randi_range(config.spawn_int_min, config.spawn_int_max))
		var sz: int = item.get_size_bytes() if item.has_method("get_size_bytes") else 1
		if not pool.try_place_item_automatically(item):
			item.queue_free()
			break
		total += sz


func _tutorial_intro_id() -> String:
	return TutorialTexts.KEY_PHASE_BACKPACK


func _on_spawn_pressed():
	if item_held != null:
		return
	var item: Node2D = ITEM_SCENE.instantiate()
	add_child(item)
	if config.random_pool.size() > 0:
		var id := str(config.random_pool[randi() % config.random_pool.size()])
		if DataHandler and DataHandler.item_data.has(id):
			item.load_item(id)
			if item.data_type != item.DataType.INT:
				item.set_value_directly(randi_range(config.spawn_int_min, config.spawn_int_max))
		else:
			item.set_value_directly(randi_range(config.spawn_int_min, config.spawn_int_max))
	else:
		item.set_value_directly(randi_range(config.spawn_int_min, config.spawn_int_max))
	item.selected = true
	item_held = item
	_update_bytes_label()


func is_phase_success() -> bool:
	# Precisa interagir E encher exatamente a capacidade (não conta estouro nem mochila vazia).
	if not backpack_grid:
		return false
	if moves_count <= 0:
		return false
	var used := backpack_grid.total_bytes_used()
	return used == backpack_grid.capacity_bytes

func _on_btn_inspect_pressed():
	if not inspect_slot or inspect_slot.item_stored == null:
		_show_not_ready_modal("Coloque um orbe no slot de inspeção primeiro.")
		return
	var item = inspect_slot.item_stored
	
	_open_orb_inspector(item)
