class_name PhaseScriptLog
extends RefCounted
## Registro de ações da fase → código Python (NumPy) mínimo representando o que foi feito.

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


func to_dict() -> Dictionary:
	return {
		"title": title,
		"objective": objective,
		"events": events.duplicate(true),
		"state_entries": state_entries.duplicate(true),
		"aula": render_aula(),
		"python": render_python(),
		"executar": render_executar(),
	}


static func from_dict(d: Dictionary) -> PhaseScriptLog:
	var log_obj := PhaseScriptLog.new()
	log_obj.title = str(d.get("title", ""))
	log_obj.objective = str(d.get("objective", ""))
	var evs = d.get("events", [])
	if evs is Array:
		for e in evs:
			if e is Dictionary:
				log_obj.events.append((e as Dictionary).duplicate(true))
	var ses = d.get("state_entries", [])
	if ses is Array:
		for se in ses:
			if se is Dictionary:
				log_obj.state_entries.append((se as Dictionary).duplicate(true))
	log_obj._recompute_helpers()
	return log_obj


## Reconstrói um PhaseScriptLog a partir da configuração da fase (fallback para saves antigos).
static func build_fallback_from_step(phase_num: int, p_title: String, step: PhaseSequenceStep = null) -> PhaseScriptLog:
	var log_obj := PhaseScriptLog.new()
	var eff_title := p_title if p_title != "" else ("Fase %02d" % phase_num)
	log_obj.set_header(eff_title, "")
	if step != null:
		var csv := ""
		if step.kind == PhaseSequenceStep.Kind.MOCHILA and step.config_mochila != null:
			csv = step.config_mochila.star3_best_solution_csv.strip_edges()
			if csv == "":
				csv = step.config_mochila.initial_backpack_csv.strip_edges()
		elif step.kind == PhaseSequenceStep.Kind.RAW_MOCHILA and step.config_raw_mochila != null:
			csv = step.config_raw_mochila.star3_best_solution_csv.strip_edges()
		elif step.kind == PhaseSequenceStep.Kind.TYPE_BOX and step.config_type_box != null:
			var raws := step.config_type_box.initial_raw_values
			var exps := step.config_type_box.expected_solution_types
			var entries_tb: Array = []
			for i in range(raws.size()):
				var val_s := str(raws[i]).strip_edges().trim_suffix("_r")
				var t_lbl := "Float" if "." in val_s else "Int"
				if i < exps.size():
					t_lbl = _normalize_type_tag(str(exps[i]))
				var vname := "%s%d" % [t_lbl.to_lower(), i + 1]
				var b := bytes_for_type_label(t_lbl)
				log_obj.push("assign", {
					"name": vname,
					"py_value": val_s,
					"type": t_lbl,
					"bytes": b,
					"where": "Linha " + t_lbl,
				})
				entries_tb.append({
					"name": vname,
					"py_value": val_s,
					"type_label": t_lbl,
					"bytes": b,
					"where": "Linha " + t_lbl,
					"note": "",
				})
			log_obj.set_state(entries_tb)
			return log_obj

		if csv != "":
			var entries_m: Array = []
			var idx := 0
			for part in csv.split(",", false):
				var p := part.strip_edges()
				var u := p.rfind("_")
				if u <= 0:
					continue
				idx += 1
				var val_s := p.substr(0, u).strip_edges()
				var tag := p.substr(u + 1).strip_edges().to_lower()
				var t_lbl := _normalize_type_tag(tag)
				var b := bytes_for_type_label(t_lbl)
				var vname := "%s_%d" % [t_lbl.to_lower(), idx]
				log_obj.push("move", {
					"name": vname,
					"py_value": val_s,
					"type": t_lbl,
					"bytes": b,
					"src": "bancada",
					"dest": "mochila",
					"where": "mochila",
				})
				entries_m.append({
					"name": vname,
					"py_value": val_s,
					"type_label": t_lbl,
					"bytes": b,
					"where": "mochila",
					"note": "",
				})
			log_obj.set_state(entries_m)
	return log_obj


static func _normalize_type_tag(tag: String) -> String:
	match tag.strip_edges().to_lower():
		"i", "int":
			return "Int"
		"s", "short", "short_int":
			return "Short"
		"f", "float":
			return "Float"
		"d", "double":
			return "Double"
		"fp16", "h":
			return "FP16"
		"fp8", "q":
			return "FP8"
		_:
			return "Float"


func _is_active_state_where(where: String) -> bool:
	return where == "mochila" or where.begins_with("Linha ") or where == "alvo" or where == "alvos"


func _recompute_helpers() -> void:
	needs_fp8_helper = false
	needs_fp16_helper = false
	needs_short_helper = false
	needs_float32_helper = false
	for e in _build_minimal_events():
		_note_helpers_from_event(e)
	for entry in state_entries:
		if not _is_active_state_where(str(entry.get("where", ""))):
			continue
		_note_helpers_from_type(str(entry.get("type_label", "")))


