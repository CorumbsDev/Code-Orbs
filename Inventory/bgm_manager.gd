extends AudioStreamPlayer

const SFX_ORB := "res://Inventory/sounds/selecionar e colocar orbe.mp3"
const SFX_STAR := "res://Inventory/sounds/estrela.mp3"
const SFX_THREE_STARS := "res://Inventory/sounds/3Estrelas.mp3"
const SFX_ACHIEVEMENT := "res://Inventory/sounds/conquistas.mp3"
const SFX_GAME_START := "res://Inventory/sounds/game_Start.mp3"
const SFX_WIN_GAME := "res://Inventory/sounds/win_game.mp3"

const SFX_POOL_SIZE := 8
const PREFS_PATH := "user://audio_prefs.cfg"
const PREFS_SECTION := "audio"
const MUSIC_VOLUME_DB := -15.0

var _streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _last_orb_sfx_msec: int = -1000
var music_muted: bool = false
var sfx_muted: bool = false


func _ready():
	stream = preload("res://Inventory/Art/music/impressionist-sky-avbe-main-version-38452-01-49.mp3")
	if "loop" in stream:
		stream.loop = true
	volume_db = MUSIC_VOLUME_DB
	autoplay = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_players.append(p)

	_load_prefs()
	_apply_music_mute()
	if not music_muted:
		play()


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
	if sfx_muted:
		return
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


func set_music_muted(muted: bool) -> void:
	music_muted = muted
	_apply_music_mute()
	_save_prefs()


func set_sfx_muted(muted: bool) -> void:
	sfx_muted = muted
	_save_prefs()


func toggle_music_muted() -> bool:
	set_music_muted(not music_muted)
	return music_muted


func toggle_sfx_muted() -> bool:
	set_sfx_muted(not sfx_muted)
	return sfx_muted


func _apply_music_mute() -> void:
	if music_muted:
		volume_db = -80.0
		stream_paused = true
	else:
		volume_db = MUSIC_VOLUME_DB
		stream_paused = false
		if not playing:
			play()


func _load_prefs() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PREFS_PATH) != OK:
		return
	music_muted = bool(cfg.get_value(PREFS_SECTION, "music_muted", false))
	sfx_muted = bool(cfg.get_value(PREFS_SECTION, "sfx_muted", false))


func _save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PREFS_PATH)
	cfg.set_value(PREFS_SECTION, "music_muted", music_muted)
	cfg.set_value(PREFS_SECTION, "sfx_muted", sfx_muted)
	cfg.save(PREFS_PATH)
