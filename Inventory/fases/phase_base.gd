extends Control

const ItemRef = preload("res://Inventory/Items/item.gd")

@onready var btn_voltar = $TopBar/BtnVoltar
@onready var btn_help = (
	get_node_or_null("TopBar/CenterVBox/TitleHBox/BtnHelp")
	if get_node_or_null("TopBar/CenterVBox/TitleHBox/BtnHelp")
	else get_node_or_null("TopBar/BtnHelp")
)
@onready var btn_reiniciar: Button = get_node_or_null("TopBar/BtnReiniciar")
@onready var btn_proxima = get_node_or_null("TopBar/BtnProxima")
# phase_base.tscn: TopBar/CenterVBox/... ; backup/type_box: TopBar/PhaseTitle
@onready var phase_title = (
	get_node_or_null("TopBar/CenterVBox/TitleHBox/PhaseTitle")
	if get_node_or_null("TopBar/CenterVBox/TitleHBox/PhaseTitle")
	else get_node_or_null("TopBar/PhaseTitle")
)
@onready var phase_progress_label = get_node_or_null("TopBar/CenterVBox/PhaseProgress")
@onready var bytes_label = $HBox/BackpackPanel/MarginContainer/VBoxContainer/PhaseInfoBar/MarginContainer/VBoxContainer/BytesLabel
@onready var hint_label = $HBox/BackpackPanel/MarginContainer/VBoxContainer/PhaseInfoBar/MarginContainer/VBoxContainer/HintLabel

@onready var backpack_container = $HBox/BackpackPanel/MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var pool_container = $HBox/BancadaPanel/MarginContainer/VBoxContainer/GridContainer

var backpack_grid: InventoryGrid = null
var pool_grid: InventoryGrid = null
var converter_slot: TextureRect = null
var converter_option_btn: OptionButton = null
var double_slot: TextureRect = null
var short_slot: TextureRect = null
var calc_slot_1: TextureRect = null
var calc_slot_2 = null
var calc_slot_result: TextureRect = null
var calc_op_btn = null
var inspect_slot: TextureRect = null
var btn_inspect: Button = null

var item_held = null
var current_slot = null
var can_place := false
var inspector_modal = null
var _orb_hover_bar: OrbHoverBar = null

var moves_count: int = 0
var _source_slot = null
var _is_finishing: bool = false

var calculator: CalculatorTool = null
var converter: ConverterTool = null

var _custom_tutorial_title: String = ""
var _custom_tutorial_text: String = ""
var _uses_custom_tutorial: bool = false
var _earned_stars: int = 0

## Degradações confirmadas pelo jogador (converter/calculadora): {kind, message, abs_error, rel_error, move}.
var degradation_history: Array[Dictionary] = []

var script_log: PhaseScriptLog = null
var _script_console: ScriptConsole = null

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	if PhaseRunner.has_custom_tutorial():
		_uses_custom_tutorial = true
		var t := PhaseRunner.take_tutorial_if_any()
		_custom_tutorial_title = t["title"]
		_custom_tutorial_text = t["body"]
	
	if btn_voltar:
		btn_voltar.text = "Voltar"
		btn_voltar.pressed.connect(_on_voltar_pressed)
	if btn_help:
		btn_help.pressed.connect(_on_help_pressed)
	if btn_reiniciar == null:
		btn_reiniciar = _ensure_reset_button()
	if btn_reiniciar:
		btn_reiniciar.pressed.connect(_on_reiniciar_pressed)
	if btn_proxima:
		btn_proxima.visible = PhaseRunner.should_show_next_button()
		btn_proxima.disabled = true # só libera quando is_phase_success()
		btn_proxima.pressed.connect(_on_proxima_pressed)
		_update_next_button_label()
		call_deferred("_update_next_button_state")
	VerScriptButton.ensure_on(self)
	PhaseRunner.phase_advance_blocked.connect(_on_phase_advance_blocked)
	call_deferred("_try_show_intro")
	call_deferred("_update_phase_title")
	call_deferred("_init_script_log")
	
	# Wait one frame to let subclasses assign the tool slots
	call_deferred("_initialize_tools")

func _initialize_tools():
	if calc_slot_1 and calc_slot_2 and calc_slot_result and calc_op_btn:
		calculator = CalculatorTool.new(self, calc_slot_1, calc_slot_2, calc_slot_result, calc_op_btn)
	
	if converter_slot:
		converter = ConverterTool.new(self, converter_slot, converter_option_btn)

func _tutorial_intro_id() -> String:
	return ""

func _phase_display_name() -> String:
	# 1) título do step no criador (mesmo com use_custom_tutorial=false)
	var from_step := PhaseRunner.peek_step_title()
	if from_step != "":
		return from_step
	if _custom_tutorial_title != "":
		return _custom_tutorial_title
	var tid := _tutorial_intro_id()
	if not tid.is_empty():
		var t := TutorialTexts.title_for(tid)
		if t != "" and t != "Ajuda":
			return t
	return "Fase"


func _update_next_button_label() -> void:
	if not btn_proxima:
		return
	if PhaseRunner.is_last_phase():
		btn_proxima.text = "Concluir →"
	else:
		btn_proxima.text = "Próxima fase →"


func _update_phase_title() -> void:
	if not phase_title:
		return
	# Evita título longo cobrir o botão Próxima/Concluir.
	phase_title.clip_text = true
	phase_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var display_name := _phase_display_name()
	if PhaseRunner.is_sequence_active():
		var n := PhaseRunner.current_phase_number()
		var total := PhaseRunner.total_phases()
		phase_title.text = "Fase %d/%d — %s" % [n, total, display_name]
	else:
		phase_title.text = display_name
	_update_next_button_label()

