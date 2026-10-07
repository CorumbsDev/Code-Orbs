class_name ItemData
extends RefCounted

static func get_item_info(item) -> Dictionary:
	var info = {
		"tipo": "",
		"valor": "",
		"id": "",
		"detalhes": ""
	}
	
	if item.item_ID == null or item.item_ID == "":
		match item.data_type:
			item.DataType.INT:
				info.id = "item_number_" + str(item.value)
			item.DataType.FLOAT:
				info.id = "item_float_" + str(item.value_float)
			item.DataType.STRING:
				info.id = "item_string_" + str(item.value_string.hash())
			item.DataType.OPERATOR:
				info.id = "item_operator_" + item.operator
			item.DataType.DOUBLE:
				info.id = "item_double_" + str(item.value_double)
			item.DataType.BINARY:
				info.id = "item_binary_" + str(item.value)
			item.DataType.RAW:
				info.id = "item_raw_" + str(item.value_float)
			_:
				info.id = "item_unknown"
	else:
		info.id = item.item_ID
	
	var full_val: String = OrbValueFormat.full_value_string(item)
	match item.data_type:
		item.DataType.INT:
			info.tipo = "INT (Inteiro)"
			info.valor = full_val
			info.detalhes = "Número inteiro: " + full_val
		item.DataType.FLOAT:
			info.tipo = "FLOAT (Decimal)"
			info.valor = full_val
			info.detalhes = "Número decimal: " + full_val
		item.DataType.STRING:
			info.tipo = "STRING (Texto)"
			info.valor = '"' + item.value_string + '"'
			info.detalhes = "Texto: " + item.value_string
		item.DataType.OPERATOR:
			info.tipo = "OPERATOR (Operador)"
			info.valor = item.operator
			info.detalhes = "Operador: " + item.operator
		item.DataType.DOUBLE:
			info.tipo = "DOUBLE (Precisão Dupla)"
			info.valor = full_val
			info.detalhes = "Valor double: " + full_val + "\nOcupa 2 slots lado a lado (8 bytes)"
		item.DataType.SHORT_INT:
			info.tipo = "SHORT (Inteiro Curto)"
			info.valor = full_val
			info.detalhes = "Inteiro curto de 16 bits: " + full_val + "\nOcupa 0.5 slots (2 bytes)"
		item.DataType.BINARY:
			var decimal_val = binary_to_int(item.value_binary)
			var explicacao = get_binary_explanation(item.value_binary)
			info.tipo = "BINARY (Binário)"
			info.valor = item.value_binary
			info.detalhes = "Binário: " + item.value_binary + "\nDecimal: " + str(decimal_val) + "\nBits: " + str(item.binary_bits) + "\nOcupa " + str(item.binary_bits) + " slots\n\nComo o binário funciona:\n" + explicacao
		item.DataType.FP8:
			info.tipo = "FP8 (Float 8-bit)"
			info.valor = full_val
			info.detalhes = "Ponto flutuante 8-bit: " + full_val + "\nOcupa 0.25 slots"
		item.DataType.FP16:
			info.tipo = "FP16 (Float 16-bit)"
			info.valor = full_val
			info.detalhes = "Ponto flutuante 16-bit: " + full_val + "\nOcupa 0.5 slots"
		item.DataType.RAW:
			info.tipo = "RAW (Valor Puro)"
			info.valor = full_val
			info.detalhes = "Valor sem tipo definido: " + full_val + "\nArraste para uma caixa de tipagem."
		_:
			info.tipo = "DESCONHECIDO"
			info.valor = str(item.value)
			info.detalhes = "Tipo não identificado"
	
	return info

