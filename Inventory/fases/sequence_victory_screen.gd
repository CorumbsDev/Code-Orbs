class_name SequenceVictoryScreen
extends Control
## Tela de vitória mostrando todas as estrelas colecionadas ao longo da sequência de fases.

@export var is_modal: bool = false

@onready var lbl_header: Label = $Panel/VBoxMain/HeaderBox/LblTitle
@onready var lbl_subtitle: Label = $Panel/VBoxMain/HeaderBox/LblSubtitle
@onready var lbl_stars_count: Label = $Panel/VBoxMain/StatsCard/Margin/HBox/CenterStats/LblStarsCount
@onready var lbl_rank: Label = $Panel/VBoxMain/StatsCard/Margin/HBox/CenterStats/LblRank
@onready var lbl_moves: Label = $Panel/VBoxMain/StatsCard/Margin/HBox/RightStats/LblMoves
@onready var lbl_completed: Label = $Panel/VBoxMain/StatsCard/Margin/HBox/RightStats/LblCompleted
@onready var phases_container: VBoxContainer = $Panel/VBoxMain/Scroll/PhasesVBox
@onready var btn_replay: Button = $Panel/VBoxMain/ButtonsBox/BtnReplay
@onready var btn_menu: Button = $Panel/VBoxMain/ButtonsBox/BtnMenu
@onready var btn_close: Button = $Panel/VBoxMain/ButtonsBox/BtnClose
@onready var confetti: CPUParticles2D = $Confetti

const STAR_TEXTURE_PATH := "res://Inventory/Art/UI/star.png"
var _star_texture: Texture2D = null


func _ready() -> void:
	if ResourceLoader.exists(STAR_TEXTURE_PATH):
		_star_texture = load(STAR_TEXTURE_PATH) as Texture2D

	PanelArtLoader.apply_background(self)
	PanelArtLoader.skin_all_buttons(self)
	PanelArtLoader.apply_dialog_panel($Panel)

	btn_menu.pressed.connect(_on_menu_pressed)
	btn_replay.pressed.connect(_on_replay_pressed)
	if btn_close:
		btn_close.pressed.connect(_on_close_pressed)
		btn_close.visible = is_modal

	if is_modal:
		lbl_header.text = "Coleção de Estrelas"
		lbl_subtitle.text = "Progresso em todas as fases do Code Orbs"
		btn_replay.visible = false
		btn_menu.visible = false
		if btn_close:
			btn_close.visible = true
			btn_close.text = "Voltar"
	else:
		lbl_header.text = "Vitória! Jornada Concluída!"
		lbl_subtitle.text = "Parabéns! Você dominou o gerenciamento de tipos e memória!"
		btn_menu.visible = true
		btn_replay.visible = true
		if btn_close:
			btn_close.visible = false
		if BGMManager != null and BGMManager.has_method("play_win_game"):
			BGMManager.play_win_game()

	_populate_data()


func _unhandled_input(event: InputEvent) -> void:
	if is_modal and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()


func _populate_data() -> void:
	var summary := PhaseRunner.get_all_phases_summary()
	var total_stars := 0
	var max_stars := summary.size() * 3
	var total_moves := 0
	var completed_phases := 0

	# Limpa lista prévia
	for child in phases_container.get_children():
		child.queue_free()

	for item in summary:
		var stars: int = int(item.get("stars", 0))
		total_stars += stars
		total_moves += int(item.get("moves", 0))
		if item.get("completed", false) and stars > 0:
			completed_phases += 1

		var card := _create_phase_card(item)
		phases_container.add_child(card)

	# Atualiza cartão de resumo
	lbl_stars_count.text = "%d / %d" % [total_stars, max_stars]
	lbl_moves.text = "Movimentos: %d" % (PhaseRunner.get_total_run_moves() if PhaseRunner.get_total_run_moves() > 0 else total_moves)
	lbl_completed.text = "Fases Concluídas: %d / %d" % [completed_phases, summary.size()]
	lbl_rank.text = _rank_for_stars(total_stars, max_stars)

	# Inicia confete se obteve bom desempenho
	if confetti:
		confetti.emitting = true


