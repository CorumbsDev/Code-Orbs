extends Control

@onready var icon_texture = $PanelContainer/HBoxContainer/Icon
@onready var title_label = $PanelContainer/HBoxContainer/VBoxContainer/Title
@onready var desc_label = $PanelContainer/HBoxContainer/VBoxContainer/Description

func setup(title: String, desc: String, icon_path: String) -> void:
	title_label.text = title
	desc_label.text = desc
	
	if ResourceLoader.exists(icon_path):
		var tex = load(icon_path)
		if tex:
			icon_texture.texture = tex
			icon_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _ready() -> void:
	var vp_size = get_viewport_rect().size
	var width = $PanelContainer.size.x
	
	var start_pos = Vector2(vp_size.x, vp_size.y - 120)
	var end_pos = Vector2(vp_size.x - width - 20, vp_size.y - 120)
	
	position = start_pos
	
	var tween = create_tween()
	tween.tween_property(self, "position", end_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(3.5)
	tween.tween_property(self, "position", start_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)
