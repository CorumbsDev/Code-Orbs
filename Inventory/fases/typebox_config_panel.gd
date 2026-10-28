class_name TypeboxConfigPanel
extends RefCounted

var ui: Dictionary

var typebox_grid: GridContainer = null
var spin_slots_int: SpinBox = null
var spin_slots_float: SpinBox = null
var spin_slots_short: SpinBox = null
var spin_slots_double: SpinBox = null
var spin_slots_fp8: SpinBox = null
var spin_slots_fp16: SpinBox = null

func _init(ui_elements: Dictionary) -> void:
	ui = ui_elements

func _ensure_typebox_grid() -> void:
	if typebox_grid != null and is_instance_valid(typebox_grid):
		return
	var vbox: VBoxContainer = ui.get("configs_vbox")
	if not vbox:
		return
		
	typebox_grid = GridContainer.new()
	typebox_grid.columns = 4
	typebox_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	typebox_grid.add_theme_constant_override("h_separation", 10)
	typebox_grid.add_theme_constant_override("v_separation", 6)
	
	var cb: Callable = ui.get("trigger_save_callback", Callable())
	
	var make_entry = func(label_text: String, min_v: float, max_v: float) -> SpinBox:
		var lbl = Label.new()
		lbl.text = label_text
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		typebox_grid.add_child(lbl)
		var sp = SpinBox.new()
		sp.min_value = min_v
		sp.max_value = max_v
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if cb.is_valid():
			sp.value_changed.connect(cb)
		typebox_grid.add_child(sp)
		return sp

	spin_slots_int = make_entry.call("Slots INT:", 0.0, 20.0)
	spin_slots_float = make_entry.call("Slots FLOAT:", 0.0, 20.0)
	spin_slots_short = make_entry.call("Slots SHORT:", 0.0, 20.0)
	spin_slots_double = make_entry.call("Slots DOUBLE:", 0.0, 20.0)
	spin_slots_fp8 = make_entry.call("Slots FP8:", 0.0, 20.0)
	spin_slots_fp16 = make_entry.call("Slots FP16:", 0.0, 20.0)
	
	var hbox_m = ui.get("hbox_mochila")
	if hbox_m and hbox_m.get_parent() == vbox:
		var idx = hbox_m.get_index() + 1
		vbox.add_child(typebox_grid)
		vbox.move_child(typebox_grid, idx)
	else:
		vbox.add_child(typebox_grid)

func show_data(step: PhaseSequenceStep) -> void:
	var cfg = step.config_type_box
	if not cfg:
		cfg = TypeBoxPhaseConfig.new()
		step.config_type_box = cfg
		
	_ensure_typebox_grid()
	if typebox_grid:
		typebox_grid.visible = true
		if spin_slots_int: spin_slots_int.set_value_no_signal(cfg.slots_int)
		if spin_slots_float: spin_slots_float.set_value_no_signal(cfg.slots_float)
		if spin_slots_short: spin_slots_short.set_value_no_signal(cfg.slots_short)
		if spin_slots_double: spin_slots_double.set_value_no_signal(cfg.slots_double)
		if spin_slots_fp8: spin_slots_fp8.set_value_no_signal(cfg.slots_fp8)
		if spin_slots_fp16: spin_slots_fp16.set_value_no_signal(cfg.slots_fp16)
		
	var joined := ", ".join(cfg.initial_raw_values)
	if ui.line_edit_csv.text != joined:
		ui.line_edit_csv.text = joined
	ui.spin_rnd_pool.value = 1 if cfg.randomize_values else 0
	ui.spin_star2_moves.value = cfg.star2_max_moves
	if not cfg.expected_solution_types.is_empty():
		ui.line_edit_star3_solution.text = ", ".join(cfg.expected_solution_types)
	else:
		ui.line_edit_star3_solution.text = cfg.star3_best_solution_csv

func apply_to_step(step: PhaseSequenceStep) -> void:
	var cfg: TypeBoxPhaseConfig = step.config_type_box
	if not cfg:
		cfg = ConfigGenerator.generate_type_box_config()
		step.config_type_box = cfg
		
	if typebox_grid:
		if spin_slots_int: cfg.slots_int = int(spin_slots_int.value)
		if spin_slots_float: cfg.slots_float = int(spin_slots_float.value)
		if spin_slots_short: cfg.slots_short = int(spin_slots_short.value)
		if spin_slots_double: cfg.slots_double = int(spin_slots_double.value)
		if spin_slots_fp8: cfg.slots_fp8 = int(spin_slots_fp8.value)
		if spin_slots_fp16: cfg.slots_fp16 = int(spin_slots_fp16.value)
		cfg.apply_constraints()

	var vals: PackedStringArray = PackedStringArray()
	for p in ui.line_edit_csv.text.split(",", false):
		var p_str: String = p
		var s := p_str.strip_edges()
		if not s.is_empty():
			vals.append(s)
	cfg.initial_raw_values = vals
	cfg.randomize_values = (int(ui.spin_rnd_pool.value) > 0)
	cfg.star2_max_moves = int(ui.spin_star2_moves.value)
	var sol_text: String = str(ui.line_edit_star3_solution.text).strip_edges()
	cfg.star3_best_solution_csv = sol_text
	var exp_types: PackedStringArray = PackedStringArray()
	if not sol_text.is_empty():
		for item in sol_text.split(",", false):
			var s := item.strip_edges().to_lower()
			if not s.is_empty():
				if s.ends_with("_i"): s = "int"
				elif s.ends_with("_f"): s = "float"
				elif s.ends_with("_d"): s = "double"
				elif s.ends_with("_s"): s = "short"
				exp_types.append(s)
	cfg.expected_solution_types = exp_types

func get_visibility_rules() -> Dictionary:
	return {
		"hbox_type": false,
		"grid_mochila": false,
		"hbox_mochila": true,
		"sep_mochila": true,
		"hbox_valores": true,
		"grid_vals": false,
		"sep_valores": true,
		"lbl_csv": true,
		"line_edit_csv": true,
		"lbl_rnd_pool": true,
		"spin_rnd_pool": true,
		"sep_tools": false,
		"lbl_tools": false,
		"check_float": false,
		"check_double": false,
		"check_short": false,
		"check_fp8": false,
		"check_fp16": false,
		"check_fp_cust": false,
		"check_calc": false,
		"star_grid": true,
		"binary_panel": false,
		"lbl_csv_text": "Valores brutos iniciais (ex: 5, -18, 5.0, 0.25, 0.0):",
		"line_edit_csv_placeholder": "5, -18, 5.0, 0.25, 0.0",
		"lbl_rnd_pool_text": "Valores aleatórios (1=sim, 0=não):",
		"lbl_star3_text": "Tipos esperados (CSV, ex: int, float):",
		"line_edit_star3_placeholder": "int, int, float, float, float"
	}
