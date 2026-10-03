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
signal item_changed(slot)


func _ready() -> void:
	custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
	size = Vector2(SLOT_PX, SLOT_PX)
	expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_apply_frame_texture(States.DEFAULT)
	add_to_group("slot")


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
	emit_signal("item_changed", self)


func add_item(item) -> void:
	if not items_stored.has(item):
		items_stored.append(item)
	emit_signal("item_changed", self)


func remove_item(item) -> void:
	if items_stored.has(item):
		items_stored.erase(item)
	emit_signal("item_changed", self)


func clear_items() -> void:
	items_stored.clear()
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
	match a_state:
		States.DEFAULT:
			filter.color = Color(Color.WHITE, 0.0)
		States.TAKEN:
			filter.color = Color(Color.RED, 0.12)
		States.PARTIAL:
			filter.color = Color(Color.YELLOW, 0.12)
		States.FREE:
			filter.color = Color(Color.GREEN, 0.08)


func _process(_delta) -> void:
	if get_global_rect().has_point(get_global_mouse_position()):
		if not is_hovering:
			is_hovering = true
			emit_signal("slot_entered", self)
	else:
		if is_hovering:
			is_hovering = false
			emit_signal("slot_exited", self)

func _draw() -> void:
	if slot_bytes != 4:
		return
	var w = size.x
	var h = size.y
	var line_color = Color(1, 1, 1, 0.15)
	var segment_w = w / 4.0
	for i in range(1, 4):
		var lx = i * segment_w
		draw_dashed_line(Vector2(lx, 2), Vector2(lx, h - 2), line_color, 1.0, 4.0)
