class_name TypeConversionSystem
extends RefCounted

const ItemRef = preload("res://Inventory/Items/item.gd")

## Maior valor finito representável em float32.
const FLOAT32_MAX := 3.4028235e38
const INT32_MIN := -2147483648
const INT32_MAX := 2147483647
const INT16_MIN := -32768
const INT16_MAX := 32767

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

## Arredonda para float32 real (round-to-nearest-even do hardware) e devolve como float64.
static func quantize_float32(val: float) -> float:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_float(0, val)
	return b.decode_float(0)

## Valor efetivamente guardado por um Float de 32 bits.
## Se a quantização for "invisível" (o decimal digitado, ex.: 3.14, é o menor decimal que
## identifica o float32), mantém o valor original; senão devolve o valor arredondado (ex.: 16777219 -> 16777220).
static func float32_effective(val: float) -> float:
	if is_nan(val) or is_inf(val) or val == 0.0:
		return val
	if absf(val) > FLOAT32_MAX:
		return val
	var q := quantize_float32(val)
	if q == val:
		return val
	if _decimal_roundtrips_float32(val, q):
		return val
	return q

static func _decimal_roundtrips_float32(val: float, q: float) -> bool:
	var exp10 := int(floor(log(absf(q)) / log(10.0)))
	for d in range(1, 11):
		var e := d - 1 - exp10
		var r: float
		if e >= 0:
			var p := pow(10.0, e)
			r = roundf(q * p) / p
		else:
			var p2 := pow(10.0, -e)
			r = roundf(q / p2) * p2
		if quantize_float32(r) == q:
			return absf(r - val) <= absf(val) * 1e-12
	return false

static func _fmt(v: float) -> String:
	if is_nan(v):
		return "NaN"
	if is_inf(v):
		return "Inf" if v > 0 else "-Inf"
	if v == floorf(v) and absf(v) < 1e15:
		return str(int(v))
	return String.num(v, 6)

static func apply_target_type_to_item(item: Node, target_type_str: String, final_val: float, config) -> void:
	if item == null or not is_instance_valid(item):
		return
	match target_type_str:
		"Int":
			item.set_value_by_type(int(final_val), ItemRef.DataType.INT)
		"Float":
			item.set_value_by_type(float32_effective(final_val), ItemRef.DataType.FLOAT)
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

## Retorna {has_warning, message, degraded_value, kind, abs_error, rel_error, blocks_conversion}.
## kind: "none" | "overflow" | "underflow" | "truncation" | "precision" (a calculadora ainda pode usar "absorption").
## Int/Short com overflow: NÃO satura (não muda o valor binário); blocks_conversion=true.
## FP8/FP16 (e Float→Inf): podem aproximar / virar Inf; blocks_conversion=false.
static func check_degradation(target_type_str: String, val_to_convert: float, config) -> Dictionary:
	var result = {
		"has_warning": false, "message": "", "degraded_value": val_to_convert,
		"kind": "none", "abs_error": 0.0, "rel_error": 0.0,
		"blocks_conversion": false,
	}
	if target_type_str == "Int":
		var trunc_val = float(int(val_to_convert))
		if trunc_val != val_to_convert:
			result.has_warning = true
			result.kind = "truncation"
			result.message = "Perda de precisão: A parte decimal será descartada."
		
		if trunc_val < INT32_MIN or trunc_val > INT32_MAX:
			result.has_warning = true
			result.kind = "overflow"
			result.blocks_conversion = true
			if trunc_val < INT32_MIN:
				result.message = "Overflow: o valor não cabe em Int 32 bits (−2.1B a 2.1B). A conversão foi bloqueada — o valor binário não será alterado nem saturado."
			else:
				result.message = "Overflow: o valor não cabe em Int 32 bits (−2.1B a 2.1B). A conversão foi bloqueada — o valor binário não será alterado nem saturado."
			# Mantém o inteiro truncado original (sem clamp).
			result.degraded_value = trunc_val
		else:
			result.degraded_value = trunc_val
			
	elif target_type_str == "Short":
		var trunc_val = float(int(val_to_convert))
		if trunc_val != val_to_convert:
			result.has_warning = true
			result.kind = "truncation"
			result.message = "Perda de precisão: A parte decimal será descartada."
			
		if trunc_val < INT16_MIN or trunc_val > INT16_MAX:
			result.has_warning = true
			result.kind = "overflow"
			result.blocks_conversion = true
			result.message = "Overflow: o valor não cabe em Short 16 bits (−32768 a 32767). A conversão foi bloqueada — o valor binário não será alterado nem saturado."
			result.degraded_value = trunc_val
		else:
			result.degraded_value = trunc_val
			
	elif target_type_str == "Float":
		if val_to_convert > FLOAT32_MAX:
			result.has_warning = true
			result.kind = "overflow"
			result.message = "Overflow: O valor excede a capacidade máxima de um Float de 32 bits e se tornará Infinito Positivo."
			result.degraded_value = INF
		elif val_to_convert < -FLOAT32_MAX:
			result.has_warning = true
			result.kind = "overflow"
			result.message = "Underflow: O valor excede a capacidade mínima de um Float de 32 bits e se tornará Infinito Negativo."
			result.degraded_value = -INF
		else:
			var eff := float32_effective(val_to_convert)
			if eff != val_to_convert:
				result.has_warning = true
				result.kind = "precision"
				result.message = "Perda de precisão: mantissa de 23 bits arredondou o valor de %s para %s." % [_fmt(val_to_convert), _fmt(eff)]
				result.degraded_value = eff
			
	elif target_type_str == "FP8":
		var e_bits = 4
		var m_bits = 3
		if config != null and config.get("fp8_exp_bits") != null:
			e_bits = config.fp8_exp_bits
			m_bits = config.fp8_mant_bits
		_check_custom_fp(result, "FP8", val_to_convert, e_bits, m_bits)
		
	elif target_type_str == "FP16":
		var e_bits = 5
		var m_bits = 10
		if config != null and config.get("fp16_exp_bits") != null:
			e_bits = config.fp16_exp_bits
			m_bits = config.fp16_mant_bits
		_check_custom_fp(result, "FP16", val_to_convert, e_bits, m_bits)
	
	_fill_errors(result, val_to_convert)
	return result


