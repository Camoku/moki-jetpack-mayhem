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

# --- Slot machine (spend spin tokens at the end of a run) ---
@export var slot_spin_duration: float = 1.1   # How long the reel flickers before it lands.
@export var revive_transition_time: float = 1.3  # A "get ready" beat after REVIVE lands before play resumes.
# Coin payouts for the three "win" outcomes.
@export var slot_small_coins: int = 25
@export var slot_medium_coins: int = 75
@export var slot_mega_coins: int = 300
# Relative odds of each outcome (a weighted pick, like the powerup weights). Small
# wins are common; mega + revive are the rare, exciting ones.
@export var slot_weight_small: float = 40.0
@export var slot_weight_medium: float = 22.0
@export var slot_weight_shield: float = 18.0
@export var slot_weight_mega: float = 12.0
@export var slot_weight_revive: float = 12.0

var camera: Node2D
var start_x: float = 0.0
var have_start: bool = false
var distance_m: int = 0   # how far we have flown this run, in metres
var run_coins: int = 0
var run_spins: int = 0   # spin tokens collected THIS run (use-it-or-lose-it)
var game_over: bool = false

# Slot-machine state (the screen shown on a crash when run_spins > 0).
var _slot_open: bool = false     # is the slot panel up (and the game paused for it)?
var _spinning: bool = false      # is the reel currently flickering toward a result?
var _spin_time: float = 0.0      # seconds left in the current spin animation
var _flicker: float = 0.0        # countdown to the next reel-symbol flicker
var _pending_reward: String = "" # the result this spin will land on (decided up front)
var _revive_pending: float = 0.0 # >0 = a revive landed; holding a beat before play resumes

# The symbols the reel flickers through while spinning (one per reward, + a star).
const SLOT_SYMBOLS: Array[String] = ["$", "$$$", "777", "SHLD", "1UP", "★"]

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
@onready var spin_label: Label = $SpinLabel
@onready var slot_panel: Control = $SlotPanel
@onready var reel_label: Label = $SlotPanel/Center/VBox/ReelLabel
@onready var slot_result_label: Label = $SlotPanel/Center/VBox/SlotResultLabel
@onready var slot_prompt_label: Label = $SlotPanel/Center/VBox/PromptLabel

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
	slot_panel.visible = false
	banner_label.visible = false
	survival_label.visible = false
	boss_bar.visible = false
	flash_rect.visible = false
	mult_label.text = "Multiplier: x1.0"
	coin_label.text = "Coins: 0"
	spin_label.text = "Spins: 0"
	best_label.text = "Best: %d m" % GameState.best_distance


func _process(delta: float) -> void:
	# Spin the slot reel while a spin is in progress. This runs even though the
	# game is paused, because this HUD's Process Mode is "Always".
	if _spinning:
		_spin_time -= delta
		_flicker -= delta
		if _flicker <= 0.0:
			_flicker = 0.06
			# Flicker through random symbols (white) for the rolling-reel look.
			reel_label.text = SLOT_SYMBOLS[randi() % SLOT_SYMBOLS.size()]
			reel_label.modulate = Color(1, 1, 1, 1)
		if _spin_time <= 0.0:
			_spinning = false
			_land_reward(_pending_reward)

	# After a REVIVE lands, hold a short "get ready" beat (the game stays paused,
	# slot panel still up) before we actually drop the Moki back into the run.
	if _revive_pending > 0.0:
		_revive_pending -= delta
		if _revive_pending <= 0.0:
			_finish_revive()

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


# Called by a spin token when the Moki grabs it: bank one spin for the slot machine.
func add_spin_token() -> void:
	run_spins += 1
	spin_label.text = "Spins: %d" % run_spins


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("boost"):
		return
	# The slot machine takes over the Space key while it is open.
	if _slot_open:
		if _spinning or _revive_pending > 0.0:
			return                 # ignore input mid-spin / during the revive beat
		if run_spins > 0:
			_start_spin()          # spend a token, roll the reel
		else:
			_finish_slots()        # out of spins -> on to the game-over screen
		return
	# Otherwise, once crashed, the next Space / click starts a fresh run.
	if game_over:
		get_tree().paused = false
		get_tree().reload_current_scene()


