extends Control

func _dbg(a=null, b=null, c=null, d=null) -> void:
	if not OS.is_debug_build():
		return
	if d != null:
		print(a, b, c, d)
	elif c != null:
		print(a, b, c)
	elif b != null:
		print(a, b)
	elif a != null:
		print(a)


@onready var slot_scene = preload("res://Inventory/slots/slot.tscn")
@onready var grid_container = $Background/MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var item_scene = preload("res://Inventory/Items/Item.tscn")
@onready var scroll_container = $Background/MarginContainer/VBoxContainer/ScrollContainer
@onready var col_count = grid_container.columns
@onready var controlador_externo = $ControladorExterno
@onready var info_panel = $InfoPanel  # Novo: referência ao painel de informações
@onready var info_type_label = $InfoPanel/MarginContainer/VBoxContainer/ScrollContainer/InfoContainer/TypeLabel
@onready var info_value_label = $InfoPanel/MarginContainer/VBoxContainer/ScrollContainer/InfoContainer/ValueLabel
@onready var info_id_label = $InfoPanel/MarginContainer/VBoxContainer/ScrollContainer/InfoContainer/IDLabel
@onready var info_details_label = $InfoPanel/MarginContainer/VBoxContainer/ScrollContainer/InfoContainer/DetailsLabel

var grid_array := []
var item_held = null
var current_slot = null
var can_place := false
var icon_anchor : Vector2

# Variáveis para controlar as expressões e itens consumidos
var ultimos_slots_expressao = []  # Armazena os slots usados na última expressão
var ultima_expressao = ""         # Armazena a última expressão processada

func _ready():
	if controlador_externo and controlador_externo.has_signal("expressao_processada"):
		controlador_externo.expressao_processada.connect(_on_expressao_processada)
		_dbg("Controlador externo conectado")
	else:
		_dbg("Controlador externo não encontrado, usando fallback")
	
	# Conecta sinais de hover dos itens
	connect_items_hover_signals()
	
	# Inicializa o painel de informações como vazio
	clear_info_panel()
	
	for i in range(64):
		create_slot()
	call_deferred("_recenter_all_slot_items")
	
	PanelArtLoader.skin_all_buttons(self)
	PanelArtLoader.apply_background(self)

func _recenter_all_slot_items() -> void:
	for slot in grid_array:
		for it in slot.items_stored:
			if it != null and is_instance_valid(it) and it.has_method("snap_to_slot"):
				it.snap_to_slot(slot)

func connect_items_hover_signals():
	"""Conecta os sinais de hover de todos os itens existentes"""
	# Conecta itens que já existem
	for slot in grid_array:
		if slot.item_stored != null:
			var item = slot.item_stored
			if item.has_signal("mouse_entered_item"):
				if not item.mouse_entered_item.is_connected(_on_item_mouse_entered):
					item.mouse_entered_item.connect(_on_item_mouse_entered)
			if item.has_signal("mouse_exited_item"):
				if not item.mouse_exited_item.is_connected(_on_item_mouse_exited):
					item.mouse_exited_item.connect(_on_item_mouse_exited)
	
	# Também conecta o item segurado
	if item_held != null:
		if item_held.has_signal("mouse_entered_item"):
			if not item_held.mouse_entered_item.is_connected(_on_item_mouse_entered):
				item_held.mouse_entered_item.connect(_on_item_mouse_entered)
		if item_held.has_signal("mouse_exited_item"):
			if not item_held.mouse_exited_item.is_connected(_on_item_mouse_exited):
				item_held.mouse_exited_item.connect(_on_item_mouse_exited)

func _on_expressao_processada(resultado: Variant, tipo_resultado: String, codigo: String):
	_dbg("=== EXPRESSÃO PROCESSADA ===")
	_dbg("Resultado: ", resultado)
	_dbg("Tipo: ", tipo_resultado)
	_dbg("Código: ", codigo)
	
	# Consome os itens usados na expressão ANTES de criar o novo item
	consumir_itens_expressao()
	
	# Cria o item de resultado com o tipo correto
	create_result_item_typed(resultado, tipo_resultado)