func _try_show_intro() -> void:
	if PhaseRunner.consume_suppress_tutorial_popup():
		return
	if _uses_custom_tutorial:
		TutorialOverlay.open(self, "custom", _custom_tutorial_title, _custom_tutorial_text, false)
		return

	var tid := _tutorial_intro_id()
	if tid.is_empty():
		return
	# Sempre abre o tutorial ao começar a fase (não pula se já viu).
	TutorialOverlay.open(self, tid, TutorialTexts.title_for(tid), TutorialTexts.body_for(tid), false)


func _ensure_reset_button() -> Button:
	var top := get_node_or_null("TopBar")
	if top == null:
		return null
	var existing := top.get_node_or_null("BtnReiniciar") as Button
	if existing != null:
		return existing
	var btn := Button.new()
	btn.name = "BtnReiniciar"
	btn.text = "Reiniciar"
	btn.custom_minimum_size = Vector2(110, 40)
	top.add_child(btn)
	var help_node := top.get_node_or_null("BtnHelp")
	if help_node != null:
		top.move_child(btn, help_node.get_index() + 1)
	elif btn_voltar != null and btn_voltar.get_parent() == top:
		top.move_child(btn, btn_voltar.get_index() + 1)
	PanelArtLoader.apply_button_style(btn)
	return btn


func _on_reiniciar_pressed() -> void:
	if _is_finishing:
		return
	if item_held != null and is_instance_valid(item_held):
		item_held.queue_free()
		item_held = null
	PhaseRunner.restart_current_phase()

func _on_help_pressed() -> void:
	if _uses_custom_tutorial:
		TutorialOverlay.open(self, "custom", _custom_tutorial_title, _custom_tutorial_text, false)
		return

	var tid := _tutorial_intro_id()
	if tid.is_empty():
		return
	TutorialOverlay.open(self, tid, TutorialTexts.title_for(tid), TutorialTexts.body_for(tid), false)

func setup_grids(backpack: InventoryGrid, pool: InventoryGrid):
	backpack_grid = backpack
	pool_grid = pool
	backpack_grid.slot_entered.connect(_on_slot_entered)
	backpack_grid.slot_exited.connect(_on_slot_exited)
	backpack_grid.item_changed.connect(_on_slot_item_changed)
	pool_grid.slot_entered.connect(_on_slot_entered)
	pool_grid.slot_exited.connect(_on_slot_exited)
	pool_grid.item_changed.connect(_on_slot_item_changed)
	_update_bytes_label()
	_update_hint()
	call_deferred("_apply_panel_art")
	call_deferred("_wire_all_orbs")
	call_deferred("_anchor_orb_hover_above_pool")

func _get_phase_config():
	return null

func _solution_types_valid() -> bool:
	return true

func _apply_panel_art() -> void:
	var bp := get_node_or_null("HBox/BackpackPanel") as Control
	var bn := get_node_or_null("HBox/BancadaPanel") as Control
	if bp:
		PanelArtLoader.apply_zone_chrome(bp)
	if bn:
		PanelArtLoader.apply_zone_chrome(bn)
	_style_phase_labels()
	PanelArtLoader.skin_all_buttons(self)
	PanelArtLoader.apply_background(self)

func _style_phase_labels() -> void:
	var bar := get_node_or_null("HBox/BackpackPanel/MarginContainer/VBoxContainer/PhaseInfoBar")
	if bar is PhaseInfoBar:
		return
	if bytes_label:
		OrbHoverBar.apply_info_label(bytes_label)
	if hint_label:
		OrbHoverBar.apply_info_label(hint_label)

func _wire_all_orbs() -> void:
	for grid in [backpack_grid, pool_grid]:
		if grid == null:
			continue
		for slot in grid.slots_array:
			for it in slot.items_stored:
				_wire_orb(it)
			if not slot.item_changed.is_connected(_on_orb_slot_changed):
				slot.item_changed.connect(_on_orb_slot_changed)

func _on_orb_slot_changed(slot) -> void:
	for it in slot.items_stored:
		_wire_orb(it)

func _wire_orb(item: Node) -> void:
	var bar := _get_orb_hover_bar()
	if bar:
		bar.wire_orb(item)

func _get_orb_hover_bar() -> OrbHoverBar:
	if _orb_hover_bar != null and is_instance_valid(_orb_hover_bar):
		return _orb_hover_bar
	for path in [
		"HBox/BancadaPanel/MarginContainer/VBoxContainer/OrbHoverBar",
		"HBox/BancadaPanel/MarginContainer/VBoxContainer/OrbHoverPanel",
	]:
		var n := get_node_or_null(path)
		if n is OrbHoverBar:
			_orb_hover_bar = n
			return _orb_hover_bar
	return null

func _register_orb_hover_bar(bar: OrbHoverBar) -> void:
	_orb_hover_bar = bar

func _anchor_orb_hover_above_pool() -> void:
	var bar := _get_orb_hover_bar()
	if bar == null or pool_grid == null:
		return
	var parent := pool_grid.get_parent()
	if parent == null:
		return
	parent.move_child(bar, pool_grid.get_index())

func _open_orb_inspector(item: Node) -> void:
	if item == null or not is_instance_valid(item):
		return
	var cfg = _get_phase_config()
	if not inspector_modal:
		inspector_modal = preload("res://Inventory/fases/inspector_modal.gd").new()
		add_child(inspector_modal)
	inspector_modal.open(cfg, item)


