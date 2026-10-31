extends CanvasLayer

const POPUP_SCENE = preload("res://Inventory/Achievements/achievement_popup.tscn")

func _ready() -> void:
	# Alto Z-index para ficar em cima de tudo
	layer = 100
	
	if AchievementManager != null:
		AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(id: String) -> void:
	var achievements = AchievementManager.get_all_achievements()
	if not achievements.has(id):
		return
		
	var data = achievements[id]
	if BGMManager != null and BGMManager.has_method("play_achievement"):
		BGMManager.play_achievement()
	var popup = POPUP_SCENE.instantiate()
	add_child(popup)
	popup.setup(data["name"], data["desc"], data["icon"])