func create_slot():
	var new_slot = slot_scene.instantiate()
	new_slot.slot_ID = grid_array.size()
	grid_container.add_child(new_slot)
	grid_array.push_back(new_slot)

	new_slot.slot_entered.connect(_on_slot_mouse_entered)
	new_slot.slot_exited.connect(_on_slot_mouse_exited)
	new_slot.item_changed.connect(_on_item_changed)

func _on_item_changed(slot):
	_dbg("Item mudou no slot:", slot.slot_ID)
	check_combinations()

@warning_ignore("unused_parameter")
func _process(delta):
	if item_held:
		if Input.is_action_just_pressed("select_item"):
			var mouse := get_global_mouse_position()
			if current_slot != null or scroll_container.get_global_rect().has_point(mouse) \
					or grid_container.get_global_rect().has_point(mouse):
				place_item()
	else:
		if Input.is_action_just_pressed("select_item"):
			var mouse := get_global_mouse_position()
			if current_slot != null or scroll_container.get_global_rect().has_point(mouse) \
					or grid_container.get_global_rect().has_point(mouse):
				pick_item()

func _on_slot_mouse_entered(a_Slot):
	icon_anchor = Vector2(10000, 100000)
	current_slot = a_Slot
	if item_held:
		check_slot_availability(current_slot)
		set_grids.call_deferred(current_slot)

@warning_ignore("unused_parameter")
func _on_slot_mouse_exited(a_Slot):
	clear_grid()
	if not grid_container.get_global_rect().has_point(get_global_mouse_position()):
		current_slot = null

func create_item_on_hand_randomly():
	if item_held == null:
		var new_item = item_scene.instantiate()
		add_child(new_item)
		
		var random_item = ""
		match randi_range(1, 10):
			1: random_item = "item_number_7"
			2: random_item = "item_operator_plus"
			3: random_item = "item_operator_increment"
			4: random_item = "item_operator_to_short"
			5: random_item = "item_number_5"
			6: random_item = "item_double_3.14159"
			7: random_item = "item_binary_10"
			8: random_item = "item_operator_to_float"
			9: random_item = "item_operator_to_int"
			10: random_item = "item_number_10"
		
		if new_item.has_method("load_item"):
			new_item.load_item(random_item)
		else:
			_dbg("Item não tem método load_item")
		
		# Conecta sinais de hover (verifica se já está conectado)
		if new_item.has_signal("mouse_entered_item"):
			if not new_item.mouse_entered_item.is_connected(_on_item_mouse_entered):
				new_item.mouse_entered_item.connect(_on_item_mouse_entered)
		if new_item.has_signal("mouse_exited_item"):
			if not new_item.mouse_exited_item.is_connected(_on_item_mouse_exited):
				new_item.mouse_exited_item.connect(_on_item_mouse_exited)
		
		new_item.selected = true
		item_held = new_item

func _on_button_spawn_pressed():
	create_item_on_hand_randomly()

func check_slot_availability(a_Slot):
	if not item_held:
		can_place = false
		return
	
	for grid in item_held.item_grids:
		var grid_to_check = a_Slot.slot_ID + grid[0] + grid[1] * col_count
		var line_switch_check = a_Slot.slot_ID % col_count + grid[0]
		if line_switch_check < 0 or line_switch_check >= col_count:
			can_place = false
			return
		if grid_to_check < 0 or grid_to_check >= grid_array.size():
			can_place = false
			return
		if grid_array[grid_to_check].state == grid_array[grid_to_check].States.TAKEN:
			can_place = false
			return
	
	can_place = true

