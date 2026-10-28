class_name RawConfigPanel
extends RefCounted

var ui: Dictionary

func _init(ui_elements: Dictionary) -> void:
	ui = ui_elements

func show_data(step: PhaseSequenceStep) -> void:
	var cfg: RawKnapsackPhaseConfig = step.config_raw_mochila
	if not cfg:
		cfg = ConfigGenerator.generate_raw_knapsack_config()
		step.config_raw_mochila = cfg
	ui.spin_cap.value = cfg.capacity_bytes
	ui.spin_slots_m.value = cfg.backpack_slot_count
	ui.spin_slots_p.value = cfg.pool_slot_count
	ui.spin_cols.value = cfg.pool_grid_columns
	var joined := ",".join(cfg.initial_raw_values)
	if ui.line_edit_csv.text != joined:
		ui.line_edit_csv.text = joined
	ui.spin_rnd_pool.value = 1 if cfg.randomize_values else 0
	ui.check_float.button_pressed = cfg.allow_float
	ui.check_double.button_pressed = cfg.allow_double
	ui.check_short.button_pressed = cfg.allow_short
	ui.check_fp8.button_pressed = cfg.allow_fp8
	ui.check_fp16.button_pressed = cfg.allow_fp16
	ui.check_calc.button_pressed = false
	ui.check_fp_cust.button_pressed = false
	ui.spin_star2_moves.value = cfg.star2_max_moves
	ui.line_edit_star3_solution.text = cfg.star3_best_solution_csv
	MemoryLayout.select_option(ui.opt_slot_bytes, cfg.slot_bytes)

func apply_to_step(step: PhaseSequenceStep) -> void:
	var cfg: RawKnapsackPhaseConfig = step.config_raw_mochila
	if not cfg:
		cfg = ConfigGenerator.generate_raw_knapsack_config()
		step.config_raw_mochila = cfg
	cfg.backpack_slot_count = int(ui.spin_slots_m.value)
	cfg.pool_slot_count = int(ui.spin_slots_p.value)
	cfg.pool_grid_columns = int(ui.spin_cols.value)
	var raw_vals: PackedStringArray = PackedStringArray()
	for p in ui.line_edit_csv.text.split(",", false):
		var p_str: String = p
		var s := p_str.strip_edges()
		if not s.is_empty():
			raw_vals.append(s)
	cfg.initial_raw_values = raw_vals
	cfg.randomize_values = (int(ui.spin_rnd_pool.value) > 0)
	cfg.allow_float = ui.check_float.button_pressed
	cfg.allow_double = ui.check_double.button_pressed
	cfg.allow_short = ui.check_short.button_pressed
	cfg.allow_fp8 = ui.check_fp8.button_pressed
	cfg.allow_fp16 = ui.check_fp16.button_pressed
	cfg.star2_max_moves = int(ui.spin_star2_moves.value)
	cfg.star3_best_solution_csv = ui.line_edit_star3_solution.text.strip_edges()
	cfg.slot_bytes = MemoryLayout.read_option(ui.opt_slot_bytes)
	if cfg.slot_bytes == 1:
		cfg.capacity_bytes = cfg.backpack_slot_count
		ui.spin_cap.value = cfg.capacity_bytes
	else:
		cfg.capacity_bytes = int(ui.spin_cap.value)

func get_visibility_rules() -> Dictionary:
	return {
		"spin_cap": true,
		"lbl_cap": true,
		"grid_mochila": true,
		"hbox_mochila": true,
		"sep_mochila": true,
		"hbox_valores": true,
		"grid_vals": false,
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
		"check_fp_cust": false,
		"check_calc": false,
		"star_grid": true,
		"binary_panel": false,
		"lbl_csv_text": "Valores RAW no pool (ex: 7, 3.14, 42):",
		"line_edit_csv_placeholder": "7, 3.14, 42",
		"lbl_rnd_pool_text": "Valores aleatórios (1=sim, 0=não):",
		"opt_slot_bytes": true
	}
