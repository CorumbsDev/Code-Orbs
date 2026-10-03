extends Control
## Fase: sequência de desafios decimal -> binário (MSB à esquerda).

@export var config: ConversionPhaseConfig
@export var num_bits: int = 3
@export var challenge_decimals: Array[int] = [5, 3, 6]
@export var advance_delay_seconds: float = 2.4

@onready var slot_scene = preload("res://Inventory/slots/slot.tscn")
@onready var item_scene = preload("res://Inventory/Items/Item.tscn")
@onready var left_grid = $HBox/LeftPanel/MarginContainer/VBox/GridContainer
@onready var targets_row = $HBox/RightPanel/MarginContainer/VBox/TargetsRow
@onready var goal_label = $HBox/RightPanel/MarginContainer/VBox/PhaseInfoBar/MarginContainer/VBoxContainer/GoalLabel
@onready var progress_label = $HBox/RightPanel/MarginContainer/VBox/ProgressLabel
@onready var result_label = $HBox/RightPanel/MarginContainer/VBox/PhaseInfoBar/MarginContainer/VBoxContainer/ResultLabel
@onready var explanation_label = $HBox/RightPanel/MarginContainer/VBox/PhaseInfoBar/MarginContainer/VBoxContainer/ExplanationLabel
@onready var btn_voltar = $TopBar/BtnVoltar
@onready var btn_help = $TopBar/BtnHelp
@onready var btn_proxima = $TopBar/BtnProxima
@onready var title_label: Label = $TopBar/Title
@onready var bits_info_label: Label = $TopBar/BitsInfoLabel
@onready var orb_hover_bar: OrbHoverBar = $HBox/RightPanel/MarginContainer/VBox/OrbHoverBar

var left_slots: Array = []
var target_slots: Array = []
var item_held = null
var current_slot = null
var can_place = false
var challenge_idx := 0
var suppress_check := false
var is_advancing := false
var _configured_num_bits := 0
var _is_finishing: bool = false
var _phase_completed: bool = false
var _custom_tutorial_text: String = ""
var _uses_custom_tutorial: bool = false


func _resolve_conversion_config() -> ConversionPhaseConfig:
	var injected := PhaseRunner.take_conversion_config_if_any()
	if injected != null:
		return injected
	if config != null:
		return config
	var fallback := ConversionPhaseConfig.new()
	fallback.num_bits = num_bits
	fallback.challenge_decimals = challenge_decimals.duplicate()
	fallback.advance_delay_seconds = advance_delay_seconds
	return fallback


func _ready():
	if PhaseRunner.has_custom_tutorial():
		_uses_custom_tutorial = true
		_custom_tutorial_text = PhaseRunner.take_tutorial_text_if_any()

	var cfg := _resolve_conversion_config()
	cfg.apply_constraints()
	num_bits = cfg.num_bits
	challenge_decimals = cfg.challenge_decimals.duplicate()
	advance_delay_seconds = cfg.advance_delay_seconds

	btn_voltar.pressed.connect(_on_voltar_pressed)
	btn_help.pressed.connect(_on_help_pressed)
	if btn_proxima:
		btn_proxima.visible = PhaseRunner.should_show_next_button()
		btn_proxima.disabled = true
		btn_proxima.pressed.connect(_on_proxima_pressed)
		call_deferred("_update_next_button_state")

	_apply_phase_panels()
	if challenge_decimals.is_empty():
		challenge_decimals = [5, 3, 6]
	_normalize_challenges()
	_configured_num_bits = num_bits
	_autoadjust_num_bits_for_challenges()
	if num_bits < 1:
		num_bits = 1
	if advance_delay_seconds < 0.3:
		advance_delay_seconds = 0.3
	challenge_idx = 0

	if title_label:
		title_label.text = "Decimal → binário (%d bits)" % num_bits

	for i in range(6):
		var s = slot_scene.instantiate()
		s.slot_ID = i
		left_grid.add_child(s)
		left_slots.append(s)
		s.slot_entered.connect(_on_slot_entered)
		s.slot_exited.connect(_on_slot_exited)
		_spawn_bit_at_slot(i, i % 2)
	for j in range(num_bits):
		var ts = slot_scene.instantiate()
		ts.slot_ID = 100 + j
		ts.state = ts.States.FREE
		targets_row.add_child(ts)
		target_slots.append(ts)
		ts.slot_entered.connect(_on_slot_entered)
		ts.slot_exited.connect(_on_slot_exited)
		ts.item_changed.connect(_on_target_changed)

	_refresh_challenge_ui()
	call_deferred("_try_show_intro")
	call_deferred("_relayout_all_bits")
	call_deferred("_wire_bits_hover")


