class_name VictoryOverlay
extends Control

signal advance_requested
signal script_requested

@onready var star1_rect: TextureRect = $Panel/VBoxContainer/StarsContainer/Star1
@onready var star2_rect: TextureRect = $Panel/VBoxContainer/StarsContainer/Star2
@onready var star3_rect: TextureRect = $Panel/VBoxContainer/StarsContainer/Star3

@onready var confete_1: CPUParticles2D = $Panel/VBoxContainer/StarsContainer/Star1/CPUParticles2D
@onready var confete_2: CPUParticles2D = $Panel/VBoxContainer/StarsContainer/Star2/CPUParticles2D
@onready var confete_3: CPUParticles2D = $Panel/VBoxContainer/StarsContainer/Star3/CPUParticles2D

@onready var lbl_star1_desc: Label = $Panel/VBoxContainer/StarBreakdown/Star1Label
@onready var lbl_star2_desc: Label = $Panel/VBoxContainer/StarBreakdown/Star2Label
@onready var lbl_star3_desc: Label = $Panel/VBoxContainer/StarBreakdown/Star3Label

@onready var lbl_title: Label = $Panel/VBoxContainer/Title
@onready var lbl_desc: Label = $Panel/VBoxContainer/Desc

@onready var btn_advance: Button = $Panel/VBoxContainer/Buttons/BtnAdvance
@onready var btn_retry: Button = $Panel/VBoxContainer/Buttons/BtnRetry
@onready var btn_ver_script: Button = get_node_or_null("Panel/VBoxContainer/Buttons/BtnVerScript")

var earned_star1: bool = false
var earned_star2: bool = false
var earned_star3: bool = false


func _ready():
	hide()
	btn_advance.pressed.connect(_on_advance_pressed)
	btn_retry.pressed.connect(_on_retry_pressed)
	if btn_ver_script:
		btn_ver_script.visible = false
		btn_ver_script.pressed.connect(_on_ver_script_pressed)

	star1_rect.modulate = Color(0.2, 0.2, 0.2, 0.8)
	star2_rect.modulate = Color(0.2, 0.2, 0.2, 0.8)
	star3_rect.modulate = Color(0.2, 0.2, 0.2, 0.8)

	PanelArtLoader.apply_background(self)
	PanelArtLoader.skin_all_buttons(self)
	PanelArtLoader.apply_dialog_panel($Panel)


func show_victory(s1: bool, s2: bool, s3: bool, desc: String = ""):
	earned_star1 = s1
	earned_star2 = s2
	earned_star3 = s3
	lbl_desc.text = desc

	# Textos e status das 3 estrelas
	_update_star_labels()
	_populate_phase_achievements()

	# Botão de avançar com texto especial na última fase
	if PhaseRunner.is_last_phase():
		btn_advance.text = "Concluir Jornada →"
	else:
		btn_advance.text = "Próxima Fase →"

	show()
	_animate_stars()


func _update_star_labels() -> void:
	if lbl_star1_desc:
		lbl_star1_desc.text = "Objetivo"
		lbl_star1_desc.modulate = Color(0.45, 0.95, 0.45) if earned_star1 else Color(0.5, 0.5, 0.5, 0.8)
	if lbl_star2_desc:
		lbl_star2_desc.text = "Movimentos"
		lbl_star2_desc.modulate = Color(0.45, 0.95, 0.45) if earned_star2 else Color(0.5, 0.5, 0.5, 0.8)
	if lbl_star3_desc:
		lbl_star3_desc.text = "Precisão"
		lbl_star3_desc.modulate = Color(0.45, 0.95, 0.45) if earned_star3 else Color(0.5, 0.5, 0.5, 0.8)


