class_name ScriptConsole
extends CanvasLayer
## Console híbrido Aula | Python | Executar ligado a um PhaseScriptLog.

signal closed

const MODE_AULA := "aula"
const MODE_PYTHON := "python"
const MODE_EXECUTAR := "executar"

var log_ref: PhaseScriptLog = null
var _mode: String = MODE_AULA
var _frozen: bool = false
var _aula_cache: String = ""
var _python_cache: String = ""
var _executar_cache: String = ""

var _root: Control
var _title_label: Label
var _btn_aula: Button
var _btn_python: Button
var _btn_executar: Button
var _code: TextEdit
var _btn_copy: Button
var _btn_close: Button


func _ready() -> void:
	layer = 80
	_build_ui()
	hide()
	_try_skin()


func _try_skin() -> void:
	if _root == null:
		return
	PanelArtLoader.skin_all_buttons(_root)
	if _root.has_node("Panel"):
		PanelArtLoader.apply_dialog_panel(_root.get_node("Panel"))


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.06, 0.09, 0.72)
	dim.gui_input.connect(_on_dim_input)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(640, 480)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE, 0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -320
	panel.offset_top = -240
	panel.offset_right = 320
	panel.offset_bottom = 240
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "Ver Script"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_title_label)

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	vbox.add_child(tabs)

	_btn_aula = Button.new()
	_btn_aula.text = "Aula"
	_btn_aula.toggle_mode = true
	_btn_aula.button_pressed = true
	_btn_aula.pressed.connect(_on_aula_pressed)
	tabs.add_child(_btn_aula)

	_btn_python = Button.new()
	_btn_python.text = "Python"
	_btn_python.toggle_mode = true
	_btn_python.pressed.connect(_on_python_pressed)
	tabs.add_child(_btn_python)

	_btn_executar = Button.new()
	_btn_executar.text = "Executar"
	_btn_executar.toggle_mode = true
	_btn_executar.pressed.connect(_on_executar_pressed)
	tabs.add_child(_btn_executar)

	_code = TextEdit.new()
	_code.editable = false
	_code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code.custom_minimum_size = Vector2(0, 320)
	_code.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_code)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	vbox.add_child(buttons)

	_btn_copy = Button.new()
	_btn_copy.text = "Copiar"
	_btn_copy.custom_minimum_size = Vector2(120, 40)
	_btn_copy.pressed.connect(_on_copy_pressed)
	buttons.add_child(_btn_copy)

	_btn_close = Button.new()
	_btn_close.text = "Fechar"
	_btn_close.custom_minimum_size = Vector2(120, 40)
	_btn_close.pressed.connect(close_console)
	buttons.add_child(_btn_close)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_console()


func bind_log(p_log: PhaseScriptLog, freeze: bool = false) -> void:
	if log_ref != null and log_ref.changed.is_connected(_on_log_changed):
		log_ref.changed.disconnect(_on_log_changed)
	log_ref = p_log
	_frozen = freeze
	if log_ref != null:
		if freeze:
			_aula_cache = log_ref.render_aula()
			_python_cache = log_ref.render_python()
			_executar_cache = log_ref.render_executar()
		elif not log_ref.changed.is_connected(_on_log_changed):
			log_ref.changed.connect(_on_log_changed)
	_refresh_title()
	_refresh_text()


func open_console(p_log: PhaseScriptLog = null, freeze: bool = false) -> void:
	if p_log != null:
		bind_log(p_log, freeze)
	show()
	_refresh_text()


func toggle_console(p_log: PhaseScriptLog = null) -> void:
	if visible and not _frozen:
		close_console()
		return
	open_console(p_log if p_log != null else log_ref, false)


func close_console() -> void:
	hide()
	closed.emit()


func _on_log_changed() -> void:
	if visible and not _frozen:
		_refresh_text()


func _set_mode(mode: String) -> void:
	_mode = mode
	_btn_aula.button_pressed = mode == MODE_AULA
	_btn_python.button_pressed = mode == MODE_PYTHON
	_btn_executar.button_pressed = mode == MODE_EXECUTAR
	_refresh_text()


func _on_aula_pressed() -> void:
	_set_mode(MODE_AULA)


func _on_python_pressed() -> void:
	_set_mode(MODE_PYTHON)


func _on_executar_pressed() -> void:
	_set_mode(MODE_EXECUTAR)


func _refresh_title() -> void:
	if _title_label == null:
		return
	var t := "Ver Script"
	if log_ref != null and log_ref.title != "":
		t = "Ver Script — %s" % log_ref.title
	if _frozen:
		t += " (fase concluída)"
	_title_label.text = t


func _refresh_text() -> void:
	if _code == null:
		return
	if _frozen:
		match _mode:
			MODE_PYTHON:
				_code.text = _python_cache
			MODE_EXECUTAR:
				_code.text = _executar_cache
			_:
				_code.text = _aula_cache
		return
	if log_ref == null:
		_code.text = "# (sem log)"
		return
	match _mode:
		MODE_PYTHON:
			_code.text = log_ref.render_python()
		MODE_EXECUTAR:
			_code.text = log_ref.render_executar()
		_:
			_code.text = log_ref.render_aula()


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(_code.text if _code else "")
