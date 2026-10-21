extends RefCounted
class_name ConfigGenerator

static var data_handler: Node

## Gera PhaseConfig para mochila com params + constraints
static func generate_knapsack_config(
	_capacity: int = 8,
	backpack_slots: int = 8,
	pool_slots: int = 10,
	grid_cols: int = 4,
	int_min: int = 1,
	int_max: int = 10,
	initial_csv: String = "",
	random_pool_size: int = 4,
	use_converter: bool = false
) -> PhaseConfig:
	var config = PhaseConfig.new()
	config.backpack_slot_count = clampi(backpack_slots, 1, 64)
	# Capacidade em bytes independente dos slots (slots = grade visual).
	config.capacity_bytes = clampi(_capacity, 1, 4096)
	config.pool_slot_count = clampi(pool_slots, 8, 40)
	config.grid_columns = clampi(grid_cols, 2, 8)
	config.spawn_int_min = int_min
	config.spawn_int_max = int_max
	config.initial_backpack_csv = initial_csv
	config.min_bytes_random_pool = 0
	
	config.random_pool = _random_int_items(random_pool_size)
	config.use_converter = use_converter
	
	
	config.apply_constraints()
	return config

static func generate_binary_config(left_bit: int = 1, right_bit: int = 0) -> BinaryPhaseConfig:
	var config = BinaryPhaseConfig.new()
	config.fixed_left_bit = clampi(left_bit, 0, 1)
	config.fixed_right_bit = clampi(right_bit, 0, 1)
	config.apply_constraints()
	return config


static func generate_conversion_config(
	bits: int = 3,
	decimals: Array = [5, 3, 6],
	delay_s: float = 2.4
) -> ConversionPhaseConfig:
	var config := ConversionPhaseConfig.new()
	config.num_bits = clampi(bits, 1, 16)
	var vals: Array[int] = []
	for v in decimals:
		vals.append(maxi(0, int(v)))
	config.challenge_decimals = vals if not vals.is_empty() else [5, 3, 6]
	config.advance_delay_seconds = maxf(delay_s, 0.3)
	config.apply_constraints()
	return config

static func generate_raw_knapsack_config(
	capacity: int = 8,
	backpack_slots: int = 8,
	pool_slots: int = 10,
	grid_cols: int = 4,
	raw_values: Array = ["7", "3.14", "42"]
) -> RawKnapsackPhaseConfig:
	var config := RawKnapsackPhaseConfig.new()
	config.capacity_bytes = clampi(capacity, 1, 4096)
	config.backpack_slot_count = clampi(backpack_slots, 1, 512)
	config.pool_slot_count = clampi(pool_slots, 4, 64)
	config.grid_columns = clampi(grid_cols, 2, 8)
	config.pool_grid_columns = 5
	config.initial_raw_values = PackedStringArray(raw_values)
	config.allow_int = true
	config.allow_float = true
	config.allow_short = false
	config.apply_constraints()
	return config


static func generate_type_box_config(capacity: int = 8, raw_values: Array = ["250", "3.14", "1"]) -> TypeBoxPhaseConfig:
	var config = TypeBoxPhaseConfig.new()
	config.capacity_bytes = capacity
	config.initial_raw_values = PackedStringArray(raw_values)
	config.slots_int = 2
	config.slots_float = 3
	config.slots_short = 0
	config.slots_double = 0
	config.slots_fp8 = 0
	config.slots_fp16 = 0
	config.apply_constraints()
	return config

static func generate_sequence(num_phases: int, mix_types: bool = true, base_knapsack_params: Dictionary = {}) -> Array:
	var steps: Array = []
	var phase_count := clampi(num_phases, 1, 99)  # Permitir até 99 fases
	var _base_capacity := int(base_knapsack_params.get("capacity", 8))  # Base para referência
	var base_backpack_slots := int(base_knapsack_params.get("backpack_slots", base_knapsack_params.get("slots", 8)))
	var base_pool_slots := int(base_knapsack_params.get("pool_slots", 10))
	var base_grid_cols := int(base_knapsack_params.get("grid_cols", 4))
	var base_int_min := int(base_knapsack_params.get("int_min", 1))
	var base_int_max := int(base_knapsack_params.get("int_max", 10))
	var initial_csv := str(base_knapsack_params.get("initial_csv", ""))
	var random_pool_size := int(base_knapsack_params.get("random_pool_size", 4))
	var vary_capacity := bool(base_knapsack_params.get("vary_capacity", true))
	var vary_int_max := bool(base_knapsack_params.get("vary_int_max", true))
	var use_converter := bool(base_knapsack_params.get("use_converter", false))

	for i in range(phase_count):
		var step = PhaseSequenceStep.new()
		var use_binary = PhaseSequenceStep.binary_phases_enabled() and mix_types and (i % 3 == 1)
		var use_type_box = mix_types and (i % 3 == 2)
		if use_binary:
			step.kind = PhaseSequenceStep.Kind.BINARIO
			step.config_binario = generate_binary_config(randi() % 2, randi() % 2)
		elif use_type_box:
			step.kind = PhaseSequenceStep.Kind.TYPE_BOX
			# Gera valores aleatórios para a fase de caixas
			var raw_vals = []
			for r in range(4):
				var is_float = randi() % 2 == 0
				if is_float:
					raw_vals.append(str(snapped(randf_range(1.0, 100.0), 0.01)))
				else:
					raw_vals.append(str(randi_range(1, 40000))) # Alguns podem precisar de int em vez de short
			step.config_type_box = generate_type_box_config(base_knapsack_params.get("capacity", 8), raw_vals)
		else:
			step.kind = PhaseSequenceStep.Kind.MOCHILA
			# Variação MÍNIMA - apenas para diferenciar um pouco
			var varying_slots = base_backpack_slots + (i if vary_capacity else 0)  # +1 a cada fase
			var varying_int_min = base_int_min  # Não varia
			var varying_int_max = base_int_max + (i if vary_int_max else 0)  # +1 a cada fase
			var varying_capacity = _base_capacity  # Não varia
			var varying_pool = base_pool_slots + (i if vary_capacity else 0)  # +1 a cada fase
			
			step.config_mochila = generate_knapsack_config(
				varying_capacity,
				varying_slots,
				varying_pool,
				base_grid_cols,
				varying_int_min,
				varying_int_max,
				initial_csv,
				random_pool_size,
				use_converter
			)
		steps.append(step)
	return steps

static func _random_int_items(count: int) -> PackedStringArray:
	if not data_handler or not data_handler.item_data:
		return PackedStringArray(["item_number_5", "item_number_7"])
	
	var int_items: Array = []
	for id in data_handler.item_data:
		var data = data_handler.item_data[id]
		if data.get("DataType") == "INT":
			int_items.append(id)
	
	int_items.shuffle()
	var out: PackedStringArray = []
	for i in range(min(count, int_items.size())):
		out.append(int_items[i])
	return out

static func init_with_data_handler(dh: Node):
	data_handler = dh
