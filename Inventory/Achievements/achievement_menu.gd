extends Control

@onready var container = $Panel/ScrollContainer/VBoxContainer

func _ready() -> void:
	_populate_achievements()

func _populate_achievements() -> void:
	for child in container.get_children():
		child.queue_free()
		
	var achs = AchievementManager.get_all_achievements()
	for id in achs:
		var data = achs[id]
		var item = _create_achievement_item(data)
		container.add_child(item)

func _create_achievement_item(data: Dictionary) -> Control:
	var panel = PanelContainer.new()
	var hbox = HBoxContainer.new()
	panel.add_child(hbox)
	
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(data["icon"]):
		icon.texture = load(data["icon"])
	
	if not data["unlocked"]:
		icon.modulate = Color(0.3, 0.3, 0.3, 1.0)
	
	hbox.add_child(icon)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(vbox)
	
	var title = Label.new()
	title.text = data["name"]
	title.add_theme_font_size_override("font_size", 20)
	if not data["unlocked"]:
		title.text += " (Bloqueado)"
		title.modulate = Color(0.5, 0.5, 0.5, 1.0)
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = data["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 16)
	if not data["unlocked"]:
		desc.modulate = Color(0.5, 0.5, 0.5, 1.0)
	vbox.add_child(desc)
	
	if data["max_progress"] > 1:
		var progress = ProgressBar.new()
		progress.max_value = data["max_progress"]
		progress.value = data["current_progress"]
		vbox.add_child(progress)
		
	return panel

func _on_close_button_pressed() -> void:
	queue_free()

func _on_reset_button_pressed() -> void:
	AchievementManager.reset_achievements()
	_populate_achievements()
