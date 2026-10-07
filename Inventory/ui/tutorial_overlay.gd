class_name TutorialOverlay
extends CanvasLayer
## Painel modal de tutorial/onboarding.

signal closed()

const PATH_FONT := ""

@onready var title_label: Label = $CenterContainer/Panel/Margin/VBox/TitleLabel
@onready var body_label: RichTextLabel = $CenterContainer/Panel/Margin/VBox/RichTextLabel
@onready var btn_ok: Button = $CenterContainer/Panel/Margin/VBox/BtnOk

var _pref_key: String = ""
var _mark_on_close: bool = false
var _pending_present: Array = []


func _ready():
	btn_ok.pressed.connect(_on_ok)
	var panel: PanelContainer = $CenterContainer/Panel
	PanelArtLoader.apply_dialog_panel(panel)
	PanelArtLoader.apply_button_style(btn_ok)
	_style_labels()
	btn_ok.custom_minimum_size = Vector2(220, 52)
	visible = false
	if not _pending_present.is_empty():
		var args: Array = _pending_present
		_pending_present = []
		present(args[0], args[1], args[2], args[3])


func _style_labels() -> void:
	var font: Font = null
	if not PATH_FONT.is_empty():
		font = load(PATH_FONT) as Font
	if font:
		title_label.add_theme_font_override("font", font)
		body_label.add_theme_font_override("normal_font", font)
		body_label.add_theme_font_override("bold_font", font)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.78, 1))
	title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 1))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_font_size_override("font_size", 22)
	body_label.add_theme_color_override("default_color", Color(0.97, 0.98, 1, 1))
	body_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	body_label.add_theme_constant_override("outline_size", 3)
	body_label.add_theme_font_size_override("normal_font_size", 18)
	body_label.add_theme_font_size_override("bold_font_size", 18)


func present(pref_key: String, title: String, bbcode_body: String, mark_on_close: bool) -> void:
	if title_label == null or body_label == null:
		_pending_present = [pref_key, title, bbcode_body, mark_on_close]
		return
	_pref_key = pref_key
	_mark_on_close = mark_on_close
	title_label.text = title
	body_label.text = ReadableBbcode.for_ui(bbcode_body)
	var panel: PanelContainer = $CenterContainer/Panel
	if panel:
		var vp := get_viewport().get_visible_rect().size
		panel.custom_minimum_size = Vector2(
			clampf(minf(560.0, vp.x - 80.0), 320.0, 720.0),
			clampf(minf(320.0, vp.y - 120.0), 220.0, 480.0)
		)
	visible = true


func _on_ok() -> void:
	if _mark_on_close and not _pref_key.is_empty():
		LearningPrefs.mark_tutorial_seen(_pref_key)
	closed.emit()
	queue_free()


static func open(parent: Node, pref_key: String, title: String, bbcode_body: String, mark_on_close: bool) -> void:
	var tree := parent.get_tree()
	if tree == null:
		return
	# Evita empilhar vários overlays travando o mouse.
	for child in tree.root.get_children():
		if child is TutorialOverlay:
			child.queue_free()
	var inst = preload("res://Inventory/ui/tutorial_overlay.tscn").instantiate()
	tree.root.add_child(inst)
	inst.present(pref_key, title, bbcode_body, mark_on_close)
