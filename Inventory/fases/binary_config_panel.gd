class_name BinaryConfigPanel
extends RefCounted

var ui: Dictionary

func _init(ui_elements: Dictionary) -> void:
	ui = ui_elements

func show_data(step: PhaseSequenceStep) -> void:
	var bc: BinaryPhaseConfig = step.config_binario
	if not bc:
		bc = ConfigGenerator.generate_binary_config()
		step.config_binario = bc
	ui.spin_bin_left.min_value = 0
	ui.spin_bin_left.max_value = 1
	ui.spin_bin_right.min_value = 0
	ui.spin_bin_right.max_value = 1
	ui.spin_bin_left.value = bc.fixed_left_bit
	ui.spin_bin_right.value = bc.fixed_right_bit
	_set_binary_labels("Bit fixo esquerda:", "Bit fixo direita:")

func apply_to_step(step: PhaseSequenceStep) -> void:
	var bc: BinaryPhaseConfig = step.config_binario
	if not bc:
		bc = ConfigGenerator.generate_binary_config()
		step.config_binario = bc
	bc.fixed_left_bit = int(ui.spin_bin_left.value)
	bc.fixed_right_bit = int(ui.spin_bin_right.value)

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
		"sep_mochila": false,
		"hbox_valores": false,
		"grid_vals": false,
		"sep_valores": false,
		"lbl_csv": true,
		"line_edit_csv": false,
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
		"lbl_csv_text": "Itens forçados (não usado em fase binária):",
		"line_edit_csv_placeholder": "",
		"lbl_rnd_pool_text": ""
	}
