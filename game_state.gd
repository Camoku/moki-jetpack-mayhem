# ==========================================================
#  game_state.gd - a global "autoload" singleton
# ==========================================================
#  Registered as an AUTOLOAD, so ONE copy stays alive for the whole
#  game and survives reloading the scene after a crash. It is also
#  where we SAVE progress to disk so it survives closing the game.
#
#  Use it anywhere as: GameState.high_score, GameState.coins, etc.
# ==========================================================

extends Node

var high_score: int = 0
var best_distance: int = 0   # furthest distance (metres) ever reached
var coins: int = 0       # banked currency, to spend in the store later

# Local leaderboard: the player's name (entered on the title screen, remembered)
# and the top runs, saved to disk so they persist between sessions in this
# browser / on this machine. Each entry is {"name", "score", "dist"}.
var player_name: String = ""
var leaderboard: Array = []
const MAX_SCORES := 10

# How "dark" the world is right now: 0.0 = normal daylight, 1.0 = full
# blackout. The spawner tweens this up/down during the Blackout event; the
# CanvasModulate dims the world by it, and every coin/asteroid/player glow
# brightens by it. It is RUNTIME-ONLY (never saved to disk). It lives here
# because it is a single value that lots of unrelated nodes need to read.
var blackout: float = 0.0

# Set true by a slot-machine win ("SHIELD NEXT RUN!") and consumed the next time
# the Moki spawns (player._ready grants a shield, then clears it). Like blackout
# it is RUNTIME-ONLY (never saved): it just needs to survive the scene reload
# between runs, which an autoload does for free.
var start_with_shield: bool = false

# Where the save file lives. "user://" is a safe per-user folder Godot
# manages for us (no need to worry about the real path on disk).
const SAVE_PATH := "user://save.cfg"


func _ready() -> void:
	load_game()


# Write our progress to disk. A ConfigFile is a simple key=value store,
# grouped into [sections] - very beginner friendly.
func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "high_score", high_score)
	cfg.set_value("progress", "best_distance", best_distance)
	cfg.set_value("progress", "coins", coins)
	cfg.set_value("progress", "player_name", player_name)
	cfg.set_value("scores", "entries", leaderboard)
	cfg.save(SAVE_PATH)


# Record a finished run on the local leaderboard (keeps the top MAX_SCORES,
# sorted high-to-low). Blank names become "Player". Caller saves afterwards.
func add_score(pname: String, score: int, dist: int) -> void:
	var nm := pname.strip_edges()
	if nm == "":
		nm = "Player"
	leaderboard.append({"name": nm.left(16), "score": score, "dist": dist})
	leaderboard.sort_custom(func(a, b): return a["score"] > b["score"])
	if leaderboard.size() > MAX_SCORES:
		leaderboard.resize(MAX_SCORES)


# Read it back. The third argument to get_value() is the default used
# when the key (or the whole file) does not exist yet - e.g. first launch.
func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = cfg.get_value("progress", "high_score", 0)
		best_distance = cfg.get_value("progress", "best_distance", 0)
		coins = cfg.get_value("progress", "coins", 0)
		player_name = cfg.get_value("progress", "player_name", "")
		leaderboard = cfg.get_value("scores", "entries", [])
