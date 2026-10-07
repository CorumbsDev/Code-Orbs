extends AudioStreamPlayer

func _ready():
	stream = preload("res://Inventory/Art/music/impressionist-sky-avbe-main-version-38452-01-49.mp3")
	volume_db = -15.0
	autoplay = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	play()