## Inspetor de orbes presente em todas as fases e tipos de fases (slot + botão com ícone de lupa).
func _create_inspector_ui(target_vbox: Node = null) -> void:
	if inspect_slot != null and is_instance_valid(inspect_slot):
		return
	var pool_vbox: Node = target_vbox
	if pool_vbox == null and pool_container != null and is_instance_valid(pool_container):
		pool_vbox = pool_container.get_parent()
	if pool_vbox == null:
		pool_vbox = get_node_or_null("HBox/BancadaPanel/MarginContainer/VBoxContainer")
	if pool_vbox == null:
		return
	var tools_hbox := _get_or_create_tools_hbox(pool_vbox)

	var insp_panel := PanelContainer.new()
	var insp_vbox := VBoxContainer.new()
	insp_panel.add_child(insp_vbox)

	var insp_lbl := Label.new()
	insp_lbl.text = "Inspecionar"
	insp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	insp_lbl.add_theme_font_size_override("font_size", 14)
	insp_vbox.add_child(insp_lbl)

	var insp_hbox := HBoxContainer.new()
	insp_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	insp_hbox.add_theme_constant_override("separation", 8)
	insp_vbox.add_child(insp_hbox)

	var insp_c := CenterContainer.new()
	insp_c.custom_minimum_size = Vector2(64, 64)
	insp_hbox.add_child(insp_c)

	inspect_slot = preload("res://Inventory/slots/slot.tscn").instantiate()
	inspect_slot.slot_ID = 903
	inspect_slot.set_meta("is_tool_slot", true)
	insp_c.add_child(inspect_slot)

	inspect_slot.slot_entered.connect(_on_slot_entered)
	inspect_slot.slot_exited.connect(_on_slot_exited)
	inspect_slot.item_changed.connect(func(_s): _update_inspect_button())

	btn_inspect = MagnifyingGlassIcon.make_inspect_button(_on_btn_inspect_pressed)
	insp_hbox.add_child(btn_inspect)

	tools_hbox.add_child(insp_panel)
	PanelArtLoader.skin_all_buttons(insp_panel)
	_update_inspect_button()


## Container inferior de ferramentas (Calculadora / Inspetor): visível por padrão em todas as fases.
func _get_or_create_tools_hbox(pool_vbox: Node) -> HFlowContainer:
	var existing := pool_vbox.get_node_or_null("BottomToolsContainer")
	if existing:
		return existing.get_node("BottomToolsHBox")

	var tools_container := VBoxContainer.new()
	tools_container.name = "BottomToolsContainer"

	var toggle_btn := Button.new()
	toggle_btn.text = "Ferramentas"
	toggle_btn.icon = UiIcons.get_icon("down")
	toggle_btn.custom_minimum_size = Vector2(150, 34)

	var tools_hbox := HFlowContainer.new()
	tools_hbox.name = "BottomToolsHBox"
	tools_hbox.alignment = FlowContainer.ALIGNMENT_CENTER
	tools_hbox.add_theme_constant_override("h_separation", 15)
	tools_hbox.add_theme_constant_override("v_separation", 12)
	tools_hbox.visible = true

	toggle_btn.pressed.connect(func():
		tools_hbox.visible = not tools_hbox.visible
		toggle_btn.icon = UiIcons.get_icon("down" if tools_hbox.visible else "up")
	)

	tools_container.add_child(tools_hbox)
	tools_container.add_child(toggle_btn)

	pool_vbox.add_child(tools_container)
	if pool_container != null and is_instance_valid(pool_container) and pool_container.get_parent() == pool_vbox:
		pool_vbox.move_child(tools_container, pool_container.get_index() + 1)
	PanelArtLoader.skin_all_buttons(tools_container)
	return tools_hbox


func _update_inspect_button() -> void:
	if btn_inspect == null or not is_instance_valid(btn_inspect):
		return
	var has_orb: bool = (inspect_slot != null and is_instance_valid(inspect_slot) and inspect_slot.item_stored != null and is_instance_valid(inspect_slot.item_stored))
	btn_inspect.disabled = not has_orb
	btn_inspect.modulate = Color(1, 1, 1, 1.0) if has_orb else Color(0.55, 0.55, 0.6, 0.4)
	btn_inspect.tooltip_text = "Inspecionar orbe" if has_orb else "Coloque um orbe no slot de inspeção primeiro"


func _on_btn_inspect_pressed() -> void:
	if not inspect_slot or inspect_slot.item_stored == null:
		_show_not_ready_modal("Coloque um orbe no slot de inspeção primeiro.")
		return
	var item = inspect_slot.item_stored
	_open_orb_inspector(item)

func _on_voltar_pressed():
	PhaseRunner.abort_sequence()
	get_tree().change_scene_to_file("res://Inventory/fases/main_menu.tscn")

func _on_proxima_pressed():
	if _is_finishing:
		return

	_update_next_button_state()
	# Sem interação / objetivo incompleto: nunca avança nem mostra estrelas.
	if moves_count <= 0 or not is_phase_success():
		_show_not_ready_modal(
			"Complete o objetivo da fase antes de avançar.\n(É preciso interagir e cumprir o que a fase pede.)"
		)
		return

	_is_finishing = true
	_show_victory_overlay()

func _on_ver_script_pressed() -> void:
	open_script_console(false)


func _ensure_script_log() -> PhaseScriptLog:
	if script_log == null:
		script_log = PhaseScriptLog.new()
	return script_log


