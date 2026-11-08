extends TextureRect

signal slot_entered(slot)
signal slot_exited(slot)

const SLOT_PX := 64
const PATH_FRAME := "res://Inventory/Art/UI/slot.png"
const PATH_FRAME_FREE := "res://Inventory/Art/UI/slot.png"
const PATH_FRAME_PARTIAL := "res://Inventory/Art/UI/slot.png"
const PATH_FRAME_TAKEN := "res://Inventory/Art/UI/slot.png"

@onready var filter = $StatusFilter

var slot_ID
var is_hovering := false
enum States {DEFAULT, TAKEN, FREE, PARTIAL}
var state = States.DEFAULT
var slot_bytes: int = 4
var items_stored = []
var _placeholder_label: Label = null
var _locked_remainder_rect: ColorRect = null
var item_stored:
	get:
		if items_stored.size() > 0:
			return items_stored[0]
		return null
	set(value):
		if value == null:
			items_stored.clear()
		else:
			items_stored = [value]
		_update_placeholder_visibility()
		_update_locked_remainder()
		queue_redraw()
		emit_signal("item_changed", self)
signal item_changed(slot)


func _ready() -> void:
	_apply_slot_dimensions()
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	_apply_frame_texture(States.DEFAULT)
	add_to_group("slot")
	call_deferred("_init_tool_placeholder_if_needed")


func _apply_slot_dimensions() -> void:
	var span_units: int = int(get_meta("slot_span_units", 1)) if has_meta("slot_span_units") else (2 if slot_bytes == 8 else 1)
	var w := float(SLOT_PX * maxi(span_units, 1))
	var h := float(SLOT_PX)
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)


func set_placeholder_text(txt: String) -> void:
	if _placeholder_label == null:
		_placeholder_label = Label.new()
		_placeholder_label.name = "PlaceholderLabel"
		_placeholder_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_placeholder_label.offset_left = 3
		_placeholder_label.offset_right = -3
		_placeholder_label.offset_top = 2
		_placeholder_label.offset_bottom = -2
		_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_placeholder_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_placeholder_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_placeholder_label.add_theme_font_size_override("font_size", 10)
		_placeholder_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 0.78))
		_placeholder_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_placeholder_label.add_theme_constant_override("outline_size", 2)
		_placeholder_label.add_theme_constant_override("line_spacing", -2)
		add_child(_placeholder_label)
	_placeholder_label.text = txt
	_update_placeholder_visibility()


func _init_tool_placeholder_if_needed() -> void:
	_apply_slot_dimensions()
	if _placeholder_label != null:
		_update_placeholder_visibility()
		return
	if has_meta("is_tool_slot") and not has_meta("is_calc_result") and not has_meta("is_type_box") and not has_meta("is_type_station"):
		set_placeholder_text("Colocar orbes aqui")


func _update_placeholder_visibility() -> void:
	if _placeholder_label != null and is_instance_valid(_placeholder_label):
		_placeholder_label.visible = (item_stored == null)


func _update_locked_remainder() -> void:
	if not has_meta("is_type_box") or item_stored == null or not is_instance_valid(item_stored):
		if _locked_remainder_rect != null and is_instance_valid(_locked_remainder_rect):
			_locked_remainder_rect.visible = false
		return
	var used_b: int = item_stored.get_size_bytes() if item_stored.has_method("get_size_bytes") else slot_bytes
	if used_b <= 0 or used_b >= slot_bytes:
		if _locked_remainder_rect != null and is_instance_valid(_locked_remainder_rect):
			_locked_remainder_rect.visible = false
		return
	if _locked_remainder_rect == null or not is_instance_valid(_locked_remainder_rect):
		_locked_remainder_rect = ColorRect.new()
		_locked_remainder_rect.name = "LockedRemainderRect"
		_locked_remainder_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_locked_remainder_rect.color = Color(0.46, 0.48, 0.52, 0.88)
		add_child(_locked_remainder_rect)
	var w := size.x if size.x > 0 else float(SLOT_PX)
	var h := size.y if size.y > 0 else float(SLOT_PX)
	var used_ratio := clampf(float(used_b) / float(slot_bytes), 0.0, 1.0)
	var lock_x := w * used_ratio
	_locked_remainder_rect.position = Vector2(lock_x, 3.0)
	_locked_remainder_rect.size = Vector2(maxf(0.0, w - lock_x - 3.0), maxf(0.0, h - 6.0))
	_locked_remainder_rect.visible = true


func _apply_frame_texture(a_state: States) -> void:
	var path := PATH_FRAME
	match a_state:
		States.FREE:
			path = PATH_FRAME_FREE if ResourceLoader.exists(PATH_FRAME_FREE) else PATH_FRAME
		States.PARTIAL:
			path = PATH_FRAME_PARTIAL if ResourceLoader.exists(PATH_FRAME_PARTIAL) else PATH_FRAME
		States.TAKEN:
			path = PATH_FRAME_TAKEN if ResourceLoader.exists(PATH_FRAME_TAKEN) else PATH_FRAME
		_:
			path = PATH_FRAME
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D