static func load_item(item, a_ItemID: String, dh = null) -> void:
	print("[DEBUG] ItemData: Chamado load_item para '%s'" % a_ItemID)
	item.item_ID = a_ItemID
	if dh == null:
		dh = Engine.get_main_loop().root.get_node_or_null("DataHandler")
		
	if dh != null and not dh.item_data.has(item.item_ID):
		_register_dynamic_orb(item.item_ID, dh)
		
	var data = dh.item_data.get(item.item_ID, {})

	if data.has("Operator") and str(data["Operator"]) != "":
		item.operator = str(data["Operator"])
		item.data_type = item.DataType.OPERATOR
		item.value = 0
		item.value_float = 0.0
		item.value_string = ""
	elif data.has("DataType"):
		var tipo = str(data["DataType"]).to_upper()
		match tipo:
			"FLOAT":
				item.data_type = item.DataType.FLOAT
				item.value_float = float(data.get("Value", 0.0))
				item.value = 0
				item.value_string = ""
			"STRING", "STR":
				item.data_type = item.DataType.STRING
				item.value_string = str(data.get("Value", ""))
				item.value = 0
				item.value_float = 0.0
			"DOUBLE":
				item.data_type = item.DataType.DOUBLE
				item.value_double = float(data.get("Value", 0.0))
				item.value = int(item.value_double)
				item.value_float = item.value_double
				item.value_string = ""
				item.item_grids = [Vector2(0,0), Vector2(1,0)]
			"BINARY", "BIN":
				item.data_type = item.DataType.BINARY
				item.binary_bits = int(data.get("Bits", 8))
				item.value = int(data.get("Value", 0))
				item.value_binary = int_to_binary(item.value, item.binary_bits)
				item.value_float = float(item.value)
				item.value_string = ""
				item.item_grids = [Vector2(0,0)]
			"SHORT_INT", "SHORT":
				item.data_type = item.DataType.SHORT_INT
				item.value_short = int(data.get("Value", 0))
				item.value = item.value_short
				item.value_float = float(item.value_short)
				item.value_string = ""
				item.item_grids = [Vector2(0,0)]
			"FP8":
				item.data_type = item.DataType.FP8
				item.value_float = float(data.get("Value", 0.0))
				item.value = int(item.value_float)
				item.value_string = ""
				item.item_grids = [Vector2(0,0)]
			"FP16":
				item.data_type = item.DataType.FP16
				item.value_float = float(data.get("Value", 0.0))
				item.value = int(item.value_float)
				item.value_string = ""
				item.item_grids = [Vector2(0,0)]
			"RAW":
				item.data_type = item.DataType.RAW
				item.value_float = float(data.get("Value", 0.0))
				item.value = int(item.value_float)
				item.value_string = ""
				item.item_grids = [Vector2(0,0)]
			_:
				item.data_type = item.DataType.INT
				item.value = int(data.get("Value", 0))
				item.value_float = 0.0
				item.value_string = ""
	else:
		item.data_type = item.DataType.INT
		item.value = int(data.get("Value", 0))
		item.value_float = 0.0
		item.value_string = ""
		item.operator = ""

static func set_value_by_type(item, new_value, tipo) -> void:
	item.data_type = tipo
	item.operator = ""
	
	match tipo:
		item.DataType.INT:
			item.value = int(new_value)
			item.value_float = float(new_value)
			item.value_string = ""
			item.item_grids = [Vector2(0,0)]
		item.DataType.FLOAT:
			item.value_float = float(new_value)
			item.value = int(item.value_float)
			item.value_string = ""
			item.item_grids = [Vector2(0,0)]
		item.DataType.STRING:
			item.value_string = str(new_value)
			item.value = 0
			item.value_float = 0.0
			item.item_grids = [Vector2(0,0)]
		item.DataType.OPERATOR:
			item.operator = str(new_value)
			item.value = 0
			item.value_float = 0.0
			item.value_string = ""
			item.item_grids = [Vector2(0,0)]
		item.DataType.DOUBLE:
			item.value_double = float(new_value)
			item.value = int(item.value_double)
			item.value_float = item.value_double
			item.value_string = ""
			item.item_grids = [Vector2(0,0), Vector2(1,0)]
		item.DataType.BINARY:
			item.value = int(new_value)
			item.value_binary = int_to_binary(item.value, item.binary_bits)
			item.value_float = float(item.value)
			item.value_string = ""
			item.item_grids = [Vector2(0,0)]
		item.DataType.SHORT_INT:
			item.value_short = int(new_value)
			item.value = item.value_short
			item.value_float = float(item.value_short)
			item.value_string = ""
			item.item_grids = [Vector2(0,0)]
		item.DataType.FP8:
			item.value_float = float(new_value)
			item.value = int(item.value_float)
			item.value_string = ""
			item.item_grids = [Vector2(0,0)]
		item.DataType.FP16:
			item.value_float = float(new_value)
			item.value = int(item.value_float)
			item.value_string = ""
			item.item_grids = [Vector2(0,0)]
		item.DataType.RAW:
			item.value_float = float(new_value)
			item.value = int(item.value_float)
			item.value_string = ""
			item.item_grids = [Vector2(0,0)]

