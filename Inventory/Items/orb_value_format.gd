class_name OrbValueFormat
extends RefCounted

## Rótulo compacto no orbe; valor exato e precisão no hover / popup / inspetor.

const MAX_LABEL_CHARS := 7
const ORB_FLOAT_DECIMALS := 2
const LARGE_INT_THRESHOLD := 10_000
const LARGE_FLOAT_ABS := 10_000.0
const TINY_FLOAT_ABS := 0.0001
const ELLIPSIS := "..."


static func _has_data_type(item: Node) -> bool:
	# INT == 0 no enum; nunca usar "if not data_type".
	return item != null and is_instance_valid(item) and item is Object and item.has_method("get") and item.get("data_type") != null


static func compact_label_string(item: Node) -> String:
	if not _has_data_type(item):
		return "?"
	if item.data_type == item.DataType.BINARY:
		return item.value_binary
	if item.data_type == item.DataType.OPERATOR and item.has_method("operator_display_label"):
		return item.operator_display_label()
	var s: String = _compact_for_type(item)
	if should_compact(item):
		match item.data_type:
			item.DataType.FLOAT, item.DataType.DOUBLE, item.DataType.FP8, item.DataType.FP16, item.DataType.RAW:
				if _float_has_representation_noise(_numeric_value(item)):
					return "~" + s
			_:
				pass
	return s


static func full_value_string(item: Node) -> String:
	if item == null:
		return ""
	if not _has_data_type(item):
		return str(item.get("value") if item.get("value") != null else "")
	var dt: int = item.data_type
	match dt:
		item.DataType.INT:
			return str(item.value)
		item.DataType.SHORT_INT:
			return str(item.value_short)
		item.DataType.FLOAT, item.DataType.FP8, item.DataType.FP16, item.DataType.RAW:
			return _float_full(item.value_float)
		item.DataType.DOUBLE:
			return _float_full(item.value_double)
		item.DataType.STRING:
			return "\"" + item.value_string + "\""
		item.DataType.OPERATOR:
			return item.operator
		item.DataType.BINARY:
			if item.has_method("binary_to_int"):
				var dec: int = item.binary_to_int(item.value_binary)
				return item.value_binary + "  ->  " + str(dec) + " (decimal)"
			return item.value_binary
		_:
			return str(item.value)


static func python_repr_string(item: Node) -> String:
	if not _has_data_type(item):
		return ""
	var dt: int = item.data_type
	match dt:
		item.DataType.INT, item.DataType.SHORT_INT:
			return str(int(_numeric_value(item)))
		item.DataType.FLOAT, item.DataType.FP8, item.DataType.FP16, item.DataType.RAW:
			return _float_full(item.value_float)
		item.DataType.DOUBLE:
			return _float_full(item.value_double)
		item.DataType.STRING:
			return '"' + str(item.value_string).replace('\\', '\\\\').replace('"', '\\"') + '"'
		item.DataType.OPERATOR:
			return item.operator
		item.DataType.BINARY:
			return "0b" + item.value_binary
		_:
			return full_value_string(item)


static func should_compact(item: Node) -> bool:
	if not _has_data_type(item):
		return false
	var dt: int = item.data_type
	match dt:
		item.DataType.INT:
			return absi(item.value) >= LARGE_INT_THRESHOLD or str(item.value).length() > MAX_LABEL_CHARS
		item.DataType.SHORT_INT:
			return absi(item.value_short) >= LARGE_INT_THRESHOLD or str(item.value_short).length() > MAX_LABEL_CHARS
		item.DataType.FLOAT, item.DataType.FP8, item.DataType.FP16, item.DataType.RAW:
			return _float_needs_compact(item.value_float)
		item.DataType.DOUBLE:
			return _float_needs_compact(item.value_double)
		item.DataType.STRING:
			return ("\"" + item.value_string + "\"").length() > MAX_LABEL_CHARS
		item.DataType.BINARY:
			return item.value_binary.length() > MAX_LABEL_CHARS
		_:
			return false


static func hover_hint_string(item: Node) -> String:
	return detail_plain_text(item, false)


static func detail_plain_text(item: Node, include_controls: bool = true) -> String:
	if item == null:
		return ""
	var lines := detail_lines(item)
	if not include_controls:
		return "\n".join(lines)
	var extra: PackedStringArray = PackedStringArray()
	if should_compact(item):
		extra.append("Clique duplo: painel de detalhes")
		extra.append("Botao direito: inspetor (quando disponivel)")
	return "\n".join(lines + extra)


static func detail_bbcode(item: Node) -> String:
	if item == null:
		return ""
	var tipo: String = ""
	if item.has_method("get_item_info"):
		tipo = str(item.get_item_info().get("tipo", ""))
	var compact: String = compact_label_string(item)
	var full: String = full_value_string(item)
	var py: String = python_repr_string(item)
	var out: String = "[b]%s[/b]\n" % tipo
	if should_compact(item):
		out += "[color=#aaaaaa]No orbe:[/color] [b]%s[/b]\n" % compact
		out += "[color=#aaaaaa]Valor exato:[/color] [b][color=#7ec8e3]%s[/color][/b]\n" % full
	else:
		out += "[color=#aaaaaa]Valor:[/color] [b]%s[/b]\n" % full
	out += "[color=#aaaaaa]Como em Python:[/color] [i]%s[/i]" % py
	if item.data_type in [item.DataType.FLOAT, item.DataType.DOUBLE, item.DataType.FP8, item.DataType.FP16]:
		var raw: String = str(_numeric_value(item))
		if raw != full and _float_has_representation_noise(_numeric_value(item)):
			out += "\n[color=#e8a85e]Nota:[/color] float guardado com imprecisao binaria."
			out += "\n[color=#888888]str() interno: %s[/color]" % raw
	return out


