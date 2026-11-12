extends AudioStreamPlayer

const SFX_ORB := "res://Inventory/sounds/selecionar e colocar orbe.mp3"
const SFX_STAR := "res://Inventory/sounds/estrela.mp3"
const SFX_THREE_STARS := "res://Inventory/sounds/3Estrelas.mp3"
const SFX_ACHIEVEMENT := "res://Inventory/sounds/conquistas.mp3"
const SFX_GAME_START := "res://Inventory/sounds/game_Start.mp3"
const SFX_WIN_GAME := "res://Inventory/sounds/win_game.mp3"

const SFX_POOL_SIZE := 8

var _streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _last_orb_sfx_msec: int = -1000


func _ready():
	stream = preload("res://Inventory/Art/music/impressionist-sky-avbe-main-version-38452-01-49.mp3")
	if "loop" in stream:
		stream.loop = true
	volume_db = -15.0
	autoplay = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	play()

	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_players.append(p)


func _get_stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	if not ResourceLoader.exists(path):
		return null
	var s := load(path) as AudioStream
	if s != null:
		if "loop" in s:
			s.loop = false
		_streams[path] = s
	return s


func play_sfx(path: String, vol_db: float = -4.0) -> void:
	var s := _get_stream(path)
	if s == null:
		return
	var target: AudioStreamPlayer = null
	for p in _sfx_players:
		if not p.playing:
			target = p
			break
	if target == null and not _sfx_players.is_empty():
		target = _sfx_players[0]
	if target != null:
		target.stream = s
		target.volume_db = vol_db
		target.play()


func play_orb_sfx() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_orb_sfx_msec < 35:
		return
	_last_orb_sfx_msec = now
	play_sfx(SFX_ORB, -4.0)


func play_star() -> void:
	play_sfx(SFX_STAR, -3.0)


func play_three_stars() -> void:
	play_sfx(SFX_THREE_STARS, -2.0)


func play_achievement() -> void:
	play_sfx(SFX_ACHIEVEMENT, -3.0)


func play_game_start() -> void:
	play_sfx(SFX_GAME_START, -3.0)


func play_win_game() -> void:
	play_sfx(SFX_WIN_GAME, -2.0)
