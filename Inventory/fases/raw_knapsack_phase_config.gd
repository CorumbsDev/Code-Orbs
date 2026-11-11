class_name RawKnapsackPhaseConfig
extends BasePhaseConfig

@export var grid_columns: int = 4
@export var backpack_slot_count: int = 8
@export var pool_slot_count: int = 10
@export var pool_grid_columns: int = 5

## Valores sem tipo no pool (ex: "42", "3.14", "0.5").
@export var initial_raw_values: PackedStringArray = PackedStringArray(["7", "3.14", "42"])
@export var randomize_values: bool = false

## Tipos que o aluno pode escolher nas estações de tipagem (demais allow_* herdadas de BasePhaseConfig).
@export var allow_int: bool = true


func _init() -> void:
	allow_float = true


func apply_constraints() -> void:
	_apply_base_constraints()
	grid_columns = clampi(grid_columns, 1, 64)
	backpack_slot_count = clampi(backpack_slot_count, 1, 512)
	pool_slot_count = clampi(pool_slot_count, 1, 512)
	pool_grid_columns = clampi(pool_grid_columns, 1, 64)
