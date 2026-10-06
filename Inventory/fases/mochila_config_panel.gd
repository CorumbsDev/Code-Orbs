class_name MochilaConfigPanel
extends RefCounted

var ui: Dictionary

func _init(ui_elements: Dictionary) -> void:
	ui = ui_elements

func show_data(step: PhaseSequenceStep) -> void:
	var cfg = step.config_mochila
	if not cfg:
		cfg = PhaseConfig.new()
		step.config_mochila = cfg
		
	ui.spin_slots_m.value = cfg.backpack_slot_count
	ui.spin_slots_p.value = cfg.pool_slot_count
	ui.spin_cols.value = cfg.pool_grid_columns
	ui.spin_min.value = cfg.spawn_int_min
	ui.spin_max.value = cfg.spawn_int_max
	if ui.line_edit_csv.text != cfg.initial_backpack_csv:
		ui.line_edit_csv.text = cfg.initial_backpack_csv
	ui.spin_rnd_pool.value = cfg.random_pool.size()
	ui.check_float.button_pressed = cfg.use_converter
	ui.check_double.button_pressed = cfg.allow_double
	ui.check_short.button_pressed = cfg.allow_short
	ui.check_fp8.button_pressed = cfg.allow_fp8
	ui.check_fp16.button_pressed = cfg.allow_fp16
	ui.check_fp_cust.button_pressed = cfg.allow_fp_customization
	ui.check_calc.button_pressed = cfg.allow_calc
	ui.spin_star2_moves.value = cfg.star2_max_moves
	if ui.line_edit_star3_solution.text != cfg.star3_best_solution_csv:
		ui.line_edit_star3_solution.text = cfg.star3_best_solution_csv
	MemoryLayout.select_option(ui.opt_slot_bytes, cfg.slot_bytes)

func apply_to_step(step: PhaseSequenceStep, last_rnd_pool_size: int) -> int:
	var cfg: PhaseConfig = step.config_mochila
	if not cfg:
		cfg = PhaseConfig.new()
		step.config_mochila = cfg
		
	cfg.backpack_slot_count = int(ui.spin_slots_m.value)
	cfg.pool_slot_count = int(ui.spin_slots_p.value)
	cfg.pool_grid_columns = int(ui.spin_cols.value)
	cfg.spawn_int_min = int(ui.spin_min.value)
	cfg.spawn_int_max = int(ui.spin_max.value)
	cfg.initial_backpack_csv = ui.line_edit_csv.text.strip_edges()
	
	var pool_size := int(ui.spin_rnd_pool.value)
	if pool_size != last_rnd_pool_size:
		if pool_size > 0:
			cfg.random_pool = ConfigGenerator._random_int_items(pool_size)
		else:
			cfg.random_pool.clear()
		last_rnd_pool_size = pool_size
		
	cfg.use_converter = ui.check_float.button_pressed
	cfg.allow_double = ui.check_double.button_pressed
	cfg.allow_short = ui.check_short.button_pressed
	cfg.allow_fp8 = ui.check_fp8.button_pressed
	cfg.allow_fp16 = ui.check_fp16.button_pressed
	cfg.allow_fp_customization = ui.check_fp_cust.button_pressed
	cfg.allow_calc = ui.check_calc.button_pressed
	cfg.star2_max_moves = int(ui.spin_star2_moves.value)
	cfg.star3_best_solution_csv = ui.line_edit_star3_solution.text.strip_edges()
	cfg.slot_bytes = MemoryLayout.read_option(ui.opt_slot_bytes)
	cfg.capacity_bytes = cfg.backpack_slot_count * cfg.slot_bytes
	
	return last_rnd_pool_size

func get_visibility_rules() -> Dictionary:
	return {
		"spin_cap": false,
		"lbl_cap": false,
		"grid_mochila": true,
		"hbox_mochila": true,
		"sep_mochila": true,
		"hbox_valores": true,
		"grid_vals": true,
		"sep_valores": true,
		"lbl_csv": true,
		"line_edit_csv": true,
		"lbl_rnd_pool": true,
		"spin_rnd_pool": true,
		"sep_tools": true,
		"lbl_tools": true,
		"check_float": true,
		"check_double": true,
		"check_short": true,
		"check_fp8": true,
		"check_fp16": true,
		"check_fp_cust": true,
		"check_calc": true,
		"star_grid": true,
		"binary_panel": false,
		"lbl_csv_text": "Itens iniciais na bancada (ex: 1_i, 2_i, 3.14_f):",
		"line_edit_csv_placeholder": "1_i, 2_i, 3.14_f",
		"lbl_rnd_pool_text": "Qtd Tipos Aleatórios Extra:",
		"opt_slot_bytes": true
	}