func set_item(item) -> void:
	self.item_stored = item
	_update_placeholder_visibility()
	_update_locked_remainder()
	queue_redraw()
	emit_signal("item_changed", self)


func add_item(item) -> void:
	if not items_stored.has(item):
		items_stored.append(item)
	_update_placeholder_visibility()
	_update_locked_remainder()
	queue_redraw()
	emit_signal("item_changed", self)


func remove_item(item) -> void:
	if items_stored.has(item):
		items_stored.erase(item)
	_update_placeholder_visibility()
	_update_locked_remainder()
	queue_redraw()
	emit_signal("item_changed", self)


func clear_items() -> void:
	items_stored.clear()
	_update_placeholder_visibility()
	_update_locked_remainder()
	queue_redraw()
	emit_signal("item_changed", self)


## Escolhe o orb sob o mouse (visual), não só o primeiro de items_stored.
func pick_item_at(global_pos: Vector2):
	var best = null
	for it in items_stored:
		if is_instance_valid(it) and it.has_method("hit_test_global") and it.hit_test_global(global_pos):
			best = it
	if best != null:
		return best
	for it in items_stored:
		if is_instance_valid(it) and bool(it.get("is_hovered")):
			return it
	if items_stored.size() > 0:
		return items_stored.back()
	return null


## Remove o orb do slot e anexa em `drag_parent` para arrastar.
func pop_item_for_drag(global_pos: Vector2, drag_parent: Node):
	var item = pick_item_at(global_pos)
	if item == null or not is_instance_valid(item):
		return null
	item.selected = true
	if item.get_parent():
		item.get_parent().remove_child(item)
	if drag_parent:
		drag_parent.add_child(item)
	item.global_position = global_pos
	remove_item(item)
	if get_used_bytes() == 0:
		state = States.FREE
		set_color(States.FREE)
	elif get_used_bytes() < slot_bytes:
		state = States.PARTIAL
		set_color(States.PARTIAL)
	return item


func get_used_bytes() -> int:
	var total := 0
	for item in items_stored:
		if item and item.has_method("get_size_bytes"):
			total += item.get_size_bytes()
	return total


func set_color(a_state: States = States.DEFAULT) -> void:
	state = a_state
	_apply_frame_texture(a_state)
	if has_meta("is_type_box"):
		filter.color = Color(Color.WHITE, 0.0)
		_update_locked_remainder()
		queue_redraw()
		return
	match a_state:
		States.DEFAULT:
			filter.color = Color(Color.WHITE, 0.0)
		States.TAKEN:
			filter.color = Color(Color.RED, 0.12)
		States.PARTIAL:
			filter.color = Color(Color.YELLOW, 0.12)
		States.FREE:
			filter.color = Color(Color.GREEN, 0.08)


func is_mouse_over_slot(mpos: Vector2 = get_global_mouse_position()) -> bool:
	if not is_visible_in_tree():
		return false
	if not get_global_rect().has_point(mpos):
		return false
	var p: Node = get_parent()
	while p != null:
		if p is Control and (p as Control).clip_contents:
			if not (p as Control).get_global_rect().has_point(mpos):
				return false
		p = p.get_parent()
	return true


func _process(_delta) -> void:
	_update_placeholder_visibility()
	if is_mouse_over_slot(get_global_mouse_position()):
		if not is_hovering:
			is_hovering = true
			emit_signal("slot_entered", self)
	else:
		if is_hovering:
			is_hovering = false
			emit_signal("slot_exited", self)

func _draw() -> void:
	if slot_bytes != 4 and slot_bytes != 8:
		return
	var w := size.x
	var h := size.y
	if has_meta("is_type_box") and item_stored != null and is_instance_valid(item_stored):
		var used_b: int = item_stored.get_size_bytes() if item_stored.has_method("get_size_bytes") else slot_bytes
		if used_b > 0 and used_b < slot_bytes:
			var used_ratio := clampf(float(used_b) / float(slot_bytes), 0.0, 1.0)
			var lock_x := w * used_ratio
			draw_rect(Rect2(Vector2(lock_x, 3), Vector2(w - lock_x - 3, h - 6)), Color(0.46, 0.48, 0.52, 0.88), true)
	var line_color := Color(1, 1, 1, 0.15)
	var segments := slot_bytes
	var segment_w := w / float(segments)
	for i in range(1, segments):
		var lx := float(i) * segment_w
		draw_dashed_line(Vector2(lx, 2), Vector2(lx, h - 2), line_color, 1.0, 4.0)