func _relayout_all_bits() -> void:
	for slot in left_slots:
		if slot.item_stored != null and is_instance_valid(slot.item_stored):
			if slot.item_stored.has_method("install_in_slot"):
				slot.item_stored.install_in_slot(slot)
	for slot in target_slots:
		if slot.item_stored != null and is_instance_valid(slot.item_stored):
			if slot.item_stored.has_method("install_in_slot"):
				slot.item_stored.install_in_slot(slot)


func _apply_phase_panels() -> void:
	var left := get_node_or_null("HBox/LeftPanel") as Control
	var right := get_node_or_null("HBox/RightPanel") as Control
	if left:
		PanelArtLoader.apply_zone_chrome(left)
	if right:
		PanelArtLoader.apply_zone_chrome(right)


func _try_show_intro() -> void:
	if _uses_custom_tutorial and not _custom_tutorial_text.is_empty():
		TutorialOverlay.open(self, "custom", "Tutorial da Fase", _custom_tutorial_text, false)
		return
	var k := TutorialTexts.KEY_PHASE_CONVERSION
	TutorialOverlay.open(self, k, TutorialTexts.title_for(k), TutorialTexts.body_for(k), false)


func _on_help_pressed() -> void:
	if _uses_custom_tutorial and not _custom_tutorial_text.is_empty():
		TutorialOverlay.open(self, "custom", "Tutorial da Fase", _custom_tutorial_text, false)
		return
	var k := TutorialTexts.KEY_PHASE_CONVERSION
	TutorialOverlay.open(self, k, TutorialTexts.title_for(k), TutorialTexts.body_for(k), false)


func _on_voltar_pressed() -> void:
	PhaseRunner.abort_sequence()
	get_tree().change_scene_to_file("res://Inventory/fases/main_menu.tscn")


func _on_proxima_pressed() -> void:
	if _is_finishing:
		return
	if not is_phase_success():
		_update_next_button_state()
		var dlg := AcceptDialog.new()
		dlg.dialog_text = "Conclua todos os desafios de conversão antes de avançar."
		add_child(dlg)
		dlg.popup_centered(Vector2(420, 120))
		return
	PhaseRunner.advance_from_phase()


func is_phase_success() -> bool:
	return _phase_completed


func _update_next_button_state() -> void:
	if btn_proxima and btn_proxima.visible:
		btn_proxima.disabled = not is_phase_success()


func _spawn_bit_at_slot(slot_idx: int, bit_value: int) -> void:
	var slot = left_slots[slot_idx]
	if slot.item_stored != null:
		return
	var item: Node2D = item_scene.instantiate()
	var id := "item_binary_1" if bit_value == 1 else "item_binary_0"
	item.load_item(id)
	if item.has_method("install_in_slot"):
		item.install_in_slot(slot)
	else:
		slot.add_child(item)
		item.position = slot.size * 0.5
	slot.state = slot.States.TAKEN
	slot.item_stored = item
	slot.set_item(item)
	item.grid_anchor = slot
	if orb_hover_bar:
		orb_hover_bar.wire_orb(item)


func _wire_bits_hover() -> void:
	if orb_hover_bar == null:
		return
	orb_hover_bar.wire_slot_items(left_slots)
	orb_hover_bar.wire_slot_items(target_slots)


func _on_slot_entered(s):
	current_slot = s
	if not item_held:
		return
	if s in target_slots:
		var is_bit = item_held.get("data_type") != null and item_held.data_type == item_held.DataType.BINARY
		if is_bit and item_held.value_binary.length() == 1:
			can_place = true
		else:
			can_place = false
	elif s in left_slots:
		can_place = false
		if s.item_stored == null:
			can_place = true


func _on_slot_exited(_s):
	current_slot = null
	can_place = false


func _on_target_changed(_slot):
	if suppress_check:
		return
	_check_solution()


func _check_solution() -> void:
	if is_advancing or _phase_completed:
		return
	var target := _current_target_decimal()
	for t in target_slots:
		if t.item_stored == null:
			_clear_completion_labels()
			return
	var bin_str := ""
	for t in target_slots:
		bin_str += _bit_char_from_item(t.item_stored)
	var expected := _decimal_to_binary_bits(target, num_bits)
	if bin_str == expected:
		if challenge_idx < _challenge_count() - 1:
			is_advancing = true
			var next_idx := challenge_idx + 1
			_clear_completion_labels()
			await get_tree().create_timer(advance_delay_seconds).timeout
			challenge_idx = next_idx
			_clear_target_slots_to_pool()
			_refill_pool_if_empty()
			_refresh_challenge_ui()
			is_advancing = false
		else:
			_phase_completed = true
			_show_completion_message()
			_update_next_button_state()
	else:
		_clear_completion_labels()


