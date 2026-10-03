class_name ConverterTool
extends RefCounted

var phase: Node
var slot: TextureRect
var option_btn: OptionButton
var _converter_syncing: bool = false

func _init(_phase: Node, _slot: TextureRect, _option_btn: OptionButton):
	phase = _phase
	slot = _slot
	option_btn = _option_btn
	if option_btn:
		option_btn.item_selected.connect(_on_type_changed)

func target_item() -> Node:
	if slot and slot.item_stored:
		return slot.item_stored
	if phase.item_held and is_instance_valid(phase.item_held):
		return phase.item_held
	return null

func revert_dropdown(dt: int) -> void:
	if not option_btn:
		return
	var revert_str := TypeConversionSystem.get_type_string(dt)
	_converter_syncing = true
	for i in range(option_btn.item_count):
		if option_btn.get_item_text(i) == revert_str:
			option_btn.select(i)
			break
	_converter_syncing = false

func mount_item(item: Node) -> void:
	if item == null or not is_instance_valid(item) or slot == null:
		return
	item.grid_anchor = slot
	var parent = item.get_parent()
	if parent != slot:
		if parent:
			parent.remove_child(item)
		slot.add_child(item)
	if item.has_method("shrink_orb_for_tool_slot"):
		item.shrink_orb_for_tool_slot()
	if item.has_method("snap_to_slot"):
		item.snap_to_slot(slot)
	else:
		item.position = slot.size * 0.5
	item.selected = false
	slot.item_stored = item
	slot.state = slot.States.TAKEN

func convert_with_dialog(item: Node, mount_on_converter: bool) -> bool:
	if item == null or not is_instance_valid(item):
		return false
	var target_type_str := option_btn.get_item_text(option_btn.selected) if option_btn else "Float"
	var config = phase.get("config") if phase.has_method("get") else null
	var deg := TypeConversionSystem.check_degradation(target_type_str, TypeConversionSystem.value_for_conversion(item), config)
	
	var prev_priority := TypeConversionSystem.get_type_priority(item)
	if deg.has_warning:
		var dlg := ConfirmationDialog.new()
		dlg.dialog_text = deg.message + "\n\nDeseja converter assim mesmo?"
		dlg.title = "Aviso de Degradação"
		dlg.ok_button_text = "Prosseguir"
		dlg.cancel_button_text = "Cancelar"
		phase.add_child(dlg)
		dlg.popup_centered(Vector2(450, 150))
		var res = await phase._wait_for_dialog(dlg)
		dlg.queue_free()
		if not res:
			return false
		_notify_convert_warning(deg.message, prev_priority, target_type_str)
			
	if not is_instance_valid(item):
		return false
		
	TypeConversionSystem.apply_target_type_to_item(item, target_type_str, deg.degraded_value, config)
	_note_upgrade_if_any(prev_priority, item)
	
	if mount_on_converter:
		mount_item(item)
	return true

func _on_type_changed(_index: int):
	if _converter_syncing:
		return
	var item := target_item()
	if item == null or not is_instance_valid(item):
		return
	var previous_dt: int = item.data_type
	var target_type_str := option_btn.get_item_text(option_btn.selected) if option_btn else "Float"
	
	var config = phase.get("config") if phase.has_method("get") else null
	var deg := TypeConversionSystem.check_degradation(target_type_str, TypeConversionSystem.value_for_conversion(item), config)
	
	var prev_priority := TypeConversionSystem.priority_for_data_type(previous_dt)
	if deg.has_warning:
		var dlg := ConfirmationDialog.new()
		dlg.dialog_text = deg.message + "\n\nDeseja prosseguir mesmo assim?"
		dlg.title = "Aviso de Degradação de Dados"
		dlg.ok_button_text = "Prosseguir"
		dlg.cancel_button_text = "Cancelar"
		phase.add_child(dlg)
		dlg.popup_centered(Vector2(450, 150))
		var res = await phase._wait_for_dialog(dlg)
		dlg.queue_free()
		if not res:
			revert_dropdown(previous_dt)
			return
		_notify_convert_warning(deg.message, prev_priority, target_type_str)
			
	if not is_instance_valid(item):
		return
		
	TypeConversionSystem.apply_target_type_to_item(item, target_type_str, deg.degraded_value, config)
	_note_upgrade_if_any(prev_priority, item)
	
	if phase.has_method("_update_bytes_label"):
		phase._update_bytes_label()
	if phase.has_method("_update_hint"):
		phase._update_hint()


func _notify_convert_warning(message: String, prev_priority: int, target_type_str: String) -> void:
	if AchievementManager == null:
		return
	if message.begins_with("Overflow"):
		AchievementManager.note_runtime_event("overflow")
	elif message.begins_with("Underflow"):
		AchievementManager.note_runtime_event("underflow")
	elif "Perda de precisão" in message:
		var target_dt := _data_type_from_label(target_type_str)
		var new_p := TypeConversionSystem.priority_for_data_type(target_dt)
		if new_p < prev_priority:
			AchievementManager.note_runtime_event("forced_cast")


func _note_upgrade_if_any(prev_priority: int, item: Node) -> void:
	if phase == null or item == null:
		return
	var new_p := TypeConversionSystem.get_type_priority(item)
	if new_p > prev_priority:
		phase.set_meta("upgraded_type_before_op", true)


func _data_type_from_label(label: String) -> int:
	var ItemRef = preload("res://Inventory/Items/item.gd")
	match label:
		"Int": return ItemRef.DataType.INT
		"Float": return ItemRef.DataType.FLOAT
		"Double": return ItemRef.DataType.DOUBLE
		"Short": return ItemRef.DataType.SHORT_INT
		"FP8": return ItemRef.DataType.FP8
		"FP16": return ItemRef.DataType.FP16
		_: return ItemRef.DataType.FLOAT