static func numpy_dtype_for_label(type_label: String) -> String:
	match type_label.strip_edges():
		"Short":
			return "np.int16"
		"Int":
			return "np.int32"
		"FP16":
			return "np.float16"
		"Float":
			return "np.float32"
		"Double":
			return "np.float64"
		"FP8":
			return "np_fp8"
		"Binary":
			return "np.uint8"
		_:
			return "np.float32"


## Filtra e compacta os eventos nas linhas mínimas que representam o que foi feito na fase.
func _build_minimal_events() -> Array[Dictionary]:
	# 1) Colapsa casts consecutivos no conversor (quando o jogador troca o dropdown no mesmo orbe).
	var step1: Array[Dictionary] = []
	for raw_e in events:
		var kind := str(raw_e.get("kind", ""))
		if kind in ["phase_start", "warning"]:
			continue
		var e := raw_e.duplicate(true)
		if kind == "cast" and not step1.is_empty() and str(step1[step1.size() - 1].get("kind", "")) == "cast":
			var prev := step1[step1.size() - 1]
			if str(prev.get("to_type", "")) == str(e.get("from_type", "")) \
					and _values_numerically_equal(str(prev.get("after", "")), str(e.get("before", ""))):
				prev["to_type"] = e.get("to_type", "")
				prev["after"] = e.get("after", "")
				prev["to_bytes"] = e.get("to_bytes", 0)
				prev["warning"] = e.get("warning", "")
				prev["deg_kind"] = e.get("deg_kind", "")
				if str(prev.get("from_type", "")).to_lower() == str(prev.get("to_type", "")).to_lower() \
						and _values_numerically_equal(str(prev.get("before", "")), str(prev.get("after", ""))):
					step1.pop_back()
				continue
		if kind == "cast" and str(e.get("from_type", "")).to_lower() == str(e.get("to_type", "")).to_lower():
			continue
		step1.append(e)

	# 2) Filtra movimentos desfeitos e funde `move` vindo do conversor/calculadora na operação anterior.
	var out: Array[Dictionary] = []
	for e in step1:
		var kind := str(e.get("kind", ""))
		if kind == "cast":
			# Se veio logo após um binop cujo resultado é o input deste cast, referencia a variável do binop.
			if not out.is_empty() and str(out[out.size() - 1].get("kind", "")) == "binop":
				var prev_b := out[out.size() - 1]
				if str(prev_b.get("result_type", "")) == str(e.get("from_type", "")) \
						and _values_numerically_equal(str(prev_b.get("result", "")), str(e.get("before", ""))):
					e["input_var"] = str(prev_b.get("name", ""))
			out.append(e)
		elif kind == "binop":
			out.append(e)
		elif kind == "assign":
			if not _matches_mochila_value_type(e):
				continue
			out.append(e)
		elif kind == "move":
			var src := str(e.get("src", ""))
			var dest := str(e.get("dest", ""))
			if src == dest or src == "inspetor" or dest == "inspetor":
				continue
			if src == "mochila" and dest == "bancada":
				continue
			if dest == "mochila" and not _matches_mochila_value_type(e):
				continue
			# Se acabou de converter ou calcular este exato orbe, usa o nome final na operação e não duplica linha.
			if dest == "mochila" and not out.is_empty():
				var last := out[out.size() - 1]
				var last_kind := str(last.get("kind", ""))
				if last_kind == "cast" and str(last.get("to_type", "")) == str(e.get("type", "")) \
						and _values_numerically_equal(str(last.get("after", "")), str(e.get("py_value", ""))):
					last["name"] = str(e.get("name", last.get("name", "x")))
					continue
				if last_kind == "binop" and str(last.get("result_type", "")) == str(e.get("type", "")) \
						and _values_numerically_equal(str(last.get("result", "")), str(e.get("py_value", ""))):
					last["name"] = str(e.get("name", last.get("name", "r")))
					continue
			if dest == "mochila" and _has_matching_prior_op(out, e):
				continue
			out.append(e)
		else:
			out.append(e)
	return out


func _has_matching_prior_op(prior: Array[Dictionary], move_e: Dictionary) -> bool:
	var typ := str(move_e.get("type", ""))
	var val := str(move_e.get("py_value", ""))
	var nm := str(move_e.get("name", ""))
	for other in prior:
		var k := str(other.get("kind", ""))
		if k == "assign":
			if (nm != "" and str(other.get("name", "")) == nm) \
					or (str(other.get("type", "")) == typ and _values_numerically_equal(str(other.get("py_value", "")), val)):
				return true
		elif k == "cast":
			if str(other.get("to_type", "")) == typ and _values_numerically_equal(str(other.get("after", "")), val):
				return true
		elif k == "binop":
			if str(other.get("result_type", "")) == typ and _values_numerically_equal(str(other.get("result", "")), val):
				return true
	return false


