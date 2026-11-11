class_name StarEvaluator
extends RefCounted

const ItemRef = preload("res://Inventory/Items/item.gd")


## Avalia as 3 estrelas de conclusão de uma fase (Mochila, Raw Mochila ou Type Box).
## Retorna Dictionary: { "s1": bool, "s2": bool, "s3": bool, "earned": int, "desc": String }
static func evaluate_phase_stars(
	cfg: Variant,
	moves_count: int,
	is_partial: bool,
	current_orbs: Array,
	degradation_history: Array,
	solution_types_valid: bool = true,
	prioritize_expected_types: bool = false,
	s1_override: bool = true
) -> Dictionary:
	var s1: bool = s1_override
	var s2: bool = true
	var s3: bool = true
	var desc: String = "Movimentos: %d" % moves_count

	if cfg == null or not ("star2_max_moves" in cfg):
		if is_partial:
			s3 = false
		return {
			"s1": s1,
			"s2": s2,
			"s3": s3,
			"earned": int(s1) + int(s2) + int(s3),
			"desc": desc,
		}

	var max_moves: int = int(cfg.star2_max_moves)
	if max_moves > 0:
		s2 = moves_count <= max_moves
		desc += " (meta estrela 2: ≤ %d)" % max_moves

	var star3_csv: String = ""
	if "star3_best_solution_csv" in cfg:
		star3_csv = str(cfg.star3_best_solution_csv).strip_edges()

	var has_expected_types: bool = false
	if "expected_solution_types" in cfg:
		var expected: PackedStringArray = cfg.expected_solution_types
		has_expected_types = not expected.is_empty()

	if prioritize_expected_types:
		if has_expected_types:
			s3 = solution_types_valid
		elif star3_csv != "" and csv_has_typed_values(star3_csv):
			s3 = check_star3_solution(star3_csv, current_orbs)
	else:
		if star3_csv != "":
			s3 = check_star3_solution(star3_csv, current_orbs)
		elif has_expected_types:
			s3 = solution_types_valid

	if "penalize_truncation_and_overflow" in cfg and bool(cfg.penalize_truncation_and_overflow):
		if precision_penalty_applies(cfg, degradation_history, current_orbs):
			s3 = false

	if is_partial:
		s3 = false

	return {
		"s1": s1,
		"s2": s2,
		"s3": s3,
		"earned": int(s1) + int(s2) + int(s3),
		"desc": desc,
	}


## Erro relativo do orbe vs. valor original (Inf/NaN contam como erro infinito).
static func orb_rel_error(item: Node) -> float:
	if item == null or not is_instance_valid(item) or not bool(item.get("has_source_value")):
		return 0.0
	var cur: float = float(item.get_numeric_value())
	if is_nan(cur) or is_inf(cur):
		return INF
	var src: float = float(item.source_value)
	return absf(cur - src) / maxf(absf(src), 1e-9)


## True se um orbe Int/Short guarda valor fora da faixa suportada.
static func orb_int_overflowed(item: Node) -> bool:
	if item == null or not is_instance_valid(item):
		return false
	var cur: float = float(item.get_numeric_value())
	if item.data_type == ItemRef.DataType.SHORT_INT:
		return cur > float(TypeConversionSystem.INT16_MAX) or cur < float(TypeConversionSystem.INT16_MIN)
	if item.data_type == ItemRef.DataType.INT:
		return cur > float(TypeConversionSystem.INT32_MAX) or cur < float(TypeConversionSystem.INT32_MIN)
	return false


## True se a fase deve perder estrela por perda de precisão.
static func precision_penalty_applies(cfg: Variant, degradation_history: Array, orbs: Array) -> bool:
	for h in degradation_history:
		if typeof(h) == TYPE_DICTIONARY and str(h.get("kind", "")) in ["truncation", "overflow", "absorption"]:
			return true
	var tol: float = float(cfg.error_tolerance_rel) if (cfg != null and "error_tolerance_rel" in cfg) else 0.01
	for it in orbs:
		if orb_rel_error(it) > tol:
			return true
	return false


## Compara os orbes atuais com a solução ideal (CSV "valor_tipo"), sem ordem.
static func check_star3_solution(target_csv: String, current: Array) -> bool:
	var targets: Array = []
	for part in target_csv.split(",", false):
		var e: String = part.strip_edges()
		if e.is_empty():
			continue
		var idx: int = e.rfind("_")
		if idx <= 0:
			return false
		targets.append({"value": float(e.substr(0, idx)), "tag": e.substr(idx + 1).to_lower()})

	if current.size() != targets.size():
		return false

	var used: Array = []
	for t in targets:
		var found: bool = false
		for i in range(current.size()):
			if used.has(i):
				continue
			var it = current[i]
			if not is_instance_valid(it):
				continue
			var csv_str: String = item_to_csv_string(it)
			var tag: String = csv_str.substr(csv_str.rfind("_") + 1).to_lower()
			if tag != str(t.tag):
				continue
			var cur: float = float(it.get_numeric_value())
			var want: float = float(t.value)
			var tol: float = absf(want) * (0.02 if tag in ["fp8", "fp16"] else 1e-6) + 1e-9
			if absf(cur - want) <= tol:
				used.append(i)
				found = true
				break
		if not found:
			return false
	return true


