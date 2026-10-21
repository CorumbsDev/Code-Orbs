class_name TypeBoxPhaseConfig
extends Resource

const ItemRef = preload("res://Inventory/Items/item.gd")

## Capacidade total em bytes permitida para a fase (soma de todas as caixas).
@export var capacity_bytes: int = 8
## 4 = palavra. 1 = cada slot visual vale 1 byte.
@export var slot_bytes: int = 4

## Valores puros iniciais que o jogador deve tipar. (ex: "250_raw", "3.14_raw").
@export var initial_raw_values: PackedStringArray = PackedStringArray()

## Se verdadeiro, gera valores aleatórios "interessantes" ignorando initial_raw_values.
@export var randomize_values: bool = false

## Quantidade de espaços (slots) visíveis em cada caixa de tipagem.
@export var box_slot_count: int = 5

## Quantidade de slots por tipo (cada tipo com > 0 slots terá sua própria linha)
@export var slots_int: int = 2
@export var slots_float: int = 3
@export var slots_short: int = 0
@export var slots_double: int = 0
@export var slots_fp8: int = 0
@export var slots_fp16: int = 0

## Legado / Compatibilidade
@export var grid_rows: int = 1
@export var max_int_per_row: int = 2
@export var max_float_per_row: int = 3
@export var max_short_per_row: int = 0
@export var max_double_per_row: int = 0
@export var max_fp8_per_row: int = 0
@export var max_fp16_per_row: int = 0

## Caixas (tipos) permitidas na fase.
@export var allow_int: bool = true
@export var allow_short: bool = false
@export var allow_float: bool = true
@export var allow_double: bool = false
@export var allow_fp8: bool = false
@export var allow_fp16: bool = false

@export var fp8_exp_bits: int = 4
@export var fp8_mant_bits: int = 3
@export var fp16_exp_bits: int = 5
@export var fp16_mant_bits: int = 10

## Limite de movimentos para ganhar a 2ª estrela. 0 significa que não é exigido.
@export var star2_max_moves: int = 0
## Solução ideal (CSV de atalhos) para ganhar a 3ª estrela. Vazio significa que não é exigido.
@export var star3_best_solution_csv: String = ""

## Se false, não há limite/medidor de bytes: vence quem tipar todos os orbes corretamente.
@export var use_byte_limit: bool = false

## Tipos esperados por valor RAW (paralelo a initial_raw_values). Ex.: int,float,int
## Vazio = só valida bytes totais.
@export var expected_solution_types: PackedStringArray = PackedStringArray()

func get_slots_for_type(dt: int) -> int:
	match dt:
		ItemRef.DataType.INT: return slots_int
		ItemRef.DataType.FLOAT: return slots_float
		ItemRef.DataType.DOUBLE: return slots_double
		ItemRef.DataType.SHORT_INT: return slots_short
		ItemRef.DataType.FP8: return slots_fp8
		ItemRef.DataType.FP16: return slots_fp16
		_: return 0

func get_total_backpack_slots() -> int:
	return slots_int + slots_float + slots_short + slots_double + slots_fp8 + slots_fp16

func get_slots_per_row() -> int:
	return maxi(slots_int, maxi(slots_float, maxi(slots_short, maxi(slots_double, maxi(slots_fp8, slots_fp16)))))

func get_max_for_type(dt: int) -> int:
	return get_slots_for_type(dt)

func apply_constraints() -> void:
	slots_int = clampi(slots_int, 0, 20)
	slots_float = clampi(slots_float, 0, 20)
	slots_short = clampi(slots_short, 0, 20)
	slots_double = clampi(slots_double, 0, 20)
	slots_fp8 = clampi(slots_fp8, 0, 20)
	slots_fp16 = clampi(slots_fp16, 0, 20)
	allow_int = (slots_int > 0)
	allow_float = (slots_float > 0)
	allow_short = (slots_short > 0)
	allow_double = (slots_double > 0)
	allow_fp8 = (slots_fp8 > 0)
	allow_fp16 = (slots_fp16 > 0)
	max_int_per_row = slots_int
	max_float_per_row = slots_float
	max_short_per_row = slots_short
	max_double_per_row = slots_double
	max_fp8_per_row = slots_fp8
	max_fp16_per_row = slots_fp16
	var active_rows := 0
	if slots_int > 0: active_rows += 1
	if slots_short > 0: active_rows += 1
	if slots_float > 0: active_rows += 1
	if slots_double > 0: active_rows += 1
	if slots_fp8 > 0: active_rows += 1
	if slots_fp16 > 0: active_rows += 1
	grid_rows = maxi(1, active_rows)
	box_slot_count = get_slots_per_row()
	capacity_bytes = clampi(capacity_bytes, 1, 4096)
	slot_bytes = 1 if slot_bytes <= 1 else 4
