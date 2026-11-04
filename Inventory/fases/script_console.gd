class_name ScriptConsole
extends CanvasLayer
## Console Python (NumPy) enxuto ligado a um ou vários PhaseScriptLog, com exportação .py.

signal closed

var log_ref: PhaseScriptLog = null
var _multi_logs: Array[PhaseScriptLog] = []
var _selected_phase_idx: int = -1 # -1 = Todas as Fases
var _frozen: bool = false
var _python_cache: String = ""

var _root: Control
var _title_label: Label
var _phase_selector_box: HBoxContainer
var _phase_option: OptionButton
var _code: TextEdit
var _btn_copy: Button
var _btn_download: Button
var _btn_close: Button


func _ready() -> void:
	layer = 120
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
	dim.color = Color(0.05, 0.06, 0.09, 0.78)
	dim.gui_input.connect(_on_dim_input)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(760, 520)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE, 0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -380
	panel.offset_top = -260
	panel.offset_right = 380
	panel.offset_bottom = 260
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "Seu Código em Python (NumPy)"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_title_label)

	_phase_selector_box = HBoxContainer.new()
	_phase_selector_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_phase_selector_box.add_theme_constant_override("separation", 10)
	_phase_selector_box.visible = false
	vbox.add_child(_phase_selector_box)

	var sel_lbl := Label.new()
	sel_lbl.text = "Visualizar:"
	sel_lbl.add_theme_font_size_override("font_size", 15)
	_phase_selector_box.add_child(sel_lbl)

	_phase_option = OptionButton.new()
	_phase_option.custom_minimum_size = Vector2(360, 34)
	_phase_option.add_theme_font_size_override("font_size", 14)
	_phase_option.item_selected.connect(_on_phase_option_selected)
	_phase_selector_box.add_child(_phase_option)

	_code = TextEdit.new()
	_code.editable = false
	_code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code.custom_minimum_size = Vector2(0, 360)
	_code.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_code)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	vbox.add_child(buttons)

	_btn_copy = Button.new()
	_btn_copy.text = "Copiar Código"
	_btn_copy.custom_minimum_size = Vector2(150, 40)
	_btn_copy.pressed.connect(_on_copy_pressed)
	buttons.add_child(_btn_copy)

	_btn_download = Button.new()
	_btn_download.text = "Baixar .py (Todas as Fases)"
	_btn_download.custom_minimum_size = Vector2(220, 40)
	_btn_download.pressed.connect(_on_download_pressed)
	buttons.add_child(_btn_download)

	_btn_close = Button.new()
	_btn_close.text = "Fechar"
	_btn_close.custom_minimum_size = Vector2(130, 40)
	_btn_close.pressed.connect(close_console)
	buttons.add_child(_btn_close)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_console()


func bind_log(p_log: PhaseScriptLog, freeze: bool = false) -> void:
	_multi_logs.clear()
	_selected_phase_idx = -1
	if _phase_selector_box != null:
		_phase_selector_box.visible = false
	if log_ref != null and log_ref.changed.is_connected(_on_log_changed):
		log_ref.changed.disconnect(_on_log_changed)
	log_ref = p_log
	_frozen = freeze
	if log_ref != null:
		if freeze:
			_python_cache = log_ref.render_python()
		elif not log_ref.changed.is_connected(_on_log_changed):
			log_ref.changed.connect(_on_log_changed)
	_refresh_title()
	_refresh_text()


func open_multi_console(logs: Array[PhaseScriptLog], initial_phase_idx: int = -1) -> void:
	if log_ref != null and log_ref.changed.is_connected(_on_log_changed):
		log_ref.changed.disconnect(_on_log_changed)
	log_ref = null
	_frozen = false
	_multi_logs = logs.duplicate()
	_selected_phase_idx = initial_phase_idx
	if _phase_option != null:
		_phase_option.clear()
		_phase_option.add_item("Todas as Fases (Python / NumPy)")
		for i in range(_multi_logs.size()):
			var slog := _multi_logs[i]
			var t := slog.title if (slog != null and slog.title != "") else ("Fase %02d" % (i + 1))
			_phase_option.add_item("Fase %02d — %s" % [i + 1, t])
		if initial_phase_idx >= 0 and initial_phase_idx < _multi_logs.size():
			_phase_option.select(initial_phase_idx + 1)
		else:
			_selected_phase_idx = -1
			_phase_option.select(0)
	if _phase_selector_box != null:
		_phase_selector_box.visible = _multi_logs.size() > 0
	show()
	_refresh_title()
	_refresh_text()


func _on_phase_option_selected(item_idx: int) -> void:
	if item_idx <= 0:
		_selected_phase_idx = -1
	else:
		_selected_phase_idx = item_idx - 1
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
	if visible and not _frozen and _multi_logs.is_empty():
		_refresh_text()


func _refresh_title() -> void:
	if _title_label == null:
		return
	if not _multi_logs.is_empty():
		if _selected_phase_idx >= 0 and _selected_phase_idx < _multi_logs.size():
			var slog := _multi_logs[_selected_phase_idx]
			var pt := slog.title if (slog != null and slog.title != "") else ("Fase %02d" % (_selected_phase_idx + 1))
			_title_label.text = "Código Python (NumPy) — Fase %02d: %s" % [_selected_phase_idx + 1, pt]
		else:
			_title_label.text = "Seu Código Completo em Python (NumPy)"
		return
	var t := "Seu Código em Python (NumPy)"
	if log_ref != null and log_ref.title != "":
		t = "Código Python (NumPy) — %s" % log_ref.title
	_title_label.text = t


func _refresh_text() -> void:
	if _code == null:
		return
	if not _multi_logs.is_empty():
		if _selected_phase_idx >= 0 and _selected_phase_idx < _multi_logs.size():
			var chosen := _multi_logs[_selected_phase_idx]
			if chosen == null:
				_code.text = "# (sem log)"
				return
			_code.text = chosen.render_python()
		else:
			_code.text = PhaseScriptLog.render_combined(_multi_logs)
		return
	if _frozen:
		_code.text = _python_cache
		return
	if log_ref == null:
		_code.text = "# (sem log)"
		return
	_code.text = log_ref.render_python()


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(_code.text if _code else "")


func _on_download_pressed() -> void:
	var logs_to_save: Array[PhaseScriptLog] = _multi_logs
	if logs_to_save.is_empty():
		logs_to_save = PhaseRunner.get_all_phase_script_logs()
	ScriptConsole.download_all_phases_py(self, logs_to_save)


static func download_all_phases_py(parent_node: Node, logs: Array[PhaseScriptLog]) -> void:
	var py_content := PhaseScriptLog.render_combined(logs)
	var file_name := "code_orbs_fases.py"

	if OS.has_feature("web"):
		var buf := py_content.to_utf8_buffer()
		JavaScriptBridge.download_buffer(buf, file_name, "text/x-python")
		return

	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.title = "Salvar Código Python de Todas as Fases (.py)"
	dialog.filters = PackedStringArray(["*.py ; Script Python (.py)"])
	var downloads_dir := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if downloads_dir != "":
		dialog.current_dir = downloads_dir
	dialog.current_file = file_name
	dialog.file_selected.connect(func(path: String) -> void:
		var final_path := path if path.to_lower().ends_with(".py") else (path + ".py")
		var f := FileAccess.open(final_path, FileAccess.WRITE)
		if f != null:
			f.store_string(py_content)
			f.close()
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
	parent_node.add_child(dialog)
	dialog.popup_centered(Vector2i(720, 480))

