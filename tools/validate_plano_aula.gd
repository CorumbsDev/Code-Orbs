extends SceneTree
## Validação headless da sequência pedagógica (14 fases).
## Uso: godot --headless --path . --script res://tools/validate_plano_aula.gd

const PATH := "res://Inventory/fases/scenarios/sequencia_base.tres"

var _errors: Array[String] = []
var _oks: int = 0


func _init() -> void:
	print("=== validate_plano_aula ===")
	var res = ResourceLoader.load(PATH)
	if res == null:
		_fail("Não carregou %s" % PATH)
		_finish(1)
		return
	if not (res is PhaseSequenceList):
		_fail("Não é PhaseSequenceList")
		_finish(1)
		return

	var seq := res as PhaseSequenceList
	_expect(seq.steps.size() == 14, "steps.size == 14 (got %d)" % seq.steps.size())

	var playable := PhaseSequenceStep.filter_playable_steps(seq.to_runtime_array())
	_expect(playable.size() == 14, "playable == 14 (got %d)" % playable.size())

	var expected_kinds := [
		PhaseSequenceStep.Kind.TYPE_BOX, PhaseSequenceStep.Kind.TYPE_BOX,
		PhaseSequenceStep.Kind.MOCHILA, PhaseSequenceStep.Kind.MOCHILA,
		PhaseSequenceStep.Kind.MOCHILA, PhaseSequenceStep.Kind.MOCHILA,
		PhaseSequenceStep.Kind.MOCHILA, PhaseSequenceStep.Kind.MOCHILA,
		PhaseSequenceStep.Kind.MOCHILA, PhaseSequenceStep.Kind.MOCHILA,
		PhaseSequenceStep.Kind.MOCHILA, PhaseSequenceStep.Kind.MOCHILA,
		PhaseSequenceStep.Kind.RAW_MOCHILA, PhaseSequenceStep.Kind.RAW_MOCHILA,
	]
	var expected_titles := [
		"Ponto de Partida Inicial", "Tipos de Dados", "Está Apertado", "Agora Explodiu",
		"Conversão pela Adição", "A Soma Explosiva", "O Corte Seco", "A Ilusão do Float",
		"Espremendo a Mantissa", "O Abismo do Underflow", "Quantização em Lote", "O Mestre dos Dados",
		"Primeira Declaração", "O Arquiteto de Sistema",
	]

	for i in range(seq.steps.size()):
		var step: PhaseSequenceStep = seq.steps[i]
		var n := i + 1
		_expect(step != null, "step %d null" % n)
		if step == null:
			continue
		_expect(step.kind == expected_kinds[i], "fase %d kind=%s expected=%s" % [n, step.kind, expected_kinds[i]])
		_expect(step.custom_tutorial_title == expected_titles[i], "fase %d title='%s'" % [n, step.custom_tutorial_title])
		step.sanitize_configs_for_kind()
		match step.kind:
			PhaseSequenceStep.Kind.TYPE_BOX:
				_check_typebox(n, step)
			PhaseSequenceStep.Kind.MOCHILA:
				_check_mochila(n, step)
			PhaseSequenceStep.Kind.RAW_MOCHILA:
				_check_raw(n, step)

	# Checks pontuais do plano
	_check_fase1(seq.steps[0])
	_check_fase3(seq.steps[2])
	_check_fase5(seq.steps[4])
	_check_fase10(seq.steps[9])
	_check_fase12(seq.steps[11])
	_check_fase13(seq.steps[12])
	_check_fase14(seq.steps[13])

	# Simula o que o PhaseRunner faz: duplicate configs
	for i in range(seq.steps.size()):
		var step: PhaseSequenceStep = seq.steps[i]
		match step.kind:
			PhaseSequenceStep.Kind.MOCHILA:
				var c: PhaseConfig = step.config_mochila.duplicate(true)
				_expect(c != null and c.capacity_bytes > 0, "dup mochila fase %d" % (i + 1))
			PhaseSequenceStep.Kind.TYPE_BOX:
				var t: TypeBoxPhaseConfig = step.config_type_box.duplicate(true)
				_expect(t != null and t.initial_raw_values.size() > 0, "dup typebox fase %d" % (i + 1))
			PhaseSequenceStep.Kind.RAW_MOCHILA:
				var r: RawKnapsackPhaseConfig = step.config_raw_mochila.duplicate(true)
				_expect(r != null and r.initial_raw_values.size() > 0, "dup raw fase %d" % (i + 1))

	print("---")
	print("OK checks: ", _oks)
	print("FAILS: ", _errors.size())
	for e in _errors:
		print("  FAIL: ", e)
	_finish(0 if _errors.is_empty() else 1)


