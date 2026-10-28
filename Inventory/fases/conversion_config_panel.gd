class_name ConversionConfigPanel
extends RefCounted

var ui: Dictionary

func _init(ui_elements: Dictionary) -> void:
	ui = ui_elements

func show_data(step: PhaseSequenceStep) -> void:
	var cc: ConversionPhaseConfig = step.config_conversao
	if not cc:
		cc = ConfigGenerator.generate_conversion_config()
		step.config_conversao = cc
	cc.apply_constraints()
	ui.spin_bin_left.max_value = 16
	ui.spin_bin_left.min_value = 1
	ui.spin_bin_right.max_value = 100
	ui.spin_bin_right.min_value = 3
	ui.spin_bin_left.value = cc.num_bits
	ui.spin_bin_right.value = int(round(cc.advance_delay_seconds * 10.0))
	ui.line_edit_csv.text = cc.challenges_csv()
	_set_binary_labels("Qtd. de bits:", "Delay (x0.1s):")

func apply_to_step(step: PhaseSequenceStep) -> void:
	var cc: ConversionPhaseConfig = step.config_conversao
	if not cc:
		cc = ConfigGenerator.generate_conversion_config()
		step.config_conversao = cc
	cc.num_bits = clampi(int(ui.spin_bin_left.value), 1, 16)
	cc.advance_delay_seconds = maxf(0.3, float(ui.spin_bin_right.value) / 10.0)
	cc.set_challenges_from_csv(ui.line_edit_csv.text.strip_edges())
	cc.apply_constraints()

func _set_binary_labels(left_txt: String, right_txt: String) -> void:
	var left_lbl = ui.spin_bin_left.get_parent().get_node_or_null("LblBinLeft")
	var right_lbl = ui.spin_bin_right.get_parent().get_node_or_null("LblBinRight")
	if left_lbl:
		left_lbl.text = left_txt
	if right_lbl:
		right_lbl.text = right_txt

func get_visibility_rules() -> Dictionary:
	return {
		"hbox_type": false,
		"grid_mochila": false,
		"hbox_mochila": false,
		"sep_mochila": true,
		"hbox_valores": false,
		"grid_vals": false,
		"sep_valores": true,
		"lbl_csv": true,
		"line_edit_csv": true,
		"lbl_rnd_pool": false,
		"spin_rnd_pool": false,
		"sep_tools": false,
		"lbl_tools": false,
		"check_float": false,
		"check_double": false,
		"check_short": false,
		"check_fp8": false,
		"check_fp16": false,
		"check_fp_cust": false,
		"check_calc": false,
		"binary_panel": true,
		"star_grid": false,
		"lbl_csv_text": "Desafios decimais (ex: 5, 3, 6):",
		"line_edit_csv_placeholder": "5, 3, 6",
		"lbl_rnd_pool_text": ""
	}
