class_name SequenceFileManager
extends RefCounted

const SEQUENCES_DIR = "user://sequences"
## Arquivo padrão editado no Criador de Fases e usado pelo botão Começar.
const DEFAULT_PLAY_SEQUENCE_FILE := "Sequencia_Base.tres"
## Fallback embutido se user:// ainda não tiver sequência salva.
const BUNDLED_PEDAGOGICAL_SEQUENCE := "res://Inventory/fases/scenarios/sequencia_base.tres"
var sequences: Dictionary = {}

func _init() -> void:
	_ensure_dir()

func _ensure_dir() -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("sequences"):
		dir.make_dir("sequences")

func load_all_sequences() -> Dictionary:
	sequences.clear()
	var dir = DirAccess.open(SEQUENCES_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = ResourceLoader.load(SEQUENCES_DIR + "/" + file_name)
				if res is PhaseSequenceList:
					sequences[file_name] = res
			file_name = dir.get_next()
			
	if sequences.is_empty():
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
	var keys = sequences.keys()
	keys.sort()
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
	var path := SEQUENCES_DIR + "/" + file_name
	var err := ResourceSaver.save(seq, path)
	if err != OK:
		push_error("Erro ao salvar sequência %s: %s" % [file_name, error_string(err)])
		return false
	sequences[file_name] = seq
	
	# Salvar também no diretório do projeto (res://) para rastreamento no Git
	var res_path = "res://Inventory/fases/scenarios/" + file_name
	if file_name == DEFAULT_PLAY_SEQUENCE_FILE:
		res_path = BUNDLED_PEDAGOGICAL_SEQUENCE
	ResourceSaver.save(seq, res_path)
	
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
