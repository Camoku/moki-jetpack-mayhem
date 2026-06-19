# ==========================================================
#  title_screen.gd - the start menu
# ==========================================================
#  Auto-scrolls the city parallax, bobs the Moki, pulses the "start" prompt,
#  shows the local Top-10 leaderboard, and lets you type a name (remembered
#  between runs). Press boost (Space/click) or Enter in the name box to start;
#  the typed name is saved and tagged onto this run's score at game over.
# ==========================================================
extends Node2D

const MAIN_SCENE := "res://Main.tscn"
const SCROLL_SPEED := 130.0   # how fast the city drifts by

var _t: float = 0.0
var _moki_y: float = 0.0
var _started: bool = false

@onready var bg: ParallaxBackground = $Background
@onready var moki: AnimatedSprite2D = $Moki
@onready var prompt: Label = $UI/Prompt
@onready var stats: Label = $UI/Stats
@onready var name_field: LineEdit = $UI/NameField
@onready var leaderboard: Label = $UI/Leaderboard


func _ready() -> void:
	Audio.start_music()            # carries seamlessly into the run
	moki.play("boost")
	_moki_y = moki.position.y
	stats.text = "HIGH SCORE  %d        BEST  %d m        COINS  %d" % [
		GameState.high_score, GameState.best_distance, GameState.coins]
	name_field.text = GameState.player_name     # remember the last name
	name_field.text_submitted.connect(_on_name_submitted)
	leaderboard.text = _build_board()


func _build_board() -> String:
	var s := "TOP SCORES\n\n"
	if GameState.leaderboard.is_empty():
		return s + "no runs yet —\nbe the first!"
	var rank := 1
	for e in GameState.leaderboard:
		s += "%2d. %-16s %d\n" % [rank, str(e.get("name", "Player")), int(e.get("score", 0))]
		rank += 1
	return s


func _process(delta: float) -> void:
	_t += delta
	bg.scroll_offset.x += SCROLL_SPEED * delta
	moki.position.y = _moki_y + sin(_t * 2.0) * 16.0
	moki.rotation = sin(_t * 2.0) * 0.06
	prompt.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * 3.0))


func _on_name_submitted(_text: String) -> void:
	_start()


# Any boost input starts the run. Using _unhandled_input means clicks on the
# name box / corner Audio button (which they consume) don't accidentally start.
func _unhandled_input(event: InputEvent) -> void:
	if not _started and event.is_action_pressed("boost"):
		_start()


func _start() -> void:
	if _started:
		return
	_started = true
	GameState.player_name = name_field.text.strip_edges()
	GameState.save_game()          # remember the name for next time
	Audio.play("select")
	get_tree().change_scene_to_file(MAIN_SCENE)
