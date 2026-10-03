class_name TypeConversionSystem
extends RefCounted

const ItemRef = preload("res://Inventory/Items/item.gd")

static func get_type_priority(item) -> int:
	if item == null:
		return 0
	return priority_for_data_type(item.data_type)

static func priority_for_data_type(dt: int) -> int:
	if dt == ItemRef.DataType.DOUBLE: return 100
	if dt == ItemRef.DataType.FLOAT: return 90
	if dt == ItemRef.DataType.FP16: return 80
	if dt == ItemRef.DataType.FP8: return 70
	if dt == ItemRef.DataType.INT: return 60
	if dt == ItemRef.DataType.SHORT_INT: return 50
	return 0

static func get_type_string(dt: int) -> String:
	if dt == ItemRef.DataType.DOUBLE: return "Double"
	if dt == ItemRef.DataType.FLOAT: return "Float"
	if dt == ItemRef.DataType.FP16: return "FP16"
	if dt == ItemRef.DataType.FP8: return "FP8"
	if dt == ItemRef.DataType.INT: return "Int"
	if dt == ItemRef.DataType.SHORT_INT: return "Short"
	return "Float"

static func value_for_conversion(item: Node) -> float:
	if item == null:
		return 0.0
	if item.data_type in [
		ItemRef.DataType.FLOAT, ItemRef.DataType.DOUBLE,
		ItemRef.DataType.FP8, ItemRef.DataType.FP16, ItemRef.DataType.RAW
	]:
		return item.value_float
	return float(item.value)

static func apply_fp_bits_from_config(item: Node, kind: String, config) -> void:
	if config == null or item == null:
		return
	if kind == "fp8":
		item.fp_exp_bits = config.fp8_exp_bits
		item.fp_mant_bits = config.fp8_mant_bits
	elif kind == "fp16":
		item.fp_exp_bits = config.fp16_exp_bits
		item.fp_mant_bits = config.fp16_mant_bits

static func apply_target_type_to_item(item: Node, target_type_str: String, final_val: float, config) -> void:
	if item == null or not is_instance_valid(item):
		return
	match target_type_str:
		"Int":
			item.set_value_by_type(int(final_val), ItemRef.DataType.INT)
		"Float":
			item.set_value_by_type(final_val, ItemRef.DataType.FLOAT)
		"Double":
			item.set_value_by_type(final_val, ItemRef.DataType.DOUBLE)
		"Short":
			item.set_value_by_type(int(final_val), ItemRef.DataType.SHORT_INT)
		"FP8":
			item.set_value_by_type(final_val, ItemRef.DataType.FP8)
			apply_fp_bits_from_config(item, "fp8", config)
		"FP16":
			item.set_value_by_type(final_val, ItemRef.DataType.FP16)
			apply_fp_bits_from_config(item, "fp16", config)
	if item.has_method("update_label_display"):
		item.update_label_display()