static func item_to_csv_string(item: Node) -> String:
	if not is_instance_valid(item):
		return ""
	var v_str: String = ""
	var t_str: String = ""
	match int(item.data_type):
		0:
			v_str = str(item.value)
			t_str = "i"
		1:
			v_str = str(item.value_float)
			t_str = "f"
		4:
			v_str = str(item.value_double)
			t_str = "d"
		9:
			v_str = str(item.value_string) if "value_string" in item else str(item.value)
			t_str = "raw"
		6:
			v_str = str(item.value_short)
			t_str = "s"
		7:
			v_str = str(item.value_float)
			t_str = "fp8"
		8:
			v_str = str(item.value_float)
			t_str = "fp16"
		_:
			v_str = str(item.value)
			t_str = "i"
	return v_str + "_" + t_str


## True se o CSV tem entradas "valor_tipo" (ex.: 5_i); falso para listas de nomes de tipo.
static func csv_has_typed_values(csv: String) -> bool:
	for part in csv.split(",", false):
		var e: String = part.strip_edges()
		var idx: int = e.rfind("_")
		if idx <= 0 or not e.substr(0, idx).is_valid_float():
			return false
	return true


static func parse_expected_type(type_str: String) -> int:
	match type_str.strip_edges().to_lower():
		"int":
			return ItemRef.DataType.INT
		"short", "short_int":
			return ItemRef.DataType.SHORT_INT
		"float":
			return ItemRef.DataType.FLOAT
		"double":
			return ItemRef.DataType.DOUBLE
		"fp8":
			return ItemRef.DataType.FP8
		"fp16":
			return ItemRef.DataType.FP16
		_:
			return -1


static func item_numeric_value(item: Node) -> float:
	if item.data_type in [ItemRef.DataType.FLOAT, ItemRef.DataType.DOUBLE, ItemRef.DataType.FP8, ItemRef.DataType.FP16, ItemRef.DataType.RAW]:
		return float(item.value_float)
	return float(item.value)


static func raw_values_match(item_val: float, target_str: String) -> bool:
	var clean: String = target_str.trim_suffix("_i").trim_suffix("_f").trim_suffix("_d").trim_suffix("_s").trim_suffix("_fp8").trim_suffix("_fp16").trim_suffix("_r")
	var target: float = float(clean)
	if is_equal_approx(item_val, target):
		return true
	var tolerance: float = maxf(0.0001, absf(target) * 1e-4)
	return absf(item_val - target) <= tolerance


static func validate_type_box_solution_types(config: Variant, placed: Array) -> bool:
	if config == null or config.expected_solution_types.is_empty():
		return true
	if bool(config.randomize_values):
		return true
	var expected: PackedStringArray = config.expected_solution_types
	var raw_vals: PackedStringArray = config.initial_raw_values
	var n: int = mini(expected.size(), raw_vals.size())
	if n == 0:
		return true
	if placed.size() != n:
		return false
	if expected.size() == raw_vals.size():
		var all_indexed: bool = true
		for it in placed:
			if int(it.raw_index) < 0 or int(it.raw_index) >= expected.size():
				all_indexed = false
				break
		if all_indexed:
			for it in placed:
				var t_idx: int = parse_expected_type(str(expected[int(it.raw_index)]))
				if t_idx >= 0 and it.data_type != t_idx:
					var is_exact_int_from_float: bool = (
						"." in str(it.raw_literal)
						and is_equal_approx(item_numeric_value(it), roundf(item_numeric_value(it)))
						and it.data_type in [ItemRef.DataType.INT, ItemRef.DataType.SHORT_INT]
					)
					if not is_exact_int_from_float:
						return false
			return true
	var used_indices: Dictionary = {}
	for i in range(n):
		var target_type: int = parse_expected_type(str(expected[i]))
		if target_type < 0:
			continue
		var found: bool = false
		for j in range(placed.size()):
			if used_indices.has(j):
				continue
			var item = placed[j]
			var type_matches: bool = (item.data_type == target_type) or (
				"." in str(item.raw_literal)
				and is_equal_approx(item_numeric_value(item), roundf(item_numeric_value(item)))
				and item.data_type in [ItemRef.DataType.INT, ItemRef.DataType.SHORT_INT]
			)
			if not type_matches:
				continue
			if not raw_values_match(item_numeric_value(item), str(raw_vals[i])):
				continue
			used_indices[j] = true
			found = true
			break
		if not found:
			return false
	return true