func set_grids(a_Slot):
	if not item_held:
		return
	
	for grid in item_held.item_grids:
		var grid_to_check = a_Slot.slot_ID + grid[0] + grid[1] * col_count
		if grid_to_check < 0 or grid_to_check >= grid_array.size():
			continue
		var line_switch_check = a_Slot.slot_ID % col_count + grid[0]
		if line_switch_check < 0 or line_switch_check >= col_count:
			continue
		
		if can_place:
			grid_array[grid_to_check].set_color(grid_array[grid_to_check].States.FREE)
			if grid[1] < icon_anchor.x: icon_anchor.x = grid[1]
			if grid[0] < icon_anchor.y: icon_anchor.y = grid[0]
		else:
			grid_array[grid_to_check].set_color(grid_array[grid_to_check].States.TAKEN)

func clear_grid():
	for slot in grid_array:
		slot.set_color(slot.States.DEFAULT)

func place_item():
	if not can_place or not current_slot: 
		return
	
	# Salva referência ao item sendo colocado (a cascata de expressão pode alterar item_held)
	var placing_item = item_held
	
	var calculated_grid_id: int = current_slot.slot_ID + int(icon_anchor.x) * col_count + int(icon_anchor.y)
	var anchor_slot = grid_array[calculated_grid_id]
	placing_item.grid_anchor = anchor_slot
	if placing_item.get_parent() != anchor_slot:
		placing_item.get_parent().remove_child(placing_item)
		anchor_slot.add_child(placing_item)
	placing_item.snap_to_slot(anchor_slot)
	
	for grid in placing_item.item_grids:
		var grid_to_check = current_slot.slot_ID + grid[0] + grid[1] * col_count
		grid_array[grid_to_check].state = grid_array[grid_to_check].States.TAKEN 
		grid_array[grid_to_check].item_stored = placing_item
		grid_array[grid_to_check].set_item(placing_item)
	
	# Conecta sinais de hover do item colocado (verifica se já está conectado)
	if placing_item.has_signal("mouse_entered_item"):
		if not placing_item.mouse_entered_item.is_connected(_on_item_mouse_entered):
			placing_item.mouse_entered_item.connect(_on_item_mouse_entered)
	if placing_item.has_signal("mouse_exited_item"):
		if not placing_item.mouse_exited_item.is_connected(_on_item_mouse_exited):
			placing_item.mouse_exited_item.connect(_on_item_mouse_exited)
	
	# Só zera item_held se a cascata de expressão não criou um novo item resultado
	if item_held == placing_item:
		item_held = null
	clear_grid()

func pick_item():
	if not current_slot or current_slot.items_stored.size() == 0: 
		return
	
	item_held = current_slot.pick_item_at(get_global_mouse_position())
	if item_held == null:
		return
	
	# Desconecta sinais do item no grid (vai reconectar quando colocar de volta)
	if item_held.has_signal("mouse_entered_item"):
		if item_held.mouse_entered_item.is_connected(_on_item_mouse_entered):
			item_held.mouse_entered_item.disconnect(_on_item_mouse_entered)
	if item_held.has_signal("mouse_exited_item"):
		if item_held.mouse_exited_item.is_connected(_on_item_mouse_exited):
			item_held.mouse_exited_item.disconnect(_on_item_mouse_exited)
	
	item_held.selected = true
	
	item_held.get_parent().remove_child(item_held)
	add_child(item_held)
	item_held.global_position = get_global_mouse_position()
	
	for grid in item_held.item_grids:
		var grid_to_check = item_held.grid_anchor.slot_ID + grid[0] + grid[1] * col_count
		grid_array[grid_to_check].remove_item(item_held)
		if grid_array[grid_to_check].get_used_bytes() == 0:
			grid_array[grid_to_check].state = grid_array[grid_to_check].States.FREE 
		elif grid_array[grid_to_check].get_used_bytes() < 4:
			grid_array[grid_to_check].state = grid_array[grid_to_check].States.PARTIAL
	
	# Conecta sinais do item segurado (verifica se já está conectado)
	if item_held.has_signal("mouse_entered_item"):
		if not item_held.mouse_entered_item.is_connected(_on_item_mouse_entered):
			item_held.mouse_entered_item.connect(_on_item_mouse_entered)
	if item_held.has_signal("mouse_exited_item"):
		if not item_held.mouse_exited_item.is_connected(_on_item_mouse_exited):
			item_held.mouse_exited_item.connect(_on_item_mouse_exited)
	
	check_slot_availability(current_slot)
	set_grids.call_deferred(current_slot)

