class_name PhaseScriptLog
extends RefCounted
## Diário didático de ações da fase → texto Aula / Python (Trace + Estado).

signal changed

var title: String = ""
var objective: String = ""
var events: Array[Dictionary] = []
## Entradas do estado atual: {name, py_value, type_label, bytes, where, note}
var state_entries: Array[Dictionary] = []
var needs_fp16_helper: bool = false
var needs_fp8_helper: bool = false
var needs_short_helper: bool = false
var needs_float32_helper: bool = false
var _var_counter: int = 0


func clear() -> void:
	events.clear()
	state_entries.clear()
	needs_fp16_helper = false
	needs_fp8_helper = false
	needs_short_helper = false
	needs_float32_helper = false
	_var_counter = 0
	changed.emit()


func set_header(p_title: String, p_objective: String = "") -> void:
	title = p_title
	objective = ReadableBbcode.strip_tags(p_objective) if p_objective != "" else ""
	changed.emit()


func next_var_name(prefix: String = "v") -> String:
	_var_counter += 1
	return "%s%d" % [prefix, _var_counter]


func push(kind: String, data: Dictionary = {}) -> void:
	var e: Dictionary = data.duplicate(true)
	e["kind"] = kind
	events.append(e)
	_note_helpers_from_event(e)
	changed.emit()


func set_state(entries: Array) -> void:
	state_entries.clear()
	for entry in entries:
		if entry is Dictionary:
			state_entries.append((entry as Dictionary).duplicate(true))
	changed.emit()


func _recompute_helpers() -> void:
	needs_fp8_helper = false
	needs_fp16_helper = false
	needs_short_helper = false
	needs_float32_helper = false
	for e in events:
		if _is_noise_event(e):
			continue
		_note_helpers_from_event(e)
	for entry in state_entries:
		# Bancada (RAW/sobras) não puxa helper; mochila e caixas de tipagem sim.
		if str(entry.get("where", "")) == "bancada":
			continue
		_note_helpers_from_type(str(entry.get("type_label", "")))


func render_aula() -> String:
	_recompute_helpers()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# Code Orbs — visão Aula (didática)")
	if title != "":
		lines.append("# Fase: %s" % title)
	lines.append_array(_header_objective_lines())
	lines.append("")
	lines.append("# --- passos ---")
	if events.is_empty():
		lines.append("# (ainda sem ações — mexa nos orbes)")
	else:
		var step := 0
		for e in events:
			if _is_noise_event(e):
				continue
			step += 1
			lines.append_array(_render_event_aula(step, e))
	lines.append("")
	lines.append("# --- estado ---")
	lines.append_array(_render_state_aula())
	return "\n".join(lines)


func render_python() -> String:
	_recompute_helpers()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# -*- coding: utf-8 -*-")
	lines.append("# Code Orbs — visão Python (o mais executável possível)")
	if title != "":
		lines.append("# Fase: %s" % title)
	lines.append_array(_header_objective_lines())
	lines.append("")
	if needs_fp8_helper or needs_fp16_helper or needs_short_helper:
		lines.append("# Helpers didáticos (não são tipos nativos do Python)")
		if needs_short_helper:
			lines.append("def as_short(x):")
			lines.append("    \"\"\"int16 com wraparound (complemento de 2), como no Code Orbs.\"\"\"")
			lines.append("    return (int(x) + 32768) % 65536 - 32768")
			lines.append("")
		if needs_fp8_helper:
			lines.append("def as_fp8(x):")
			lines.append("    \"\"\"Valor já quantizado como FP8 no jogo.\"\"\"")
			lines.append("    return float(x)")
			lines.append("")
		if needs_fp16_helper:
			lines.append("def as_fp16(x):")
			lines.append("    \"\"\"Valor já quantizado como FP16 no jogo.\"\"\"")
			lines.append("    return float(x)")
			lines.append("")
	lines.append("# --- passos ---")
	if events.is_empty():
		lines.append("# (ainda sem ações)")
	else:
		var step := 0
		for e in events:
			if _is_noise_event(e):
				continue
			step += 1
			lines.append_array(_render_event_python(step, e))
	lines.append("")
	lines.append("# --- estado ---")
	lines.append_array(_render_state_python())
	return "\n".join(lines)