## Overflow de Int/Short: não se aplica conversão (sem saturar). FP8/FP16/Float podem seguir com aviso.
static func blocks_conversion(deg: Dictionary) -> bool:
	if deg == null or deg.is_empty():
		return false
	return bool(deg.get("blocks_conversion", false))


## Quantiza para FP customizado e classifica o resultado (overflow / underflow / precision).
static func _check_custom_fp(result: Dictionary, label: String, val: float, e_bits: int, m_bits: int) -> void:
	var dict = float_to_custom_fp_bits(val, e_bits, m_bits)
	var back_to_float = custom_fp_bits_to_float(dict.bits, e_bits, m_bits)
	if val != back_to_float:
		result.has_warning = true
		if is_inf(back_to_float) and not is_inf(val):
			result.kind = "overflow"
			result.message = "Overflow: valor excede o limite do tipo %s (%d exp, %d mant) e se tornará Infinito." % [label, e_bits, m_bits]
		elif back_to_float == 0.0 and val != 0.0:
			result.kind = "underflow"
			result.message = "Underflow: valor colapsou para 0.0 (menor que o menor valor normal de %s com %d bits de expoente)." % [label, e_bits]
		else:
			result.kind = "precision"
			result.message = "Perda de precisão: O formato %s (%d exp, %d mant) não possui precisão suficiente para o valor exato. Valor aproximado: %s" % [label, e_bits, m_bits, str(back_to_float)]
	result.degraded_value = back_to_float

static func _fill_errors(result: Dictionary, val: float) -> void:
	var dv: float = result.degraded_value
	if is_nan(val) or is_inf(val) or is_nan(dv):
		result.abs_error = 0.0
		result.rel_error = 0.0
		return
	var abs_err := absf(dv - val)
	result.abs_error = abs_err
	result.rel_error = abs_err / maxf(absf(val), 1e-9)

## Converte um float (32 bits) em bits de FP customizado com round-to-nearest-even.
## Subnormais são zerados (flush-to-zero); expoente máximo reservado para Inf/NaN.
static func float_to_custom_fp_bits(val: float, exp_bits: int, mant_bits: int) -> Dictionary:
	var bytes = PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0, val)
	var f_bits = bytes.decode_u32(0)
	var sign_bit = (f_bits >> 31) & 1
	var f_exp = (f_bits >> 23) & 0xFF
	var f_mant = f_bits & 0x7FFFFF
	var tgt_bias = (1 << (exp_bits - 1)) - 1
	var max_exp = (1 << exp_bits) - 1
	var tgt_exp = 0
	var tgt_mant = 0
	if f_exp == 0xFF:
		tgt_exp = max_exp
		tgt_mant = 1 if f_mant != 0 else 0
	elif f_exp == 0:
		tgt_exp = 0
		tgt_mant = 0
	else:
		var actual_exp = f_exp - 127
		tgt_exp = actual_exp + tgt_bias
		if tgt_exp >= max_exp:
			tgt_exp = max_exp
			tgt_mant = 0
		elif tgt_exp <= 0:
			tgt_exp = 0
			tgt_mant = 0
		else:
			if mant_bits < 23:
				var shift = 23 - mant_bits
				tgt_mant = f_mant >> shift
				var rem = f_mant & ((1 << shift) - 1)
				var half = 1 << (shift - 1)
				# Round-to-nearest-even: guard bit (half), round/sticky (restante).
				if rem > half or (rem == half and (tgt_mant & 1) == 1):
					tgt_mant += 1
					if tgt_mant >= (1 << mant_bits):
						# Carry da mantissa para o expoente.
						tgt_mant = 0
						tgt_exp += 1
						if tgt_exp >= max_exp:
							tgt_exp = max_exp
							tgt_mant = 0
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