func _on_voltar_pressed():
	get_tree().change_scene_to_file("res://Inventory/fases/main_menu.tscn")

func _on_add_slot_pressed():
	create_slot()

func check_combinations():
	# Verifica combinações horizontais
	for linha in range(8):
		var sequence = []
		var slots_na_sequencia = []  # Armazena os slots usados na sequência
		var itens_ja_contados = []  # Evita duplicatas de itens multi-slot
		for coluna in range(8):
			var index = linha * 8 + coluna
			if index < grid_array.size():
				var slot = grid_array[index]
				if slot.item_stored != null:
					var item = slot.item_stored
					# Pula se este item já foi contado (multi-slot)
					if item in itens_ja_contados:
						continue
					itens_ja_contados.append(item)
					# Verifica se é operador
					if item.get("data_type") != null and item.data_type == item.DataType.OPERATOR:
						if item.operator != "":
							sequence.append(item.operator)
							slots_na_sequencia.append(slot)
					# Verifica se é um valor (qualquer tipo)
					elif item.get("data_type") != null:
						sequence.append(OrbValueFormat.python_repr_string(item))
						slots_na_sequencia.append(slot)
					# Fallback para itens antigos (compatibilidade)
					elif item.get("operator") != null and item.operator != "":
						sequence.append(item.operator)
						slots_na_sequencia.append(slot)
					elif item.get("value") != null and item.value != 0:
						sequence.append(str(item.value))
						slots_na_sequencia.append(slot)
				else:
					if sequence.size() >= 3:
						# Armazena os slots usados antes de processar
						ultimos_slots_expressao = slots_na_sequencia.duplicate()
						_process_sequence(sequence)
					sequence.clear()
					slots_na_sequencia.clear()
					itens_ja_contados.clear()
		
		if sequence.size() >= 3:
			# Armazena os slots usados antes de processar
			ultimos_slots_expressao = slots_na_sequencia.duplicate()
			_process_sequence(sequence)
	
	# Verifica combinações verticais
	for coluna in range(8):
		var sequence = []
		var slots_na_sequencia = []  # Armazena os slots usados na sequência
		var itens_ja_contados = []  # Evita duplicatas de itens multi-slot
		for linha in range(8):
			var index = linha * 8 + coluna
			if index < grid_array.size():
				var slot = grid_array[index]
				if slot.item_stored != null:
					var item = slot.item_stored
					# Pula se este item já foi contado (multi-slot)
					if item in itens_ja_contados:
						continue
					itens_ja_contados.append(item)
					# Verifica se é operador
					if item.get("data_type") != null and item.data_type == item.DataType.OPERATOR:
						if item.operator != "":
							sequence.append(item.operator)
							slots_na_sequencia.append(slot)
					# Verifica se é um valor (qualquer tipo)
					elif item.get("data_type") != null:
						sequence.append(OrbValueFormat.python_repr_string(item))
						slots_na_sequencia.append(slot)
					# Fallback para itens antigos (compatibilidade)
					elif item.get("operator") != null and item.operator != "":
						sequence.append(item.operator)
						slots_na_sequencia.append(slot)
					elif item.get("value") != null and item.value != 0:
						sequence.append(str(item.value))
						slots_na_sequencia.append(slot)
				else:
					if sequence.size() >= 3:
						# Armazena os slots usados antes de processar
						ultimos_slots_expressao = slots_na_sequencia.duplicate()
						_process_sequence(sequence)
					sequence.clear()
					slots_na_sequencia.clear()
					itens_ja_contados.clear()
		
		if sequence.size() >= 3:
			# Armazena os slots usados antes de processar
			ultimos_slots_expressao = slots_na_sequencia.duplicate()
			_process_sequence(sequence)

