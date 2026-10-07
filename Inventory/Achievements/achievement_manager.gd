extends Node

signal achievement_unlocked(id: String)
signal achievement_progressed(id: String, current: int, max_val: int)

const SAVE_PATH = "user://achievements.json"

var _achievements = {
	"basic_done_well": {
		"name": "O Básico Bem Feito",
		"desc": "Valores em uma faixa de valores compatível com um tipo de dado específico e em quantidade menor do que a quantidade de memória (slots) disponíveis.",
		"icon": "res://Inventory/Art/conquistas/conquista 1.png",
		"max_progress": 1,
		"current_progress": 0,
		"unlocked": false
	},
	"jack_of_all_trades": {
		"name": "Pau Pra Toda Obra",
		"desc": "Valores em uma faixas de valores compatíveis com alguns tipos de dado e em quantidade menor do que a quantidade de memória (slots) disponíveis.",
		"icon": "res://Inventory/Art/conquistas/conquista 2.png",
		"max_progress": 1,
		"current_progress": 0,
		"unlocked": false
	},
	"square_peg": {
		"name": "Pino Quadrado no Buraco Redondo",
		"desc": "Valores em uma faixa de valor incompatível com um tipo de dado e em quantidade menor do que a quantidade de memória (slots) disponíveis.",
		"icon": "res://Inventory/Art/conquistas/conquista 3.png",
		"max_progress": 1,
		"current_progress": 0,
		"unlocked": false
	},
	"diet_operation": {
		"name": "Operação Dieta",
		"desc": "Valores em uma faixa de valor compatível com um tipo de dado, mas que poderia usar um tipo de dado mais simples, e em quantidade maior do que a quantidade de memória (slots) disponíveis (considerando o tipo de dado original) e menor se considerar o tipo de dado convertido.",
		"icon": "res://Inventory/Art/conquistas/conquista 4.png",
		"max_progress": 1,
		"current_progress": 0,
		"unlocked": false
	},
	"overflow": {
		"name": "O Copo Transbordou",
		"desc": "Valores resultantes de uma operação que excedem o limite máximo suportado pelo tipo de dado atual (overflow), e em quantidade menor do que a quantidade de memória (slots) disponíveis.",
		"icon": "res://Inventory/Art/conquistas/conquista 5.png",
		"max_progress": 1,
		"current_progress": 0,
		"unlocked": false
	},
	"underflow": {
		"name": "Fundo do Poço (e Além)",
		"desc": "Valores resultantes de uma operação que caem abaixo do limite mínimo suportado pelo tipo de dado atual (underflow), e em quantidade menor do que a quantidade de memória (slots) disponíveis.",
		"icon": "res://Inventory/Art/conquistas/conquista 6.png",
		"max_progress": 1,
		"current_progress": 0,
		"unlocked": false
	},
	"one_step_ahead": {
		"name": "Um Passo à Frente",
		"desc": "Valores próximos do limite de um tipo de dado que sofrem uma conversão prévia (upgrade de tipo) antes de uma operação para evitar overflow/underflow, respeitando a quantidade de memória (slots) disponíveis.",
		"icon": "res://Inventory/Art/conquistas/conquista 7.png",
		"max_progress": 1,
		"current_progress": 0,
		"unlocked": false
	},
	"forced_cast": {
		"name": "Forçando a Barra",
		"desc": "Valores em um tipo de dado convertidos forçadamente para um tipo de dado de menor capacidade, resultando em perda de precisão, e em quantidade menor do que a quantidade de memória (slots) disponíveis.",
		"icon": "res://Inventory/Art/conquistas/conquista 8.png",
		"max_progress": 1,
		"current_progress": 0,
		"unlocked": false
	},
	"code_chameleon": {
		"name": "Camaleão de Código",
		"desc": "Valores de tipos de dados diferentes alocados nos slots que exigem uma conversão automática pelo sistema para um tipo de dado comum a fim de resolver uma expressão.",
		"icon": "res://Inventory/Art/conquistas/conquista 9.png",
		"max_progress": 1,
		"current_progress": 0,
		"unlocked": false
	},
	"compression_expert": {
		"name": "Especialista em Compressão",
		"desc": "Valores gerados em quantidade maior do que a memória (slots) disponíveis, mas que passam a caber perfeitamente após todos serem convertidos para o menor tipo de dado possível que suporte suas faixas de valor.",
		"icon": "res://Inventory/Art/conquistas/conquista 10.png",
		"max_progress": 1,
		"current_progress": 0,
		"unlocked": false
	},
	"the_line_moves": {
		"name": "A Fila Anda",
		"desc": "Valores gerados continuamente em quantidade maior do que a quantidade de memória (slots) disponíveis, exigindo que os valores mais antigos desapareçam ao longo do tempo para permitir a alocação dos novos.",
		"icon": "res://Inventory/Art/conquistas/conquista 11.png",
		"max_progress": 1,
		"current_progress": 0,
		"unlocked": false
	},
	"shooting_star": {
		"name": "Estrela Cadente",
		"desc": "Valores temporários que ocupam a memória (slots) apenas até serem consumidos por uma expressão, desaparecendo logo em seguida e liberando espaço no inventário.",
		"icon": "res://Inventory/Art/conquistas/conquista 12.png",
		"max_progress": 1,
		"current_progress": 0,
		"unlocked": false
	},
	"digital_hoarder": {
		"name": "Acumulador Digital",
		"desc": "Valores em quantidade excessiva tentando ser armazenados simultaneamente em slots cheios antes que qualquer valor antigo tenha tempo de desaparecer.",
		"icon": "res://Inventory/Art/conquistas/conquista 13.png",
		"max_progress": 1,
		"current_progress": 0,
		"unlocked": false
	},
	"data_alchemist": {
		"name": "Alquimista de Dados",
		"desc": "Valores de um tipo de dado inicial que, após passarem pela avaliação de uma expressão complexa, geram resultados de um tipo de dado totalmente novo e ocupam os slots disponíveis.",
		"icon": "res://Inventory/Art/conquistas/conquista 14.png",
		"max_progress": 1,
		"current_progress": 0,
		"unlocked": false
	},
	"union_is_strength": {
		"name": "A União Faz a Força",
		"desc": "Múltiplos valores de tipos de dados simples combinados (consumidos) através de uma expressão para gerar um único valor de um tipo de dado mais complexo, reduzindo a quantidade de memória (slots) utilizada.",
		"icon": "res://Inventory/Art/conquistas/conquista 15.png",
		"max_progress": 1,
		"current_progress": 0,
		"unlocked": false
	},
	"oil_and_water": {
		"name": "Misturando Água e Óleo",
		"desc": "Valores alocados na memória (slots) que são inseridos em uma expressão cuja natureza (matemática, lógica, string) é incompatível com os tipos de dados fornecidos, gerando um erro de avaliação.",
		"icon": "res://Inventory/Art/conquistas/conquista 16.png",
		"max_progress": 1,
		"current_progress": 0,
		"unlocked": false
	}
}

