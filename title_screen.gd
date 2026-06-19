# ==========================================================
#  title_screen.gd - the start menu
# ==========================================================
#  Auto-scrolls the city parallax, bobs the Moki on his jet flame, pulses
#  the "start" prompt, and shows the best-run stats. Press boost (Space or
#  click) to drop into a run. The Audio autoload's corner button + Esc menu
#  ride along on top, and the music carries straight into the game.
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


func _ready() -> void:
	Audio.start_music()            # carries seamlessly into the run
	moki.play("boost")
	_moki_y = moki.position.y
	stats.text = "HIGH SCORE  %d        BEST  %d m        COINS  %d" % [
		GameState.high_score, GameState.best_distance, GameState.coins]


func _process(delta: float) -> void:
	_t += delta
	# Drift the city by (increasing scroll_offset = parallax moves left, like flying).
	bg.scroll_offset.x += SCROLL_SPEED * delta
	# Bob + gently tilt the hovering Moki.
	moki.position.y = _moki_y + sin(_t * 2.0) * 16.0
	moki.rotation = sin(_t * 2.0) * 0.06
	# Pulse the start prompt.
	prompt.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * 3.0))


# Any boost input starts the run. Using _unhandled_input means clicks on the
# corner Audio button (which the button consumes) don't accidentally start.
func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	if event.is_action_pressed("boost"):
		_started = true
		Audio.play("select")
		get_tree().change_scene_to_file(MAIN_SCENE)