func validar_tipos_expressao(sequence: Array) -> Dictionary:
	return ExpressionEvaluator.validate_types(sequence)

func _process_sequence(seq: Array):
	if seq.size() >= 3:
		var expr = "".join(seq)
		ultima_expressao = expr
		_dbg("Expressão formada:", expr)
		
		var validacao = validar_tipos_expressao(seq)
		if not validacao.valido:
			_dbg("AVISO: ", validacao.mensagem)
		
		if controlador_externo and controlador_externo.has_method("processar_expressao_assincrona"):
			controlador_externo.processar_expressao_assincrona(expr)
		else:
			var resultado_info = avaliar_expressao_com_tipo(expr)
			_dbg("Resultado (fallback):", resultado_info.resultado, " Tipo:", resultado_info.tipo)
			
			consumir_itens_expressao()
			create_result_item_typed(resultado_info.resultado, resultado_info.tipo)

func avaliar_expressao_com_tipo(expr: String) -> Dictionary:
	return ExpressionEvaluator.evaluate_with_type(expr)

func create_result_item(resultado: float):
	"""Método antigo mantido para compatibilidade - sempre cria INT"""
	if item_held == null:
		var new_item = item_scene.instantiate()
		add_child(new_item)
		
		# Converte o resultado para inteiro
		var valor_inteiro = int(resultado)
		valor_inteiro = clamp(valor_inteiro, 0, 999)
		
		# Usa o método para definir o valor diretamente
		if new_item.has_method("set_value_directly"):
			new_item.set_value_directly(valor_inteiro)
		else:
			# Fallback para o método antigo
			var item_type = "item_number_" + str(valor_inteiro)
			if new_item.has_method("load_item"):
				new_item.load_item(item_type)
		
		new_item.selected = true
		item_held = new_item
		_dbg("Item de resultado criado com valor: ", valor_inteiro)

func create_result_item_typed(resultado: Variant, tipo_resultado: String):
	"""Cria um item de resultado com o tipo correto"""
	var new_item = item_scene.instantiate()
	add_child(new_item)
	
	# Verifica se o item tem o método set_value_by_type
	if new_item.has_method("set_value_by_type"):
		# Mapeia o tipo string para o enum DataType
		var tipo_enum = new_item.DataType.INT  # Default
		
		match tipo_resultado:
			"INT":
				tipo_enum = new_item.DataType.INT
				var valor_int = int(resultado)
				valor_int = clamp(valor_int, -999, 999)  # Permite negativos
				new_item.set_value_by_type(valor_int, tipo_enum)
			"SHORT_INT":
				tipo_enum = new_item.DataType.SHORT_INT
				var valor_int = int(resultado)
				valor_int = clamp(valor_int, -999, 999)
				new_item.set_value_by_type(valor_int, tipo_enum)
			"FLOAT":
				tipo_enum = new_item.DataType.FLOAT
				var valor_float = float(resultado)
				# Limita casas decimais para exibição
				valor_float = clamp(valor_float, -999.99, 999.99)
				new_item.set_value_by_type(valor_float, tipo_enum)
			"STRING":
				tipo_enum = new_item.DataType.STRING
				var valor_str = str(resultado)
				# Limita tamanho da string
				if valor_str.length() > 20:
					valor_str = valor_str.substr(0, 20) + "..."
				new_item.set_value_by_type(valor_str, tipo_enum)
			"DOUBLE":
				tipo_enum = new_item.DataType.DOUBLE
				var valor_double = float(resultado)
				new_item.set_value_by_type(valor_double, tipo_enum)
			"BINARY":
				tipo_enum = new_item.DataType.BINARY
				var valor_binary = int(resultado)
				new_item.set_value_by_type(valor_binary, tipo_enum)
			_:
				# Fallback: tenta converter para int
				tipo_enum = new_item.DataType.INT
				var valor_int = int(float(resultado))
				valor_int = clamp(valor_int, -999, 999)
				new_item.set_value_by_type(valor_int, tipo_enum)
	else:
		# Fallback: usa método antigo
		var valor_inteiro = int(float(resultado))
		valor_inteiro = clamp(valor_inteiro, 0, 999)
		if new_item.has_method("set_value_directly"):
			new_item.set_value_directly(valor_inteiro)
		else:
			var item_type = "item_number_" + str(valor_inteiro)
			if new_item.has_method("load_item"):
				new_item.load_item(item_type)
	
	new_item.selected = true
	item_held = new_item
	_dbg("Item de resultado criado - Valor: ", resultado, " Tipo: ", tipo_resultado)
	
	# Força a verificação de disponibilidade para o novo item
	# (o mouse já está sobre um slot, mas o sinal slot_entered não vai disparar novamente)
	if current_slot:
		check_slot_availability(current_slot)
		set_grids.call_deferred(current_slot)