func render_executar() -> String:
	_recompute_helpers()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# -*- coding: utf-8 -*-")
	lines.append("# Code Orbs — Executar (lógica numérica das ações; não a UI do jogo)")
	if title != "":
		lines.append("# Fase: %s" % title)
	lines.append("# Rode com: python este_arquivo.py")
	lines.append("")
	var need_struct := needs_float32_helper
	if need_struct or needs_short_helper or needs_fp8_helper or needs_fp16_helper:
		if need_struct:
			lines.append("import struct")
			lines.append("")
		if needs_short_helper:
			lines.append("def as_short(x):")
			lines.append("    \"\"\"int16 com wraparound (complemento de 2), como no Code Orbs.\"\"\"")
			lines.append("    return (int(x) + 32768) % 65536 - 32768")
			lines.append("")
		if needs_float32_helper:
			lines.append("def as_float32(x):")
			lines.append("    \"\"\"IEEE float32 (4 bytes).\"\"\"")
			lines.append("    return struct.unpack('f', struct.pack('f', float(x)))[0]")
			lines.append("")
		if needs_fp8_helper:
			lines.append("def as_fp8(x):")
			lines.append("    \"\"\"Aproximação FP8 (sem IEEE completo).\"\"\"")
			lines.append("    return float(x)")
			lines.append("")
		if needs_fp16_helper:
			lines.append("def as_fp16(x):")
			lines.append("    \"\"\"Aproximação FP16 (sem IEEE completo).\"\"\"")
			lines.append("    return float(x)")
			lines.append("")
	var meaningful := 0
	for e in events:
		if _is_noise_event(e):
			continue
		if str(e.get("kind", "")) == "phase_start":
			continue
		meaningful += 1
		lines.append_array(_render_event_executar(e))
	if meaningful == 0:
		lines.append("print('sem ações ainda')")
		return "\n".join(lines)
	lines.append("")
	lines.append("print('--- estado ---')")
	var printed := 0
	for entry in state_entries:
		# Executar imprime só a mochila (bancada RAW não é resultado da tipagem).
		if str(entry.get("where", "")) != "mochila":
			continue
		var nm := str(entry.get("name", "x"))
		var typ := str(entry.get("type_label", ""))
		var val := str(entry.get("py_value", ""))
		# Se a variável ainda não apareceu nos passos, materializa a partir do estado.
		if not _name_assigned_in_events(nm):
			lines.append("%s = %s" % [nm, _wrap_exec_value(typ, val)])
		lines.append("print('%s =', %s)" % [nm, nm])
		printed += 1
	if printed == 0:
		lines.append("print('(vazio)')")
	return "\n".join(lines)


func _name_assigned_in_events(nm: String) -> bool:
	for e in events:
		if _is_noise_event(e):
			continue
		var kind := str(e.get("kind", ""))
		if kind in ["assign", "move", "cast", "binop"] and str(e.get("name", "")) == nm:
			return true
	return false


static func type_label_for_item(item: Node) -> String:
	if item == null or not is_instance_valid(item):
		return "?"
	if item.get("data_type") == null:
		return "?"
	match int(item.data_type):
		item.DataType.RAW:
			return "RAW"
		item.DataType.BINARY:
			return "Binary"
		item.DataType.SHORT_INT:
			return "Short"
		_:
			return TypeConversionSystem.get_type_string(item.data_type)


static func py_value_for_item(item: Node) -> String:
	if item == null or not is_instance_valid(item):
		return "None"
	return OrbValueFormat.python_repr_string(item)


static func bytes_for_item(item: Node) -> int:
	if item == null or not is_instance_valid(item):
		return 0
	if item.has_method("get_size_bytes"):
		return int(item.get_size_bytes())
	return 0


static func bytes_for_type_label(type_label: String) -> int:
	match type_label.strip_edges():
		"Double":
			return 8
		"Short", "FP16":
			return 2
		"FP8":
			return 1
		"RAW", "Binary":
			return 0
		_:
			return 4


func _header_objective_lines() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if objective.strip_edges() == "":
		return out
	var plain := objective.strip_edges().replace("\r", "")
	# Preserva parágrafos; cada linha vira comentário(s) quebrado(s).
	var paras := plain.split("\n", false)
	var first := true
	for para in paras:
		var p := str(para).strip_edges()
		if p.is_empty():
			continue
		var prefix := "Objetivo: " if first else "          "
		first = false
		out.append_array(_wrap_comment(prefix + p, 88))
	return out


func _wrap_comment(text: String, width: int = 88) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var words := text.split(" ", false)
	var cur := ""
	for w in words:
		var candidate := w if cur.is_empty() else cur + " " + w
		if cur != "" and candidate.length() > width:
			out.append("# " + cur)
			cur = w
		else:
			cur = candidate
	if cur != "":
		out.append("# " + cur)
	return out