static func check_degradation(target_type_str: String, val_to_convert: float, config) -> Dictionary:
	var result = {"has_warning": false, "message": "", "degraded_value": val_to_convert}
	if target_type_str == "Int":
		var trunc_val = float(int(val_to_convert))
		if trunc_val != val_to_convert:
			result.has_warning = true
			result.message = "Perda de precisão: A parte decimal será descartada."
		
		if trunc_val < -2147483648:
			result.has_warning = true
			result.message = "Underflow: O valor fica abaixo do mínimo de um Inteiro de 32 bits (-2.1B a 2.1B)."
			trunc_val = -2147483648
		elif trunc_val > 2147483647:
			result.has_warning = true
			result.message = "Overflow: O valor excede os limites de um Inteiro de 32 bits (-2.1B a 2.1B)."
			trunc_val = 2147483647
		result.degraded_value = trunc_val
			
	elif target_type_str == "Short":
		var trunc_val = float(int(val_to_convert))
		if trunc_val != val_to_convert:
			result.has_warning = true
			result.message = "Perda de precisão: A parte decimal será descartada."
			
		if trunc_val < -32768:
			result.has_warning = true
			result.message = "Underflow: O valor fica abaixo do mínimo de um Short Inteiro de 16 bits (-32768 a 32767)."
			trunc_val = -32768
		elif trunc_val > 32767:
			result.has_warning = true
			result.message = "Overflow: O valor excede os limites de um Short Inteiro de 16 bits (-32768 a 32767)."
			trunc_val = 32767
		result.degraded_value = trunc_val
			
	elif target_type_str == "Float":
		if val_to_convert > 3.4028235e38:
			result.has_warning = true
			result.message = "Overflow: O valor excede a capacidade máxima de um Float de 32 bits e se tornará Infinito Positivo."
			result.degraded_value = INF
		elif val_to_convert < -3.4028235e38:
			result.has_warning = true
			result.message = "Underflow: O valor excede a capacidade mínima de um Float de 32 bits e se tornará Infinito Negativo."
			result.degraded_value = -INF
			
	elif target_type_str == "FP8":
		var e_bits = 4
		var m_bits = 3
		if config != null and config.get("fp8_exp_bits") != null:
			e_bits = config.fp8_exp_bits
			m_bits = config.fp8_mant_bits
		
		var dict = float_to_custom_fp_bits(val_to_convert, e_bits, m_bits)
		var back_to_float = custom_fp_bits_to_float(dict.bits, e_bits, m_bits)
		if val_to_convert != back_to_float:
			result.has_warning = true
			result.message = "Perda de precisão: O formato FP8 (" + str(e_bits) + " exp, " + str(m_bits) + " mant) não possui precisão suficiente para o valor exato. Valor aproximado: " + str(back_to_float)
		result.degraded_value = back_to_float
		
	elif target_type_str == "FP16":
		var e_bits = 5
		var m_bits = 10
		if config != null and config.get("fp16_exp_bits") != null:
			e_bits = config.fp16_exp_bits
			m_bits = config.fp16_mant_bits
		
		var dict = float_to_custom_fp_bits(val_to_convert, e_bits, m_bits)
		var back_to_float = custom_fp_bits_to_float(dict.bits, e_bits, m_bits)
		if val_to_convert != back_to_float:
			result.has_warning = true
			result.message = "Perda de precisão: O formato FP16 não possui precisão suficiente para manter o valor exato. Valor aproximado: " + str(back_to_float)
		result.degraded_value = back_to_float
		
	return result

static func float_to_custom_fp_bits(val: float, exp_bits: int, mant_bits: int) -> Dictionary:
	var bytes = PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0, val)
	var f_bits = bytes.decode_u32(0)
	var sign_bit = (f_bits >> 31) & 1
	var f_exp = (f_bits >> 23) & 0xFF
	var f_mant = f_bits & 0x7FFFFF
	var tgt_bias = (1 << (exp_bits - 1)) - 1
	var tgt_exp = 0
	var tgt_mant = 0
	if f_exp == 0xFF:
		tgt_exp = (1 << exp_bits) - 1
		tgt_mant = 1 if f_mant != 0 else 0
	elif f_exp == 0:
		tgt_exp = 0
		tgt_mant = 0
	else:
		var actual_exp = f_exp - 127
		tgt_exp = actual_exp + tgt_bias
		if tgt_exp >= (1 << exp_bits) - 1:
			tgt_exp = (1 << exp_bits) - 1
			tgt_mant = 0
		elif tgt_exp <= 0:
			tgt_exp = 0
			tgt_mant = 0
		else:
			if mant_bits <= 23:
				tgt_mant = f_mant >> (23 - mant_bits)
			else:
				tgt_mant = f_mant << (mant_bits - 23)
	var combined_bits = (sign_bit << (exp_bits + mant_bits)) | (tgt_exp << mant_bits) | tgt_mant
	return {"bits": combined_bits}

static func custom_fp_bits_to_float(bits: int, exp_bits: int, mant_bits: int) -> float:
	var sign_bit = (bits >> (exp_bits + mant_bits)) & 1
	var tgt_exp = (bits >> mant_bits) & ((1 << exp_bits) - 1)
	var tgt_mant = bits & ((1 << mant_bits) - 1)
	var tgt_bias = (1 << (exp_bits - 1)) - 1
	var f_exp = 0
	var f_mant = 0
	if tgt_exp == ((1 << exp_bits) - 1):
		f_exp = 0xFF
		f_mant = 1 if tgt_mant != 0 else 0
	elif tgt_exp == 0:
		f_exp = 0
		f_mant = 0
	else:
		var actual_exp = tgt_exp - tgt_bias
		f_exp = actual_exp + 127
		if f_exp <= 0:
			f_exp = 0
		elif f_exp >= 0xFF:
			f_exp = 0xFF
			f_mant = 0
		else:
			if mant_bits <= 23:
				f_mant = tgt_mant << (23 - mant_bits)
			else:
				f_mant = tgt_mant >> (mant_bits - 23)
	var f_bits = (sign_bit << 31) | (f_exp << 23) | f_mant
	var bytes = PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, f_bits)
	return bytes.decode_float(0)
