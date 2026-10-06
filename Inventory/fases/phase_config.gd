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
@export var fp8_exp_bits: int = 4
@export var fp8_mant_bits: int = 3
@export var fp16_exp_bits: int = 5
@export var fp16_mant_bits: int = 10
@export var allow_fp_customization: bool = false

## Limite de movimentos para ganhar a 2ª estrela. 0 significa que não é exigido.
@export var star2_max_moves: int = 0
## Solução ideal (CSV de atalhos) para ganhar a 3ª estrela. Vazio significa que não é exigido.
@export var star3_best_solution_csv: String = ""

## Garante limites válidos (capacidade, slots e faixa de valores INT).
func apply_constraints() -> void:
	capacity_bytes = clampi(capacity_bytes, 1, 4096)
	slot_bytes = 1 if slot_bytes <= 1 else 4
	grid_columns = clampi(grid_columns, 1, 64)
	backpack_slot_count = clampi(backpack_slot_count, 1, 512)
	pool_slot_count = clampi(pool_slot_count, 1, 512)
	pool_grid_columns = clampi(pool_grid_columns, 1, 64)
	min_bytes_random_pool = clampi(min_bytes_random_pool, 0, 8192)
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