func _rank_for_stars(stars: int, max_stars: int) -> String:
	if max_stars <= 0:
		return "Explorador da Máquina"
	var pct := float(stars) / float(max_stars)
	if pct >= 1.0:
		return "Arquiteto Supremo de Memória (100%)"
	elif pct >= 0.85:
		return "Mestre dos Dados (Avançado)"
	elif pct >= 0.65:
		return "Engenheiro de Sistemas"
	elif pct >= 0.40:
		return "Programador Júnior"
	else:
		return "Aprendiz dos Orbes"


func _create_phase_card(data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.20, 0.95)
	sb.border_color = Color(0.35, 0.45, 0.65, 0.7) if data.get("completed", false) else Color(0.2, 0.2, 0.25, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_top = 8
	sb.content_margin_right = 12
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Badge de número
	var num_panel := PanelContainer.new()
	var num_sb := StyleBoxFlat.new()
	num_sb.bg_color = Color(0.22, 0.38, 0.72, 0.9) if data.get("completed", false) else Color(0.2, 0.2, 0.2, 0.8)
	num_sb.set_corner_radius_all(4)
	num_sb.content_margin_left = 8
	num_sb.content_margin_right = 8
	num_sb.content_margin_top = 4
	num_sb.content_margin_bottom = 4
	num_panel.add_theme_stylebox_override("panel", num_sb)
	var num_lbl := Label.new()
	num_lbl.text = "Fase %02d" % int(data.get("number", 1))
	num_lbl.add_theme_font_size_override("font_size", 14)
	num_panel.add_child(num_lbl)
	hbox.add_child(num_panel)

	# Título e detalhes da fase
	var vbox_info := VBoxContainer.new()
	vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_info.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(vbox_info)

	var title_lbl := Label.new()
	title_lbl.text = str(data.get("title", "Fase"))
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 1.0))
	vbox_info.add_child(title_lbl)

	# Breakdown de estrelas em texto descritivo
	var detail_lbl := Label.new()
	var s1: bool = bool(data.get("s1", false))
	var s2: bool = bool(data.get("s2", false))
	var s3: bool = bool(data.get("s3", false))
	var details: Array[String] = []
	if s1:
		details.append("Objetivo")
	if s2:
		details.append("Movimentos")
	if s3:
		details.append("Precisão")
	if details.is_empty():
		detail_lbl.text = "Sem estrelas registradas"
	else:
		detail_lbl.text = " | ".join(details)
	detail_lbl.add_theme_font_size_override("font_size", 12)
	detail_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9, 0.8))
	vbox_info.add_child(detail_lbl)

	# Container das 3 Estrelas Visuais
	var stars_box := HBoxContainer.new()
	stars_box.add_theme_constant_override("separation", 6)
	stars_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(stars_box)

	for star_idx in [s1, s2, s3]:
		var star_rect := TextureRect.new()
		star_rect.custom_minimum_size = Vector2(32, 32)
		star_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if _star_texture:
			star_rect.texture = _star_texture
		if star_idx:
			star_rect.modulate = Color(1.0, 0.92, 0.25, 1.0)
		else:
			star_rect.modulate = Color(0.2, 0.2, 0.25, 0.5)
		stars_box.add_child(star_rect)

	# Total de estrelas nesta fase
	var score_lbl := Label.new()
	var stars_earned: int = int(data.get("stars", 0))
	score_lbl.text = "%d / 3" % stars_earned
	score_lbl.custom_minimum_size = Vector2(48, 0)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_lbl.add_theme_font_size_override("font_size", 16)
	score_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3) if stars_earned == 3 else Color(0.85, 0.85, 0.9))
	hbox.add_child(score_lbl)

	return panel


func _on_menu_pressed() -> void:
	PhaseRunner.abort_sequence()
	get_tree().change_scene_to_file("res://Inventory/fases/main_menu.tscn")


func _on_replay_pressed() -> void:
	if is_modal:
		queue_free()
	PhaseRunner.restart_sequence()


func _on_close_pressed() -> void:
	queue_free()

