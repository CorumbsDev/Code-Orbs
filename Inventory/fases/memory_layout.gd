class_name MemoryLayout
extends RefCounted

## Dois jeitos de o mesmo tipo ocupar a memória.
## slot de 4 bytes = uma palavra (int cabe em 1 slot, short na metade).
## slot de 1 byte = célula, no espírito da fase binária (int ocupa 4 células, short ocupa 2).

const WORD_BYTES := 4
const BYTE_SLOT := 1


static func normalize_slot_bytes(n: int) -> int:
	return BYTE_SLOT if int(n) <= 1 else WORD_BYTES


static func select_option(opt: OptionButton, slot_bytes: int) -> void:
	if opt == null:
		return
	var want := normalize_slot_bytes(slot_bytes)
	opt.set_block_signals(true)
	for i in opt.item_count:
		if opt.get_item_id(i) == want:
			opt.select(i)
			break
	opt.set_block_signals(false)


static func read_option(opt: OptionButton) -> int:
	if opt == null or opt.selected < 0:
		return WORD_BYTES
	return normalize_slot_bytes(opt.get_selected_id())


static func int_struct() -> Dictionary:
	return {
		"nome": "int",
		"bytes": 4,
		"no_slot_de_4": {"slots": 1, "como": "ocupa a palavra inteira"},
		"no_slot_de_1": {"slots": 4, "como": "4 células de 1 byte em sequência"},
	}


static func short_struct() -> Dictionary:
	return {
		"nome": "short int",
		"bytes": 2,
		"no_slot_de_4": {"slots": 1, "como": "metade da palavra (2 bytes)"},
		"no_slot_de_1": {"slots": 2, "como": "2 células de 1 byte em sequência"},
	}


static func slots_occupied(type_bytes: int, slot_bytes: int) -> int:
	var sb := normalize_slot_bytes(slot_bytes)
	var b := maxi(int(type_bytes), 0)
	if b == 0:
		return 1
	if sb == BYTE_SLOT:
		return b
	return maxi(1, int(ceil(float(b) / float(WORD_BYTES))))


## Grava em item.item_grids o formato certo para a grade de destino.
static func apply_to_item(item, slot_bytes: int, grid_columns: int) -> void:
	if item == null:
		return
	var sb := normalize_slot_bytes(slot_bytes)
	var cols := maxi(int(grid_columns), 1)
	var prev_sb: int = int(item.get_meta("slot_bytes", -1)) if item.has_meta("slot_bytes") else -1
	var prev_cols: int = int(item.get_meta("grid_columns", -1)) if item.has_meta("grid_columns") else -1
	item.set_meta("slot_bytes", sb)
	item.set_meta("grid_columns", cols)
	var nbytes := 4
	if item.has_method("get_size_bytes"):
		nbytes = int(item.get_size_bytes())
	var span := 1
	if nbytes <= 0:
		span = 1
	elif sb == BYTE_SLOT:
		span = nbytes
	elif nbytes >= 8:
		span = 2
	var prev_span: int = item.item_grids.size() if item.get("item_grids") != null else 0
	item.item_grids = _span_cells(span, cols)
	if (prev_sb != sb or prev_cols != cols or prev_span != span) and item.has_method("update_label_display"):
		item.update_label_display()


static func _span_cells(span: int, columns: int) -> Array:
	var grids: Array = []
	var n := maxi(span, 1)
	var cols := mini(maxi(columns, 1), WORD_BYTES)
	for i in n:
		grids.append(Vector2(i % cols, int(floor(float(i) / float(cols)))))
	return grids
