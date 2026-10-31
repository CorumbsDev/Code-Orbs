class_name VictoryOverlay
extends Control

signal advance_requested

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
@onready var lbl_total_stars: Label = $Panel/VBoxContainer/TotalStarsPanel/Margin/HBox/LblTotalStars
@onready var btn_view_all_stars: Button = $Panel/VBoxContainer/TotalStarsPanel/Margin/HBox/BtnViewAllStars

@onready var btn_advance: Button = $Panel/VBoxContainer/Buttons/BtnAdvance
@onready var btn_retry: Button = $Panel/VBoxContainer/Buttons/BtnRetry

var earned_star1: bool = false
var earned_star2: bool = false
var earned_star3: bool = false


func _ready():
	hide()
	btn_advance.pressed.connect(_on_advance_pressed)
	btn_retry.pressed.connect(_on_retry_pressed)
	if btn_view_all_stars:
		btn_view_all_stars.pressed.connect(_on_view_all_stars_pressed)

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

	# Total de estrelas colecionadas
	var total_stars: int = PhaseRunner.get_total_saved_stars()
	var max_stars: int = PhaseRunner.get_max_total_stars()
	if lbl_total_stars:
		lbl_total_stars.text = "Estrelas Colecionadas: %d / %d" % [total_stars, max_stars]

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


func _on_view_all_stars_pressed() -> void:
	var screen := preload("res://Inventory/fases/sequence_victory_screen.tscn").instantiate()
	screen.is_modal = true
	add_child(screen)


func _on_advance_pressed():
	advance_requested.emit()
	queue_free()


func _on_retry_pressed():
	PhaseRunner.restart_current_phase()
