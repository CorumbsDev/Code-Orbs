extends Control
## Fase 1: Completar binário.
## Esquerda: inventário com 0 e 1. Direita: binário incompleto (ex: 1 _ 0).
## Jogador arrasta 0 ou 1 para o espaço vazio; não há penalidade por errar.

@export var config: BinaryPhaseConfig

@onready var slot_scene = preload("res://Inventory/slots/slot.tscn")
@onready var item_scene = preload("res://Inventory/Items/Item.tscn")
@onready var left_grid = $HBox/LeftPanel/MarginContainer/VBox/GridContainer
@onready var target_slot = $HBox/RightPanel/MarginContainer/VBox/BinaryRow/TargetSlot
@onready var feedback_info_bar = $HBox/RightPanel/MarginContainer/VBox/FeedbackInfoBar
@onready var result_label = $HBox/RightPanel/MarginContainer/VBox/FeedbackInfoBar/MarginContainer/VBoxContainer/ResultLabel
@onready var explanation_label = $HBox/RightPanel/MarginContainer/VBox/FeedbackInfoBar/MarginContainer/VBoxContainer/ExplanationLabel
@onready var binary_display = $HBox/RightPanel/MarginContainer/VBox/BinaryDisplay
@onready var btn_voltar = $TopBar/BtnVoltar
@onready var btn_help = $TopBar/BtnHelp
@onready var btn_proxima = $TopBar/BtnProxima
@onready var title_label = $TopBar/Title
@onready var left_digit_label = $HBox/RightPanel/MarginContainer/VBox/BinaryRow/LeftDigit
@onready var right_digit_label = $HBox/RightPanel/MarginContainer/VBox/BinaryRow/RightDigit
@onready var orb_hover_bar: OrbHoverBar = $HBox/RightPanel/MarginContainer/VBox/OrbHoverBar

var left_slots := []
var item_held = null
var current_slot = null
var can_place = false
var icon_anchor: Vector2
var BINARY_LEFT := "1"
var BINARY_RIGHT := "0"

var _custom_tutorial_text: String = ""
var _uses_custom_tutorial: bool = false
var _is_finishing: bool = false
var _phase_completed: bool = false

func _resolve_binary_config() -> BinaryPhaseConfig:
	var injected := PhaseRunner.take_binary_config_if_any()
	if injected != null:
		return injected
	if config != null:
		return config
	return BinaryPhaseConfig.new()


func _ready():
	if PhaseRunner.has_custom_tutorial():
		_uses_custom_tutorial = true
		_custom_tutorial_text = PhaseRunner.take_tutorial_text_if_any()

	var cfg := _resolve_binary_config()
	cfg.apply_constraints()
	BINARY_LEFT = cfg.left_digit_string()
	BINARY_RIGHT = cfg.right_digit_string()
	if title_label:
		title_label.text = "Fase binário: %s _ %s" % [BINARY_LEFT, BINARY_RIGHT]
	if left_digit_label:
		left_digit_label.text = BINARY_LEFT
	if right_digit_label:
		right_digit_label.text = BINARY_RIGHT
	btn_voltar.pressed.connect(_on_voltar_pressed)
	btn_help.pressed.connect(_on_help_pressed)
	btn_proxima.visible = PhaseRunner.should_show_next_button()
	btn_proxima.disabled = true
	btn_proxima.pressed.connect(_on_proxima_pressed)
	call_deferred("_update_next_button_state")
	_apply_phase_panels()
	# Cria 2 slots à esquerda (inventário de bits)
	for i in range(2):
		var s = slot_scene.instantiate()
		s.slot_ID = i
		left_grid.add_child(s)
		left_slots.append(s)
		s.slot_entered.connect(_on_slot_entered)
		s.slot_exited.connect(_on_slot_exited)
	# Coloca bit 0 no primeiro slot e bit 1 no segundo
	_spawn_bit_at_slot(0, 0)   # bit 0
	_spawn_bit_at_slot(1, 1)   # bit 1
	# Slot alvo (meio): quando recebe item, mostra resultado
	target_slot.slot_entered.connect(_on_slot_entered)
	target_slot.slot_exited.connect(_on_slot_exited)
	target_slot.item_changed.connect(_on_target_item_changed)
	_update_binary_display(null)
	_hide_instruction_panels()
	call_deferred("_try_show_intro")
	call_deferred("_relayout_all_bits")
	call_deferred("_wire_bits_hover")


func _hide_instruction_panels() -> void:
	for path in [
		"HBox/LeftPanel/MarginContainer/VBox/PhaseInfoBar",
		"HBox/RightPanel/MarginContainer/VBox/IntroInfoBar",
	]:
		var panel := get_node_or_null(path) as Control
		if panel:
			panel.visible = false
	if feedback_info_bar:
		feedback_info_bar.visible = false
	if result_label:
		result_label.text = ""
	if explanation_label:
		explanation_label.text = ""