## Gera apenas as linhas mínimas de código Python (NumPy) para esta fase (sem cabeçalho de import).
func render_minimal_phase_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var min_events := _build_minimal_events()
	var covered_keys: Dictionary = {}

	for e in min_events:
		var line := _render_minimal_event_line(e)
		if line != "":
			lines.append(line)
		var k := str(e.get("kind", ""))
		if k in ["assign", "move"]:
			_mark_covered(covered_keys, str(e.get("type", "")), str(e.get("py_value", "")), str(e.get("name", "")))
		elif k == "cast":
			_mark_covered(covered_keys, str(e.get("to_type", "")), str(e.get("after", "")), str(e.get("name", "")))
		elif k == "binop":
			_mark_covered(covered_keys, str(e.get("result_type", "")), str(e.get("result", "")), str(e.get("name", "")))

	# Garante que qualquer orbe presente na solução final apareça mesmo se não houve evento explícito.
	for entry in state_entries:
		var w := str(entry.get("where", ""))
		if not _is_active_state_where(w):
			continue
		var nm := str(entry.get("name", "x"))
		var typ := str(entry.get("type_label", ""))
		var val := str(entry.get("py_value", ""))
		if _is_covered(covered_keys, typ, val, nm):
			continue
		_mark_covered(covered_keys, typ, val, nm)
		lines.append("%s = %s" % [nm, _wrap_py_value(typ, val)])

	return lines


func _mark_covered(covered: Dictionary, typ: String, val: String, nm: String) -> void:
	if nm != "":
		covered["nm|" + nm] = true
	covered["%s|%s" % [typ, val]] = true
	if val.is_valid_float():
		covered["%s|#%s" % [typ, str(val.to_float())]] = true


func _is_covered(covered: Dictionary, typ: String, val: String, nm: String) -> bool:
	if nm != "" and covered.has("nm|" + nm):
		return true
	if covered.has("%s|%s" % [typ, val]):
		return true
	if val.is_valid_float() and covered.has("%s|#%s" % [typ, str(val.to_float())]):
		return true
	return false


func _render_minimal_event_line(e: Dictionary) -> String:
	var kind := str(e.get("kind", ""))
	match kind:
		"assign", "move":
			var nm := str(e.get("name", "x"))
			var typ := str(e.get("type", ""))
			var val := str(e.get("py_value", ""))
			return "%s = %s" % [nm, _wrap_py_value(typ, val)]
		"cast":
			var nm_c := str(e.get("name", "x"))
			var fr_p := str(e.get("from_type", ""))
			var to := str(e.get("to_type", ""))
			var before := str(e.get("before", ""))
			var after := str(e.get("after", ""))
			var input_var := str(e.get("input_var", ""))
			var src_expr := input_var if input_var != "" else _wrap_py_value(fr_p, before)
			return "%s = %s" % [nm_c, _render_cast_expr_numpy(src_expr, fr_p, to, before, after)]
		"binop":
			var nm_b := str(e.get("name", "r"))
			var a := str(e.get("a", "0"))
			var bop := str(e.get("b", "0"))
			var op := str(e.get("op", "+"))
			var res := str(e.get("result", "0"))
			var rt := str(e.get("result_type", ""))
			var a_t := str(e.get("a_type", ""))
			var b_t := str(e.get("b_type", ""))
			var a_expr := _wrap_py_value(a_t, a) if a_t != "" else _py_literal(a)
			var b_expr := _wrap_py_value(b_t, bop) if b_t != "" else _py_literal(bop)
			if rt in ["Short", "Int", "FP16", "Float", "Double", "FP8"]:
				return "%s = %s(%s %s %s)" % [nm_b, numpy_dtype_for_label(rt), a_expr, op, b_expr]
			return "%s = %s %s %s" % [nm_b, a_expr, op, b_expr]
		"bit_place":
			var full := str(e.get("full_binary", "0"))
			return "bits = np.uint8(0b%s)" % full
		"binary_challenge":
			var dec2 := int(e.get("decimal", 0))
			var bits_n := int(e.get("num_bits", 0))
			return "bits = np.binary_repr(%d, width=%d)" % [dec2, bits_n]
		_:
			return ""


func render_python() -> String:
	_recompute_helpers()
	var lines := PackedStringArray()
	lines.append("import numpy as np")
	if needs_fp8_helper:
		lines.append("np_fp8 = lambda x: np.float16(x)  # FP8 (1 byte)")
	lines.append("")
	if title != "":
		lines.append("# %s" % title)
	var body := render_minimal_phase_lines()
	if body.is_empty():
		lines.append("pass")
	else:
		lines.append_array(body)
	return "\n".join(lines)