# Called by the Moki from its crash() function. If we collected any spin tokens
# this run, open the slot machine first (a revive there can save the run);
# otherwise go straight to the game-over screen.
func player_crashed() -> void:
	if run_spins > 0:
		_open_slot()
	else:
		show_game_over()


# Open the slot-machine panel and pause the game for it. Nothing about the run is
# finalised here - a "revive" must be able to drop us back in.
func _open_slot() -> void:
	_slot_open = true
	_spinning = false
	_revive_pending = 0.0
	reel_label.text = "★"
	reel_label.modulate = Color(1, 1, 1, 1)
	slot_result_label.text = ""
	_update_slot_prompt()
	slot_panel.visible = true
	get_tree().paused = true


# Start one spin: spend a token, pick the result now, and let _process roll the
# reel toward it over slot_spin_duration seconds.
func _start_spin() -> void:
	_spinning = true
	_spin_time = slot_spin_duration
	_flicker = 0.0
	run_spins -= 1
	spin_label.text = "Spins: %d" % run_spins
	_pending_reward = _pick_slot_reward()
	slot_result_label.text = ""
	slot_prompt_label.text = "spinning..."


# A weighted random outcome (same shape as the spawner's powerup weights).
func _pick_slot_reward() -> String:
	var table := [
		["small", slot_weight_small],
		["medium", slot_weight_medium],
		["shield", slot_weight_shield],
		["mega", slot_weight_mega],
		["revive", slot_weight_revive],
	]
	var total := 0.0
	for e in table:
		total += float(e[1])
	var roll := randf() * total
	for e in table:
		roll -= float(e[1])
		if roll <= 0.0:
			return str(e[0])
	return "small"


# The reel has stopped: show the landed symbol + result text, and apply the prize.
func _land_reward(kind: String) -> void:
	match kind:
		"small":
			reel_label.text = "$"
			reel_label.modulate = Color(0.6, 1.0, 0.6)
			_award_coins(slot_small_coins, "SMALL WIN!")
		"medium":
			reel_label.text = "$$$"
			reel_label.modulate = Color(1.0, 0.85, 0.3)
			_award_coins(slot_medium_coins, "MEDIUM WIN!")
		"mega":
			reel_label.text = "777"
			reel_label.modulate = Color(1.0, 0.5, 1.0)
			_award_coins(slot_mega_coins, "MEGA WIN!")
			flash(Color(1.0, 0.5, 1.0, 0.4))
		"shield":
			reel_label.text = "SHLD"
			reel_label.modulate = Color(0.3, 0.7, 1.0)
			GameState.start_with_shield = true
			slot_result_label.text = "SHIELD NEXT RUN!"
			_update_slot_prompt()
		"revive":
			reel_label.text = "1UP"
			reel_label.modulate = Color(1.0, 0.5, 0.7)
			slot_result_label.text = "REVIVE!"
			slot_prompt_label.text = "Get ready..."
			flash(Color(1.0, 0.5, 0.7, 0.4))
			_revive_pending = revive_transition_time   # hold the beat; _process finishes it


# Bank a coin prize immediately (so a later revive can't make us lose it) and
# show the result line.
func _award_coins(amount: int, label: String) -> void:
	GameState.coins += amount
	GameState.save_game()
	slot_result_label.text = "%s   +%d COINS" % [label, amount]
	_update_slot_prompt()


# The "what to press next" line: spin again if tokens remain, else continue.
func _update_slot_prompt() -> void:
	if run_spins > 0:
		slot_prompt_label.text = "Press SPACE to spin   (%d left)" % run_spins
	else:
		slot_prompt_label.text = "Press SPACE to continue"


# A revive win: after the "get ready" beat, close the slot, un-pause, and bring the
# Moki back where it fell. run_spins is NOT cleared - any leftover tokens stay usable
# if we crash again this run.
func _finish_revive() -> void:
	slot_panel.visible = false
	_slot_open = false
	get_tree().paused = false
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("revive"):
		player.revive()
	show_banner("REVIVED!", Color(1.0, 0.5, 0.7, 1.0), 2.0)
	flash(Color(1.0, 0.5, 0.7, 0.45))


# No spins left (or none won a revive): leave the slot and finalise the run.
func _finish_slots() -> void:
	slot_panel.visible = false
	_slot_open = false
	show_game_over()


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
