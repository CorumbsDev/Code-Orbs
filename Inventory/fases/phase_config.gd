class_name PhaseConfig
extends Resource

## Capacidade em bytes da mochila do desafio (lado esquerdo).
@export var capacity_bytes: int = 8
## 4 = cada slot é uma palavra. 1 = cada slot é 1 byte (células, estilo fase binária).
@export var slot_bytes: int = 4
@export var grid_columns: int = 4
## Quantidade de slots visíveis na mochila (grade do desafio).
@export var backpack_slot_count: int = 8
## Slots na bancada / pool de itens.
@export var pool_slot_count: int = 10
@export var pool_grid_columns: int = 5
## Intervalo inclusivo para INT aleatório (spawn e preenchimento sem random_pool).
@export var spawn_int_min: int = 0
@export var spawn_int_max: int = 99
## Itens iniciais na bancada (pool). Atalhos: "42_i", "3.14_f", "2.5_D" ou IDs do DataHandler (ex: "item_number_5").
## Nome do campo mantido por compatibilidade com CSV/sequências já exportadas.
@export var initial_backpack_items: PackedStringArray = PackedStringArray()
## Se não vazio, substitui initial_backpack_items (valores separados por vírgula, mesmo formato dos atalhos).
@export var initial_backpack_csv: String = ""
## Itens fixos no pool antes do sorteio (IDs ou atalhos).
@export var initial_pool_items: PackedStringArray = PackedStringArray()
## Sorteia apenas IDs existentes em DataHandler.item_data (ex: "item_number_3").
@export var random_pool: PackedStringArray = PackedStringArray()
## Metas de bytes adicionados por itens sortidos no pool (após os fixos). Se 0, completa até capacity_bytes com extras na bancada (descontando os itens fixos já colocados).
@export var min_bytes_random_pool: int = 0
@export var use_converter: bool = false
@export var allow_float: bool = false
@export var allow_double: bool = false
@export var allow_short: bool = false
@export var allow_fp8: bool = false
@export var allow_fp16: bool = false
@export var allow_calc: bool = false
## Limite de usos da Calculadora (0 = ilimitado, >= 1 = máximo de operações permitidas).
@export var calc_max_uses: int = 1
@export var fp8_exp_bits: int = 4
@export var fp8_mant_bits: int = 3
@export var fp16_exp_bits: int = 5
@export var fp16_mant_bits: int = 10
@export var allow_fp_customization: bool = false
## Se true, o menu principal NÃO sobrescreve use_converter/allow_* ao jogar (a fase define as ferramentas).
@export var respect_tool_flags: bool = true
## Se true, o Inspetor de orbes é criado mesmo sem a Calculadora.
@export var allow_inspector: bool = true
## Se true, a bancada contém apenas os orbes fixos (nenhum orbe aleatório extra é injetado).
@export var fixed_pool_only: bool = true
## Condição de bytes da mochila: EXACT_FILL (bytes == capacidade) ou FIT_WITHIN (0 < bytes <= capacidade).
@export_enum("EXACT_FILL", "FIT_WITHIN") var win_mode: int = 0

## Perde 1 estrela se houve truncamento/overflow/absorção ou se algum orbe da mochila excede error_tolerance_rel.
@export var penalize_truncation_and_overflow: bool = true
## Bloqueia a vitória se algum orbe da mochila colapsou para 0.0 partindo de um valor diferente de zero (ex.: Fases 10 e 12).
@export var forbid_underflow_zero: bool = false
## Bloqueia a vitória se algum orbe da mochila for Inf/NaN ou tiver estourado (overflow inteiro).
@export var forbid_overflow_inf: bool = true
## Tolerância relativa de erro (0.01 = 1%). Ex.: 0.001 na Fase 9, 0.02 na Fase 11.
@export var error_tolerance_rel: float = 0.01
## Valores que devem estar presentes na mochila (CSV, dentro de error_tolerance_rel). Ex.: "40000,16777217,0.0005,1.5". Vazio = não exige.
@export var required_values_csv: String = ""

## Limite de movimentos para ganhar a 2ª estrela. 0 significa que não é exigido.
@export var star2_max_moves: int = 0
## Solução ideal (CSV de atalhos) para ganhar a 3ª estrela. Vazio significa que não é exigido.
@export var star3_best_solution_csv: String = ""

## Retorna true se qualquer tipo de conversor estiver habilitado na fase.
func has_any_converter() -> bool:
	return use_converter or allow_float or allow_double or allow_short or allow_fp8 or allow_fp16

## Garante limites válidos (capacidade, slots e faixa de valores INT).
func apply_constraints() -> void:
	capacity_bytes = clampi(capacity_bytes, 1, 4096)
	slot_bytes = 1 if slot_bytes <= 1 else 4
	grid_columns = clampi(grid_columns, 1, 64)
	backpack_slot_count = clampi(backpack_slot_count, 1, 512)
	pool_slot_count = clampi(pool_slot_count, 1, 512)
	pool_grid_columns = clampi(pool_grid_columns, 1, 64)
	min_bytes_random_pool = clampi(min_bytes_random_pool, 0, 8192)
	calc_max_uses = clampi(calc_max_uses, 0, 99)
	spawn_int_min = clampi(spawn_int_min, -2147483648, 2147483647)
	spawn_int_max = clampi(spawn_int_max, -2147483648, 2147483647)
	if spawn_int_min > spawn_int_max:
		var t := spawn_int_min
		spawn_int_min = spawn_int_max
		spawn_int_max = t


func clamp_int_value(v: int) -> int:
	return clampi(v, spawn_int_min, spawn_int_max)


func get_backpack_entry_list() -> PackedStringArray:
	if initial_backpack_csv.strip_edges() != "":
		var out: PackedStringArray = PackedStringArray()
		for part in initial_backpack_csv.split(",", false):
			var s = part.strip_edges()
			if not s.is_empty():
				out.append(s)
		return out
	return initial_backpack_items