func _populate_phase_achievements() -> void:
	var vbox: VBoxContainer = $Panel/VBoxContainer
	if vbox == null:
		return
	var old_sec := vbox.get_node_or_null("PhaseAchievementsSection")
	if old_sec:
		old_sec.queue_free()

	var unlocked: Array[Dictionary] = []
	if AchievementManager != null and AchievementManager.has_method("get_phase_unlocked_achievements"):
		unlocked = AchievementManager.get_phase_unlocked_achievements()

	var sec := VBoxContainer.new()
	sec.name = "PhaseAchievementsSection"
	sec.add_theme_constant_override("separation", 6)

	var header := Label.new()
	header.text = "Conquistas Alcançadas na Fase:"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	sec.add_child(header)

	if unlocked.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Nenhuma conquista alcançada nesta fase."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", Color(0.68, 0.72, 0.78))
		sec.add_child(empty_lbl)
	else:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, mini(unlocked.size() * 58, 130))
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var list_vbox := VBoxContainer.new()
		list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list_vbox.add_theme_constant_override("separation", 6)
		scroll.add_child(list_vbox)
		for ach in unlocked:
			var card := PanelContainer.new()
			var st := StyleBoxFlat.new()
			st.bg_color = Color(0.12, 0.16, 0.22, 0.92)
			st.border_color = Color(0.95, 0.8, 0.32, 0.85)
			st.set_border_width_all(1)
			st.set_corner_radius_all(6)
			st.content_margin_left = 10
			st.content_margin_right = 10
			st.content_margin_top = 6
			st.content_margin_bottom = 6
			card.add_theme_stylebox_override("panel", st)
			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 10)
			card.add_child(hbox)
			var icon_path := str(ach.get("icon", ""))
			if icon_path != "" and ResourceLoader.exists(icon_path):
				var icon_rect := TextureRect.new()
				icon_rect.custom_minimum_size = Vector2(36, 36)
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				icon_rect.texture = load(icon_path)
				hbox.add_child(icon_rect)
			var text_vbox := VBoxContainer.new()
			text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text_vbox.add_theme_constant_override("separation", 2)
			var name_lbl := Label.new()
			name_lbl.text = str(ach.get("name", ""))
			name_lbl.add_theme_font_size_override("font_size", 14)
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.93, 0.55))
			text_vbox.add_child(name_lbl)
			var desc_lbl := Label.new()
			desc_lbl.text = str(ach.get("desc", ""))
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_lbl.add_theme_font_size_override("font_size", 11)
			desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.94))
			text_vbox.add_child(desc_lbl)
			hbox.add_child(text_vbox)
			list_vbox.add_child(card)
		sec.add_child(scroll)

	vbox.add_child(sec)
	var sep2 := vbox.get_node_or_null("HSeparator2")
	if sep2:
		vbox.move_child(sec, sep2.get_index())

	var panel: Panel = $Panel
	if panel:
		var extra_h: float = 60.0 if unlocked.is_empty() else float(mini(unlocked.size() * 62 + 40, 170))
		panel.custom_minimum_size = Vector2(640, 410 + extra_h)
		panel.offset_top = -(410.0 + extra_h) * 0.5
		panel.offset_bottom = (410.0 + extra_h) * 0.5


func _animate_stars():
	var all_three := earned_star1 and earned_star2 and earned_star3
	if earned_star1:
		await get_tree().create_timer(0.4).timeout
		star1_rect.modulate = Color(1, 0.92, 0.3, 1)
		confete_1.emitting = true
		if BGMManager != null and BGMManager.has_method("play_star"):
			BGMManager.play_star()

	if earned_star2:
		await get_tree().create_timer(0.6).timeout
		star2_rect.modulate = Color(1, 0.92, 0.3, 1)
		confete_2.emitting = true
		if BGMManager != null and BGMManager.has_method("play_star"):
			BGMManager.play_star()

	if earned_star3:
		await get_tree().create_timer(0.8).timeout
		star3_rect.modulate = Color(1, 0.92, 0.3, 1)
		confete_3.emitting = true
		if BGMManager != null:
			if all_three and BGMManager.has_method("play_three_stars"):
				BGMManager.play_three_stars()
			elif BGMManager.has_method("play_star"):
				BGMManager.play_star()


func _on_ver_script_pressed() -> void:
	script_requested.emit()


func _on_advance_pressed():
	advance_requested.emit()
	queue_free()


func _on_retry_pressed():
	PhaseRunner.restart_current_phase()
