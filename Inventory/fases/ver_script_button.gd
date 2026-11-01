class_name VerScriptButton
extends Object
## Garante `TopBar/BtnVerScript` em qualquer cena de fase.
## Se o nó não existir (cena nova sem o botão no .tscn), cria e posiciona
## ao lado de `BtnProxima`. Conecta `pressed` a `_on_ver_script_pressed` na
## raiz da cena, ou ao stub do PhaseRunner.

const BTN_NAME := "BtnVerScript"
const BTN_TEXT := "Ver Script"
const BTN_MIN_SIZE := Vector2(120, 40)
const ABSOLUTE_GAP := 10.0


static func ensure_on(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	var top := root.get_node_or_null("TopBar")
	if top == null:
		return
	var btn := top.get_node_or_null(BTN_NAME) as Button
	if btn == null:
		btn = _create_button(top)
	btn.visible = true
	_wire(root, btn)


static func _create_button(top: Node) -> Button:
	var btn := Button.new()
	btn.name = BTN_NAME
	btn.text = BTN_TEXT
	btn.custom_minimum_size = BTN_MIN_SIZE
	var proxima := top.get_node_or_null("BtnProxima") as Control
	top.add_child(btn)
	if proxima != null:
		top.move_child(btn, proxima.get_index() + 1)
		if top is Control and not (top is BoxContainer):
			_place_absolute_beside_proxima(btn, proxima)
	return btn


static func _place_absolute_beside_proxima(btn: Button, proxima: Control) -> void:
	btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var width := BTN_MIN_SIZE.x
	btn.offset_left = proxima.offset_left - ABSOLUTE_GAP - width
	btn.offset_right = proxima.offset_left - ABSOLUTE_GAP
	btn.offset_top = proxima.offset_top
	btn.offset_bottom = proxima.offset_bottom if proxima.offset_bottom != 0.0 else BTN_MIN_SIZE.y


static func _wire(root: Node, btn: Button) -> void:
	var cb: Callable
	if root.has_method("_on_ver_script_pressed"):
		cb = Callable(root, "_on_ver_script_pressed")
	else:
		cb = Callable(PhaseRunner, "_on_ver_script_pressed")
	if not btn.pressed.is_connected(cb):
		btn.pressed.connect(cb)
