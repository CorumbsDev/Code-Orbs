class_name InventoryGrid
extends Panel

signal slot_entered(slot)
signal slot_exited(slot)
signal item_changed(slot)

@export var capacity_bytes: int = 8
## 4 = palavra (até 4 bytes empilhados no slot). 1 = cada slot é uma célula de 1 byte.
@export var slot_bytes: int = 4
@export var number_of_slots: int = 8
@export var grid_columns: int = 4
@export var initial_items: Array[String] = ["item_number_5", "item_number_7", "item_operator_plus"]
@onready var grid_container = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer

var slots_array: Array = []


func _ready():
	if not grid_container:
		push_error("InventoryGrid: GridContainer inválido!")
		return
	grid_container.columns = grid_columns
	_create_slots()
	_fill_initial_items()


func _create_slots():
	for i in range(number_of_slots):
		var slot = preload("res://Inventory/slots/slot.tscn").instantiate()
		slot.slot_ID = i
		slot.state = slot.States.FREE
		slot.slot_bytes = slot_bytes
		grid_container.add_child(slot)
		slots_array.append(slot)
		slot.slot_entered.connect(_on_slot_entered)
		slot.slot_exited.connect(_on_slot_exited)
		slot.item_changed.connect(_on_slot_item_changed)


func clear_initial_items():
	initial_items.clear()


func _fill_initial_items():
	# Coloca respeitando o span (ex.: int em slot 1B = 4 células).
	# NÃO usar slots_array[i] como âncora — o 2º item sobrepõe o 1º.
	for item_id in initial_items:
		if str(item_id).strip_edges().is_empty():
			continue
		print("[DEBUG] InventoryGrid: Inicializando item com id '%s'" % str(item_id))
		var item = preload("res://Inventory/Items/Item.tscn").instantiate()
		item.load_item(str(item_id))
		MemoryLayout.apply_to_item(item, slot_bytes, grid_columns)
		var anchor = find_first_free_anchor_for(item)
		if anchor == null:
			push_warning("InventoryGrid: sem espaço para item inicial '%s'" % item_id)
			item.queue_free()
			continue
		place_item(item, anchor)


func _attach_item_to_slot(item: Node, slot: TextureRect) -> void:
	if not is_instance_valid(item) or not is_instance_valid(slot):
		return
	if item.get_parent() != slot:
		if item.get_parent():
			item.get_parent().remove_child(item)
		slot.add_child(item)
	item.z_index = 2
	_set_item_position_in_slot(item, slot)


func _set_item_position_in_slot(item: Node, slot: TextureRect) -> void:
	var anchor: TextureRect = slot
	if item.get("grid_anchor") != null and item.grid_anchor is TextureRect:
		anchor = item.grid_anchor
	if item.has_method("position_in_slot"):
		item.position = item.position_in_slot(anchor)
	else:
		var side: float = maxf(anchor.size.x, 64.0)
		item.position = Vector2(side, side) * 0.5


func refresh_item_positions() -> void:
	var positioned := {}
	for slot in slots_array:
		for it in slot.items_stored:
			if not is_instance_valid(it) or positioned.has(it):
				continue
			_set_item_position_in_slot(it, slot)
			positioned[it] = true


func total_bytes_used() -> int:
	var total = 0
	var counted := {}
	for slot in slots_array:
		for it in slot.items_stored:
			if it and it.has_method("get_size_bytes") and not counted.has(it):
				counted[it] = true
				total += it.get_size_bytes()
	return total


func can_place_item(item, slot) -> bool:
	if not item or not slot:
		return false
	MemoryLayout.apply_to_item(item, slot_bytes, grid_columns)
	var item_bytes = item.get_size_bytes() if item.has_method("get_size_bytes") else 4

	# RAW: um orbe por slot (pool visual), sem empilhar sub-células de 1 byte.
	if item_bytes == 0:
		for offset in item.item_grids:
			var idx0 = slot.slot_ID + int(offset.x) + int(offset.y) * grid_columns
			if idx0 < 0 or idx0 >= slots_array.size():
				return false
			if _slot_occupied_by_other(slots_array[idx0], item):
				return false
		return true

	# Célula de 1 byte: o tipo ocupa N slots seguidos (int = 4, short = 2).
	if MemoryLayout.normalize_slot_bytes(slot_bytes) == MemoryLayout.BYTE_SLOT:
		for offset in item.item_grids:
			var idx1 = slot.slot_ID + int(offset.x) + int(offset.y) * grid_columns
			if idx1 < 0 or idx1 >= slots_array.size():
				return false
			if _slot_occupied_by_other(slots_array[idx1], item):
				return false
		return true
	
	for offset in item.item_grids:
		var idx = slot.slot_ID + int(offset.x) + int(offset.y) * grid_columns
		if idx < 0 or idx >= slots_array.size():
			return false
		var target_slot = slots_array[idx]
		
		# Simulando o espaço de memória (4 blocos de 1 byte por slot)
		var current_grid = [null, null, null, null]
		for it in target_slot.items_stored:
			if it == item: continue
			var sz = it.get_size_bytes() if it.has_method("get_size_bytes") else 4
			if sz >= 4:
				current_grid[0] = it; current_grid[1] = it; current_grid[2] = it; current_grid[3] = it
			elif sz == 2:
				if current_grid[0] == null and current_grid[1] == null:
					current_grid[0] = it; current_grid[1] = it
				elif current_grid[2] == null and current_grid[3] == null:
					current_grid[2] = it; current_grid[3] = it
			elif sz <= 1:
				for i in range(4):
					if current_grid[i] == null:
						current_grid[i] = it
						break
		
		var can_fit = false
		if item_bytes >= 4:
			can_fit = (current_grid[0] == null and current_grid[1] == null and current_grid[2] == null and current_grid[3] == null)
		elif item_bytes == 2:
			can_fit = (current_grid[0] == null and current_grid[1] == null) or (current_grid[2] == null and current_grid[3] == null)
		elif item_bytes <= 1:
			can_fit = (current_grid[0] == null or current_grid[1] == null or current_grid[2] == null or current_grid[3] == null)
			
		if not can_fit:
			return false
	return true


