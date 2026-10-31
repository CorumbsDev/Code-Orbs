extends Node

const PATH_PHASE2 := "res://Inventory/fases/phase2.tscn"
const PATH_BINARY := "res://Inventory/fases/binary_phase.tscn"
const PATH_TYPE_BOX := "res://Inventory/fases/type_box_phase.tscn"
const PATH_RAW_MOCHILA := "res://Inventory/fases/raw_knapsack_phase.tscn"
const PATH_CONVERSAO := "res://Inventory/fases/conversion_phase.tscn"
const PATH_MENU := "res://Inventory/fases/main_menu.tscn"
const PATH_VICTORY_SCREEN := "res://Inventory/fases/sequence_victory_screen.tscn"
const STARS_SAVE_PATH := "user://player_stars.json"

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

var _run_phase_stars: Dictionary = {}
var _saved_phase_stars: Dictionary = {}
var _stars_loaded: bool = false
var _total_run_moves: int = 0


func _ready() -> void:
	_load_saved_stars()


func _load_saved_stars() -> void:
	_stars_loaded = true
	if not FileAccess.file_exists(STARS_SAVE_PATH):
		_saved_phase_stars = {}
		return
	var f := FileAccess.open(STARS_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var json = JSON.parse_string(text)
	if json is Dictionary and json.get("phases") is Dictionary:
		_saved_phase_stars = json.get("phases")
	else:
		_saved_phase_stars = {}


func _ensure_stars_loaded() -> void:
	if not _stars_loaded:
		_load_saved_stars()


func _save_stars_to_file() -> void:
	# Calcula antes de abrir o arquivo (abrir em WRITE o trunca).
	var data := {
		"version": 1,
		"phases": _saved_phase_stars,
		"total_stars": get_total_saved_stars()
	}
	var f := FileAccess.open(STARS_SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func record_phase_stars(phase_idx: int, title: String, s1: bool, s2: bool, s3: bool, moves: int) -> void:
	_ensure_stars_loaded()
	var stars_count := int(s1) + int(s2) + int(s3)
	var record := {
		"title": title,
		"s1": s1,
		"s2": s2,
		"s3": s3,
		"stars": stars_count,
		"moves": moves
	}
	_run_phase_stars[phase_idx] = record
	_total_run_moves += moves

	var key := str(phase_idx)
	var prev = _saved_phase_stars.get(key)
	var should_save := false
	if prev == null:
		should_save = true
	else:
		var prev_stars: int = int(prev.get("stars", 0))
		var prev_moves: int = int(prev.get("moves", 999999))
		if stars_count > prev_stars or (stars_count == prev_stars and moves < prev_moves):
			should_save = true

	if should_save:
		_saved_phase_stars[key] = record
		_save_stars_to_file()


func get_run_stars_count() -> int:
	var total := 0
	for k in _run_phase_stars:
		total += int(_run_phase_stars[k].get("stars", 0))
	return total


func get_total_saved_stars() -> int:
	_ensure_stars_loaded()
	var total := 0
	for k in _saved_phase_stars:
		total += int(_saved_phase_stars[k].get("stars", 0))
	return total


func get_max_total_stars() -> int:
	var count := _steps.size() if _active and _steps.size() > 0 else 14
	return count * 3


func get_total_run_moves() -> int:
	return _total_run_moves


func get_all_phases_summary() -> Array[Dictionary]:
	_ensure_stars_loaded()
	var summary: Array[Dictionary] = []
	var total_count: int = _steps.size() if _active and _steps.size() > 0 else 14
	var default_titles := [
		"Ponto de Partida Inicial", "Tipos de Dados", "Está Apertado", "Agora Explodiu",
		"Conversão pela Adição", "A Soma Explosiva", "O Corte Seco", "A Ilusão do Float",
		"Espremendo a Mantissa", "O Abismo do Underflow", "Quantização em Lote", "O Mestre dos Dados",
		"Primeira Declaração", "O Arquiteto de Sistema"
	]

	for i in range(total_count):
		var key := str(i)
		var title := ""
		if _active and i < _steps.size() and _steps[i] is PhaseSequenceStep:
			title = (_steps[i] as PhaseSequenceStep).custom_tutorial_title.strip_edges()
		if title.is_empty():
			if i < default_titles.size():
				title = default_titles[i]
			else:
				title = "Fase %d" % (i + 1)

		var run_data = _run_phase_stars.get(i)
		var saved_data = _saved_phase_stars.get(key)

		var best_stars := 0
		var s1 := false
		var s2 := false
		var s3 := false
		var moves := 0
		var completed := false

		if saved_data != null:
			best_stars = int(saved_data.get("stars", 0))
			s1 = bool(saved_data.get("s1", false))
			s2 = bool(saved_data.get("s2", false))
			s3 = bool(saved_data.get("s3", false))
			moves = int(saved_data.get("moves", 0))
			completed = true

		if run_data != null:
			var r_stars: int = int(run_data.get("stars", 0))
			if r_stars >= best_stars:
				best_stars = r_stars
				s1 = bool(run_data.get("s1", false))
				s2 = bool(run_data.get("s2", false))
				s3 = bool(run_data.get("s3", false))
				moves = int(run_data.get("moves", 0))
				completed = true

		summary.append({
			"index": i,
			"number": i + 1,
			"title": title,
			"stars": best_stars,
			"s1": s1,
			"s2": s2,
			"s3": s3,
			"moves": moves,
			"completed": completed
		})
	return summary


func restart_sequence() -> void:
	abort_sequence()
	var fm := SequenceFileManager.new()
	var steps := fm.get_play_steps()
	if not steps.is_empty():
		begin_with_steps(steps)
	else:
		get_tree().change_scene_to_file(PATH_MENU)


func is_sequence_active() -> bool:
	return _active


## Refaz a fase atual recarregando exatamente a configuração original do step
## (a config pendente é consumida ao entrar na fase, então recarregar a cena sozinha
## perderia os orbes/valores originais).
func restart_current_phase() -> void:
	if _active and _idx >= 0 and _idx < _steps.size():
		_go_step(_idx)
	else:
		get_tree().reload_current_scene()


func should_show_next_button() -> bool:
	return _active


## Índice 1-based da fase atual na sequência ativa (0 se inativo).
func current_phase_number() -> int:
	if not _active or _idx < 0:
		return 0
	return _idx + 1


func total_phases() -> int:
	return _steps.size() if _active else 0


func is_last_phase() -> bool:
	return _active and _idx >= 0 and _idx == _steps.size() - 1


func get_current_step() -> PhaseSequenceStep:
	if not _active or _idx < 0 or _idx >= _steps.size():
		return null
	var s = _steps[_idx]
	return s as PhaseSequenceStep if s is PhaseSequenceStep else null


## Título amigável do step (custom do criador, se houver).
func peek_step_title() -> String:
	var step := get_current_step()
	if step == null:
		return ""
	return step.custom_tutorial_title.strip_edges()


func begin_with_steps(steps: Array) -> void:
	abort_sequence()
	var playable := PhaseSequenceStep.filter_playable_steps(steps)
	if playable.is_empty():
		push_warning("PhaseRunner: sequência vazia (ou só fases desabilitadas).")
		return
	for s in playable:
		# Cópia profunda: save/edição no criador não altera a run em andamento.
		if s is PhaseSequenceStep:
			var dup := (s as PhaseSequenceStep).duplicate(true) as PhaseSequenceStep
			dup.sanitize_configs_for_kind()
			_steps.append(dup)
		else:
			_steps.append(s)
	if _steps.is_empty():
		return
	_active = true
	_idx = 0
	if BGMManager != null and BGMManager.has_method("play_game_start"):
		BGMManager.play_game_start()
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
		_finish_sequence_to_victory()
		return
	_go_step(_idx)


## Avança índice sem validar sucesso nem conceder conquistas (fases desabilitadas).
func _advance_index_skip_achievements() -> void:
	_idx += 1
	if _idx >= _steps.size():
		_finish_sequence_to_victory()
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


## Compatível com binary/conversion_phase (só o corpo do tutorial).
func take_tutorial_text_if_any() -> String:
	return str(take_tutorial_if_any().get("body", ""))


func abort_sequence() -> void:
	_active = false
	_steps.clear()
	_idx = -1
	_run_phase_stars.clear()
	_total_run_moves = 0
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


func _finish_sequence_to_victory() -> void:
	get_tree().change_scene_to_file(PATH_VICTORY_SCREEN)


func _finish_sequence_to_menu() -> void:
	abort_sequence()
	get_tree().change_scene_to_file(PATH_MENU)