func _script_objective_text() -> String:
	# Texto completo (sem cortar com "..."); o console quebra em várias linhas #.
	if _custom_tutorial_text != "":
		return ReadableBbcode.strip_tags(_custom_tutorial_text)
	return ""


func _init_script_log() -> void:
	var slog := _ensure_script_log()
	slog.clear()
	slog.set_header(_phase_display_name(), _script_objective_text())
	slog.push("phase_start", {})
	_refresh_script_state()


func open_script_console(freeze: bool = false) -> void:
	_refresh_script_state()
	if _script_console == null or not is_instance_valid(_script_console):
		_script_console = ScriptConsole.new()
		add_child(_script_console)
	if freeze:
		_script_console.open_console(_ensure_script_log(), true)
	else:
		_script_console.toggle_console(_ensure_script_log())


func log_script_event(kind: String, data: Dictionary = {}) -> void:
	_ensure_script_log().push(kind, data)
	_refresh_script_state()


func log_script_cast(from_type: String, before_py: String, to_type: String, after_py: String, deg: Dictionary = {}) -> void:
	# Cast sem mudança de tipo (ex.: Double → Double) não entra no Trace.
	if from_type.strip_edges().to_lower() == to_type.strip_edges().to_lower():
		_refresh_script_state()
		return
	var warn := ""
	if deg.get("has_warning", false):
		warn = str(deg.get("message", ""))
	log_script_event("cast", {
		"name": _ensure_script_log().next_var_name("x"),
		"from_type": from_type,
		"to_type": to_type,
		"before": before_py,
		"after": after_py,
		"warning": warn,
		"deg_kind": str(deg.get("kind", "")),
		"from_bytes": PhaseScriptLog.bytes_for_type_label(from_type),
		"to_bytes": PhaseScriptLog.bytes_for_type_label(to_type),
	})


func log_script_binop(
	a_py: String,
	b_py: String,
	op: String,
	result_py: String,
	result_type: String,
	deg: Dictionary = {},
	a_type: String = "",
	b_type: String = ""
) -> void:
	var warn := ""
	if deg.get("has_warning", false):
		warn = str(deg.get("message", ""))
	var res_bytes := PhaseScriptLog.bytes_for_type_label(result_type)
	log_script_event("binop", {
		"name": _ensure_script_log().next_var_name("r"),
		"a": a_py,
		"b": b_py,
		"op": op,
		"result": result_py,
		"result_type": result_type,
		"a_type": a_type,
		"b_type": b_type,
		"a_bytes": PhaseScriptLog.bytes_for_type_label(a_type),
		"b_bytes": PhaseScriptLog.bytes_for_type_label(b_type),
		"result_bytes": res_bytes,
		"warning": warn,
		"deg_kind": str(deg.get("kind", "")),
	})


func _slot_region_name(slot) -> String:
	if slot == null:
		return "?"
	if slot == converter_slot:
		return "conversor"
	if slot == calc_slot_1 or slot == calc_slot_2 or slot == calc_slot_result:
		return "calculadora"
	if slot == inspect_slot:
		return "inspetor"
	if backpack_grid and slot in backpack_grid.slots_array:
		return "mochila"
	if pool_grid and slot in pool_grid.slots_array:
		return "bancada"
	if slot.has_meta("box_name"):
		return str(slot.get_meta("box_name"))
	if slot.has_meta("is_pool"):
		return "bancada"
	return "slot"


func _refresh_script_state() -> void:
	var slog := _ensure_script_log()
	var entries: Array = []
	if backpack_grid:
		for it in _backpack_orbs():
			var vname := PhaseScriptLog.stable_var_name_for_item(it)
			entries.append(PhaseScriptLog.state_entry_from_item(it, vname, "mochila"))
	if pool_grid:
		for it in pool_grid.get_all_items():
			if it == null or not is_instance_valid(it):
				continue
			var bname := PhaseScriptLog.stable_var_name_for_item(it, "bench")
			entries.append(PhaseScriptLog.state_entry_from_item(it, bname, "bancada"))
	slog.set_state(entries)


