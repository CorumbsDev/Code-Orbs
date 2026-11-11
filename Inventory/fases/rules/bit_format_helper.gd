class_name BitFormatHelper
extends RefCounted


static func cfg_int(config: Variant, prop: String, default_val: int) -> int:
	if config != null and (prop in config):
		return int(config.get(prop))
	return default_val


static func build_bit_specs_for_item(item: Node, config: Variant = null) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	var dt: int = int(item.data_type)

	if dt in [item.DataType.INT, item.DataType.SHORT_INT]:
		var bits: int = 32 if dt == item.DataType.INT else 16
		var int_val: int = int(item.value) if dt == item.DataType.INT else int(item.value_short)
		var bin_str: String = int_to_bin_str(int_val, bits)
		for i in range(bits):
			var bit_pos: int = (bits - 1) - i
			var b_ch: String = bin_str[i]
			if i == 0:
				specs.append({
					"bit": b_ch,
					"role": "sign",
					"role_label": "Sinal",
					"tooltip": "Bit %d — Sinal (Complemento de 2): %s (%s)" % [bit_pos, b_ch, "Negativo (-)" if b_ch == "1" else "Positivo (+)"]
				})
			else:
				var weight: int = 1 << bit_pos
				specs.append({
					"bit": b_ch,
					"role": "byte",
					"role_label": "Magnitude",
					"tooltip": "Bit %d — Magnitude Inteira: bit %s (peso 2^%d = %d)" % [bit_pos, b_ch, bit_pos, weight]
				})
		return specs

	if dt == item.DataType.BINARY:
		var b_str: String = str(item.value_binary) if str(item.value_binary) != "" else int_to_bin_str(int(item.value), maxi(int(item.binary_bits), 1))
		var n: int = b_str.length()
		for i in range(n):
			var bit_pos: int = (n - 1) - i
			var b_ch: String = b_str[i]
			specs.append({
				"bit": b_ch,
				"role": "byte",
				"role_label": "Binário",
				"tooltip": "Bit %d — Valor posicional: %s × 2^%d = %d" % [bit_pos, b_ch, bit_pos, (1 << bit_pos) if b_ch == "1" else 0]
			})
		return specs

	if dt == item.DataType.RAW:
		var raw_v: float = float(item.value_float)
		var is_decimal: bool = ("." in str(item.raw_literal)) or not is_equal_approx(raw_v, roundf(raw_v))
		if not is_decimal and absf(raw_v) <= 2147483647.0:
			var bin_i: String = int_to_bin_str(int(roundf(raw_v)), 16 if absf(raw_v) <= 32767.0 else 32)
			var nb: int = bin_i.length()
			for i in range(nb):
				var bit_pos: int = (nb - 1) - i
				var b_ch: String = bin_i[i]
				if i == 0:
					specs.append({
						"bit": b_ch,
						"role": "sign",
						"role_label": "Sinal",
						"tooltip": "Bit %d — Sinal: %s (%s)" % [bit_pos, b_ch, "Negativo (-)" if b_ch == "1" else "Positivo (+)"]
					})
				else:
					specs.append({
						"bit": b_ch,
						"role": "byte",
						"role_label": "Magnitude",
						"tooltip": "Bit %d — Magnitude: bit %s (2^%d)" % [bit_pos, b_ch, bit_pos]
					})
			return specs
		return build_fp_bit_specs(float_to_custom_fp_bits(raw_v, 8, 23), 8, 23)

	if dt == item.DataType.FLOAT:
		return build_fp_bit_specs(float_to_custom_fp_bits(float(item.value_float), 8, 23), 8, 23)
	if dt == item.DataType.DOUBLE:
		return build_fp_bit_specs(double_to_fp_bits(float(item.value_double)), 11, 52)
	if dt == item.DataType.FP8:
		var e8: int = int(item.fp_exp_bits) if int(item.fp_exp_bits) != -1 else cfg_int(config, "fp8_exp_bits", 4)
		var m8: int = int(item.fp_mant_bits) if int(item.fp_mant_bits) != -1 else cfg_int(config, "fp8_mant_bits", 3)
		return build_fp_bit_specs(float_to_custom_fp_bits(float(item.value_float), e8, m8), e8, m8)
	if dt == item.DataType.FP16:
		var e16: int = int(item.fp_exp_bits) if int(item.fp_exp_bits) != -1 else cfg_int(config, "fp16_exp_bits", 5)
		var m16: int = int(item.fp_mant_bits) if int(item.fp_mant_bits) != -1 else cfg_int(config, "fp16_mant_bits", 10)
		return build_fp_bit_specs(float_to_custom_fp_bits(float(item.value_float), e16, m16), e16, m16)

	return specs