func find_first_free_anchor_for(item) -> Variant:
	for slot in slots_array:
		if can_place_item(item, slot):
			return slot
	return null


func try_place_item_automatically(item: Node) -> bool:
	var item_id = str(item.get("item_ID")) if item.get("item_ID") != null else "unknown"
	print("[DEBUG] try_place_item_automatically para item_id '%s'" % item_id)
	var slot = find_first_free_anchor_for(item)
	if slot == null:
		print("[DEBUG] FALHOU em try_place_item_automatically para item_id '%s'" % item_id)
		return false
	place_item(item, slot)
	print("[DEBUG] SUCESSO em try_place_item_automatically para item_id '%s' no slot %d" % [item_id, slot.slot_ID])
	return true


func place_item(item, slot):
	if not grid_container:
		push_error("InventoryGrid: grid_container is null")
		return
	MemoryLayout.apply_to_item(item, slot_bytes, grid_columns)
	remove_item(item)
	# Âncora + attach ANTES dos add_item (item_changed/snap usam grid_anchor).
	item.grid_anchor = slot
	_attach_item_to_slot(item, slot)
	for offset in item.item_grids:
		var idx = slot.slot_ID + int(offset.x) + int(offset.y) * grid_columns
		if idx < 0 or idx >= slots_array.size():
			continue
		var target_slot = slots_array[idx]
		target_slot.add_item(item)
		_paint_slot(target_slot)


func remove_item(item):
	for slot in slots_array:
		if slot.items_stored.has(item):
			if item.get_parent() == slot:
				slot.remove_child(item)
			slot.remove_item(item)
			_paint_slot(slot)


func _slot_occupied_by_other(target_slot, item) -> bool:
	for it in target_slot.items_stored:
		if it != item:
			return true
	return false


func _slot_is_full(target_slot) -> bool:
	if MemoryLayout.normalize_slot_bytes(slot_bytes) == MemoryLayout.BYTE_SLOT:
		return target_slot.items_stored.size() > 0
	return target_slot.get_used_bytes() >= MemoryLayout.WORD_BYTES


func _paint_slot(target_slot) -> void:
	if target_slot.items_stored.is_empty():
		target_slot.state = target_slot.States.FREE
	elif MemoryLayout.normalize_slot_bytes(slot_bytes) == MemoryLayout.BYTE_SLOT:
		target_slot.state = target_slot.States.TAKEN
	elif target_slot.get_used_bytes() >= MemoryLayout.WORD_BYTES:
		target_slot.state = target_slot.States.TAKEN
	elif target_slot.get_used_bytes() > 0:
		target_slot.state = target_slot.States.PARTIAL
	else:
		target_slot.state = target_slot.States.TAKEN
	target_slot.set_color(target_slot.state)


func clear_all_items():
	if not grid_container:
		push_error("InventoryGrid: grid_container is null.")
		return
	for slot in slots_array:
		for item in slot.items_stored.duplicate():
			if is_instance_valid(item) and item.get_parent():
				item.get_parent().remove_child(item)
			if is_instance_valid(item):
				item.queue_free()
		slot.clear_items()
		slot.state = slot.States.FREE
		slot.set_color(slot.state)
	initial_items.clear()


func remove_item_single_slot(slot):
	# Compatível com código antigo que liberava um slot do pool
	if slot.items_stored.size() > 0:
		var it = slot.items_stored[0]
		remove_item(it)


func _on_slot_entered(slot):
	slot_entered.emit(slot)


func _on_slot_exited(slot):
	slot_exited.emit(slot)


func _on_slot_item_changed(slot):
	for it in slot.items_stored:
		if not is_instance_valid(it):
			continue
		# Só reposiciona a partir da âncora (evita reparent em célula secundária).
		var mount = it.grid_anchor if it.grid_anchor is TextureRect else slot
		if mount != slot and it.grid_anchor != null:
			continue
		if it.has_method("snap_to_slot"):
			it.snap_to_slot(mount)
		else:
			_set_item_position_in_slot(it, mount)
	item_changed.emit(slot)


func get_all_items() -> Array:
	var list := []
	for slot in slots_array:
		for it in slot.items_stored:
			if is_instance_valid(it) and not list.has(it):
				list.append(it)
	return list


func pack_items_left() -> void:
	var items = get_all_items()
	for slot in slots_array:
		slot.clear_items()
		slot.state = slot.States.FREE
		slot.set_color(slot.state)
	for it in items:
		try_place_item_automatically(it)