func _check_typebox(n: int, step: PhaseSequenceStep) -> void:
	var c := step.config_type_box
	_expect(c != null, "fase %d type_box config" % n)
	if c == null:
		return
	_expect(c.initial_raw_values.size() >= 4, "fase %d raws>=4" % n)


func _check_mochila(n: int, step: PhaseSequenceStep) -> void:
	var c := step.config_mochila
	_expect(c != null, "fase %d mochila config" % n)
	if c == null:
		return
	_expect(c.slot_bytes == 1, "fase %d slot_bytes=1" % n)
	_expect(c.fixed_pool_only, "fase %d fixed_pool" % n)
	_expect(c.respect_tool_flags, "fase %d respect_tool_flags" % n)
	_expect(c.initial_backpack_csv.strip_edges() != "", "fase %d csv não vazio" % n)
	_expect(c.backpack_slot_count == c.capacity_bytes, "fase %d slots==cap" % n)


func _check_raw(n: int, step: PhaseSequenceStep) -> void:
	var c := step.config_raw_mochila
	_expect(c != null, "fase %d raw config" % n)
	if c == null:
		return
	_expect(c.initial_raw_values.size() >= 3, "fase %d raw values" % n)
	_expect(c.capacity_bytes >= 10, "fase %d cap>=10" % n)


func _check_fase1(step: PhaseSequenceStep) -> void:
	var c := step.config_type_box
	_expect(c.slots_int == 2 and c.slots_float == 4, "fase1 slots 2i/4f")
	_expect(c.initial_raw_values.size() == 6, "fase1 6 orbes")


func _check_fase3(step: PhaseSequenceStep) -> void:
	var c := step.config_mochila
	_expect(c.capacity_bytes == 8, "fase3 cap=8")
	_expect(c.allow_short and c.allow_float and c.allow_double, "fase3 tools")
	_expect(c.star3_best_solution_csv.contains("8.5_f"), "fase3 star3")


func _check_fase5(step: PhaseSequenceStep) -> void:
	var c := step.config_mochila
	_expect(c.allow_calc and not c.has_any_converter(), "fase5 só calculadora")


func _check_fase10(step: PhaseSequenceStep) -> void:
	var c := step.config_mochila
	_expect(c.forbid_underflow_zero, "fase10 forbid underflow")
	_expect(c.allow_fp8 and c.allow_fp16, "fase10 fp8/fp16")


func _check_fase12(step: PhaseSequenceStep) -> void:
	var c := step.config_mochila
	_expect(c.capacity_bytes == 15, "fase12 cap=15")
	_expect(c.required_values_csv.contains("40000"), "fase12 required")
	_expect(c.allow_calc and c.allow_fp8, "fase12 arsenal")


func _check_fase13(step: PhaseSequenceStep) -> void:
	var c := step.config_raw_mochila
	_expect(c.capacity_bytes == 10, "fase13 cap=10")
	_expect(c.slot_bytes == 4, "fase13 slot_bytes=4")
	_expect(c.allow_short and c.allow_int and c.allow_fp16 and c.allow_float and c.allow_double and not c.allow_fp8, "fase13 estações")


func _check_fase14(step: PhaseSequenceStep) -> void:
	var c := step.config_raw_mochila
	_expect(c.capacity_bytes == 13, "fase14 cap=13")
	_expect(c.slot_bytes == 4, "fase14 slot_bytes=4")
	_expect(c.allow_fp8 and c.allow_short and c.allow_int, "fase14 estações")
	_expect("3.14159" in c.initial_raw_values, "fase14 pi")


func _expect(cond: bool, msg: String) -> void:
	if cond:
		_oks += 1
	else:
		_errors.append(msg)


func _fail(msg: String) -> void:
	_errors.append(msg)
	print("FATAL: ", msg)


func _finish(code: int) -> void:
	quit(code)
