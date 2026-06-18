# ==========================================================
#  chest.gd - the RISK survival reward you fly over to claim
# ==========================================================
#  Dropped at the end of a survived Choice-Gate RISK gauntlet. Fly the Moki
#  into it and it banks a chunk of coins + grants a free shield, with a little
#  fanfare, then vanishes. (It scrolls along like everything else and cleans
#  itself up if it ever drifts off-screen unclaimed.)
# ==========================================================

extends Area2D

# All set by the spawner before we're added. A chest banks `coins`, grants
# `powerup_type` (empty = none), and (for the main-boss chest) a run-long
# `bonus_mult`. `big` makes it a fancier, larger golden chest.
@export var coins: int = 100
@export var powerup_type: String = "shield"
@export var bonus_mult: float = 0.0
@export var big: bool = false
@export var cleanup_behind: float = 760.0

var camera: Node2D

@onready var lid: ColorRect = $Lid
@onready var body_rect: ColorRect = $Body


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("chest")
	if big:
		scale = Vector2(1.5, 1.5)               # a grander prize
		lid.color = Color(1.0, 0.95, 0.5, 1.0)  # bright gold
		body_rect.color = Color(0.55, 0.2, 0.5, 1.0)  # royal purple


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("add_coin"):
		hud.add_coin(coins)        # bank the coins (+ bump the multiplier)
	if powerup_type != "" and body.has_method("gain_powerup"):
		body.gain_powerup(powerup_type)
	if hud != null:
		if bonus_mult > 0.0 and hud.has_method("add_bonus_multiplier"):
			hud.add_bonus_multiplier(bonus_mult)
		if hud.has_method("show_banner"):
			var label := "GRAND CHEST!" if big else "CHEST!"
			hud.show_banner("%s   +%d COINS" % [label, coins], Color(1.0, 0.9, 0.4), 2.5)
		if hud.has_method("flash"):
			hud.flash(Color(1.0, 0.92, 0.5, 0.4))
	queue_free()


func _process(_delta: float) -> void:
	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	if camera != null and global_position.x < camera.global_position.x - cleanup_behind:
		queue_free()
