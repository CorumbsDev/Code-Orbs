extends Node

const PATH_PHASE2 := "res://Inventory/fases/phase2.tscn"
const PATH_BINARY := "res://Inventory/fases/binary_phase.tscn"
const PATH_TYPE_BOX := "res://Inventory/fases/type_box_phase.tscn"
const PATH_RAW_MOCHILA := "res://Inventory/fases/raw_knapsack_phase.tscn"
const PATH_CONVERSAO := "res://Inventory/fases/conversion_phase.tscn"
const PATH_MENU := "res://Inventory/fases/main_menu.tscn"

signal phase_advance_blocked(reason: String)

var _steps: Array = []
var _idx: int = -1
var _active: bool = false
var _pending_backpack: PhaseConfig = null
var _pending_binary: BinaryPhaseConfig = null
var _pending_type_box: TypeBoxPhaseConfig = null
var _pending_raw_mochila: RawKnapsackPhaseConfig = null
var _pending_conversion: ConversionPhaseConfig = null
var _pending_tutorial_title: String = ""
var _pending_tutorial_text: String = ""
var _has_pending_tutorial: bool = false


func is_sequence_active() -> bool:
	return _active


func should_show_next_button() -> bool:
	return _active


func begin_with_steps(steps: Array) -> void:
	abort_sequence()
	var playable := PhaseSequenceStep.filter_playable_steps(steps)
	if playable.is_empty():
		push_warning("PhaseRunner: sequência vazia (ou só fases desabilitadas).")
		return
	for s in playable:
		_steps.append(s)
	if _steps.is_empty():
		return
	_active = true
	_idx = 0
	_go_step(_idx)


func advance_from_phase() -> void:
	if not _active:
		return
	var current_scene = get_tree().get_current_scene()
	if current_scene and current_scene.has_method("is_phase_success"):
		var ok: bool = current_scene.is_phase_success()
		if not ok:
			phase_advance_blocked.emit("Objetivo não concluído. Complete a fase antes de avançar.")
			return
	# Progresso de conquistas (IDs pedagógicos do AchievementManager)
	if AchievementManager != null and _idx >= 0 and _idx < _steps.size():
		AchievementManager.on_phase_completed(_steps[_idx], current_scene)

	_idx += 1
	if _idx >= _steps.size():
		_finish_sequence_to_menu()
		return
	_go_step(_idx)


## Avança índice sem validar sucesso nem conceder conquistas (fases desabilitadas).
func _advance_index_skip_achievements() -> void:
	_idx += 1
	if _idx >= _steps.size():
		_finish_sequence_to_menu()
		return
	_go_step(_idx)


func take_backpack_config_if_any() -> PhaseConfig:
	var c := _pending_backpack
	_pending_backpack = null
	return c


func take_binary_config_if_any() -> BinaryPhaseConfig:
	var c := _pending_binary
	_pending_binary = null
	return c

func take_type_box_config_if_any() -> TypeBoxPhaseConfig:
	var c := _pending_type_box
	_pending_type_box = null
	return c


func take_raw_knapsack_config_if_any() -> RawKnapsackPhaseConfig:
	var c := _pending_raw_mochila
	_pending_raw_mochila = null
	return c


func take_conversion_config_if_any() -> ConversionPhaseConfig:
	var c := _pending_conversion
	_pending_conversion = null
	return c


func has_custom_tutorial() -> bool:
	return _has_pending_tutorial

func take_tutorial_if_any() -> Dictionary:
	var t := _pending_tutorial_title
	var b := _pending_tutorial_text
	_pending_tutorial_title = ""
	_pending_tutorial_text = ""
	_has_pending_tutorial = false
	return {"title": t, "body": b}


func abort_sequence() -> void:
	_active = false
	_steps.clear()
	_idx = -1
	_pending_backpack = null
	_pending_binary = null
	_pending_type_box = null
	_pending_raw_mochila = null
	_pending_conversion = null
	_pending_tutorial_title = ""
	_pending_tutorial_text = ""
	_has_pending_tutorial = false


func _go_step(i: int) -> void:
	if i < 0 or i >= _steps.size():
		return
	var step: PhaseSequenceStep = _steps[i]
	_pending_tutorial_title = step.custom_tutorial_title
	_pending_tutorial_text = step.custom_tutorial_text
	_has_pending_tutorial = step.use_custom_tutorial
	match step.kind:
		PhaseSequenceStep.Kind.MOCHILA:
			var cfg: PhaseConfig = step.config_mochila if step.config_mochila else PhaseConfig.new()
			_pending_backpack = cfg.duplicate(true)
			get_tree().change_scene_to_file(PATH_PHASE2)
		PhaseSequenceStep.Kind.BINARIO:
			if not PhaseSequenceStep.binary_phases_enabled():
				push_warning("PhaseRunner: fase binária ignorada (desabilitada).")
				_advance_index_skip_achievements()
				return
			var bc: BinaryPhaseConfig = step.config_binario if step.config_binario else BinaryPhaseConfig.new()
			_pending_binary = bc.duplicate(true)
			get_tree().change_scene_to_file(PATH_BINARY)
		PhaseSequenceStep.Kind.TYPE_BOX:
			var tbc: TypeBoxPhaseConfig = step.config_type_box if step.config_type_box else TypeBoxPhaseConfig.new()
			_pending_type_box = tbc.duplicate(true)
			get_tree().change_scene_to_file(PATH_TYPE_BOX)
		PhaseSequenceStep.Kind.RAW_MOCHILA:
			var rkc: RawKnapsackPhaseConfig = step.config_raw_mochila if step.config_raw_mochila else RawKnapsackPhaseConfig.new()
			_pending_raw_mochila = rkc.duplicate(true)
			get_tree().change_scene_to_file(PATH_RAW_MOCHILA)
		PhaseSequenceStep.Kind.CONVERSAO:
			if not PhaseSequenceStep.conversion_phases_enabled():
				push_warning("PhaseRunner: fase de conversão ignorada (desabilitada).")
				_advance_index_skip_achievements()
				return
			var cc: ConversionPhaseConfig = step.config_conversao if step.config_conversao else ConversionPhaseConfig.new()
			_pending_conversion = cc.duplicate(true)
			get_tree().change_scene_to_file(PATH_CONVERSAO)


func _finish_sequence_to_menu() -> void:
	abort_sequence()
	get_tree().change_scene_to_file(PATH_MENU)
