class_name BasePhaseConfig
extends Resource

## Capacidade total em bytes do desafio (mochila ou soma das caixas).
@export var capacity_bytes: int = 8
## 4 = cada slot é uma palavra (4 bytes). 1 = cada slot é 1 byte.
@export var slot_bytes: int = 4

## Flags de tipos de dados habilitados na fase.
@export var allow_float: bool = false
@export var allow_double: bool = false
@export var allow_short: bool = false
@export var allow_fp8: bool = false
@export var allow_fp16: bool = false

## Configuração de bits customizados para FP8 e FP16.
@export var fp8_exp_bits: int = 4
@export var fp8_mant_bits: int = 3
@export var fp16_exp_bits: int = 5
@export var fp16_mant_bits: int = 10

## Metas de estrelas comuns a todas as fases.
## Limite de movimentos para ganhar a 2ª estrela. 0 significa que não é exigido.
@export var star2_max_moves: int = 0
## Solução ideal (CSV de atalhos) para ganhar a 3ª estrela. Vazio significa que não é exigido.
@export var star3_best_solution_csv: String = ""

## Mensagens opcionais de tutorial associadas à configuração.
@export var custom_tutorial_title: String = ""
@export_multiline var custom_tutorial_text: String = ""


func _apply_base_constraints() -> void:
	capacity_bytes = clampi(capacity_bytes, 1, 4096)
	slot_bytes = 1 if slot_bytes <= 1 else 4
	fp8_exp_bits = clampi(fp8_exp_bits, 1, 6)
	fp8_mant_bits = clampi(fp8_mant_bits, 1, 7 - fp8_exp_bits)
	fp16_exp_bits = clampi(fp16_exp_bits, 1, 14)
	fp16_mant_bits = clampi(fp16_mant_bits, 1, 15 - fp16_exp_bits)
	star2_max_moves = maxi(0, star2_max_moves)


func has_any_type_flag() -> bool:
	return allow_float or allow_double or allow_short or allow_fp8 or allow_fp16