func _ready() -> void:
	_load_data()

const AnalyzerScript = preload("res://Inventory/Achievements/achievement_analyzer.gd")

func get_all_achievements() -> Dictionary:
	return _achievements


## Relatório de conquistas potencialmente alcançáveis numa sequência (configs/ferramentas).
func analyze_sequence_steps(steps: Array) -> Dictionary:
	return AnalyzerScript.analyze_steps(steps, _achievements)

func add_progress(id: String, amount: int = 1) -> void:
	if not _achievements.has(id):
		return
		
	var ach = _achievements[id]
	if ach["unlocked"]:
		return
		
	ach["current_progress"] += amount
	
	if ach["current_progress"] >= ach["max_progress"]:
		ach["current_progress"] = ach["max_progress"]
		_unlock_internal(id)
	else:
		achievement_progressed.emit(id, ach["current_progress"], ach["max_progress"])
		_save_data()

func add_unique_progress(id: String, flag: String) -> void:
	if not _achievements.has(id):
		return
	var ach = _achievements[id]
	if ach["unlocked"]:
		return
	if not ach.has("flags"):
		ach["flags"] = []
	if not flag in ach["flags"]:
		ach["flags"].append(flag)
		add_progress(id, 1)

func unlock(id: String) -> void:
	if not _achievements.has(id):
		return
		
	var ach = _achievements[id]
	if ach["unlocked"]:
		return
		
	ach["current_progress"] = ach["max_progress"]
	_unlock_internal(id)