func render_aula() -> String:
	return render_python()


func render_executar() -> String:
	return render_python()


## Renderiza todas as fases juntas com apenas as linhas mínimas de código Python + NumPy.
static func render_combined(logs: Array, _mode: String = "python") -> String:
	var lines := PackedStringArray()
	lines.append("import numpy as np")

	var any_fp8 := false
	for l in logs:
		if l is PhaseScriptLog:
			(l as PhaseScriptLog)._recompute_helpers()
			if (l as PhaseScriptLog).needs_fp8_helper:
				any_fp8 = true
	if any_fp8:
		lines.append("np_fp8 = lambda x: np.float16(x)  # FP8 (1 byte)")
	lines.append("")

	for idx in range(logs.size()):
		var slog: PhaseScriptLog = logs[idx] as PhaseScriptLog
		if slog == null:
			continue
		slog._recompute_helpers()
		var p_num := idx + 1
		var p_title := slog.title if slog.title != "" else ("Fase %02d" % p_num)
		lines.append("# Fase %02d: %s" % [p_num, p_title])
		var body := slog.render_minimal_phase_lines()
		if body.is_empty():
			lines.append("pass")
		else:
			lines.append_array(body)
		if idx < logs.size() - 1:
			lines.append("")

	return "\n".join(lines)


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


func _py_literal(s: String) -> String:
	var t := s.strip_edges()
	var n := _normalize_nonfinite(t)
	match n:
		"inf":
			return "np.inf"
		"-inf":
			return "-np.inf"
		"nan":
			return "np.nan"
		_:
			return t


static func state_entry_from_item(item: Node, var_name: String, where: String, note: String = "") -> Dictionary:
	return {
		"name": var_name,
		"py_value": py_value_for_item(item),
		"type_label": type_label_for_item(item),
		"bytes": bytes_for_item(item),
		"where": where,
		"note": note,
	}


static func stable_var_name_for_item(item: Node, prefix: String = "") -> String:
	var typ := type_label_for_item(item).to_lower().replace(" ", "_")
	var raw := py_value_for_item(item)
	var val := str(raw).replace(".", "p").replace("-", "n").replace("+", "")
	val = val.replace(" ", "")
	if prefix != "":
		return "%s_%s_%s" % [prefix, typ, val]
	return "%s_%s" % [typ, val]


func _mochila_value_type_keys() -> Dictionary:
	var keys: Dictionary = {}
	for entry in state_entries:
		var w := str(entry.get("where", ""))
		if not _is_active_state_where(w):
			continue
		var typ := str(entry.get("type_label", ""))
		var val := str(entry.get("py_value", ""))
		keys["%s|%s" % [typ, val]] = true
		if val.is_valid_float():
			keys["%s|#%s" % [typ, str(val.to_float())]] = true
	return keys


func _matches_mochila_value_type(e: Dictionary) -> bool:
	var keys := _mochila_value_type_keys()
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
	match type_label.strip_edges():
		"Short":
			return "np.int16(%s)" % lit
		"Int":
			return "np.int32(%s)" % lit
		"FP16":
			return "np.float16(%s)" % lit
		"Float":
			return "np.float32(%s)" % lit
		"Double":
			return "np.float64(%s)" % lit
		"FP8":
			return "np_fp8(%s)" % lit
		"Binary":
			return "np.uint8(%s)" % lit
		_:
			return lit


func _render_cast_expr_numpy(src_expr: String, fr_p: String, to: String, before: String, after: String) -> String:
	if to in ["Int", "Short"] and fr_p in ["Float", "Double", "FP8", "FP16"]:
		if _is_nonfinite_literal(before) or _is_nonfinite_literal(after):
			return _wrap_py_value(to, after)
		if to == "Short":
			if not _values_numerically_equal(str(int(before.to_float())), after):
				return "np.int64(int(%s)).astype(np.int16)" % src_expr
			return "np.int16(%s)" % src_expr
		if not _values_numerically_equal(str(int(before.to_float())), after):
			return "np.int64(int(%s)).astype(np.int32)" % src_expr
		return "np.int32(%s)" % src_expr
	elif to == "Short" and fr_p == "Int":
		if not _values_numerically_equal(before, after):
			return "%s.astype(np.int16)" % src_expr
		return "np.int16(%s)" % src_expr
	elif to == "Int" and fr_p == "Short":
		return "np.int32(%s)" % src_expr
	elif to == "Float":
		return "np.float32(%s)" % src_expr
	elif to == "Double":
		return "np.float64(%s)" % src_expr
	elif to == "FP16":
		return "np.float16(%s)" % src_expr
	elif to == "FP8":
		return "np_fp8(%s)" % src_expr
	return _wrap_py_value(to, after)