static func build_fp_bit_specs(dict: Dictionary, exp_bits: int, mant_bits: int) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	var total: int = 1 + exp_bits + mant_bits
	var s_ch: String = "1" if int(dict.get("sign", 0)) != 0 else "0"
	specs.append({
		"bit": s_ch,
		"role": "sign",
		"role_label": "Sinal",
		"tooltip": "Bit %d — Sinal (Losango Vermelho): %s → %s" % [total - 1, s_ch, "Negativo (-)" if s_ch == "1" else "Positivo (+)"]
	})

	var exp_val: int = int(dict.get("exp", 0))
	for i in range(exp_bits - 1, -1, -1):
		var b_ch: String = "1" if (exp_val & (1 << i)) != 0 else "0"
		var bit_pos: int = mant_bits + i
		specs.append({
			"bit": b_ch,
			"role": "exp",
			"role_label": "Expoente",
			"tooltip": "Bit %d — Expoente (Hexágono Verde): bit %s (peso 2^%d = %d no expoente)" % [bit_pos, b_ch, i, 1 << i]
		})

	var mant_val: int = int(dict.get("mant", 0))
	for i in range(mant_bits - 1, -1, -1):
		var b_ch: String = "1" if (mant_val & (1 << i)) != 0 else "0"
		var frac_idx: int = mant_bits - i
		specs.append({
			"bit": b_ch,
			"role": "mant",
			"role_label": "Mantissa",
			"tooltip": "Bit %d — Mantissa (Triângulo Dourado): bit %s (fração 2^-%d)" % [i, b_ch, frac_idx]
		})
	return specs