static func int_to_binary(val: int, bits: int) -> String:
	if val < 0:
		val = 0
	var result = ""
	var temp = val
	for i in range(bits):
		result = str(temp % 2) + result
		@warning_ignore("integer_division")
		temp = temp / 2
	return result

static func binary_to_int(bin_str: String) -> int:
	var result = 0
	for i in range(bin_str.length()):
		result = result * 2 + int(bin_str[i])
	return result

static func get_size_bytes(item, dh = null) -> int:
	if dh == null:
		dh = Engine.get_main_loop().root.get_node_or_null("DataHandler")
	match item.data_type:
		item.DataType.DOUBLE:
			return 8
		item.DataType.FLOAT:
			return 4
		item.DataType.INT:
			return 4
		item.DataType.SHORT_INT:
			return 2
		item.DataType.FP16:
			return 2
		item.DataType.FP8:
			return 1
		item.DataType.RAW:
			return 0
		item.DataType.BINARY:
			if item.item_ID != null and item.item_ID != "" and dh:
				return dh.get_item_bytes(item.item_ID)
			return int(ceil(float(item.binary_bits) / 8.0))
		_:
			if item.item_ID != null and item.item_ID != "" and dh:
				return dh.get_item_bytes(item.item_ID)
			return 4

static func get_binary_explanation(bin_str: String) -> String:
	if bin_str.is_empty():
		return "-"
	var n = bin_str.length()
	var termos: PackedStringArray = []
	for i in range(n):
		var dig = bin_str[i]
		var pos = n - 1 - i
		var exp_str = "2⁰" if pos == 0 else ("2¹" if pos == 1 else "2²" if pos == 2 else "2³" if pos == 3 else "2^" + str(pos))
		termos.append(dig + "·" + exp_str)
	var formula = " + ".join(termos)
	var decimal_val = binary_to_int(bin_str)
	return bin_str + "₂ = " + formula + " = " + str(decimal_val)

static func _register_dynamic_orb(item_id: String, dh: Node) -> void:
	print("[DEBUG] ItemData: _register_dynamic_orb chamado para '%s'" % item_id)
	if dh == null or dh.item_data.has(item_id):
		return
		
	var data := {}
	var val_str = item_id
	if item_id == "raw":
		data = {"DataType": "RAW", "Value": 0.0}
	elif item_id.ends_with("_i"):
		val_str = item_id.trim_suffix("_i")
		data = {"DataType": "INT", "Value": int(val_str), "Bytes": 4}
	elif item_id.ends_with("_f"):
		val_str = item_id.trim_suffix("_f")
		data = {"DataType": "FLOAT", "Value": float(val_str), "Bytes": 4}
	elif item_id.ends_with("_d"):
		val_str = item_id.trim_suffix("_d")
		data = {"DataType": "DOUBLE", "Value": float(val_str), "Bytes": 8}
	elif item_id.ends_with("_s"):
		val_str = item_id.trim_suffix("_s")
		data = {"DataType": "SHORT_INT", "Value": int(val_str), "Bytes": 2}
	elif item_id.ends_with("_b"):
		val_str = item_id.trim_suffix("_b")
		data = {"DataType": "BINARY", "Value": int(val_str), "Bits": 8, "Bytes": 1}
	elif item_id.ends_with("_r"):
		val_str = item_id.trim_suffix("_r")
		data = {"DataType": "RAW", "Value": float(val_str), "Bytes": 0}
	else:
		return
		
	dh.item_data[item_id] = data