func _cast_how_lines_aula(fr: String, to: String, before: String, after: String, warn: String, deg_kind: String, from_b: int, to_b: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("#    De:   %s (%d byte(s))  valor = %s" % [fr, from_b, before])
	lines.append("#    Para: %s (%d byte(s))  valor = %s" % [to, to_b, after])
	var how := _cast_how_explanation(fr, to, before, after, deg_kind, warn)
	if how != "":
		lines.append("#    Como: %s" % how)
	if from_b != to_b and from_b > 0 and to_b > 0:
		lines.append("#    Memória: %d → %d byte(s) (diferença %d)" % [from_b, to_b, to_b - from_b])
	return lines


func _binop_promotion_line(a_t: String, b_t: String, rt: String) -> String:
	if a_t == "" or b_t == "":
		return "resultado tipado como %s" % rt
	if a_t == b_t:
		return "operandos do mesmo tipo (%s); resultado permanece %s" % [a_t, rt]
	return "promoção automática: entre %s e %s vence o tipo mais forte → %s" % [a_t, b_t, rt]


func _values_numerically_equal(a: String, b: String) -> bool:
	if a == b:
		return true
	if _is_nonfinite_literal(a) or _is_nonfinite_literal(b):
		return _normalize_nonfinite(a) == _normalize_nonfinite(b) and _normalize_nonfinite(a) != ""
	if a.is_valid_float() and b.is_valid_float():
		return is_equal_approx(a.to_float(), b.to_float())
	return false


func _is_nonfinite_literal(s: String) -> bool:
	var t := s.strip_edges().to_lower()
	return t in ["inf", "+inf", "-inf", "infinity", "-infinity", "nan"]


func _normalize_nonfinite(s: String) -> String:
	var t := s.strip_edges().to_lower()
	if t in ["inf", "+inf", "infinity"]:
		return "inf"
	if t in ["-inf", "-infinity"]:
		return "-inf"
	if t == "nan":
		return "nan"
	return ""


## Literal seguro para CPython (inf/nan crus não existem como nome).
func _py_literal(s: String) -> String:
	var t := s.strip_edges()
	var n := _normalize_nonfinite(t)
	match n:
		"inf":
			return "float('inf')"
		"-inf":
			return "float('-inf')"
		"nan":
			return "float('nan')"
		_:
			return t


func _cast_how_explanation(fr: String, to: String, before: String, after: String, deg_kind: String, warn: String) -> String:
	var kind := deg_kind.to_lower()
	var same_value := _values_numerically_equal(before, after)
	var has_precision_warn := "Perda de precisão" in warn or "precision" in kind
	# Overflow / underflow / absorção primeiro (mensagem do jogo).
	if "overflow" in kind or warn.begins_with("Overflow"):
		if _is_nonfinite_literal(after) or to in ["FP8", "FP16", "Float", "Double"]:
			return "overflow — excede o limite do formato de ponto flutuante e vira Inf/não-finito (%s → %s)" % [before, after]
		if fr in ["Float", "Double", "FP8", "FP16"] and to in ["Int", "Short"]:
			return "overflow — valor fora da faixa inteira / não-finito; o jogo degrada (%s → %s)" % [before, after]
		return "overflow — o valor não cabe no destino; no jogo dá a volta em complemento de 2 (%s → %s)" % [before, after]
	if "underflow" in kind or warn.begins_with("Underflow"):
		return "underflow — valor pequeno demais para o formato; vira ~0 (%s → %s)" % [before, after]
	if "absorption" in kind:
		return "absorção de mantissa — bits de precisão insuficientes (%s → %s)" % [before, after]
	# FP8/FP16: quantização de mantissa/expoente — NÃO é int(x).
	if to in ["FP8", "FP16"]:
		if has_precision_warn or not same_value:
			return "quantização para %s (mantissa/expoente curtos) — arredonda para o valor representável (%s → %s)" % [to, before, after]
		if _is_nonfinite_literal(before):
			return "preserva não-finito ao quantizar para %s (%s)" % [to, after]
		return "quantização para %s sem perda visível; %s cabe no formato" % [to, before]
	# Float32 a partir de Double com perda de precisão.
	if fr == "Double" and to == "Float":
		if same_value:
			return "estreitamento sem perda — Double (64 bits) → Float (32 bits); %s ainda cabe exatamente no Float" % before
		return "estreitamento Double → Float: mantissa de 23 bits arredonda (%s → %s)" % [before, after]
	if fr == "Float" and to == "Double":
		return "promoção Float → Double (mais bits de precisão; valor %s)" % after
	# Truncamento inteiro de verdade (float/fp → Int/Short).
	if to in ["Int", "Short"] and fr in ["Float", "Double", "FP8", "FP16"]:
		if same_value:
			return "cast para inteiro sem perda — valor já era inteiro exato (%s → %s)" % [before, after]
		if "trunc" in kind or "Perda de precisão" in warn or "parte decimal" in warn.to_lower() or not same_value:
			return "truncamento — descarta a parte decimal (%s → %s), como int(x) em Python" % [before, after]
		return "cast para inteiro (%s → %s)" % [before, after]
	if "trunc" in kind or ("precision" in kind and to in ["Int", "Short"]):
		return "truncamento — descarta a parte decimal (%s → %s), como int(x) em Python" % [before, after]
	if fr == "Int" and to == "Short":
		if same_value:
			return "estreitamento sem perda — Int (4 bytes) → Short (2 bytes); %s cabe em 16 bits" % before
		return "estreitamento Int → Short (%s → %s)" % [before, after]
	if fr == "Short" and to == "Int":
		return "promoção Short → Int (2 → 4 bytes); valor %s" % after
	if to in ["Float", "Double"] and fr in ["Int", "Short"]:
		return "promoção para ponto flutuante (%s → %s)" % [before, after]
	if same_value:
		return "mudança de representação %s → %s sem alterar o valor (%s)" % [fr, to, before]
	return "converter de %s para %s (%s → %s)" % [fr, to, before, after]


static func state_entry_from_item(item: Node, var_name: String, where: String, note: String = "") -> Dictionary:
	return {
		"name": var_name,
		"py_value": py_value_for_item(item),
		"type_label": type_label_for_item(item),
		"bytes": bytes_for_item(item),
		"where": where,
		"note": note,
	}


## Nome estável por valor+tipo (Trace e Estado batem mesmo após pack/reordenar).
static func stable_var_name_for_item(item: Node, prefix: String = "") -> String:
	var typ := type_label_for_item(item).to_lower().replace(" ", "_")
	var raw := py_value_for_item(item)
	var val := str(raw).replace(".", "p").replace("-", "n").replace("+", "")
	val = val.replace(" ", "")
	# Sempre separa com "_": evita fp16__3… (tipo terminado em dígito) e prefix_fp163…
	if prefix != "":
		return "%s_%s_%s" % [prefix, typ, val]
	return "%s_%s" % [typ, val]


func _is_noise_event(e: Dictionary) -> bool:
	var kind := str(e.get("kind", ""))
	if kind == "move":
		var src := str(e.get("src", ""))
		var dest := str(e.get("dest", ""))
		if src == dest:
			return true
		if src == "inspetor" or dest == "inspetor":
			return true
		# Tirar da mochila de volta à bancada = tentativa/undo, não entra no script didático.
		if src == "mochila" and dest == "bancada":
			return true
		# Pack na mochila que não sobreviveu no estado final (tentativa tipada e desfeita).
		if dest == "mochila" and not _matches_mochila_value_type(e):
			return true
		# Já tipou/declarou o mesmo binding: o move só empacota — não redeclara.
		if dest == "mochila" and _has_matching_assign(e):
			return true
		return false
	if kind == "assign":
		# Declaração/tipagem que não está na mochila = tentativa abandonada.
		if not _matches_mochila_value_type(e):
			return true
		return false
	if kind == "cast":
		return str(e.get("from_type", "")).to_lower() == str(e.get("to_type", "")).to_lower()
	return false


func _has_matching_assign(e: Dictionary) -> bool:
	var typ := str(e.get("type", ""))
	var val := str(e.get("py_value", ""))
	var nm := str(e.get("name", ""))
	for other in events:
		if str(other.get("kind", "")) != "assign":
			continue
		# Evita comparar com assigns que também seriam filtrados do estado.
		if not _matches_mochila_value_type(other):
			continue
		if nm != "" and str(other.get("name", "")) == nm:
			return true
		if str(other.get("type", "")) == typ and str(other.get("py_value", "")) == val:
			return true
	return false


func _mochila_value_type_keys() -> Dictionary:
	var keys: Dictionary = {}
	for entry in state_entries:
		if str(entry.get("where", "")) != "mochila":
			continue
		var typ := str(entry.get("type_label", ""))
		var val := str(entry.get("py_value", ""))
		keys["%s|%s" % [typ, val]] = true
		# Também aceita igualdade numérica frouxa (15 vs 15.0).
		if val.is_valid_float():
			keys["%s|#%s" % [typ, str(val.to_float())]] = true
	return keys


func _matches_mochila_value_type(e: Dictionary) -> bool:
	var keys := _mochila_value_type_keys()
	# Sem orbes na mochila ainda: não filtra (senão some tudo no começo da fase).
	if keys.is_empty():
		return true
	var typ := str(e.get("type", ""))
	var val := str(e.get("py_value", ""))
	if keys.has("%s|%s" % [typ, val]):
		return true
	if val.is_valid_float() and keys.has("%s|#%s" % [typ, str(val.to_float())]):
		return true
	return false


func _note_helpers_from_event(e: Dictionary) -> void:
	_note_helpers_from_type(str(e.get("type", "")))
	_note_helpers_from_type(str(e.get("to_type", "")))
	_note_helpers_from_type(str(e.get("result_type", "")))
	_note_helpers_from_type(str(e.get("a_type", "")))
	_note_helpers_from_type(str(e.get("b_type", "")))
	_note_helpers_from_type(str(e.get("from_type", "")))


func _note_helpers_from_type(t: String) -> void:
	var u := t.to_upper()
	if u == "FP16" or t == "FP16":
		needs_fp16_helper = true
	elif u == "FP8" or t == "FP8":
		needs_fp8_helper = true
	elif u == "SHORT" or t == "Short":
		needs_short_helper = true
	elif u == "FLOAT" or t == "Float":
		needs_float32_helper = true


func _wrap_py_value(type_label: String, py_value: String) -> String:
	var lit := _py_literal(py_value)
	match type_label:
		"FP16":
			return "as_fp16(%s)" % lit
		"FP8":
			return "as_fp8(%s)" % lit
		"Short":
			return "as_short(%s)" % lit
		_:
			return lit


func _wrap_exec_value(type_label: String, py_value: String) -> String:
	var lit := _py_literal(py_value)
	match type_label:
		"FP16":
			return "as_fp16(%s)" % lit
		"FP8":
			return "as_fp8(%s)" % lit
		"Short":
			return "as_short(%s)" % lit
		"Float":
			return "as_float32(%s)" % lit
		_:
			return lit


func _render_event_executar(e: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var kind := str(e.get("kind", ""))
	match kind:
		"assign", "move":
			var nm := str(e.get("name", "x"))
			var typ := str(e.get("type", ""))
			var val := str(e.get("py_value", ""))
			lines.append("%s = %s" % [nm, _wrap_exec_value(typ, val)])
		"cast":
			var nm3 := str(e.get("name", "x"))
			var fr_p := str(e.get("from_type", ""))
			var to := str(e.get("to_type", ""))
			var after := str(e.get("after", ""))
			var before := str(e.get("before", ""))
			var warn := str(e.get("warning", ""))
			lines.append("%s = %s" % [nm3, _wrap_exec_value(fr_p, before)])
			if to in ["Int", "Short"] and fr_p in ["Float", "Double", "FP8", "FP16"]:
				# int(inf)/int(nan) estoura no CPython — usa o valor já degradado pelo jogo.
				if _is_nonfinite_literal(before) or _is_nonfinite_literal(after):
					lines.append("%s = %s" % [nm3, _py_literal(after)])
					if to == "Short":
						lines.append("%s = as_short(%s)" % [nm3, nm3])
				else:
					lines.append("%s = int(%s)" % [nm3, nm3])
					if to == "Short":
						lines.append("%s = as_short(%s)" % [nm3, nm3])
			elif to == "Short" and fr_p == "Int":
				lines.append("%s = as_short(%s)" % [nm3, nm3])
			elif to == "Int" and fr_p == "Short":
				lines.append("%s = int(%s)" % [nm3, nm3])
			elif to == "Float":
				lines.append("%s = as_float32(%s)" % [nm3, nm3])
			elif to == "Double":
				lines.append("%s = float(%s)" % [nm3, nm3])
			elif to in ["FP8", "FP16"]:
				lines.append("%s = %s" % [nm3, _wrap_exec_value(to, after)])
			else:
				lines.append("%s = %s" % [nm3, _wrap_exec_value(to, after)])
			if warn != "":
				lines.append("# aviso: %s" % warn)
		"binop":
			var a := str(e.get("a", "0"))
			var bop := str(e.get("b", "0"))
			var op := str(e.get("op", "+"))
			var res := str(e.get("result", "0"))
			var rt := str(e.get("result_type", ""))
			var nm4 := str(e.get("name", "r"))
			var a_t := str(e.get("a_type", ""))
			var b_t := str(e.get("b_type", ""))
			var warn2 := str(e.get("warning", ""))
			var a_expr := _wrap_exec_value(a_t, a) if a_t != "" else a
			var b_expr := _wrap_exec_value(b_t, bop) if b_t != "" else bop
			lines.append("%s = %s %s %s" % [nm4, a_expr, op, b_expr])
			if rt == "Float":
				lines.append("%s = as_float32(%s)" % [nm4, nm4])
			elif rt == "Short":
				lines.append("%s = as_short(%s)" % [nm4, nm4])
			elif rt in ["FP8", "FP16"]:
				lines.append("%s = %s" % [nm4, _wrap_exec_value(rt, res)])
			if warn2 != "":
				lines.append("# aviso: %s" % warn2)
		"bit_place":
			var full := str(e.get("full_binary", "0"))
			var dec := int(e.get("decimal", 0))
			lines.append("bits = 0b%s" % full)
			lines.append("assert int(bits) == %d" % dec)
		"binary_challenge":
			var dec2 := int(e.get("decimal", 0))
			var bits_n := int(e.get("num_bits", 0))
			var got := str(e.get("binary", ""))
			lines.append("n = %d" % dec2)
			lines.append("bits = format(n, '0%db')" % bits_n)
			lines.append("assert bits == '%s'" % got)
		"warning":
			lines.append("# aviso: %s" % str(e.get("message", "")))
		_:
			pass
	if not lines.is_empty():
		lines.append("")
	return lines


func _render_event_aula(step: int, e: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var kind := str(e.get("kind", ""))
	match kind:
		"phase_start":
			lines.append("# %d. Início da fase" % step)
		"assign":
			var where := str(e.get("where", ""))
			var typ := str(e.get("type", ""))
			var val := str(e.get("py_value", ""))
			var b := int(e.get("bytes", 0))
			var nm := str(e.get("name", "x"))
			lines.append("# %d. Tipou %s como %s (%s)" % [step, val, typ, where])
			if b > 0:
				lines.append("%s = %s  # %s, %d byte(s)" % [nm, _py_literal(val), typ, b])
			else:
				lines.append("%s = %s  # %s" % [nm, _py_literal(val), typ])
		"move":
			var dest := str(e.get("dest", ""))
			var val2 := str(e.get("py_value", ""))
			var typ2 := str(e.get("type", ""))
			var b2 := int(e.get("bytes", 0))
			var nm2 := str(e.get("name", "x"))
			var src := str(e.get("src", ""))
			lines.append("# %d. Moveu %s (%s) de %s → %s" % [step, val2, typ2, src, dest])
			lines.append("%s = %s  # %s, %d byte(s) → %s" % [nm2, _py_literal(val2), typ2, b2, dest])
		"cast":
			var fr := str(e.get("from_type", ""))
			var to := str(e.get("to_type", ""))
			var before := str(e.get("before", ""))
			var after := str(e.get("after", ""))
			var nm3 := str(e.get("name", "x"))
			var warn := str(e.get("warning", ""))
			var deg_kind := str(e.get("deg_kind", ""))
			var from_b := int(e.get("from_bytes", bytes_for_type_label(fr)))
			var to_b := int(e.get("to_bytes", bytes_for_type_label(to)))
			lines.append("# %d. Conversão no Conversor: %s → %s" % [step, fr, to])
			lines.append_array(_cast_how_lines_aula(fr, to, before, after, warn, deg_kind, from_b, to_b))
			lines.append("%s = %s  # %s, %d byte(s)" % [nm3, _py_literal(before), fr, from_b])
			lines.append("%s = %s  # %s, %d byte(s) após conversão" % [nm3, _py_literal(after), to, to_b])
			if warn != "":
				lines.append("# aviso do jogo: %s" % warn)
		"binop":
			var a := str(e.get("a", ""))
			var bop := str(e.get("b", ""))
			var op := str(e.get("op", "+"))
			var res := str(e.get("result", ""))
			var rt := str(e.get("result_type", ""))
			var nm4 := str(e.get("name", "r"))
			var a_t := str(e.get("a_type", ""))
			var b_t := str(e.get("b_type", ""))
			var a_b := int(e.get("a_bytes", bytes_for_type_label(a_t)))
			var b_b := int(e.get("b_bytes", bytes_for_type_label(b_t)))
			var r_b := int(e.get("result_bytes", bytes_for_type_label(rt)))
			lines.append("# %d. Calculadora: %s %s %s → %s" % [step, a, op, bop, res])
			if a_t != "":
				lines.append("#    Operando A: %s (%s, %d byte(s))" % [a, a_t, a_b])
			if b_t != "":
				lines.append("#    Operando B: %s (%s, %d byte(s))" % [bop, b_t, b_b])
			lines.append("#    %s" % _binop_promotion_line(a_t, b_t, rt))
			var warn2 := str(e.get("warning", ""))
			if "absor" in warn2.to_lower() or "absorption" in str(e.get("deg_kind", "")).to_lower():
				lines.append("#    Como: absorção de mantissa — em %s, %s %s %s ≈ %s (o termo menor some)" % [rt, a, op, bop, res])
			lines.append("#    Resultado: %s (%s, %d byte(s))" % [res, rt, r_b])
			lines.append("%s = %s %s %s  # %s, %d byte(s)" % [nm4, a, op, bop, rt, r_b])
			if warn2 != "":
				lines.append("# aviso do jogo: %s" % warn2)
		"bit_place":
			var bit := str(e.get("bit", ""))
			var full := str(e.get("full_binary", ""))
			var dec := int(e.get("decimal", 0))
			lines.append("# %d. Colocou bit %s → padrão %s (= %d)" % [step, bit, full, dec])
			lines.append("bits = 0b%s  # %d" % [full, dec])
		"binary_challenge":
			var dec2 := int(e.get("decimal", 0))
			var bits_n := int(e.get("num_bits", 0))
			var got := str(e.get("binary", ""))
			lines.append("# %d. Conversão decimal→binário: %d em %d bits → %s" % [step, dec2, bits_n, got])
			lines.append("n = %d" % dec2)
			lines.append("bits = format(n, \"0%db\")  # '%s'" % [bits_n, got])
		"warning":
			lines.append("# %d. Aviso: %s" % [step, str(e.get("message", ""))])
		_:
			lines.append("# %d. %s %s" % [step, kind, str(e)])
	return lines


func _render_event_python(step: int, e: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var kind := str(e.get("kind", ""))
	match kind:
		"phase_start":
			lines.append("# passo %d: início" % step)
		"assign":
			var nm := str(e.get("name", "x"))
			var typ := str(e.get("type", ""))
			var val := str(e.get("py_value", ""))
			var wrapped := _wrap_py_value(typ, val)
			lines.append("%s = %s  # %s" % [nm, wrapped, typ])
		"move":
			var nm_m := str(e.get("name", "x"))
			var typ_m := str(e.get("type", ""))
			var val_m := str(e.get("py_value", ""))
			var src_m := str(e.get("src", ""))
			var dest_m := str(e.get("dest", e.get("where", "")))
			var wrapped_m := _wrap_py_value(typ_m, val_m)
			lines.append("# passo %d: mover %s → %s" % [step, src_m, dest_m])
			lines.append("%s = %s  # %s" % [nm_m, wrapped_m, typ_m])
		"cast":
			var nm3 := str(e.get("name", "x"))
			var fr_p := str(e.get("from_type", ""))
			var to := str(e.get("to_type", ""))
			var after := str(e.get("after", ""))
			var before := str(e.get("before", ""))
			var warn := str(e.get("warning", ""))
			var deg_kind := str(e.get("deg_kind", ""))
			var from_b := int(e.get("from_bytes", bytes_for_type_label(fr_p)))
			var to_b := int(e.get("to_bytes", bytes_for_type_label(to)))
			var how := _cast_how_explanation(fr_p, to, before, after, deg_kind, warn)
			lines.append("# passo %d: conversão %s → %s" % [step, fr_p, to])
			if how != "":
				lines.append("# como: %s" % how)
			lines.append("%s = %s  # %s, %d byte(s)" % [nm3, _py_literal(before), fr_p, from_b])
			if to in ["Int", "Short"] and fr_p in ["Float", "Double", "FP8", "FP16"]:
				if _is_nonfinite_literal(before) or _is_nonfinite_literal(after):
					lines.append("%s = %s  # jogo degradou não-finito → %s" % [nm3, _py_literal(after), after])
					if to == "Short":
						lines.append("%s = as_short(%s)  # Short, %d byte(s)" % [nm3, after, to_b])
				else:
					# Float/Double → inteiro: mostra int() (truncamento).
					lines.append("%s = int(%s)  # → %s" % [nm3, _py_literal(before), after])
					if to == "Short":
						lines.append("%s = as_short(%s)  # Short, %d byte(s)" % [nm3, after, to_b])
			elif to == "Short" and fr_p == "Int":
				lines.append("%s = as_short(%s)  # Int → Short, %d byte(s)" % [nm3, after, to_b])
			elif to == "Int" and fr_p == "Short":
				lines.append("%s = int(%s)  # Short → Int, %d byte(s)" % [nm3, after, to_b])
			elif to in ["FP8", "FP16"]:
				lines.append("%s = %s  # %s, %d byte(s)" % [nm3, _wrap_py_value(to, after), to, to_b])
			elif to == "Float" and fr_p == "Double":
				lines.append("%s = float(%s)  # Double → Float (32 bits), %d byte(s)" % [nm3, _py_literal(before), to_b])
			elif to == "Double" and fr_p == "Float":
				lines.append("%s = float(%s)  # Float → Double, %d byte(s)" % [nm3, _py_literal(before), to_b])
			else:
				lines.append("%s = %s  # %s, %d byte(s)" % [nm3, _wrap_py_value(to, after), to, to_b])
			if warn != "":
				lines.append("# Code Orbs aviso: %s" % warn)
		"binop":
			var a := str(e.get("a", "0"))
			var bop := str(e.get("b", "0"))
			var op := str(e.get("op", "+"))
			var res := str(e.get("result", "0"))
			var rt := str(e.get("result_type", ""))
			var nm4 := str(e.get("name", "r"))
			var a_t := str(e.get("a_type", ""))
			var b_t := str(e.get("b_type", ""))
			var r_b := int(e.get("result_bytes", bytes_for_type_label(rt)))
			lines.append("# passo %d: calculadora %s %s %s" % [step, a, op, bop])
			lines.append("# %s" % _binop_promotion_line(a_t, b_t, rt))
			var warn2 := str(e.get("warning", ""))
			if "absor" in warn2.to_lower() or "absorption" in str(e.get("deg_kind", "")).to_lower():
				lines.append("# absorção de mantissa: em %s, %s %s %s ≈ %s" % [rt, a, op, bop, res])
			if a_t != "":
				lines.append("a = %s  # %s" % [_wrap_py_value(a_t, a), a_t])
			if b_t != "":
				lines.append("b = %s  # %s" % [_wrap_py_value(b_t, bop), b_t])
			if a_t != "" and b_t != "":
				if rt == "Short":
					lines.append("%s = as_short(a %s b)  # → %s (%s, %d byte(s))" % [nm4, op, res, rt, r_b])
				else:
					lines.append("%s = a %s b  # → %s (%s, %d byte(s))" % [nm4, op, _wrap_py_value(rt, res), rt, r_b])
			else:
				if rt == "Short":
					lines.append("%s = as_short(%s %s %s)  # → %s (%s)" % [nm4, _py_literal(a), op, _py_literal(bop), res, rt])
				else:
					lines.append("%s = %s %s %s  # → %s (%s)" % [nm4, _py_literal(a), op, _py_literal(bop), _wrap_py_value(rt, res), rt])
			if warn2 != "":
				lines.append("# Code Orbs aviso: %s" % warn2)
		"bit_place":
			var full := str(e.get("full_binary", "0"))
			var dec := int(e.get("decimal", 0))
			lines.append("bits = 0b%s  # %d" % [full, dec])
		"binary_challenge":
			var dec2 := int(e.get("decimal", 0))
			var bits_n := int(e.get("num_bits", 0))
			var got := str(e.get("binary", ""))
			lines.append("n = %d" % dec2)
			lines.append("bits = format(n, \"0%db\")  # %s" % [bits_n, got])
			lines.append("assert bits == \"%s\"" % got)
		"warning":
			lines.append("# Code Orbs aviso: %s" % str(e.get("message", "")))
		_:
			lines.append("# passo %d: %s" % [step, kind])
	return lines


func _render_state_aula() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if state_entries.is_empty():
		lines.append("# (estado vazio)")
		return lines
	var total_bytes := 0
	var mochila_bytes := 0
	for e in state_entries:
		var nm := str(e.get("name", "x"))
		var val := str(e.get("py_value", ""))
		var typ := str(e.get("type_label", ""))
		var b := int(e.get("bytes", 0))
		var where := str(e.get("where", ""))
		var note := str(e.get("note", ""))
		total_bytes += b
		if where == "mochila":
			mochila_bytes += b
		var extra := ""
		if note != "":
			extra = " — %s" % note
		if b > 0:
			lines.append("%s = %s  # %s, %d byte(s) @ %s%s" % [nm, _py_literal(val), typ, b, where, extra])
		else:
			lines.append("%s = %s  # %s @ %s%s" % [nm, _py_literal(val), typ, where, extra])
	if mochila_bytes > 0:
		lines.append("# layout mochila: %d byte(s)" % mochila_bytes)
	elif total_bytes > 0:
		lines.append("# layout aproximado: %d byte(s) somados" % total_bytes)
	return lines


func _render_state_python() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if state_entries.is_empty():
		lines.append("# (estado vazio)")
		return lines
	var total_bytes := 0
	var mochila_bytes := 0
	for e in state_entries:
		var nm := str(e.get("name", "x"))
		var val := str(e.get("py_value", ""))
		var typ := str(e.get("type_label", ""))
		var b := int(e.get("bytes", 0))
		var where := str(e.get("where", ""))
		total_bytes += b
		if where == "mochila":
			mochila_bytes += b
		lines.append("%s = %s  # %s @ %s" % [nm, _wrap_py_value(typ, val), typ, where])
	if mochila_bytes > 0:
		lines.append("# Code Orbs layout mochila: %d byte(s)" % mochila_bytes)
	elif total_bytes > 0:
		lines.append("# Code Orbs layout: %d byte(s)" % total_bytes)
	return lines