static func build_formula_breakdown_text(item: Node, config: Variant = null) -> String:
	var dt: int = int(item.data_type)
	if dt in [item.DataType.INT, item.DataType.SHORT_INT]:
		var bits: int = 32 if dt == item.DataType.INT else 16
		var v: int = int(item.value) if dt == item.DataType.INT else int(item.value_short)
		var s_bit: String = "1 (Negativo -)" if v < 0 else "0 (Positivo +)"
		var min_v: String = "-2.147.483.648" if bits == 32 else "-32.768"
		var max_v: String = "2.147.483.647" if bits == 32 else "32.767"
		return "[b]Estrutura Inteira (%d bits / %d Bytes):[/b]   [color=#ff6b72]• Sinal: %s[/color]   ·   [color=#b48cff]• Magnitude: %d bits[/color]   ·   Alcance do tipo: [b]%s a %s[/b]" % [
			bits, bits / 8, s_bit, bits - 1, min_v, max_v
		]
	if dt == item.DataType.BINARY:
		var b_str: String = str(item.value_binary)
		return "[b]Binário Puro (%d bit(s)):[/b]   [color=#b48cff]%s[/color]   →   Valor Decimal: [b]%d[/b]" % [b_str.length(), b_str, int(item.value)]

	var exp_bits: int = 8
	var mant_bits: int = 23
	var dict: Dictionary
	if dt == item.DataType.DOUBLE:
		exp_bits = 11
		mant_bits = 52
		dict = double_to_fp_bits(float(item.value_double))
	elif dt == item.DataType.FP8:
		exp_bits = int(item.fp_exp_bits) if int(item.fp_exp_bits) != -1 else cfg_int(config, "fp8_exp_bits", 4)
		mant_bits = int(item.fp_mant_bits) if int(item.fp_mant_bits) != -1 else cfg_int(config, "fp8_mant_bits", 3)
		dict = float_to_custom_fp_bits(float(item.value_float), exp_bits, mant_bits)
	elif dt == item.DataType.FP16:
		exp_bits = int(item.fp_exp_bits) if int(item.fp_exp_bits) != -1 else cfg_int(config, "fp16_exp_bits", 5)
		mant_bits = int(item.fp_mant_bits) if int(item.fp_mant_bits) != -1 else cfg_int(config, "fp16_mant_bits", 10)
		dict = float_to_custom_fp_bits(float(item.value_float), exp_bits, mant_bits)
	elif dt == item.DataType.RAW:
		var raw_v: float = float(item.value_float)
		var is_dec: bool = ("." in str(item.raw_literal)) or not is_equal_approx(raw_v, roundf(raw_v))
		if not is_dec and absf(raw_v) <= 2147483647.0:
			var fits_short: bool = absf(raw_v) <= 32767.0
			return "[b]Prévia Binária (Orbe sem tipo — RAW inteiro):[/b]   Cabe em [b]Short (2 Bytes)[/b]: %s   ·   Cabe em [b]Int (4 Bytes)[/b]: Sim" % [
				"Sim (≤ 32767)" if fits_short else "Não (> 32767, sofreria Overflow em Short!)"
			]
		dict = float_to_custom_fp_bits(raw_v, 8, 23)
	else:
		dict = float_to_custom_fp_bits(float(item.value_float), 8, 23)

	var bias: int = (1 << (exp_bits - 1)) - 1
	var max_exp: int = (1 << exp_bits) - 1
	var raw_exp: int = int(dict.get("exp", 0))
	var actual_exp: int = raw_exp - bias
	var sign_sym: String = "-" if int(dict.get("sign", 0)) != 0 else "+"
	var exp_desc: String = "%d (Expoente = %d − Viés %d)" % [actual_exp, raw_exp, bias]
	if raw_exp == max_exp:
		exp_desc = "TODOS 1s (%d) → INFINITO / NaN (Overflow)" % raw_exp
	elif raw_exp == 0:
		exp_desc = "TODOS 0s (0) → Zero / Subnormal"

	return "[b]Decodificação Ponto Flutuante:[/b]   [color=#ff6b72]• Sinal (1 bit): %s[/color]   |   [color=#4ce884]• Expoente (%d bits): %s[/color]   |   [color=#fca82a]• Mantissa (%d bits de precisão)[/color]" % [
		sign_sym, exp_bits, exp_desc, mant_bits
	]


