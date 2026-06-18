# ==========================================================
#  hud.gd - the on-screen score and the game-over screen
# ==========================================================
#  Lives on a CanvasLayer, so it draws in SCREEN space (it ignores the
#  camera and stays put). It does three jobs:
#    1) Show the live DISTANCE in metres (how deep you have flown).
#    2) When the Moki crashes, reveal the game-over panel showing your
#       final SCORE (distance x coin multiplier) and PAUSE the game.
#    3) Wait for Space to restart the run.
#
#  Important: this node's Process Mode is set to "Always" in the scene,
#  so it keeps running (and listening for input) even while the rest of
#  the game is paused.
# ==========================================================

extends CanvasLayer

# How many pixels equal one metre of distance (the live in-run tracker).
@export var pixels_per_meter: float = 50.0
# How many score points each metre is worth (before the coin multiplier).
# Score is its OWN thing, shown only at the end of the run.
@export var score_per_meter: float = 10.0

# The END-of-run multiplier grows in fair, even steps: every
# 'coins_per_tier' coins you collect adds 'multiplier_per_tier' to it.
# With 25 and 0.1, you get nothing until 25 coins (x1.1), then x1.2 at
# 50, x1.3 at 75, and so on.
@export var coins_per_tier: int = 25
@export var multiplier_per_tier: float = 0.1

var camera: Node2D
var start_x: float = 0.0
var have_start: bool = false
var distance_m: int = 0   # how far we have flown this run, in metres
var run_coins: int = 0
var game_over: bool = false

# A run-long score-multiplier bump (granted by beating the main boss). Adds on
# top of the coin-tier multiplier for the rest of the run.
var bonus_multiplier: float = 0.0

var player: Node2D

@onready var distance_label: Label = $DistanceLabel
@onready var mult_label: Label = $MultLabel
@onready var coin_label: Label = $CoinLabel
@onready var best_label: Label = $BestLabel
@onready var powerup_label: Label = $PowerupLabel
@onready var banner_label: Label = $BannerLabel
@onready var survival_label: Label = $SurvivalLabel
@onready var boss_bar: Control = $BossBar
@onready var boss_fill: ColorRect = $BossBar/Fill
@onready var boss_label: Label = $BossBar/Label
@onready var game_over_panel: Control = $GameOverPanel
@onready var final_label: Label = $GameOverPanel/Center/VBox/FinalLabel
@onready var flash_rect: ColorRect = $Flash

# Celebration screen-flash state: peak alpha that fades to 0.
var _flash: float = 0.0
var _flash_color: Color = Color(1, 1, 1, 1)
@export var flash_fade: float = 2.6   # how fast the flash fades (higher = snappier)

# Full pixel width of the boss health bar (matches the BossBar in Main.tscn).
const BOSS_BAR_WIDTH := 360.0

# Seconds the flash banner stays up after it appears.
var _banner_time: float = 0.0


# The final-score multiplier, based on how many coins we grabbed.
# Integer division gives the number of full tiers reached (24 coins -> 0
# tiers -> x1.0; 25 -> 1 tier -> x1.1; 50 -> 2 -> x1.2; ...).
func multiplier() -> float:
	# floori() divides then rounds DOWN to a whole number of tiers.
	var tiers := floori(float(run_coins) / float(coins_per_tier))
	return 1.0 + tiers * multiplier_per_tier + bonus_multiplier


# Add a permanent (rest-of-run) bump to the score multiplier - the main boss's
# run-long reward. Refreshes the on-screen multiplier readout.
func add_bonus_multiplier(amount: float) -> void:
	bonus_multiplier += amount
	mult_label.text = "Multiplier: x%.1f" % multiplier()


# Pop a full-screen colour flash (the passed colour's alpha is the peak), part of
# the celebration burst on clearing an event / beating a boss. It fades fast.
func flash(color: Color) -> void:
	_flash_color = color
	_flash = color.a
	flash_rect.visible = true