func _present_victory_overlay(s1: bool, s2: bool, s3: bool, desc: String) -> void:
	var phase_idx := PhaseRunner.current_phase_number() - 1
	var title := _phase_display_name()
	var slog := _ensure_script_log()
	slog.set_header(title, _script_objective_text())
	_refresh_script_state()
	PhaseRunner.record_phase_stars(maxi(0, phase_idx), title, s1, s2, s3, moves_count, slog)
	if AchievementManager != null and PhaseRunner.get_current_step() != null:
		AchievementManager.on_phase_completed(PhaseRunner.get_current_step(), self)

	var overlay = preload("res://Inventory/fases/victory_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_victory(s1, s2, s3, desc)
	overlay.advance_requested.connect(_on_victory_advance_requested)
	if overlay.has_signal("script_requested"):
		overlay.script_requested.connect(_on_victory_script_requested)


var _origin_notice_banner: PanelContainer = null

func show_origin_change_notice(msg: String) -> void:
	if msg.strip_edges().is_empty():
		return
	if hint_label:
		hint_label.text = "[i] " + msg.replace("\n", " ")
		hint_label.visible = true
	if _origin_notice_banner != null and is_instance_valid(_origin_notice_banner):
		_origin_notice_banner.queue_free()
	var banner := PanelContainer.new()
	banner.name = "OriginStructureNotice"
	banner.z_index = 95
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.16, 0.24, 0.96)
	st.border_color = Color(0.35, 0.78, 1.0, 0.95)
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	banner.add_theme_stylebox_override("panel", st)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	banner.add_child(vbox)

	var lbl := Label.new()
	lbl.text = msg
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(460, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	vbox.add_child(lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var btn_ok := Button.new()
	btn_ok.text = "OK"
	btn_ok.custom_minimum_size = Vector2(96, 32)
	PanelArtLoader.apply_button_style(btn_ok)
	btn_row.add_child(btn_ok)

	add_child(banner)
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -245.0
	banner.offset_right = 245.0
	banner.offset_top = 56.0
	banner.offset_bottom = 164.0
	_origin_notice_banner = banner

	var done := [false]
	btn_ok.pressed.connect(func():
		done[0] = true
		if is_instance_valid(banner):
			banner.queue_free()
	)
	while not done[0] and is_instance_valid(banner):
		await get_tree().process_frame


func _on_victory_script_requested() -> void:
	open_script_console(true)

func _on_victory_advance_requested() -> void:
	_is_finishing = false
	PhaseRunner.advance_from_phase()

## Verifica se a fase de mochila foi concluída de forma incompleta: mochila vazia/estourada ou orbes
## esquecidos na bancada/ferramentas. Usar MENOS espaço que a capacidade total NÃO é penalizado.
func _is_backpack_partial() -> bool:
	if not backpack_grid:
		return false
	var used := backpack_grid.total_bytes_used()
	var cap := backpack_grid.capacity_bytes
	if used <= 0 or used > cap:
		return true
	if pool_grid and not pool_grid.get_all_items().is_empty():
		return true
	if _tool_slots_have_items():
		return true
	return false

func _show_victory_overlay():
	var cfg = _get_phase_config()
	var current_orbs: Array = _collect_solution_orbs()
	var res: Dictionary = StarEvaluator.evaluate_phase_stars(
		cfg,
		moves_count,
		_is_backpack_partial(),
		current_orbs,
		degradation_history,
		_solution_types_valid(),
		false,
		true
	)
	_earned_stars = int(res.get("earned", 0))
	_present_victory_overlay(
		bool(res.get("s1", true)),
		bool(res.get("s2", true)),
		bool(res.get("s3", true)),
		str(res.get("desc", ""))
	)

func get_earned_stars() -> int:
	return _earned_stars

## Registra uma degradação confirmada pelo jogador (kind: truncation/overflow/underflow/precision/absorption).
func register_degradation(kind: String, info: Dictionary) -> void:
	degradation_history.append({
		"kind": kind,
		"message": str(info.get("message", "")),
		"abs_error": float(info.get("abs_error", 0.0)),
		"rel_error": float(info.get("rel_error", 0.0)),
		"move": moves_count,
	})

## Orbes (sem duplicar) atualmente na mochila.
func _backpack_orbs() -> Array:
	var out: Array = []
	if backpack_grid:
		for slot in backpack_grid.slots_array:
			for it in slot.items_stored:
				if it and is_instance_valid(it) and not out.has(it):
					out.append(it)
	return out

func _collect_solution_orbs() -> Array:
	if backpack_grid:
		return _backpack_orbs()
	var current: Array = []
	if "all_slots" in self:
		var all = self.get("all_slots")
		if all and typeof(all) == TYPE_ARRAY:
			for slot in all:
				if slot and "item_stored" in slot and slot.item_stored and not current.has(slot.item_stored):
					current.append(slot.item_stored)
	return current

func _orb_rel_error(item: Node) -> float:
	return StarEvaluator.orb_rel_error(item)

func _orb_int_overflowed(item: Node) -> bool:
	return StarEvaluator.orb_int_overflowed(item)

func _precision_penalty_applies(cfg) -> bool:
	return StarEvaluator.precision_penalty_applies(cfg, degradation_history, _backpack_orbs())

func _check_star3_solution(target_csv: String) -> bool:
	return StarEvaluator.check_star3_solution(target_csv, _collect_solution_orbs())

func _item_to_csv_string(item: Node) -> String:
	return StarEvaluator.item_to_csv_string(item)

func _on_phase_advance_blocked(reason: String):
	_show_not_ready_modal(reason)

func _show_not_ready_modal(custom_message: String = ""):
	var message := custom_message if custom_message != "" else "Você precisa completar o objetivo desta fase antes de avançar. Verifique as instruções e tente novamente."
	var dlg := AcceptDialog.new()
	dlg.dialog_text = message
	add_child(dlg)
	dlg.popup_centered(Vector2(400, 120))

## True se há orbe esquecido no conversor, calculadora (entradas/resultado) ou inspetor.
func _tool_slots_have_items() -> bool:
	for s in [converter_slot, calc_slot_1, calc_slot_2, calc_slot_result, inspect_slot]:
		if s != null and is_instance_valid(s) and s.item_stored != null and is_instance_valid(s.item_stored):
			return true
	return false

func _update_next_button_state():
	if not btn_proxima:
		return
	var success = is_phase_success()
	btn_proxima.disabled = not success

	if phase_progress_label:
		if success:
			if _is_backpack_partial():
				phase_progress_label.text = "Há orbes esquecidos: você pode avançar, mas perderá 1 estrela."
				phase_progress_label.add_theme_color_override("font_color", Color.YELLOW)
			else:
				phase_progress_label.text = "Fase Concluída! Você pode avançar."
				phase_progress_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			var pool_items = pool_grid.get_all_items().size() if pool_grid else 0
			var tools_pending := _tool_slots_have_items()
			if tools_pending and pool_items == 0:
				phase_progress_label.text = "Retire os orbes esquecidos nos slots das ferramentas."
				phase_progress_label.add_theme_color_override("font_color", Color.YELLOW)
			elif pool_items > 0:
				phase_progress_label.text = "Falta usar %d orbe(s) da bancada." % pool_items
				phase_progress_label.add_theme_color_override("font_color", Color.YELLOW)
			elif backpack_grid:
				var orbs := _backpack_orbs()
				if orbs.is_empty():
					phase_progress_label.text = "Coloque pelo menos 1 orbe na mochila para avançar."
					phase_progress_label.add_theme_color_override("font_color", Color.LIGHT_CORAL)
				else:
					phase_progress_label.text = "A solução atual não está correta."
					phase_progress_label.add_theme_color_override("font_color", Color.LIGHT_CORAL)

func is_phase_success() -> bool:
	# Default seguro: não permite avançar até a fase sobrescrever a regra.
	return false


func _on_slot_entered(slot):
	current_slot = slot
	if not item_held:
		return
	if slot == converter_slot:
		can_place = true
		_update_next_button_state()
	elif slot == calc_slot_result:
		can_place = false
	elif slot == calc_slot_1 or slot == calc_slot_2:
		can_place = (slot.item_stored == null) and (calculator == null or calculator.has_uses_left())
		if can_place:
			_update_next_button_state()
	elif slot == inspect_slot:
		can_place = slot.item_stored == null
		if can_place:
			_update_next_button_state()
	elif backpack_grid and slot in backpack_grid.slots_array:
		can_place = backpack_grid.can_place_item(item_held, slot)
		var need = item_held.get_size_bytes() if item_held.has_method("get_size_bytes") else 1
		var used = backpack_grid.total_bytes_used()
		if can_place and used + need > backpack_grid.capacity_bytes:
			can_place = false
	elif pool_grid and slot in pool_grid.slots_array:
		can_place = pool_grid.can_place_item(item_held, slot)
	else:
		can_place = false
		
	if backpack_grid and backpack_grid.has_method("show_placement_preview"):
		backpack_grid.clear_placement_preview()
		if slot in backpack_grid.slots_array:
			backpack_grid.show_placement_preview(item_held, slot)
	if pool_grid and pool_grid.has_method("show_placement_preview"):
		pool_grid.clear_placement_preview()
		if slot in pool_grid.slots_array:
			pool_grid.show_placement_preview(item_held, slot)

func _on_slot_exited(_slot):
	if current_slot != null and _slot != current_slot:
		return
	current_slot = null
	can_place = false
	if backpack_grid and backpack_grid.has_method("clear_placement_preview"):
		backpack_grid.clear_placement_preview()
	if pool_grid and pool_grid.has_method("clear_placement_preview"):
		pool_grid.clear_placement_preview()
	_update_hint()

func _is_tool_slot_active(slot: Control) -> bool:
	return slot != null and is_instance_valid(slot) and slot.is_visible_in_tree()

func _get_tool_panel(slot: Control) -> Control:
	if not _is_tool_slot_active(slot):
		return null
	var p: Node = slot.get_parent()
	while p != null:
		if p is PanelContainer:
			return p as Control
		p = p.get_parent()
	return null

func _is_mouse_over_any_tool_area(mpos: Vector2) -> bool:
	for ts in [calc_slot_1, calc_slot_2, calc_slot_result, inspect_slot, converter_slot]:
		if _is_tool_slot_active(ts):
			if (ts as Control).get_global_rect().grow(8.0).has_point(mpos):
				return true
			var pnl: Control = _get_tool_panel(ts)
			if pnl != null and pnl.is_visible_in_tree() and pnl.get_global_rect().grow(4.0).has_point(mpos):
				return true
	return false

func _resolve_priority_slot(mpos: Vector2) -> Control:
	# 1) Prioridade máxima: slots diretos das ferramentas (Calculadora, Inspetor, Conversor).
	var tool_slots: Array = [calc_slot_1, calc_slot_2, calc_slot_result, inspect_slot, converter_slot]
	for ts in tool_slots:
		if _is_tool_slot_active(ts) and (ts as Control).get_global_rect().has_point(mpos):
			return ts as Control
	for ts in tool_slots:
		if _is_tool_slot_active(ts) and (ts as Control).get_global_rect().grow(8.0).has_point(mpos):
			return ts as Control

	# 2) Clique/hover dentro do painel da Calculadora, Inspetor ou Conversor.
	if _is_tool_slot_active(inspect_slot):
		var insp_panel: Control = _get_tool_panel(inspect_slot)
		if insp_panel != null and insp_panel.get_global_rect().grow(4.0).has_point(mpos):
			if item_held != null and inspect_slot.item_stored == null:
				return inspect_slot
			elif item_held == null and inspect_slot.item_stored != null:
				return inspect_slot

	if _is_tool_slot_active(calc_slot_1):
		var calc_panel: Control = _get_tool_panel(calc_slot_1)
		if calc_panel != null and calc_panel.get_global_rect().grow(4.0).has_point(mpos):
			if item_held != null:
				if calculator == null or calculator.has_uses_left():
					var s1_free: bool = calc_slot_1.item_stored == null
					var s2_free: bool = _is_tool_slot_active(calc_slot_2) and calc_slot_2.item_stored == null
					if s1_free and s2_free:
						var d1: float = calc_slot_1.get_global_rect().get_center().distance_to(mpos)
						var d2: float = (calc_slot_2 as Control).get_global_rect().get_center().distance_to(mpos)
						return calc_slot_1 if d1 <= d2 else (calc_slot_2 as Control)
					elif s1_free:
						return calc_slot_1
					elif s2_free:
						return calc_slot_2 as Control
			else:
				var occupied_calc: Array[Control] = []
				for cs in [calc_slot_result, calc_slot_1, calc_slot_2]:
					if _is_tool_slot_active(cs) and cs.item_stored != null:
						occupied_calc.append(cs as Control)
				if not occupied_calc.is_empty():
					var best_cs: Control = occupied_calc[0]
					var best_d: float = best_cs.get_global_rect().get_center().distance_to(mpos)
					for cs in occupied_calc:
						var d: float = cs.get_global_rect().get_center().distance_to(mpos)
						if d < best_d:
							best_d = d
							best_cs = cs
					return best_cs

	if _is_tool_slot_active(converter_slot):
		var conv_panel: Control = _get_tool_panel(converter_slot)
		if conv_panel != null and conv_panel.get_global_rect().grow(4.0).has_point(mpos):
			return converter_slot

	# Se o mouse está sobre a área de alguma ferramenta, nunca deixa vazar para a bancada.
	if _is_mouse_over_any_tool_area(mpos):
		return null

	# 3) Slots visíveis da mochila.
	if backpack_grid != null:
		for s in backpack_grid.slots_array:
			if s != null and is_instance_valid(s) and s.has_method("is_mouse_over_slot") and s.is_mouse_over_slot(mpos):
				return s as Control

	# 4) Slots visíveis da bancada.
	if pool_grid != null:
		for s in pool_grid.slots_array:
			if s != null and is_instance_valid(s) and s.has_method("is_mouse_over_slot") and s.is_mouse_over_slot(mpos):
				return s as Control

	return null

func _sync_priority_hover(mpos: Vector2) -> void:
	if backpack_grid == null and pool_grid == null:
		return
	var resolved: Control = _resolve_priority_slot(mpos)
	if resolved != current_slot:
		if current_slot != null:
			_on_slot_exited(current_slot)
		if resolved != null:
			_on_slot_entered(resolved)
	elif resolved != null:
		_on_slot_entered(resolved)

func _on_slot_item_changed(_slot):
	_update_bytes_label()
	_update_hint()

func _click_blocked_by_ui() -> bool:
	if inspector_modal != null and is_instance_valid(inspector_modal) and inspector_modal.visible:
		return true
	if _origin_notice_banner != null and is_instance_valid(_origin_notice_banner) and _origin_notice_banner.visible:
		return true
	var c := get_viewport().gui_get_hovered_control()
	if c == null:
		return false
	if c.is_in_group("slot"):
		return false
	var p := c.get_parent()
	if p and p.is_in_group("slot"):
		return false
	return c is BaseButton or c is LineEdit or c is TextEdit or c is OptionButton or c is Slider

func _process(_delta):
	if _is_finishing:
		return
	_update_inspect_button()
	var mpos: Vector2 = get_global_mouse_position()
	_sync_priority_hover(mpos)
		
	if item_held:
		item_held.global_position = mpos
		if Input.is_action_just_pressed("select_item"):
			if _click_blocked_by_ui():
				return
			_sync_priority_hover(mpos)
			if current_slot and can_place:
				_place_item()
			elif not _is_mouse_over_any_tool_area(mpos):
				if backpack_grid and backpack_grid.get_global_rect().has_point(mpos):
					var free_slot = backpack_grid.find_first_free_anchor_for(item_held)
					if free_slot:
						var need = item_held.get_size_bytes() if item_held.has_method("get_size_bytes") else 1
						var used = backpack_grid.total_bytes_used()
						if used + need <= backpack_grid.capacity_bytes:
							current_slot = free_slot
							can_place = true
							_place_item()
				elif pool_grid and pool_grid.get_global_rect().has_point(mpos):
					var free_slot = pool_grid.find_first_free_anchor_for(item_held)
					if free_slot:
						current_slot = free_slot
						can_place = true
						_place_item()
	else:
		if Input.is_action_just_pressed("select_item"):
			if _click_blocked_by_ui():
				return
			_sync_priority_hover(mpos)
			if current_slot and current_slot.item_stored:
				_pick_item()

func _place_item():
	if not can_place or not current_slot:
		return
	if not item_held or not is_instance_valid(item_held):
		return
		
	if current_slot == converter_slot and converter:
		var placed := converter.convert_with_dialog(item_held, true)
		if not placed:
			return
		if _source_slot != current_slot:
			moves_count += 1
		item_held = null
		can_place = false
		_update_bytes_label()
		_update_hint()
		_refresh_script_state()
		return
		
	if current_slot == calc_slot_1 or current_slot == calc_slot_2 or current_slot == inspect_slot:
		if current_slot == calc_slot_1 or current_slot == calc_slot_2:
			if calculator: calculator.clear_result()
		
		# Using the calculator method to mount if available, else inline logic
		if calculator and (current_slot == calc_slot_1 or current_slot == calc_slot_2):
			calculator.mount_item(current_slot, item_held)
			_wire_orb(current_slot.item_stored)
		else:
			item_held.grid_anchor = current_slot
			if item_held.get_parent() != current_slot:
				if item_held.get_parent():
					item_held.get_parent().remove_child(item_held)
				current_slot.add_child(item_held)
			if item_held.has_method("shrink_orb_for_tool_slot"):
				item_held.shrink_orb_for_tool_slot()
			if item_held.has_method("snap_to_slot"):
				item_held.snap_to_slot(current_slot)
			else:
				item_held.position = current_slot.size * 0.5
			item_held.selected = false
			current_slot.item_stored = item_held
			current_slot.state = current_slot.States.TAKEN
			_wire_orb(current_slot.item_stored)
		
		item_held = null
		can_place = false
		if calculator: calculator.check_calculator()
		_update_bytes_label()
		_update_hint()
		_refresh_script_state()
		return
		
	var src_name := _slot_region_name(_source_slot)
	var dest_name := _slot_region_name(current_slot)
	var moved_item = item_held
	var py_val := PhaseScriptLog.py_value_for_item(moved_item)
	var typ := PhaseScriptLog.type_label_for_item(moved_item)
	var nbytes := PhaseScriptLog.bytes_for_item(moved_item)

	if current_slot in backpack_grid.slots_array:
		backpack_grid.place_item(item_held, current_slot)
		backpack_grid.pack_items_left()
	else:
		pool_grid.place_item(item_held, current_slot)
	
	if _source_slot != current_slot:
		moves_count += 1
		# Ignora rearranjo inútil, inspetor e undo mochila→bancada.
		var skip_trace := src_name == dest_name \
			or src_name == "inspetor" or dest_name == "inspetor" \
			or (src_name == "mochila" and dest_name == "bancada")
		if not skip_trace:
			var vname: String
			if dest_name == "mochila":
				vname = PhaseScriptLog.stable_var_name_for_item(moved_item)
			else:
				vname = _ensure_script_log().next_var_name("v")
			log_script_event("move", {
				"name": vname,
				"py_value": py_val,
				"type": typ,
				"bytes": nbytes,
				"src": src_name,
				"dest": dest_name,
				"where": dest_name,
			})
		
	item_held.selected = false
	item_held = null
	can_place = false
	_update_bytes_label()
	_update_hint()
	_refresh_script_state()

func _detach_orb_from_tool_slot(slot: Control, item: Node) -> void:
	if slot != null and is_instance_valid(slot):
		slot.state = slot.States.FREE
		if slot.has_method("set_item"):
			slot.set_item(null)
		else:
			slot.item_stored = null
	if item != null and is_instance_valid(item):
		if backpack_grid and item.data_type != ItemRef.DataType.RAW:
			MemoryLayout.apply_to_item(item, backpack_grid.slot_bytes, backpack_grid.grid_columns)
		if item.has_method("restore_orb_layout"):
			item.restore_orb_layout()

func _pick_item():
	var slot = current_slot
	if slot == null or slot.item_stored == null:
		return
	_source_slot = slot
	var mouse_pos := get_global_mouse_position()
	if slot.has_method("pick_item_at"):
		item_held = slot.pick_item_at(mouse_pos)
	else:
		item_held = slot.item_stored
	if not is_instance_valid(item_held):
		item_held = null
		return
	item_held.selected = true
	item_held.get_parent().remove_child(item_held)
	add_child(item_held)
	item_held.global_position = mouse_pos
	
	if slot == converter_slot:
		_detach_orb_from_tool_slot(converter_slot, item_held)
		if converter and converter.has_method("update_dropdown_visibility"):
			converter.update_dropdown_visibility()
	elif slot == inspect_slot or slot == calc_slot_result:
		_detach_orb_from_tool_slot(slot, item_held)
	elif slot == calc_slot_1 or slot == calc_slot_2:
		_detach_orb_from_tool_slot(slot, item_held)
		if calculator:
			calculator.clear_result()
	elif backpack_grid and slot in backpack_grid.slots_array:
		backpack_grid.remove_item(item_held)
		backpack_grid.pack_items_left()
	elif pool_grid and slot in pool_grid.slots_array:
		pool_grid.remove_item(item_held)
	_wire_orb(item_held)
	if converter:
		converter.revert_dropdown(item_held.data_type)
	_update_bytes_label()
	_update_hint()

func _update_bytes_label():
	if not backpack_grid:
		return
	var used = backpack_grid.total_bytes_used()
	var cap = backpack_grid.capacity_bytes
	var slot_note := ""
	if backpack_grid.get("slot_bytes") != null and MemoryLayout.normalize_slot_bytes(int(backpack_grid.slot_bytes)) == 1:
		slot_note = "  ·  slot de 1 byte (int = 4 células, short = 2)"
	bytes_label.text = "Mochila: %d / %d bytes%s" % [used, cap, slot_note]
	_update_next_button_state()

func _update_hint() -> void:
	if not hint_label:
		return
	if is_phase_success():
		if _is_backpack_partial():
			hint_label.text = "Há orbes esquecidos — você pode avançar, mas perderá 1 estrela."
		else:
			hint_label.text = "Objetivo concluído!"
		hint_label.visible = true
	else:
		hint_label.text = ""
		hint_label.visible = false
	_update_next_button_state()

func _wait_for_dialog(dlg: ConfirmationDialog) -> bool:
	var result = [false]
	var done = [false]
	dlg.confirmed.connect(func(): result[0] = true; done[0] = true)
	dlg.canceled.connect(func(): done[0] = true)
	dlg.close_requested.connect(func(): done[0] = true)
	
	while not done[0]:
		await get_tree().process_frame
		
	return result[0]


func _wait_accept_dialog(dlg: AcceptDialog) -> void:
	var done := [false]
	dlg.confirmed.connect(func(): done[0] = true)
	dlg.close_requested.connect(func(): done[0] = true)
	if dlg.has_signal("canceled"):
		dlg.canceled.connect(func(): done[0] = true)
	while not done[0]:
		await get_tree().process_frame