static func analyze_item_effect(item: Node, config: Variant = null) -> Dictionary:
	var dt: int = int(item.data_type)
	var cur_val: float = float(item.get_numeric_value()) if item.has_method("get_numeric_value") else 0.0
	var has_src: bool = bool(item.get("has_source_value"))
	var src_val: float = float(item.source_value) if has_src else cur_val
	var deg_kind: String = str(item.get("degradation_kind")) if item.get("degradation_kind") != null else ""

	# 1. Verifica OVERFLOW
	var is_overflow: bool = deg_kind == "overflow" or is_inf(cur_val)
	if not is_overflow and has_src:
		if dt == item.DataType.SHORT_INT and (src_val > 32767.0 or src_val < -32768.0):
			is_overflow = true
		elif dt == item.DataType.INT and (src_val > 2147483647.0 or src_val < -2147483648.0):
			is_overflow = true

	if is_overflow:
		var msg: String = "[b]EFEITO DETECTADO NESTE ORBE: OVERFLOW (Estouro de Capacidade)[/b]\n"
		if dt in [item.DataType.SHORT_INT, item.DataType.INT]:
			var bits: int = 16 if dt == item.DataType.SHORT_INT else 32
			msg += "O valor original ([b]%s[/b]) excedeu o limite máximo de %d bits e invadiu o [b]Losango Vermelho (Bit de Sinal)[/b], fazendo o número dar a volta para [b]%s[/b]." % [
				String.num(src_val, 4), bits, OrbValueFormat.full_value_string(item)
			]
		else:
			msg += "O valor ([b]%s[/b]) ultrapassou o alcance máximo do tipo: todos os [b]Hexágonos Verdes (Expoente)[/b] ficaram em [b]1[/b], transformando o orbe em [b]Infinito (Inf)[/b]." % [
				String.num(src_val, 4)
			]
		return {"kind": "overflow", "bbcode": msg}

	# 2. Verifica UNDERFLOW
	var is_underflow: bool = deg_kind == "underflow" or (has_src and src_val != 0.0 and cur_val == 0.0 and dt in [item.DataType.FLOAT, item.DataType.DOUBLE, item.DataType.FP8, item.DataType.FP16])
	if is_underflow:
		var msg: String = "[b]EFEITO DETECTADO NESTE ORBE: UNDERFLOW (Colapso para Zero)[/b]\n"
		msg += "O valor original ([b]%s[/b]) era pequeno demais para o menor expoente negativo deste tipo. Todos os [b]Hexágonos Verdes (Expoente)[/b] e [b]Triângulos Dourados (Mantissa)[/b] zeraram, colapsando o valor para [b]0.0[/b]." % [
			String.num(src_val, 6)
		]
		return {"kind": "underflow", "bbcode": msg}

	# 3. Verifica APROXIMAÇÃO (Perda de Precisão / Truncamento / Quantização)
	var diff: float = absf(cur_val - src_val) if has_src else 0.0
	var is_precision: bool = deg_kind == "precision" or (has_src and diff > 1e-7)
	if not is_precision and dt in [item.DataType.FP8, item.DataType.FP16]:
		var e_b: int = (int(item.fp_exp_bits) if int(item.fp_exp_bits) != -1 else cfg_int(config, "fp8_exp_bits", 4)) if dt == item.DataType.FP8 else (int(item.fp_exp_bits) if int(item.fp_exp_bits) != -1 else cfg_int(config, "fp16_exp_bits", 5))
		var m_b: int = (int(item.fp_mant_bits) if int(item.fp_mant_bits) != -1 else cfg_int(config, "fp8_mant_bits", 3)) if dt == item.DataType.FP8 else (int(item.fp_mant_bits) if int(item.fp_mant_bits) != -1 else cfg_int(config, "fp16_mant_bits", 10))
		var d_fp: Dictionary = float_to_custom_fp_bits(cur_val, e_b, m_b)
		var recon: float = custom_fp_bits_to_float(int(d_fp.bits), e_b, m_b)
		if absf(recon - cur_val) > 1e-6:
			is_precision = true

	if is_precision:
		var msg: String = "[b]EFEITO DETECTADO NESTE ORBE: APROXIMAÇÃO (Perda de Precisão)[/b]\n"
		if dt in [item.DataType.INT, item.DataType.SHORT_INT] and has_src and src_val != floorf(src_val):
			msg += "Na conversão para inteiro, a parte decimal de [b]%s[/b] foi descartada (truncamento), restando apenas [b]%s[/b]." % [
				String.num(src_val, 6), OrbValueFormat.full_value_string(item)
			]
		else:
			msg += "Os [b]Triângulos Dourados (Mantissa)[/b] têm bits limitados e arredondaram o valor de [b]%s[/b] para a representação binária mais próxima: [b]%s[/b] (erro de %s)." % [
				String.num(src_val, 6), OrbValueFormat.full_value_string(item), String.num(diff, 6)
			]
		return {"kind": "precision", "bbcode": msg}

	# 4. Sem degradação ativa (Exato) — inclui dicas preventivas
	var ok_msg: String = "[b]DIAGNÓSTICO DESTE ORBE: Representação Estável (Sem Overflow / Underflow)[/b]\n"
	if dt == item.DataType.RAW:
		if absf(cur_val) > 32767.0:
			ok_msg += "Dica: como [b]%s[/b] > 32.767, colocá-lo em [b]Short (16 bits)[/b] causará [b]Overflow[/b]! Use [b]Int (32 bits)[/b] ou superior." % OrbValueFormat.full_value_string(item)
		elif ("." in str(item.raw_literal)) or not is_equal_approx(cur_val, roundf(cur_val)):
			ok_msg += "Dica: este valor possui parte decimal ([b]%s[/b]). Em [b]Int/Short[/b] perderia a fração; use [b]Float/Double/FP16[/b]." % OrbValueFormat.full_value_string(item)
		else:
			ok_msg += "Este valor cabe perfeitamente em tipos inteiros sem perda de precisão."
	else:
		ok_msg += "Os bits atuais de Sinal, Expoente/Magnitude e Mantissa representam o valor dentro dos limites do tipo."
	return {"kind": "exact", "bbcode": ok_msg}


