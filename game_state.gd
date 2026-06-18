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
	cfg.save(SAVE_PATH)


# Read it back. The third argument to get_value() is the default used
# when the key (or the whole file) does not exist yet - e.g. first launch.
func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = cfg.get_value("progress", "high_score", 0)
		best_distance = cfg.get_value("progress", "best_distance", 0)
		coins = cfg.get_value("progress", "coins", 0)
