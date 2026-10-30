class_name CalculatorTool
extends RefCounted

var phase: Node
var slot_1: TextureRect
var slot_2: TextureRect
var slot_result: TextureRect
var op_btn: Button
var max_uses: int = 1
var uses_count: int = 0
var uses_label: Label = null

func _init(
	_phase: Node,
	_slot_1: TextureRect,
	_slot_2: TextureRect,
	_slot_result: TextureRect,
	_op_btn: Button,
	_max_uses: int = 1,
	_uses_label: Label = null
):
	phase = _phase
	slot_1 = _slot_1
	slot_2 = _slot_2
	slot_result = _slot_result
	op_btn = _op_btn
	max_uses = _max_uses
	uses_label = _uses_label
	update_uses_visual()

func has_uses_left() -> bool:
	return max_uses <= 0 or uses_count < max_uses

func remaining_uses() -> int:
	if max_uses <= 0:
		return -1
	return maxi(0, max_uses - uses_count)

func update_uses_visual() -> void:
	var active: bool = has_uses_left()
	if uses_label != null:
		if max_uses <= 0:
			uses_label.text = "🔋 Usos: ∞ (Ilimitado)"
			uses_label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
		else:
			var rem: int = remaining_uses()
			if rem > 0:
				uses_label.text = "🔋 Usos restantes: %d / %d" % [rem, max_uses]
				var col: Color = Color(0.45, 0.95, 0.55) if (rem > 1 or max_uses == 1) else Color(1.0, 0.85, 0.35)
				uses_label.add_theme_color_override("font_color", col)
			else:
				uses_label.text = "🔒 Sem usos (0 / %d)" % max_uses
				uses_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	if slot_1 != null:
		slot_1.modulate = Color.WHITE if active else Color(0.5, 0.5, 0.5, 0.8)
	if slot_2 != null:
		slot_2.modulate = Color.WHITE if active else Color(0.5, 0.5, 0.5, 0.8)
	if op_btn != null:
		op_btn.disabled = not active
		op_btn.modulate = Color.WHITE if active else Color(0.5, 0.5, 0.5, 0.8)

func clear_result() -> void:
	if slot_result == null or slot_result.item_stored == null:
		return
	var old = slot_result.item_stored
	slot_result.item_stored = null
	slot_result.state = slot_result.States.FREE
	if is_instance_valid(old):
		old.queue_free()

func mount_item(slot: TextureRect, item: Node) -> void:
	item.grid_anchor = slot
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
	item.selected = false
	slot.item_stored = item
	slot.state = slot.States.TAKEN

func check_calculator() -> void:
	if slot_1 and slot_2 and op_btn and slot_result:
		if slot_1.item_stored != null and slot_2.item_stored != null:
			if not has_uses_left():
				if phase and phase.has_method("_show_not_ready_modal"):
					phase._show_not_ready_modal("Limite de usos da Calculadora atingido (%d/%d)!" % [uses_count, max_uses])
				return
			var item1 = slot_1.item_stored
			var item2 = slot_2.item_stored
			
			var val1 = TypeConversionSystem.value_for_conversion(item1)
			var val2 = TypeConversionSystem.value_for_conversion(item2)
			
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
			
			# Absorção de mantissa: ambos não-zero e o resultado quantizado vira exatamente um dos operandos.
			if val1 != 0.0 and val2 != 0.0 and deg.kind not in ["overflow", "underflow"] \
					and target_type in [item1.DataType.FLOAT, item1.DataType.DOUBLE, item1.DataType.FP8, item1.DataType.FP16]:
				var dv: float = deg.degraded_value
				if dv != result_val and (dv == val1 or dv == val2):
					deg.has_warning = true
					deg.kind = "absorption"
					deg.message = "Perda de precisão: absorção de mantissa (o menor valor foi ignorado pelos bits de precisão)"
					deg.abs_error = absf(dv - result_val)
					deg.rel_error = deg.abs_error / maxf(absf(result_val), 1e-9)
			# Int/Short overflow: não satura — cancela o cálculo e mantém os operandos.
			if TypeConversionSystem.blocks_conversion(deg):
				var block_dlg := AcceptDialog.new()
				block_dlg.dialog_text = deg.message + "\n\nO cálculo foi cancelado. Os operandos permanecem nos slots."
				block_dlg.title = "Overflow — cálculo bloqueado"
				phase.add_child(block_dlg)
				block_dlg.popup_centered(Vector2(480, 180))
				if phase.has_method("_wait_accept_dialog"):
					await phase._wait_accept_dialog(block_dlg)
				else:
					await block_dlg.confirmed
				block_dlg.queue_free()
				_notify_calc_warning(deg.message)
				return
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
				if phase.has_method("register_degradation"):
					phase.register_degradation(str(deg.kind), deg)
			
			if item1.data_type != item2.data_type and AchievementManager:
				AchievementManager.note_runtime_event("code_chameleon")
			if phase and phase.has_meta("upgraded_type_before_op") and phase.get_meta("upgraded_type_before_op") \
					and AchievementManager:
				AchievementManager.note_runtime_event("one_step_ahead")
				phase.set_meta("upgraded_type_before_op", false)
			
			var src_types := {item1.data_type: true, item2.data_type: true}
			var fp_exp := -1
			var fp_mant := -1
			if target_type in [item1.DataType.FP8, item1.DataType.FP16]:
				if item1.data_type == target_type:
					fp_exp = item1.fp_exp_bits
					fp_mant = item1.fp_mant_bits
				elif item2.data_type == target_type:
					fp_exp = item2.fp_exp_bits
					fp_mant = item2.fp_mant_bits
			item1.queue_free()
			item2.queue_free()
			slot_1.item_stored = null
			slot_1.state = slot_1.States.FREE
			slot_2.item_stored = null
			slot_2.state = slot_2.States.FREE
			uses_count += 1
			update_uses_visual()
			
			clear_result()
			var new_item: Node2D = preload("res://Inventory/Items/Item.tscn").instantiate()
			var final_val = deg.degraded_value
			
			var config = phase.get("config") if phase.has_method("get") else null
			TypeConversionSystem.apply_target_type_to_item(new_item, target_type_str, final_val, config)
			# Valor-fonte do resultado = resultado exato em float64 (para medir erro de quantização).
			new_item.source_value = result_val
			new_item.has_source_value = true
			if AchievementManager and not src_types.has(new_item.data_type):
				AchievementManager.note_runtime_event("data_alchemist")
			if AchievementManager and src_types.size() >= 2:
				AchievementManager.note_runtime_event("union_is_strength")
			
			if fp_exp >= 0:
				new_item.fp_exp_bits = fp_exp
				new_item.fp_mant_bits = fp_mant
			
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