func _relayout_all_bits() -> void:
	for slot in left_slots:
		if slot.item_stored != null and is_instance_valid(slot.item_stored):
			if slot.item_stored.has_method("install_in_slot"):
				slot.item_stored.install_in_slot(slot)
	if target_slot.item_stored != null and is_instance_valid(target_slot.item_stored):
		if target_slot.item_stored.has_method("install_in_slot"):
			target_slot.item_stored.install_in_slot(target_slot)


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

	var k := TutorialTexts.KEY_PHASE_BINARY
	TutorialOverlay.open(self, k, TutorialTexts.title_for(k), TutorialTexts.body_for(k), false)


func _on_help_pressed() -> void:
	if _uses_custom_tutorial and not _custom_tutorial_text.is_empty():
		TutorialOverlay.open(self, "custom", "Tutorial da Fase", _custom_tutorial_text, false)
		return

	var k := TutorialTexts.KEY_PHASE_BINARY
	TutorialOverlay.open(self, k, TutorialTexts.title_for(k), TutorialTexts.body_for(k), false)

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
	if target_slot.item_stored != null:
		orb_hover_bar.wire_orb(target_slot.item_stored)

func _on_voltar_pressed():
	PhaseRunner.abort_sequence()
	get_tree().change_scene_to_file("res://Inventory/fases/main_menu.tscn")


func _on_proxima_pressed():
	if _is_finishing:
		return
	if not is_phase_success():
		_update_next_button_state()
		var dlg := AcceptDialog.new()
		dlg.dialog_text = "Complete o binário antes de avançar."
		add_child(dlg)
		dlg.popup_centered(Vector2(400, 120))
		return
	PhaseRunner.advance_from_phase()

func _on_slot_entered(s):
	current_slot = s
	if item_held and s == target_slot:
		# Só aceita bit (0 ou 1) no slot alvo
		var is_bit = item_held.get("data_type") != null and item_held.data_type == item_held.DataType.BINARY
		if is_bit and item_held.value_binary.length() == 1:
			can_place = true
		else:
			can_place = false
	elif item_held and s in left_slots:
		can_place = false  # não colocar de volta em slot já ocupado por outro; permitir soltar no vazio
		if s.item_stored == null:
			can_place = true

func _on_slot_exited(_s):
	current_slot = null
	can_place = false

func _on_target_item_changed(slot):
	if slot != target_slot:
		return
	if slot.item_stored == null:
		_phase_completed = false
		if feedback_info_bar:
			feedback_info_bar.visible = false
		if result_label:
			result_label.text = ""
		if explanation_label:
			explanation_label.text = ""
		_update_binary_display(null)
		_update_next_button_state()
		return
	var item = slot.item_stored
	var bit_str = item.value_binary if item.value_binary.length() == 1 else str(item.value)
	_update_binary_display(bit_str)
	_phase_completed = true
	if feedback_info_bar:
		feedback_info_bar.visible = true
	if result_label:
		result_label.text = "Objetivo concluído!"
	if explanation_label:
		explanation_label.text = ""
	_refill_bits_if_empty()
	_update_next_button_state()


func is_phase_success() -> bool:
	# Precisa ter colocado um bit no slot alvo.
	return _phase_completed and target_slot != null and target_slot.item_stored != null


func _update_next_button_state() -> void:
	if btn_proxima and btn_proxima.visible:
		btn_proxima.disabled = not is_phase_success()


func _binary_expansion_explanation(full_binary: String, decimal: int) -> String:
	var n := full_binary.length()
	var parts: PackedStringArray = PackedStringArray()
	for i in range(n):
		var bit := full_binary[i]
		var power: int = n - 1 - i
		parts.append("%s×2^%d" % [bit, power])
	var joined := ""
	for i in range(parts.size()):
		if i > 0:
			joined += " + "
		joined += parts[i]
	return "Expansão posicional: " + joined + " = %d." % decimal

func _binary_string_to_int(bin_str: String) -> int:
	var r = 0
	for i in range(bin_str.length()):
		r = r * 2 + int(bin_str[i])
	return r

func _update_binary_display(middle_bit: Variant):
	if middle_bit == null:
		binary_display.text = BINARY_LEFT + " _ " + BINARY_RIGHT
	else:
		binary_display.text = BINARY_LEFT + " " + str(middle_bit) + " " + BINARY_RIGHT

func _refill_bits_if_empty():
	for i in range(left_slots.size()):
		if left_slots[i].item_stored == null:
			_spawn_bit_at_slot(i, i)

@warning_ignore("unused_parameter")
func _process(delta):
	if _is_finishing:
		return
		
	if item_held:
		if Input.is_action_just_pressed("select_item"):
			_try_place_item()
	else:
		if Input.is_action_just_pressed("select_item"):
			_try_pick_item()

func _try_pick_item():
	if current_slot == null or current_slot.item_stored == null:
		return
	item_held = current_slot.pop_item_for_drag(get_global_mouse_position(), self)
	if item_held == null:
		return

func _try_place_item():
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
	if current_slot == target_slot:
		_update_binary_display(placing.value_binary if placing.value_binary.length() == 1 else str(placing.value))
