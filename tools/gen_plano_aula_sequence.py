#!/usr/bin/env python3
"""Gera Inventory/fases/scenarios/sequencia_base.tres com as 16 fases do plano de aula."""

from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "Inventory/fases/scenarios/sequencia_base.tres"

# Ext resources
EXT = {
	"list": ("1_list", "res://Inventory/fases/phase_sequence_list.gd"),
	"step": ("2_step", "res://Inventory/fases/phase_sequence_step.gd"),
	"mochila": ("3_mochila", "res://Inventory/fases/phase_config.gd"),
	"typebox": ("4_typebox", "res://Inventory/fases/type_box_phase_config.gd"),
	"raw": ("5_raw", "res://Inventory/fases/raw_knapsack_phase_config.gd"),
}

KIND = {"MOCHILA": 0, "BINARIO": 1, "TYPE_BOX": 2, "RAW_MOCHILA": 3, "CONVERSAO": 4}

# Células na grade de 1 byte (igual MemoryLayout.slots_occupied).
_TYPE_CELLS = {
	"i": 4,
	"f": 4,
	"d": 8,
	"s": 2,
	"fp16": 2,
	"h": 2,
	"fp8": 1,
	"q": 1,
}


def csv_pool_cells(csv: str) -> int:
	total = 0
	for part in csv.split(","):
		e = part.strip()
		if not e or "_" not in e:
			continue
		type_str = e.rsplit("_", 1)[-1].lower()
		total += _TYPE_CELLS.get(type_str, 4)
	return total


def mochila(
	cap: int,
	csv: str,
	*,
	use_converter=False,
	allow_float=False,
	allow_double=False,
	allow_short=False,
	allow_fp8=False,
	allow_fp16=False,
	allow_calc=False,
	allow_inspector=True,
	forbid_underflow=False,
	forbid_overflow=True,
	error_tol=0.01,
	required="",
	star3="",
	pool_slots=12,
) -> dict:
	# Bancada precisa caber todos os itens iniciais (ex.: short+int+double = 14 células).
	need = csv_pool_cells(csv) + 2
	return {
		"kind": "MOCHILA",
		"capacity_bytes": cap,
		"slot_bytes": 1,
		"grid_columns": 4,
		"backpack_slot_count": cap,
		"pool_slot_count": max(pool_slots, need, 8),
		"pool_grid_columns": 5,
		"spawn_int_min": 1,
		"spawn_int_max": 10,
		"initial_backpack_csv": csv,
		"use_converter": use_converter,
		"allow_float": allow_float,
		"allow_double": allow_double,
		"allow_short": allow_short,
		"allow_fp8": allow_fp8,
		"allow_fp16": allow_fp16,
		"allow_calc": allow_calc,
		"allow_inspector": allow_inspector,
		"forbid_underflow_zero": forbid_underflow,
		"forbid_overflow_inf": forbid_overflow,
		"error_tolerance_rel": error_tol,
		"required_values_csv": required,
		"star3_best_solution_csv": star3,
	}


def typebox(
	slots: dict,
	raws: list[str],
	*,
	expected: list[str] | None = None,
) -> dict:
	return {
		"kind": "TYPE_BOX",
		"capacity_bytes": 64,
		"slot_bytes": 4,
		"initial_raw_values": raws,
		"slots_int": slots.get("int", 0),
		"slots_float": slots.get("float", 0),
		"slots_short": slots.get("short", 0),
		"slots_double": slots.get("double", 0),
		"slots_fp8": slots.get("fp8", 0),
		"slots_fp16": slots.get("fp16", 0),
		"use_byte_limit": False,
		"expected_solution_types": expected or [],
	}


