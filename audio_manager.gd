# ==========================================================
#  audio_manager.gd - the global sound manager (autoload "Audio")
# ==========================================================
#  One place that owns all sound. Any script can just call:
#     Audio.play("coin")             # fire a one-shot SFX
#     Audio.play_varied("bounce")    # same, with a little random pitch
#     Audio.set_boost(true/false)    # start/stop the jetpack loop
#     Audio.start_music()            # begin the looping track
#  Press M in-game to mute everything.
#
#  How it works: a small POOL of AudioStreamPlayers is cycled through so
#  several SFX can overlap without cutting each other off. SFX go to the
#  "SFX" bus, music to the quieter "Music" bus (see default_bus_layout.tres).
# ==========================================================
extends Node

# All one-shot sound effects, preloaded once. Add a sound = drop a .wav in
# audio/sfx/ (see tools/gen_audio.py) and add a line here.
const SFX := {
	"coin": preload("res://audio/sfx/coin.wav"),
	"ding": preload("res://audio/sfx/ding.wav"),
	"powerup": preload("res://audio/sfx/powerup.wav"),
	"chest": preload("res://audio/sfx/chest.wav"),
	"crash": preload("res://audio/sfx/crash.wav"),
	"bounce": preload("res://audio/sfx/bounce.wav"),
	"ring": preload("res://audio/sfx/ring.wav"),
	"dash": preload("res://audio/sfx/dash.wav"),
	"laser": preload("res://audio/sfx/laser.wav"),
	"missile": preload("res://audio/sfx/missile.wav"),
	"boss_alarm": preload("res://audio/sfx/boss_alarm.wav"),
	"boss_hit": preload("res://audio/sfx/boss_hit.wav"),
	"boss_defeat": preload("res://audio/sfx/boss_defeat.wav"),
	"event": preload("res://audio/sfx/event.wav"),
	"jackpot": preload("res://audio/sfx/jackpot.wav"),
	"slot_tick": preload("res://audio/sfx/slot_tick.wav"),
	"sparkle": preload("res://audio/sfx/sparkle.wav"),
	"shield": preload("res://audio/sfx/shield.wav"),
	"revive": preload("res://audio/sfx/revive.wav"),
	"gameover": preload("res://audio/sfx/gameover.wav"),
	"select": preload("res://audio/sfx/select.wav"),
}

const POOL_SIZE := 16
const SETTINGS_PATH := "user://audio.cfg"
const BUSES := ["Master", "SFX", "Music"]

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music_player: AudioStreamPlayer
var _boost_player: AudioStreamPlayer
var muted: bool = false
# Per-bus volume as a 0..1 linear value (what the settings sliders show).
var _vol: Dictionary = {"Master": 1.0, "SFX": 1.0, "Music": 1.0}


func _ready() -> void:
	# Keep playing while the tree is paused (slot machine / game-over use pause).
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)

	# Music on its own bus. We loop by REPLAYING when it finishes rather than the
	# stream's internal loop (whose loop_end defaults to 0 = a silent zero-length
	# loop - the cause of the "music plays but you hear nothing" bug).
	var music: AudioStreamWAV = preload("res://audio/music/music_main.wav")
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.stream = music
	add_child(_music_player)
	_music_player.finished.connect(_replay_music)

	# The held jetpack thruster is a seamless loop toggled on/off.
	var boost: AudioStreamWAV = preload("res://audio/sfx/boost_loop.wav")
	boost.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_boost_player = AudioStreamPlayer.new()
	_boost_player.bus = "SFX"
	_boost_player.stream = boost
	_boost_player.volume_db = -6.0
	add_child(_boost_player)

	_load_settings()                                   # restore saved volumes + mute
	add_child(preload("res://settings_menu.gd").new())  # the global ESC settings menu


# Fire a one-shot sound. pitch 1.0 = normal; vol_db trims the level.
func play(sound: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not SFX.has(sound):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = SFX[sound]
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()


# Same, but with a little random pitch so repeated sounds (coins) don't fatigue.
func play_varied(sound: String, spread: float = 0.08, vol_db: float = 0.0) -> void:
	play(sound, 1.0 + randf_range(-spread, spread), vol_db)


func start_music() -> void:
	if not _music_player.playing:
		_music_player.play()


# Loop the track by restarting it the instant it ends.
func _replay_music() -> void:
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


# Start/stop the looping jetpack thruster (called every frame; guarded so it
# only actually starts/stops on a change).
func set_boost(on: bool) -> void:
	if on and not _boost_player.playing:
		_boost_player.play()
	elif not on and _boost_player.playing:
		_boost_player.stop()


func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
	_save_settings()


# --- volume settings (used by the settings menu) ------------------------

func get_bus_volume(bus: String) -> float:
	return _vol.get(bus, 1.0)


func set_bus_volume(bus: String, linear: float) -> void:
	_vol[bus] = clampf(linear, 0.0, 1.0)
	_apply_bus(bus)
	_save_settings()


func _apply_bus(bus: String) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		# linear_to_db(0) is -inf; floor very-low values to a silent -60 dB.
		var v: float = _vol[bus]
		AudioServer.set_bus_volume_db(idx, linear_to_db(v) if v > 0.001 else -60.0)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for b in BUSES:
			_vol[b] = float(cfg.get_value("audio", b.to_lower(), _vol[b]))
		muted = bool(cfg.get_value("audio", "muted", false))
	for b in BUSES:
		_apply_bus(b)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for b in BUSES:
		cfg.set_value("audio", b.to_lower(), _vol[b])
	cfg.set_value("audio", "muted", muted)
	cfg.save(SETTINGS_PATH)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		toggle_mute()
