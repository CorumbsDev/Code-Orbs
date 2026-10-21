class_name PhaseSequenceStep
extends Resource

enum Kind { MOCHILA, BINARIO, TYPE_BOX, RAW_MOCHILA, CONVERSAO }

## Fase de completar 1 bit (binary_phase). Desligada até reativarmos no jogo.
const BINARY_PHASES_ENABLED := false
## Fase decimal → binário (conversion_phase). Desligada até reativarmos no jogo.
const CONVERSION_PHASES_ENABLED := false


static func binary_phases_enabled() -> bool:
	return BINARY_PHASES_ENABLED


static func conversion_phases_enabled() -> bool:
	return CONVERSION_PHASES_ENABLED


static func is_kind_playable(step_kind: Kind) -> bool:
	match step_kind:
		Kind.BINARIO:
			return binary_phases_enabled()
		Kind.CONVERSAO:
			return conversion_phases_enabled()
		_:
			return true


static func filter_playable_steps(steps: Array) -> Array:
	var out: Array = []
	for s in steps:
		if not (s is PhaseSequenceStep):
			continue
		if not is_kind_playable(s.kind):
			continue
		out.append(s)
	return out

## Tipo de fase na sequência.
@export var kind: Kind = Kind.MOCHILA
## Preencher quando kind == MOCHILA (pode ficar null para usar defaults da mochila).
@export var config_mochila: PhaseConfig
## Preencher quando kind == BINARIO (pode ficar null para padrão 1 _ 0).
@export var config_binario: BinaryPhaseConfig
## Preencher quando kind == TYPE_BOX
@export var config_type_box: TypeBoxPhaseConfig
## Preencher quando kind == RAW_MOCHILA (mochila + orbes RAW para tipar).
@export var config_raw_mochila: RawKnapsackPhaseConfig
## Preencher quando kind == CONVERSAO (decimal → binário).
@export var config_conversao: ConversionPhaseConfig
## Habilita um tutorial personalizado
@export var use_custom_tutorial: bool = false
## Título customizado do tutorial.
@export var custom_tutorial_title: String = ""
## Texto customizado do tutorial (corpo).
@export_multiline var custom_tutorial_text: String = ""


## Mantém só o config do `kind` atual. Configs de outros tipos no mesmo
## step fazem o ResourceSaver gravar lixo e, em edições seguintes, a
## fase pode voltar a tocar como MOCHILA em vez do tipo certo.
func sanitize_configs_for_kind() -> void:
	if kind != Kind.MOCHILA:
		config_mochila = null
	if kind != Kind.BINARIO:
		config_binario = null
	if kind != Kind.TYPE_BOX:
		config_type_box = null
	if kind != Kind.RAW_MOCHILA:
		config_raw_mochila = null
	if kind != Kind.CONVERSAO:
		config_conversao = null