def raw(
	cap: int,
	values: list[str],
	*,
	allow_int=True,
	allow_short=False,
	allow_float=False,
	allow_double=False,
	allow_fp8=False,
	allow_fp16=False,
	slot_bytes=1,
) -> dict:
	return {
		"kind": "RAW_MOCHILA",
		"capacity_bytes": cap,
		"slot_bytes": slot_bytes,
		"grid_columns": 4,
		"backpack_slot_count": cap if slot_bytes == 1 else max(4, (cap + slot_bytes - 1) // slot_bytes),
		"pool_slot_count": max(10, len(values) + 2),
		"pool_grid_columns": 5,
		"initial_raw_values": values,
		"allow_int": allow_int,
		"allow_short": allow_short,
		"allow_float": allow_float,
		"allow_double": allow_double,
		"allow_fp8": allow_fp8,
		"allow_fp16": allow_fp16,
	}


PHASES: list[tuple[str, str, dict]] = [
	(
		"Ponto de Partida Inicial",
		"Dois inteiros e quatro floats na bancada. Classifique em Int (2 slots) e Float (4 slots). Atenção: 5.0 e 0.0 não são Int!",
		typebox(
			{"int": 2, "float": 4},
			["5", "-18", "5.0", "0.25", "0.0", "10.5"],
			expected=["int", "int", "float", "float", "float", "float"],
		),
	),
	(
		"Tipos de Dados",
		"Mesmos valores, mas agora há 6 caixas com 1 slot cada (short, int, fp8, fp16, float, double). Distribua um orbe por tipo.",
		typebox(
			{"int": 1, "short": 1, "float": 1, "double": 1, "fp8": 1, "fp16": 1},
			["5", "-18", "5.0", "0.25", "0.0", "10.5"],
		),
	),
	(
		"Está Apertado",
		"Mochila de 8 bytes. Converta com precisão: short + short + float = 8B. Solução ótima: 10_s, 5_s, 8.5_f.",
		mochila(
			8,
			"10_s, 5_i, 8.5_d",
			allow_float=True,
			allow_double=True,
			allow_short=True,
			star3="10_s, 5_s, 8.5_f",
		),
	),
	(
		"Agora Explodiu",
		"Três ints (15k, 32k, 50k) em 8 bytes. Short economiza, mas 50000 estoura. Solução: 15000_s, 32000_s, 50000_i.",
		mochila(
			8,
			"15000_i, 32000_i, 50000_i",
			allow_short=True,
			star3="15000_s, 32000_s, 50000_i",
		),
	),
	(
		"Conversão pela Adição",
		"Sem conversor: use a Calculadora para fundir tipos e caber em 8 bytes. Solução ótima: 100.25_f, 10.5_f.",
		mochila(
			8,
			"100_s, 0.25_f, 10.5_d",
			allow_calc=True,
			star3="100.25_f, 10.5_f",
		),
	),
	(
		"A Soma Explosiva",
		"Somar dois shorts pode estourar. Promova antes de somar. Solução: 38000_i, 5000_s.",
		mochila(
			6,
			"20000_s, 18000_s, 5000_s",
			allow_short=True,
			allow_calc=True,
			star3="38000_i, 5000_s",
		),
	),
	(
		"O Corte Seco",
		"Some 4.5+3.5 antes de truncar. Depois encolha 2.25 double→float. Solução: 8_s, 2.25_f.",
		mochila(
			6,
			"4.5_f, 3.5_f, 2.25_d",
			allow_float=True,
			allow_double=True,
			allow_short=True,
			allow_calc=True,
			star3="8_s, 2.25_f",
		),
	),
	(
		"A Ilusão do Float",
		"16777219.0 perde precisão em float. Mantenha como double e encolha 1024.5. Solução: 16777219.0_d, 1024.5_f.",
		mochila(
			12,
			"16777219.0_d, 1024.5_d",
			allow_float=True,
			allow_double=True,
			star3="16777219.0_d, 1024.5_f",
		),
	),
	(
		"Espremendo a Mantissa",
		"fp16 arredonda Pi/Euler (tolerância 0.1%), mas 500000 vira Inf. Solução: dois fp16 + float.",
		mochila(
			8,
			"3.1415926_f, 2.7182818_f, 500000.0_f",
			allow_float=True,
			allow_fp16=True,
			error_tol=0.001,
			star3="3.1415926_fp16, 2.7182818_fp16, 500000.0_f",
		),
	),
	(
		"O Abismo do Underflow",
		"fp8 zera 0.00008 (underflow). Proteja-o em fp16. Solução: três fp8 + um fp16.",
		mochila(
			5,
			"1.5_fp16, 2.25_fp16, 0.5_fp16, 0.00008_fp16",
			allow_fp8=True,
			allow_fp16=True,
			forbid_underflow=True,
			star3="1.5_fp8, 2.25_fp8, 0.5_fp8, 0.00008_fp16",
		),
	),
	(
		"Quantização em Lote",
		"Comprima 5 floats em 7 bytes. 3.33333 precisa de fp16; 1000 cabe em short. Solução em star3.",
		mochila(
			7,
			"1.25_f, 3.5_f, 3.33333_f, 120.0_f, 1000.0_f",
			allow_float=True,
			allow_short=True,
			allow_fp8=True,
			allow_fp16=True,
			error_tol=0.02,
			star3="1.25_fp8, 3.5_fp8, 3.33333_fp16, 120.0_fp8, 1000.0_s",
		),
	),
	(
		"O Mestre dos Dados",
		"Arsenal completo. Fuja de overflow, absorção e underflow. Valores obrigatórios: 40000, 16777217, 0.0005, 1.5.",
		mochila(
			15,
			"30000_s, 10000_s, 16777216.0_f, 1.0_f, 0.0005_d, 1.5_d",
			allow_float=True,
			allow_double=True,
			allow_short=True,
			allow_fp8=True,
			allow_fp16=True,
			allow_calc=True,
			forbid_underflow=True,
			required="40000,16777217,0.0005,1.5",
			pool_slots=14,
		),
	),
	(
		"Do Zero ao Byte",
		"Orbes RAW: declare o menor tipo seguro para 15, -300, 4.5 e 0.5 e caiba em 10 bytes.",
		raw(
			10,
			["15", "-300", "4.5", "0.5"],
			allow_int=True,
			allow_short=True,
			allow_float=True,
			allow_double=True,
			allow_fp16=True,
		),
	),
	(
		"Olho Clínico nos Limites",
		"RAW 100, 30000, 45000 e 2.5. Escolha short/int/float/double sem estourar a mochila de 12 bytes.",
		raw(
			12,
			["100", "30000", "45000", "2.5"],
			allow_int=True,
			allow_short=True,
			allow_float=True,
			allow_double=True,
		),
	),
	(
		"A Escada de Precisão",
		"RAW 1.5, 0.0002 e 16777219.0. Suba/desça na escada fp8→fp16→float→double até caber em 11 bytes.",
		raw(
			11,
			["1.5", "0.0002", "16777219.0"],
			allow_int=False,
			allow_float=True,
			allow_double=True,
			allow_fp8=True,
			allow_fp16=True,
		),
	),
	(
		"O Arquiteto de Sistema",
		"Cinco RAW, seis estações, 13 bytes. Desperdício zero: short, int, fp8, fp16 e float.",
		raw(
			13,
			["12", "-40000", "0.25", "0.00008", "3.1415926"],
			allow_int=True,
			allow_short=True,
			allow_float=True,
			allow_double=True,
			allow_fp8=True,
			allow_fp16=True,
		),
	),
]


def emit_bool(v: bool) -> str:
	return "true" if v else "false"


def emit_packed_strings(vals: list[str]) -> str:
	inner = ", ".join(f'"{v}"' for v in vals)
	return f"PackedStringArray({inner})"


def emit_mochila(rid: str, cfg: dict) -> str:
	lines = [
		f'[sub_resource type="Resource" id="{rid}"]',
		f'script = ExtResource("{EXT["mochila"][0]}")',
		f'capacity_bytes = {cfg["capacity_bytes"]}',
		f'slot_bytes = {cfg["slot_bytes"]}',
		f'grid_columns = {cfg["grid_columns"]}',
		f'backpack_slot_count = {cfg["backpack_slot_count"]}',
		f'pool_slot_count = {cfg["pool_slot_count"]}',
		f'pool_grid_columns = {cfg["pool_grid_columns"]}',
		f'spawn_int_min = {cfg["spawn_int_min"]}',
		f'spawn_int_max = {cfg["spawn_int_max"]}',
		"initial_backpack_items = PackedStringArray()",
		f'initial_backpack_csv = "{cfg["initial_backpack_csv"]}"',
		"initial_pool_items = PackedStringArray()",
		"random_pool = PackedStringArray()",
		"min_bytes_random_pool = 0",
		f'use_converter = {emit_bool(cfg["use_converter"])}',
		f'allow_float = {emit_bool(cfg["allow_float"])}',
		f'allow_double = {emit_bool(cfg["allow_double"])}',
		f'allow_short = {emit_bool(cfg["allow_short"])}',
		f'allow_fp8 = {emit_bool(cfg["allow_fp8"])}',
		f'allow_fp16 = {emit_bool(cfg["allow_fp16"])}',
		f'allow_calc = {emit_bool(cfg["allow_calc"])}',
		"fp8_exp_bits = 4",
		"fp8_mant_bits = 3",
		"fp16_exp_bits = 5",
		"fp16_mant_bits = 10",
		"allow_fp_customization = false",
		"respect_tool_flags = true",
		f'allow_inspector = {emit_bool(cfg["allow_inspector"])}',
		"fixed_pool_only = true",
		"win_mode = 0",
		"penalize_truncation_and_overflow = true",
		f'forbid_underflow_zero = {emit_bool(cfg["forbid_underflow_zero"])}',
		f'forbid_overflow_inf = {emit_bool(cfg["forbid_overflow_inf"])}',
		f'error_tolerance_rel = {cfg["error_tolerance_rel"]}',
		f'required_values_csv = "{cfg["required_values_csv"]}"',
		"star2_max_moves = 0",
		f'star3_best_solution_csv = "{cfg["star3_best_solution_csv"]}"',
		"",
	]
	return "\n".join(lines)


def emit_typebox(rid: str, cfg: dict) -> str:
	si = cfg["slots_int"]
	sf = cfg["slots_float"]
	ss = cfg["slots_short"]
	sd = cfg["slots_double"]
	s8 = cfg["slots_fp8"]
	s16 = cfg["slots_fp16"]
	active = sum(1 for x in (si, sf, ss, sd, s8, s16) if x > 0)
	box = max(si, sf, ss, sd, s8, s16, 1)
	exp = cfg["expected_solution_types"]
	lines = [
		f'[sub_resource type="Resource" id="{rid}"]',
		f'script = ExtResource("{EXT["typebox"][0]}")',
		f'capacity_bytes = {cfg["capacity_bytes"]}',
		f'slot_bytes = {cfg["slot_bytes"]}',
		f'initial_raw_values = {emit_packed_strings(cfg["initial_raw_values"])}',
		"randomize_values = false",
		f"box_slot_count = {box}",
		f"slots_int = {si}",
		f"slots_float = {sf}",
		f"slots_short = {ss}",
		f"slots_double = {sd}",
		f"slots_fp8 = {s8}",
		f"slots_fp16 = {s16}",
		f"grid_rows = {max(1, active)}",
		f"max_int_per_row = {si}",
		f"max_float_per_row = {sf}",
		f"max_short_per_row = {ss}",
		f"max_double_per_row = {sd}",
		f"max_fp8_per_row = {s8}",
		f"max_fp16_per_row = {s16}",
		f"allow_int = {emit_bool(si > 0)}",
		f"allow_short = {emit_bool(ss > 0)}",
		f"allow_float = {emit_bool(sf > 0)}",
		f"allow_double = {emit_bool(sd > 0)}",
		f"allow_fp8 = {emit_bool(s8 > 0)}",
		f"allow_fp16 = {emit_bool(s16 > 0)}",
		"fp8_exp_bits = 4",
		"fp8_mant_bits = 3",
		"fp16_exp_bits = 5",
		"fp16_mant_bits = 10",
		"star2_max_moves = 0",
		'star3_best_solution_csv = ""',
		f'use_byte_limit = {emit_bool(cfg["use_byte_limit"])}',
		f"expected_solution_types = {emit_packed_strings(exp)}",
		"",
	]
	return "\n".join(lines)


def emit_raw(rid: str, cfg: dict) -> str:
	lines = [
		f'[sub_resource type="Resource" id="{rid}"]',
		f'script = ExtResource("{EXT["raw"][0]}")',
		f'capacity_bytes = {cfg["capacity_bytes"]}',
		f'slot_bytes = {cfg["slot_bytes"]}',
		f'grid_columns = {cfg["grid_columns"]}',
		f'backpack_slot_count = {cfg["backpack_slot_count"]}',
		f'pool_slot_count = {cfg["pool_slot_count"]}',
		f'pool_grid_columns = {cfg["pool_grid_columns"]}',
		f'initial_raw_values = {emit_packed_strings(cfg["initial_raw_values"])}',
		"randomize_values = false",
		f'allow_int = {emit_bool(cfg["allow_int"])}',
		f'allow_short = {emit_bool(cfg["allow_short"])}',
		f'allow_float = {emit_bool(cfg["allow_float"])}',
		f'allow_double = {emit_bool(cfg["allow_double"])}',
		f'allow_fp8 = {emit_bool(cfg["allow_fp8"])}',
		f'allow_fp16 = {emit_bool(cfg["allow_fp16"])}',
		"fp8_exp_bits = 4",
		"fp8_mant_bits = 3",
		"fp16_exp_bits = 5",
		"fp16_mant_bits = 10",
		"star2_max_moves = 0",
		'star3_best_solution_csv = ""',
		"",
	]
	return "\n".join(lines)


def emit_step(rid: str, kind: int, cfg_key: str, cfg_id: str, title: str, body: str) -> str:
	field = {
		KIND["MOCHILA"]: "config_mochila",
		KIND["TYPE_BOX"]: "config_type_box",
		KIND["RAW_MOCHILA"]: "config_raw_mochila",
	}[kind]
	# Escapa aspas no tutorial
	body_esc = body.replace('"', '\\"')
	title_esc = title.replace('"', '\\"')
	return "\n".join(
		[
			f'[sub_resource type="Resource" id="{rid}"]',
			f'script = ExtResource("{EXT["step"][0]}")',
			f"kind = {kind}",
			f"{field} = SubResource(\"{cfg_id}\")",
			"use_custom_tutorial = true",
			f'custom_tutorial_title = "{title_esc}"',
			f'custom_tutorial_text = "{body_esc}"',
			"",
		]
	)


def main() -> None:
	parts: list[str] = []
	step_ids: list[str] = []
	sub_count = 0

	for i, (title, body, cfg) in enumerate(PHASES, start=1):
		cfg_id = f"cfg_{i}"
		step_id = f"step_{i}"
		kind_name = cfg["kind"]
		kind = KIND[kind_name]
		if kind_name == "MOCHILA":
			parts.append(emit_mochila(cfg_id, cfg))
		elif kind_name == "TYPE_BOX":
			parts.append(emit_typebox(cfg_id, cfg))
		else:
			parts.append(emit_raw(cfg_id, cfg))
		parts.append(emit_step(step_id, kind, kind_name, cfg_id, title, body))
		step_ids.append(step_id)
		sub_count += 2

	load_steps = 5 + sub_count  # 5 ext + subs
	header = [
		f'[gd_resource type="Resource" script_class="PhaseSequenceList" load_steps={load_steps} format=3]',
		"",
		f'[ext_resource type="Script" path="{EXT["list"][1]}" id="{EXT["list"][0]}"]',
		f'[ext_resource type="Script" path="{EXT["step"][1]}" id="{EXT["step"][0]}"]',
		f'[ext_resource type="Script" path="{EXT["mochila"][1]}" id="{EXT["mochila"][0]}"]',
		f'[ext_resource type="Script" path="{EXT["typebox"][1]}" id="{EXT["typebox"][0]}"]',
		f'[ext_resource type="Script" path="{EXT["raw"][1]}" id="{EXT["raw"][0]}"]',
		"",
	]
	steps_arr = ", ".join(f'SubResource("{sid}")' for sid in step_ids)
	footer = [
		"[resource]",
		f'script = ExtResource("{EXT["list"][0]}")',
		f'steps = Array[ExtResource("{EXT["step"][0]}")]([{steps_arr}])',
		"",
	]
	text = "\n".join(header) + "\n".join(parts) + "\n".join(footer)
	OUT.write_text(text, encoding="utf-8")
	print(f"Wrote {OUT} with {len(PHASES)} phases ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
	main()