func _clear_completion_labels() -> void:
	if result_label:
		result_label.text = ""
		result_label.visible = false
	if explanation_label:
		explanation_label.text = ""
		explanation_label.visible = false


func _show_completion_message() -> void:
	if result_label:
		result_label.text = "Objetivo concluído!"
		result_label.visible = true
	if explanation_label:
		explanation_label.text = "Todos os desafios convertidos."
		explanation_label.visible = true


func _current_target_decimal() -> int:
	var list := _effective_challenges()
	if challenge_idx < 0 or challenge_idx >= list.size():
		return list[0]
	return list[challenge_idx]


func _effective_challenges() -> Array[int]:
	if challenge_decimals == null or challenge_decimals.is_empty():
		return [5, 3, 6]
	return challenge_decimals


func _normalize_challenges() -> void:
	var normalized: Array[int] = []
	for v in challenge_decimals:
		normalized.append(max(0, int(v)))
	challenge_decimals = normalized


func _autoadjust_num_bits_for_challenges() -> void:
	var max_value := 0
	for v in _effective_challenges():
		if v > max_value:
			max_value = v
	var required_bits := 1
	while (1 << required_bits) - 1 < max_value:
		required_bits += 1
	if num_bits < required_bits:
		num_bits = required_bits


func _update_bits_info_label() -> void:
	if not bits_info_label:
		return
	bits_info_label.visible = true
	if num_bits > _configured_num_bits:
		bits_info_label.text = "Bits: %d → ajustado p/ %d" % [_configured_num_bits, num_bits]
	else:
		bits_info_label.text = "Bits: %d" % num_bits


func _challenge_count() -> int:
	return _effective_challenges().size()


func _refresh_challenge_ui() -> void:
	_clear_completion_labels()
	_update_bits_info_label()
	var target := _current_target_decimal()
	var total := _challenge_count()
	if goal_label:
		goal_label.visible = true
		goal_label.text = "Converta %d para binário (%d bits)." % [target, num_bits]
	if progress_label:
		progress_label.visible = true
		progress_label.text = "Desafio %d de %d" % [challenge_idx + 1, total]
	if title_label:
		title_label.text = "Decimal → binário: %d" % target


func _clear_target_slots_to_pool() -> void:
	suppress_check = true
	for slot in target_slots:
		var item = slot.item_stored
		slot.item_stored = null
		slot.state = slot.States.FREE
		slot.set_item(null)
		if item != null:
			_return_item_to_pool(item)
	suppress_check = false


func _return_item_to_pool(item: Node2D) -> void:
	for slot in left_slots:
		if slot.item_stored == null:
			if item.get_parent():
				item.get_parent().remove_child(item)
			slot.add_child(item)
			item.position = Vector2(25, 25)
			item.grid_anchor = slot
			item.selected = false
			slot.item_stored = item
			slot.state = slot.States.TAKEN
			slot.set_item(item)
			return
	if item.get_parent():
		item.get_parent().remove_child(item)
	item.queue_free()


func _bit_char_from_item(item: Node) -> String:
	if item.get("data_type") != null and item.data_type == item.DataType.BINARY and item.value_binary.length() == 1:
		return item.value_binary
	return "0"


func _decimal_to_binary_bits(value: int, bit_count: int) -> String:
	var out := ""
	for i in range(bit_count - 1, -1, -1):
		out += str((value >> i) & 1)
	return out


func _refill_pool_if_empty() -> void:
	for i in range(left_slots.size()):
		if left_slots[i].item_stored == null:
			_spawn_bit_at_slot(i, i % 2)


@warning_ignore("unused_parameter")
func _process(_delta):
	if _is_finishing:
		return
	if item_held:
		if Input.is_action_just_pressed("select_item"):
			_try_place_item()
	else:
		if Input.is_action_just_pressed("select_item"):
			_try_pick_item()


func _try_pick_item() -> void:
	if current_slot == null or current_slot.item_stored == null:
		return
	item_held = current_slot.pop_item_for_drag(get_global_mouse_position(), self)
	if item_held == null:
		return
	if current_slot in target_slots:
		_check_solution()


func _try_place_item() -> void:
	if not can_place or current_slot == null:
		return
	var placing = item_held
	placing.selected = false
	if placing.has_method("install_in_slot"):
		placing.install_in_slot(current_slot)
	else:
		placing.get_parent().remove_child(placing)
		current_slot.add_child(placing)
		placing.position = current_slot.size * 0.5
		placing.grid_anchor = current_slot
	current_slot.item_stored = placing
	current_slot.state = current_slot.States.TAKEN
	current_slot.set_item(placing)
	placing.grid_anchor = current_slot
	if orb_hover_bar:
		orb_hover_bar.wire_orb(placing)
	item_held = null
	can_place = false
	_refill_pool_if_empty()
