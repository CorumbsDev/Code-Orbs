class_name AchievementAnalyzer
extends RefCounted

## Analisa quais conquistas pedagógias uma sequência *pode* viabilizar,
## com base nos tipos de fase e ferramentas configuradas (não no desempenho do jogador).

const REQ_MEMORY := "memory" ## Mochila, Type Box ou RAW
const REQ_TYPING := "typing" ## Type Box ou RAW (escolha de tipo)
const REQ_MULTI_TYPES := "multi_types" ## ≥ 2 tipos permitidos
const REQ_CONVERTER := "converter"
const REQ_CALC := "calc"
const REQ_TIGHT := "tight_capacity" ## pouca memória vs. volume/valores
const REQ_UNIMPLEMENTED := "unimplemented" ## mecânica ainda não existe no jogo


static func requirements_for(id: String) -> PackedStringArray:
	match id:
		"basic_done_well":
			return PackedStringArray([REQ_MEMORY])
		"jack_of_all_trades":
			return PackedStringArray([REQ_MEMORY, REQ_MULTI_TYPES])
		"square_peg":
			return PackedStringArray([REQ_TYPING])
		"diet_operation":
			return PackedStringArray([REQ_TYPING, REQ_MULTI_TYPES, REQ_TIGHT])
		"overflow":
			return PackedStringArray([REQ_CALC])
		"underflow":
			return PackedStringArray([REQ_CALC])
		"one_step_ahead":
			return PackedStringArray([REQ_CONVERTER, REQ_CALC])
		"forced_cast":
			return PackedStringArray([REQ_CONVERTER])
		"code_chameleon":
			return PackedStringArray([REQ_CALC, REQ_MULTI_TYPES])
		"compression_expert":
			return PackedStringArray([REQ_CONVERTER, REQ_MULTI_TYPES, REQ_TIGHT])
		"the_line_moves":
			return PackedStringArray([REQ_UNIMPLEMENTED])
		"shooting_star":
			return PackedStringArray([REQ_UNIMPLEMENTED])
		"digital_hoarder":
			return PackedStringArray([REQ_UNIMPLEMENTED])
		"data_alchemist":
			return PackedStringArray([REQ_CALC])
		"union_is_strength":
			return PackedStringArray([REQ_CALC, REQ_MULTI_TYPES])
		"oil_and_water":
			return PackedStringArray([REQ_CALC])
		_:
			return PackedStringArray([REQ_UNIMPLEMENTED])


static func analyze_steps(steps: Array, achievements: Dictionary = {}) -> Dictionary:
	if achievements.is_empty():
		achievements = _fallback_achievements()
	var caps := _collect_capabilities(steps)
	var reachable: Array[String] = []
	var unreachable: Array[String] = []
	var names: Array[String] = []
	var all_ids: Array = achievements.keys()
	all_ids.sort()
	for id in all_ids:
		var reqs := requirements_for(str(id))
		if _caps_satisfy(caps, reqs):
			reachable.append(str(id))
			var ach: Dictionary = achievements[id]
			names.append(str(ach.get("name", id)))
		else:
			unreachable.append(str(id))
	return {
		"reachable_ids": reachable,
		"unreachable_ids": unreachable,
		"reachable_names": names,
		"count": reachable.size(),
		"total": all_ids.size(),
		"capabilities": caps,
	}


static func _fallback_achievements() -> Dictionary:
	# Usado só em testes headless sem autoload.
	if Engine.get_main_loop() != null:
		var root = Engine.get_main_loop().root
		var am = root.get_node_or_null("/root/AchievementManager")
		if am != null and am.has_method("get_all_achievements"):
			return am.get_all_achievements()
	return {}


static func _caps_satisfy(caps: Dictionary, reqs: PackedStringArray) -> bool:
	for r in reqs:
		if r == REQ_UNIMPLEMENTED:
			return false
		if not caps.get(r, false):
			return false
	return true


