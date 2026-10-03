class_name CalculatorTool
extends RefCounted

var phase: Node
var slot_1: TextureRect
var slot_2: TextureRect
var slot_result: TextureRect
var op_btn: Button

func _init(_phase: Node, _slot_1: TextureRect, _slot_2: TextureRect, _slot_result: TextureRect, _op_btn: Button):
	phase = _phase
	slot_1 = _slot_1
	slot_2 = _slot_2
	slot_result = _slot_result
	op_btn = _op_btn

func clear_result() -> void:
	if slot_result == null or slot_result.item_stored == null:
		return
	var old = slot_result.item_stored
	slot_result.item_stored = null
	slot_result.state = slot_result.States.FREE
	if is_instance_valid(old):
		old.queue_free()

func mount_item(slot: TextureRect, item: Node) -> void:
	if item.get_parent() != slot:
		if item.get_parent():
			item.get_parent().remove_child(item)
		slot.add_child(item)
	if item.has_method("shrink_orb_for_tool_slot"):
		item.shrink_orb_for_tool_slot()
	if item.has_method("snap_to_slot"):
		item.snap_to_slot(slot)
	else:
		item.position = slot.size * 0.5
	item.grid_anchor = slot
	item.selected = false
	slot.item_stored = item
	slot.state = slot.States.TAKEN

func check_calculator() -> void:
	if slot_1 and slot_2 and op_btn and slot_result:
		if slot_1.item_stored != null and slot_2.item_stored != null:
			var item1 = slot_1.item_stored
			var item2 = slot_2.item_stored
			
			var val1 = item1.value_float if item1.data_type in [item1.DataType.FLOAT, item1.DataType.DOUBLE] else float(item1.value)
			var val2 = item2.value_float if item2.data_type in [item2.DataType.FLOAT, item2.DataType.DOUBLE] else float(item2.value)
			
			var p1 = TypeConversionSystem.get_type_priority(item1)
			var p2 = TypeConversionSystem.get_type_priority(item2)
			var target_type = item1.data_type if p1 >= p2 else item2.data_type
			var target_type_str = TypeConversionSystem.get_type_string(target_type)
			
			var result_val = 0.0
			if op_btn.text == "+":
				result_val = val1 + val2
			else:
				result_val = val1 - val2
				
			var deg = TypeConversionSystem.check_degradation(target_type_str, result_val, phase.get("config") if phase.has_method("get") else null)
			if deg.has_warning:
				var dlg = ConfirmationDialog.new()
				dlg.dialog_text = deg.message + "\n\nDeseja prosseguir com o cálculo?"
				dlg.title = "Aviso da Calculadora"
				dlg.ok_button_text = "Prosseguir"
				dlg.cancel_button_text = "Cancelar"
				phase.add_child(dlg)
				dlg.popup_centered(Vector2(450, 150))
				var res = await phase._wait_for_dialog(dlg)
				dlg.queue_free()
				if not res:
					return
				_notify_calc_warning(deg.message)
			
			if item1.data_type != item2.data_type and AchievementManager:
				AchievementManager.note_runtime_event("code_chameleon")
			if phase and phase.has_meta("upgraded_type_before_op") and phase.get_meta("upgraded_type_before_op") \
					and AchievementManager:
				AchievementManager.note_runtime_event("one_step_ahead")
				phase.set_meta("upgraded_type_before_op", false)
			
			var src_types := {item1.data_type: true, item2.data_type: true}
			item1.queue_free()
			item2.queue_free()
			slot_1.item_stored = null
			slot_1.state = slot_1.States.FREE
			slot_2.item_stored = null
			slot_2.state = slot_2.States.FREE
			
			clear_result()
			var new_item: Node2D = preload("res://Inventory/Items/Item.tscn").instantiate()
			var final_val = deg.degraded_value
			
			var config = phase.get("config") if phase.has_method("get") else null
			TypeConversionSystem.apply_target_type_to_item(new_item, target_type_str, final_val, config)
			if AchievementManager and not src_types.has(new_item.data_type):
				AchievementManager.note_runtime_event("data_alchemist")
			if AchievementManager and src_types.size() >= 2:
				AchievementManager.note_runtime_event("union_is_strength")
			
			if target_type in [new_item.DataType.FP8, new_item.DataType.FP16]:
				if item1.data_type == target_type:
					new_item.fp_exp_bits = item1.fp_exp_bits
					new_item.fp_mant_bits = item1.fp_mant_bits
				elif item2.data_type == target_type:
					new_item.fp_exp_bits = item2.fp_exp_bits
					new_item.fp_mant_bits = item2.fp_mant_bits
			
			if new_item.has_method("update_label_display"):
				new_item.update_label_display()
				
			mount_item(slot_result, new_item)
			
			if phase.has_method("_wire_orb"):
				phase._wire_orb(new_item)
				
			new_item.scale = Vector2(0.2, 0.2)
			var tween = phase.create_tween()
			tween.tween_property(new_item, "scale", Vector2(1.1, 1.1), 0.18)
			tween.tween_property(new_item, "scale", Vector2(1.0, 1.0), 0.1)


func _notify_calc_warning(message: String) -> void:
	if AchievementManager == null or message.is_empty():
		return
	if message.begins_with("Overflow"):
		AchievementManager.note_runtime_event("overflow")
	elif message.begins_with("Underflow"):
		AchievementManager.note_runtime_event("underflow")
	elif "Perda de precisão" in message:
		AchievementManager.note_runtime_event("forced_cast")