func consumir_itens_expressao():
	"""Remove os itens usados na expressão do grid"""
	_dbg("Consumindo ", ultimos_slots_expressao.size(), " itens da expressão")
	
	for slot in ultimos_slots_expressao:
		for item in slot.items_stored.duplicate():
			
			# Se o item está atualmente segurado, solta ele
			if item == item_held:
				item_held = null
			
			# Remove o item da cena
			item.queue_free()
			
		# Atualiza o estado do slot
		slot.clear_items()
		slot.state = slot.States.FREE
		slot.set_color(slot.States.DEFAULT)
	
	# Limpa a lista de slots usados
	ultimos_slots_expressao.clear()

# Função para debug - mostra os slots que serão consumidos
func debug_slots_expressao():
	_dbg("Slots marcados para consumo:")
	for slot in ultimos_slots_expressao:
		_dbg(" - Slot ", slot.slot_ID)

func _on_item_mouse_entered(item):
	"""Chamado quando o mouse entra em um item"""
	show_item_info(item)

@warning_ignore("unused_parameter")
func _on_item_mouse_exited(item):
	"""Chamado quando o mouse sai de um item"""
	clear_info_panel()

func show_item_info(item):
	"""Mostra as informações do item no painel"""
	if not item or not info_panel:
		return
	
	# Obtém as informações do item
	var info = item.get_item_info() if item.has_method("get_item_info") else {}
	
	# Atualiza os labels com formatação melhorada
	if info_type_label:
		var tipo_texto = info.get("tipo", "Desconhecido")
		info_type_label.text = "Tipo: " + tipo_texto
	
	if info_value_label:
		var valor_texto: String = OrbValueFormat.full_value_string(item)
		if OrbValueFormat.should_compact(item):
			info_value_label.text = "No orbe: %s  |  Exato: %s" % [
				OrbValueFormat.compact_label_string(item), valor_texto
			]
		else:
			info_value_label.text = "Valor: " + valor_texto
	
	if info_id_label:
		var id_texto = info.get("id", "")
		if id_texto == "" or id_texto == null:
			id_texto = "N/A"
		info_id_label.text = "ID: " + str(id_texto)
	
	if info_details_label:
		info_details_label.text = "Python: " + OrbValueFormat.python_repr_string(item)
	
	# Mostra o painel
	if info_panel:
		info_panel.visible = true

func clear_info_panel():
	"""Limpa o painel de informações"""
	if info_type_label:
		info_type_label.text = "Tipo: -"
	if info_value_label:
		info_value_label.text = "Valor: -"
	if info_id_label:
		info_id_label.text = "ID: -"
	if info_details_label:
		info_details_label.text = "Detalhes: -"
	
	# Opcional: esconder o painel quando não há item
	# info_panel.visible = false  # Descomente se quiser esconder
