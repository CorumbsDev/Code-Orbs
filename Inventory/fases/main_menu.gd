extends Control

const PATH_FONT := ""
const REF_SIZE := Vector2(1920.0, 1080.0)

var _menu_font: Font


func _ready():
	if not PATH_FONT.is_empty():
		_menu_font = load(PATH_FONT) as Font
	PanelArtLoader.skin_all_buttons(self)
	PanelArtLoader.apply_background(self, PanelArtLoader.PATH_MENU_BACKGROUND)
	_style_menu_text()
	get_viewport().size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	_style_menu_text()


func _style_menu_text() -> void:
	var vp := get_viewport_rect().size
	var ui_scale := clampf(minf(vp.x / REF_SIZE.x, vp.y / REF_SIZE.y), 0.68, 1.12)

	var subtitle: Label = $Subtitle
	if subtitle:
		_apply_kiwi_font(subtitle)
		subtitle.add_theme_font_size_override("font_size", clampi(int(24.0 * ui_scale), 17, 30))
		subtitle.add_theme_constant_override("outline_size", clampi(int(4.0 * ui_scale), 3, 5))
		subtitle.add_theme_constant_override("letter_spacing", 1)
		# Ancoragem responsiva: subtítulo sobe um pouco em telas baixas (720p).
		var top_ratio := lerpf(0.30, 0.36, clampf(vp.y / REF_SIZE.y, 0.67, 1.0))
		subtitle.anchor_top = top_ratio
		subtitle.anchor_bottom = top_ratio + lerpf(0.05, 0.07, clampf(vp.y / REF_SIZE.y, 0.67, 1.0))
		subtitle.offset_top = 0
		subtitle.offset_bottom = 0

	var center: CenterContainer = $Center
	if center:
		center.anchor_top = lerpf(0.40, 0.44, clampf(vp.y / REF_SIZE.y, 0.67, 1.0))
		center.offset_top = 0

	var vbox: VBoxContainer = $Center/VBox
	if vbox:
		vbox.add_theme_constant_override("separation", clampi(int(18.0 * ui_scale), 12, 22))
		var btn_w := clampi(int(320.0 * ui_scale), 248, 380)
		var btn_h := clampi(int(52.0 * ui_scale), 44, 60)
		var sizes := [
			clampi(int(26.0 * ui_scale), 20, 30),
			clampi(int(24.0 * ui_scale), 18, 28),
			clampi(int(24.0 * ui_scale), 18, 28),
			clampi(int(24.0 * ui_scale), 18, 28),
		]
		var i := 0
		for child in vbox.get_children():
			if child is Button and i < sizes.size():
				_apply_kiwi_font(child)
				child.custom_minimum_size = Vector2(btn_w, btn_h)
				child.add_theme_font_size_override("font_size", sizes[i])
				child.add_theme_constant_override("outline_size", clampi(int(3.0 * ui_scale), 2, 4))
				i += 1


func _apply_kiwi_font(ctrl: Control) -> void:
	if _menu_font:
		ctrl.add_theme_font_override("font", _menu_font)


func _on_comecar_pressed():
	var fm := SequenceFileManager.new()
	var steps := fm.get_play_steps()
	if steps.is_empty():
		_show_menu_dialog(
			"Sem fases para jogar",
			"A primeira sequência não tem fases.\n\nAbra o Criador de Fases, adicione pelo menos uma fase e salve."
		)
		return
	var play_steps := _with_all_conversions(steps)
	PhaseRunner.begin_with_steps(play_steps)
	if not PhaseRunner.is_sequence_active():
		_show_menu_dialog(
			"Não foi possível iniciar",
			"A sequência não tem fases jogáveis.\n(Verifique se há fases além de Binário/Conversão desabilitadas.)"
		)


func _with_all_conversions(steps: Array) -> Array:
	var out: Array = []
	for s in steps:
		if s is PhaseSequenceStep:
			var copy := (s as PhaseSequenceStep).duplicate(true) as PhaseSequenceStep
			var cfg: PhaseConfig = copy.config_mochila
			if cfg:
				cfg.use_converter = true
				cfg.allow_float = true
				cfg.allow_double = true
				cfg.allow_short = true
				cfg.allow_fp8 = true
				cfg.allow_fp16 = true
			out.append(copy)
		else:
			out.append(s)
	return out


func _show_menu_dialog(title: String, message: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = title
	dlg.dialog_text = message
	add_child(dlg)
	dlg.popup_centered(Vector2(460, 160))


func _on_gerador_pressed():
	get_tree().change_scene_to_file("res://Inventory/fases/sequence_editor.tscn")


func _on_glossario_pressed():
	get_tree().change_scene_to_file("res://Inventory/fases/glossary_screen.tscn")

func _on_conquistas_pressed():
	var menu = preload("res://Inventory/Achievements/achievement_menu.tscn").instantiate()
	add_child(menu)