## Eventos em tempo real (calculadora, conversor, tipagem).
func note_runtime_event(event_id: String, detail: String = "") -> void:
	match event_id:
		"overflow":
			unlock("overflow")
		"underflow":
			unlock("underflow")
		"forced_cast":
			unlock("forced_cast")
		"code_chameleon":
			unlock("code_chameleon")
		"square_peg":
			unlock("square_peg")
		"data_alchemist":
			unlock("data_alchemist")
		"union_is_strength":
			unlock("union_is_strength")
		"one_step_ahead":
			unlock("one_step_ahead")
		"oil_and_water":
			unlock("oil_and_water")
		_:
			if detail != "":
				push_warning("AchievementManager: evento desconhecido '%s' (%s)" % [event_id, detail])


## Chamado ao concluir uma fase com sucesso (IDs pedagógicos reais).
func on_phase_completed(step: PhaseSequenceStep, scene: Node) -> void:
	if step == null or scene == null:
		return
	match step.kind:
		PhaseSequenceStep.Kind.MOCHILA, PhaseSequenceStep.Kind.RAW_MOCHILA, PhaseSequenceStep.Kind.TYPE_BOX:
			unlock("basic_done_well")
			var types := _collect_scene_types(scene)
			if types.size() >= 2:
				unlock("jack_of_all_trades")
			if step.kind == PhaseSequenceStep.Kind.TYPE_BOX or step.kind == PhaseSequenceStep.Kind.RAW_MOCHILA:
				if scene.get("_square_peg_triggered") == true:
					unlock("square_peg")
			if scene.has_method("get_earned_stars") and int(scene.get_earned_stars()) >= 3:
				# Compressão/sucesso impecável em memória apertada → especialista
				if types.size() >= 2:
					unlock("compression_expert")
		PhaseSequenceStep.Kind.BINARIO, PhaseSequenceStep.Kind.CONVERSAO:
			unlock("basic_done_well")


func _collect_scene_types(scene: Node) -> Dictionary:
	var types := {}
	var ItemRef = preload("res://Inventory/Items/item.gd")
	if "backpack_grid" in scene and scene.backpack_grid:
		for slot in scene.backpack_grid.slots_array:
			for it in slot.items_stored:
				if is_instance_valid(it):
					types[it.data_type] = true
	if scene.has_method("_typed_items_in_boxes"):
		for it in scene._typed_items_in_boxes():
			if is_instance_valid(it):
				types[it.data_type] = true
	# Conta tipos “primitivos” distintos (ignora OPERATOR/BINARY se aparecerem)
	var clean := {}
	for dt in types.keys():
		if dt in [
			ItemRef.DataType.INT, ItemRef.DataType.FLOAT, ItemRef.DataType.DOUBLE,
			ItemRef.DataType.SHORT_INT, ItemRef.DataType.FP8, ItemRef.DataType.FP16, ItemRef.DataType.RAW
		]:
			clean[dt] = true
	return clean

func reset_achievements() -> void:
	for id in _achievements:
		_achievements[id]["current_progress"] = 0
		_achievements[id]["unlocked"] = false
		if _achievements[id].has("flags"):
			_achievements[id]["flags"].clear()
	_save_data()

func _unlock_internal(id: String) -> void:
	var ach = _achievements[id]
	ach["unlocked"] = true
	achievement_unlocked.emit(id)
	_save_data()

func _save_data() -> void:
	var save_dict = {}
	for id in _achievements:
		save_dict[id] = {
			"current_progress": _achievements[id]["current_progress"],
			"unlocked": _achievements[id]["unlocked"]
		}
		if _achievements[id].has("flags"):
			save_dict[id]["flags"] = _achievements[id]["flags"]
	
	var json_string = JSON.stringify(save_dict)
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)

func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var parsed = JSON.parse_string(json_string)
		if typeof(parsed) == TYPE_DICTIONARY:
			for id in parsed:
				if _achievements.has(id):
					var data = parsed[id]
					if data.has("current_progress"):
						_achievements[id]["current_progress"] = data["current_progress"]
					if data.has("unlocked"):
						_achievements[id]["unlocked"] = data["unlocked"]
					if data.has("flags"):
						_achievements[id]["flags"] = data["flags"]
