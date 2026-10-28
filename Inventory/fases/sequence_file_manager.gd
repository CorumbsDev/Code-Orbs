class_name SequenceFileManager
extends RefCounted

const SEQUENCES_DIR = "user://sequences"
## Arquivo padrão editado no Criador de Fases e usado pelo botão Começar.
const DEFAULT_PLAY_SEQUENCE_FILE := "Sequencia_Base.tres"
## Sequência base embutida (plano de aula — 14 fases) copiada na primeira vez que o app é aberto.
const BUNDLED_PEDAGOGICAL_SEQUENCE := "res://Inventory/fases/scenarios/sequencia_base.tres"
## Marcador que garante que, na primeira abertura do app em qualquer PC, a Sequencia_Base seja inicializada.
const BASE_SEQUENCE_INIT_MARKER := "user://sequences/.base_sequence_v14_initialized"
var sequences: Dictionary = {}

func _init() -> void:
	_ensure_dir()

func _ensure_dir() -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("sequences"):
		dir.make_dir("sequences")

func _ensure_first_run_base_sequence() -> void:
	if FileAccess.file_exists(BASE_SEQUENCE_INIT_MARKER):
		return
	_create_base_sequence(DEFAULT_PLAY_SEQUENCE_FILE)
	var f := FileAccess.open(BASE_SEQUENCE_INIT_MARKER, FileAccess.WRITE)
	if f:
		f.store_string("v14\n")
		f.close()

func get_ordered_sequence_names() -> Array:
	var keys := sequences.keys()
	keys.sort()
	if keys.has(DEFAULT_PLAY_SEQUENCE_FILE):
		keys.erase(DEFAULT_PLAY_SEQUENCE_FILE)
		keys.push_front(DEFAULT_PLAY_SEQUENCE_FILE)
	return keys

func load_all_sequences() -> Dictionary:
	sequences.clear()
	_ensure_first_run_base_sequence()
	var dir = DirAccess.open(SEQUENCES_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = ResourceLoader.load(SEQUENCES_DIR + "/" + file_name, "", ResourceLoader.CACHE_MODE_REPLACE)
				if res is PhaseSequenceList:
					sequences[file_name] = res
			file_name = dir.get_next()
			
	if not sequences.has(DEFAULT_PLAY_SEQUENCE_FILE):
		_create_base_sequence(DEFAULT_PLAY_SEQUENCE_FILE)
		
	return sequences

func get_play_sequence() -> PhaseSequenceList:
	load_all_sequences()
	var seq := _find_default_sequence()
	if seq != null and not seq.steps.is_empty():
		return seq
	return _create_base_sequence(DEFAULT_PLAY_SEQUENCE_FILE)

func _find_default_sequence() -> PhaseSequenceList:
	if sequences.is_empty():
		return null
	if sequences.has(DEFAULT_PLAY_SEQUENCE_FILE):
		return sequences[DEFAULT_PLAY_SEQUENCE_FILE] as PhaseSequenceList
	var keys := get_ordered_sequence_names()
	return sequences[keys[0]] as PhaseSequenceList

func get_play_steps() -> Array:
	var seq := get_play_sequence()
	if seq == null:
		return []
	var steps := seq.to_runtime_array()
	if steps.is_empty():
		push_warning("Sequência '%s' sem fases." % DEFAULT_PLAY_SEQUENCE_FILE)
	return steps

func _create_base_sequence(file_name: String) -> PhaseSequenceList:
	# Preferir a sequência pedagógica embutida no projeto.
	var bundled := load(BUNDLED_PEDAGOGICAL_SEQUENCE) as PhaseSequenceList
	if bundled != null and not bundled.steps.is_empty():
		var to_save := bundled.duplicate(true) as PhaseSequenceList
		var path := SEQUENCES_DIR + "/" + file_name
		var err := ResourceSaver.save(to_save, path)
		if err != OK:
			push_warning("Não foi possível salvar %s (%s). Usando sequência embutida." % [path, error_string(err)])
		sequences[file_name] = to_save
		return to_save

	var seq = PhaseSequenceList.new()

	var step1 = PhaseSequenceStep.new()
	step1.kind = PhaseSequenceStep.Kind.MOCHILA
	step1.config_mochila = ConfigGenerator.generate_knapsack_config(8, 8, 10, 4, 1, 10, "", 6, false)
	seq.steps.append(step1)

	var step2 = PhaseSequenceStep.new()
	step2.kind = PhaseSequenceStep.Kind.TYPE_BOX
	step2.config_type_box = ConfigGenerator.generate_type_box_config(12, ["7", "3.14", "1"])
	step2.config_type_box.expected_solution_types = PackedStringArray(["int", "float", "int"])
	seq.steps.append(step2)

	ResourceSaver.save(seq, SEQUENCES_DIR + "/" + file_name)
	sequences[file_name] = seq
	return seq

func create_new_sequence(file_name: String) -> PhaseSequenceList:
	var seq = PhaseSequenceList.new()
	var step = PhaseSequenceStep.new()
	step.kind = PhaseSequenceStep.Kind.MOCHILA
	step.config_mochila = ConfigGenerator.generate_knapsack_config()
	seq.steps.append(step)
	
	ResourceSaver.save(seq, SEQUENCES_DIR + "/" + file_name)
	sequences[file_name] = seq
	return seq

func save_sequence(file_name: String, seq: PhaseSequenceList) -> bool:
	if not sequences.has(file_name):
		return false
	# Evita configs órfãs de outros tipos “grudarem” no .tres e
	# sobrescreverem o kind na próxima edição/reimportação.
	for s in seq.steps:
		if s is PhaseSequenceStep:
			(s as PhaseSequenceStep).sanitize_configs_for_kind()
	var path := SEQUENCES_DIR + "/" + file_name
	var err := ResourceSaver.save(seq, path)
	if err != OK:
		push_error("Erro ao salvar sequência %s: %s" % [file_name, error_string(err)])
		return false
	sequences[file_name] = seq
	return true

func delete_sequence(file_name: String) -> void:
	var path = SEQUENCES_DIR + "/" + file_name
	if DirAccess.dir_exists_absolute(SEQUENCES_DIR) and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	sequences.erase(file_name)

func rename_sequence(old_file: String, new_file: String) -> bool:
	if not sequences.has(old_file) or sequences.has(new_file):
		return false
	var seq = sequences[old_file]
	sequences.erase(old_file)
	sequences[new_file] = seq
	var err = DirAccess.rename_absolute(SEQUENCES_DIR + "/" + old_file, SEQUENCES_DIR + "/" + new_file)
	return err == OK
