class_name TypeBoxPhaseConfig
extends BasePhaseConfig

const ItemRef = preload("res://Inventory/Items/item.gd")

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

## Caixas (tipos) permitidas na fase (demais allow_* herdadas de BasePhaseConfig).
@export var allow_int: bool = true

## Se false, não há limite/medidor de bytes: vence quem tipar todos os orbes corretamente.
@export var use_byte_limit: bool = false

## Tipos esperados por valor RAW (paralelo a initial_raw_values). Ex.: int,float,int
## Vazio = só valida bytes totais.
@export var expected_solution_types: PackedStringArray = PackedStringArray()


func _init() -> void:
	allow_float = true


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
	_apply_base_constraints()
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