static func detail_lines(item: Node) -> PackedStringArray:
	if item == null:
		return PackedStringArray()
	var tipo: String = ""
	if item.has_method("get_item_info"):
		tipo = str(item.get_item_info().get("tipo", "Orbe"))
	var lines: PackedStringArray = PackedStringArray()
	lines.append(tipo)
	if should_compact(item):
		lines.append("No orbe: " + compact_label_string(item))
		lines.append("Valor exato: " + full_value_string(item))
	else:
		lines.append("Valor: " + full_value_string(item))
	lines.append("Python: " + python_repr_string(item))
	return lines


static func _compact_for_type(item: Node) -> String:
	var full: String = full_value_string(item)
	var dt: int = item.data_type
	match dt:
		item.DataType.INT:
			if not should_compact(item):
				return full
			return _compact_int(item.value)
		item.DataType.SHORT_INT:
			if not should_compact(item):
				return full
			return _compact_int(item.value_short)
		item.DataType.FLOAT, item.DataType.FP8, item.DataType.FP16, item.DataType.RAW:
			return _label_float(item.value_float)
		item.DataType.DOUBLE:
			return _label_float(item.value_double)
		item.DataType.STRING:
			if not should_compact(item):
				return full
			if full.length() <= MAX_LABEL_CHARS:
				return full
			return "\"" + full.substr(1, 3) + ELLIPSIS
		item.DataType.BINARY:
			if not should_compact(item):
				return full
			if item.value_binary.length() <= MAX_LABEL_CHARS:
				return item.value_binary
			return item.value_binary.substr(0, 5) + ELLIPSIS
		_:
			if not should_compact(item):
				return full
			if full.length() <= MAX_LABEL_CHARS:
				return full
			return full.substr(0, MAX_LABEL_CHARS - 1) + ELLIPSIS


static func _numeric_value(item: Node) -> float:
	match item.data_type:
		item.DataType.INT:
			return float(item.value)
		item.DataType.SHORT_INT:
			return float(item.value_short)
		item.DataType.DOUBLE:
			return item.value_double
		item.DataType.FLOAT, item.DataType.FP8, item.DataType.FP16, item.DataType.RAW:
			return item.value_float
		_:
			return 0.0


static func _float_has_representation_noise(v: float) -> bool:
	if is_nan(v) or is_inf(v):
		return false
	var raw := str(v)
	if raw.contains("e") or raw.contains("E"):
		return true
	if raw.find(".") == -1:
		return false
	var parts := raw.split(".")
	if parts.size() < 2:
		return false
	return parts[1].length() > ORB_FLOAT_DECIMALS


static func _float_needs_compact(v: float) -> bool:
	if is_nan(v) or is_inf(v):
		return true
	if v == 0.0:
		return false
	if _float_has_representation_noise(v):
		return true
	return absf(v) >= LARGE_FLOAT_ABS or (absf(v) < TINY_FLOAT_ABS) or _float_full(v).length() > MAX_LABEL_CHARS


static func _float_full(v: float) -> String:
	if is_nan(v):
		return "nan"
	if is_inf(v):
		return "inf" if v > 0 else "-inf"
	return String.num(v, 12).strip_edges()


static func _label_float(v: float) -> String:
	if is_nan(v):
		return "nan"
	if is_inf(v):
		return "inf" if v > 0 else "-inf"
	if v == 0.0:
		return "0"
	var av: float = absf(v)
	if av >= 1_000_000.0:
		return _format_sci(v, ORB_FLOAT_DECIMALS)
	if av >= LARGE_FLOAT_ABS:
		return _format_sci(v, ORB_FLOAT_DECIMALS)
	if av < TINY_FLOAT_ABS:
		return _format_sci(v, ORB_FLOAT_DECIMALS)
	var s: String = _format_compact_decimal(v, ORB_FLOAT_DECIMALS)
	if s.length() <= MAX_LABEL_CHARS:
		return s
	return _format_sci(v, ORB_FLOAT_DECIMALS)


static func _compact_int(v: int) -> String:
	var av: int = absi(v)
	if av < 1_000:
		return str(v)
	if av < 1_000_000:
		var k: float = float(v) / 1000.0
		if v % 1000 == 0:
			return "%dk" % int(float(v) / 1000.0)
		return "%.2fk" % k
	if av < 1_000_000_000:
		var m: float = float(v) / 1_000_000.0
		if v % 1_000_000 == 0:
			return "%dM" % int(float(v) / 1_000_000.0)
		return "%.2fM" % m
	return _format_sci(float(v), 3)


static func _format_compact_decimal(v: float, max_decimals: int) -> String:
	var s := String.num(v, max_decimals)
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s


static func _format_sci(v: float, mantissa_digits: int) -> String:
	if v == 0.0:
		return "0"
	var sign_prefix := "-" if v < 0.0 else ""
	var av := absf(v)
	var exponent := 0
	while av >= 10.0:
		av /= 10.0
		exponent += 1
	while av < 1.0:
		av *= 10.0
		exponent -= 1
	var mantissa := _format_compact_decimal(av, mantissa_digits)
	return sign_prefix + mantissa + "e" + str(exponent)