func _ready() -> void:
	# Let the Moki find us (player.crash() looks us up by this group).
	add_to_group("hud")
	game_over_panel.visible = false
	banner_label.visible = false
	survival_label.visible = false
	boss_bar.visible = false
	flash_rect.visible = false
	mult_label.text = "Multiplier: x1.0"
	coin_label.text = "Coins: 0"
	best_label.text = "Best: %d m" % GameState.best_distance


func _process(delta: float) -> void:
	# Fade the celebration screen-flash out.
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * flash_fade)
		flash_rect.color = Color(_flash_color.r, _flash_color.g, _flash_color.b, _flash)
		if _flash <= 0.0:
			flash_rect.visible = false

	# Auto-hide the flash banner a couple of seconds after it appears.
	if _banner_time > 0.0:
		_banner_time -= delta
		if _banner_time <= 0.0:
			banner_label.visible = false

	# Find the scrolling camera; how far it has moved = how deep we have flown.
	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
		return
	if not have_start:
		start_x = camera.global_position.x
		have_start = true

	if not game_over:
		distance_m = int((camera.global_position.x - start_x) / pixels_per_meter)
		distance_label.text = "Distance: %d m" % distance_m

	# Show which powerups are currently active (read from the Moki).
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player != null:
		powerup_label.text = player.powerup_status()


# Called by the spawner during a frenzy to show the survival countdown.
# Pass a negative number to hide it.
func set_status(text: String) -> void:
	if text == "":
		survival_label.visible = false
	else:
		survival_label.text = text
		survival_label.visible = true


# Called by the mini-boss to show/update its health bar. The fill shrinks as
# its HP drops; at 0 the spawner hides the bar via hide_boss_bar().
func set_boss_health(cur: int, mx: int, boss_name: String = "BOSS") -> void:
	boss_bar.visible = true
	boss_label.text = "%s   %d / %d" % [boss_name, cur, mx]
	var frac: float = clampf(float(cur) / float(mx), 0.0, 1.0)
	boss_fill.size.x = BOSS_BAR_WIDTH * frac


func hide_boss_bar() -> void:
	boss_bar.visible = false


# Called by the spawner to flash a centred message (frenzy start, frenzy
# complete, etc.). 'color' tints it; it auto-hides after 'time' seconds.
func show_banner(text: String, color: Color, time: float) -> void:
	banner_label.text = text
	banner_label.modulate = color
	banner_label.visible = true
	_banner_time = time


# Called by a coin when the Moki grabs it. 'amount' is 2 with the Doubler.
func add_coin(amount: int = 1) -> void:
	run_coins += amount
	coin_label.text = "Coins: %d" % run_coins
	mult_label.text = "Multiplier: x%.1f" % multiplier()


func _unhandled_input(event: InputEvent) -> void:
	# Once crashed, the next Space / click starts a fresh run.
	if game_over and event.is_action_pressed("boost"):
		get_tree().paused = false
		get_tree().reload_current_scene()


# Called by the Moki from its crash() function.
func show_game_over() -> void:
	if game_over:
		return
	game_over = true

	# Score is computed HERE, at the end: distance turned into points, then
	# boosted by the coin multiplier.
	var mult := multiplier()
	var final_score := int(distance_m * score_per_meter * mult)

	# New bests? Remember them. Bank this run's coins. Then save to disk.
	if final_score > GameState.high_score:
		GameState.high_score = final_score
	if distance_m > GameState.best_distance:
		GameState.best_distance = distance_m
	GameState.coins += run_coins
	GameState.save_game()

	final_label.text = "Distance: %d m\nCoins: %d  (x%.1f)\nScore: %d\n\nBest Distance: %d m\nBest Score: %d\nBanked Coins: %d\n\nPress Space to retry" % [
		distance_m, run_coins, mult, final_score, GameState.best_distance, GameState.high_score, GameState.coins
	]
	best_label.text = "Best: %d m" % GameState.best_distance
	game_over_panel.visible = true

	# Freeze the whole game. Because THIS node is "Always", it keeps
	# running so it can still catch the retry input.
	get_tree().paused = true