static func int_to_bin_str(val: int, bits: int) -> String:
	var s: String = ""
	for i in range(bits - 1, -1, -1):
		s += "1" if (val & (1 << i)) != 0 else "0"
	return s


static func float_to_custom_fp_bits(val: float, exp_bits: int, mant_bits: int) -> Dictionary:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0, val)
	var f_bits: int = bytes.decode_u32(0)

	var sign_bit: int = (f_bits >> 31) & 1
	var f_exp: int = (f_bits >> 23) & 0xFF
	var f_mant: int = f_bits & 0x7FFFFF

	var tgt_bias: int = (1 << (exp_bits - 1)) - 1
	var tgt_exp: int = 0
	var tgt_mant: int = 0

	if f_exp == 0xFF:
		tgt_exp = (1 << exp_bits) - 1
		tgt_mant = 1 if f_mant != 0 else 0
	elif f_exp == 0:
		tgt_exp = 0
		tgt_mant = 0
	else:
		var actual_exp: int = f_exp - 127
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

	var combined_bits: int = (sign_bit << (exp_bits + mant_bits)) | (tgt_exp << mant_bits) | tgt_mant
	return {"sign": sign_bit, "exp": tgt_exp, "mant": tgt_mant, "bits": combined_bits}


static func custom_fp_bits_to_float(bits: int, exp_bits: int, mant_bits: int) -> float:
	var sign_bit: int = (bits >> (exp_bits + mant_bits)) & 1
	var tgt_exp: int = (bits >> mant_bits) & ((1 << exp_bits) - 1)
	var tgt_mant: int = bits & ((1 << mant_bits) - 1)
	var tgt_bias: int = (1 << (exp_bits - 1)) - 1

	var f_exp: int = 0
	var f_mant: int = 0

	if tgt_exp == ((1 << exp_bits) - 1):
		f_exp = 0xFF
		f_mant = 1 if tgt_mant != 0 else 0
	elif tgt_exp == 0:
		f_exp = 0
		f_mant = 0
	else:
		var actual_exp: int = tgt_exp - tgt_bias
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

	var f_bits: int = (sign_bit << 31) | (f_exp << 23) | f_mant
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, f_bits)
	return bytes.decode_float(0)


static func double_to_fp_bits(val: float) -> Dictionary:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, val)
	var f_bits: int = bytes.decode_u64(0)
	var sign_bit: int = (f_bits >> 63) & 1
	var f_exp: int = (f_bits >> 52) & 0x7FF
	var f_mant: int = f_bits & 0xFFFFFFFFFFFFF
	return {"sign": sign_bit, "exp": f_exp, "mant": f_mant}