static func _collect_capabilities(steps: Array) -> Dictionary:
	var caps := {
		REQ_MEMORY: false,
		REQ_TYPING: false,
		REQ_MULTI_TYPES: false,
		REQ_CONVERTER: false,
		REQ_CALC: false,
		REQ_TIGHT: false,
		REQ_UNIMPLEMENTED: false,
	}
	var types_union: Dictionary = {}
	for s in steps:
		if not (s is PhaseSequenceStep):
			continue
		var step: PhaseSequenceStep = s
		if not PhaseSequenceStep.is_kind_playable(step.kind):
			continue
		match step.kind:
			PhaseSequenceStep.Kind.MOCHILA:
				caps[REQ_MEMORY] = true
				var cfg: PhaseConfig = step.config_mochila
				if cfg == null:
					cfg = PhaseConfig.new()
				_merge_types(types_union, _types_from_mochila(cfg))
				if cfg.use_converter:
					caps[REQ_CONVERTER] = true
				if cfg.allow_calc:
					caps[REQ_CALC] = true
				if _is_tight_mochila(cfg):
					caps[REQ_TIGHT] = true
			PhaseSequenceStep.Kind.TYPE_BOX:
				caps[REQ_MEMORY] = true
				caps[REQ_TYPING] = true
				var tcfg: TypeBoxPhaseConfig = step.config_type_box
				if tcfg == null:
					tcfg = TypeBoxPhaseConfig.new()
				_merge_types(types_union, _types_from_type_box(tcfg))
				if _is_tight_type_box(tcfg):
					caps[REQ_TIGHT] = true
			PhaseSequenceStep.Kind.RAW_MOCHILA:
				caps[REQ_MEMORY] = true
				caps[REQ_TYPING] = true
				var rcfg: RawKnapsackPhaseConfig = step.config_raw_mochila
				if rcfg == null:
					rcfg = RawKnapsackPhaseConfig.new()
				_merge_types(types_union, _types_from_raw(rcfg))
				if _is_tight_raw(rcfg):
					caps[REQ_TIGHT] = true
			PhaseSequenceStep.Kind.CONVERSAO:
				caps[REQ_MEMORY] = true
				caps[REQ_CONVERTER] = true
				caps[REQ_MULTI_TYPES] = true
				_merge_types(types_union, ["int", "float", "double", "short"])
			PhaseSequenceStep.Kind.BINARIO:
				caps[REQ_MEMORY] = true
				_merge_types(types_union, ["int"])
			_:
				pass
	caps[REQ_MULTI_TYPES] = types_union.size() >= 2 or caps[REQ_MULTI_TYPES]
	return caps


static func _merge_types(into: Dictionary, types: Array) -> void:
	for t in types:
		into[t] = true


static func _types_from_mochila(cfg: PhaseConfig) -> Array:
	var out: Array = ["int"]
	if cfg.allow_short:
		out.append("short")
	if cfg.allow_float:
		out.append("float")
	if cfg.allow_double:
		out.append("double")
	if cfg.allow_fp8:
		out.append("fp8")
	if cfg.allow_fp16:
		out.append("fp16")
	return out


static func _types_from_type_box(cfg: TypeBoxPhaseConfig) -> Array:
	var out: Array = []
	if cfg.allow_int:
		out.append("int")
	if cfg.allow_short:
		out.append("short")
	if cfg.allow_float:
		out.append("float")
	if cfg.allow_double:
		out.append("double")
	if cfg.allow_fp8:
		out.append("fp8")
	if cfg.allow_fp16:
		out.append("fp16")
	return out


static func _types_from_raw(cfg: RawKnapsackPhaseConfig) -> Array:
	var out: Array = []
	if cfg.allow_int:
		out.append("int")
	if cfg.allow_short:
		out.append("short")
	if cfg.allow_float:
		out.append("float")
	if cfg.allow_double:
		out.append("double")
	if cfg.allow_fp8:
		out.append("fp8")
	if cfg.allow_fp16:
		out.append("fp16")
	return out


static func _is_tight_mochila(cfg: PhaseConfig) -> bool:
	var fixed := cfg.initial_pool_items.size() + cfg.initial_backpack_items.size()
	if not cfg.initial_backpack_csv.strip_edges().is_empty():
		fixed += cfg.initial_backpack_csv.split(",", false).size()
	if cfg.backpack_slot_count > 0 and fixed > cfg.backpack_slot_count:
		return true
	if cfg.capacity_bytes <= 8 and (fixed >= 3 or cfg.min_bytes_random_pool > 0 or not cfg.random_pool.is_empty()):
		return true
	return false


static func _is_tight_type_box(cfg: TypeBoxPhaseConfig) -> bool:
	var n := cfg.initial_raw_values.size()
	if cfg.randomize_values:
		n = maxi(n, 3)
	if cfg.box_slot_count > 0 and n > cfg.box_slot_count:
		return true
	if cfg.capacity_bytes <= 8 and n >= 3:
		return true
	return false


static func _is_tight_raw(cfg: RawKnapsackPhaseConfig) -> bool:
	var n := cfg.initial_raw_values.size()
	if cfg.randomize_values:
		n = maxi(n, 3)
	if cfg.backpack_slot_count > 0 and n > cfg.backpack_slot_count:
		return true
	if cfg.capacity_bytes <= 8 and n >= 3:
		return true
	return false
