# ==========================================================
#  spin_token.gd - a collectible SLOT-MACHINE spin token
# ==========================================================
#  A rare violet pickup. It sits out in the world and scrolls along like a
#  coin; when the Moki touches it, it adds one SPIN to this run, then vanishes.
#
#  Those spins are spent at the end of the run on the slot machine (see hud.gd)
#  for coins, a revive, or a free shield next run. Tokens are use-it-or-lose-it:
#  they only count for THIS run and are never saved to disk.
#
#  This is almost a carbon copy of coin.gd (same scroll + cleanup + blackout
#  glow), minus the Coin-Rush "did you collect it?" reporting - tokens never
#  appear in a Coin Rush.
# ==========================================================

extends Area2D

@export var cleanup_behind: float = 760.0

var camera: Node2D

# Our violet shine for the Blackout event, exactly like a coin's gold shine.
const GLOW_MAX := 2.2
# Fog of war: only shine when the Moki is near. Bright within VISION_NEAR px,
# fading to nothing by VISION_FAR px, so far-off tokens stay hidden in the dark.
const VISION_NEAR := 120.0
const VISION_FAR := 280.0
@onready var glow: PointLight2D = $Glow
var player: Node2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("spintoken")   # so the spawner can keep hazards/pickups off us


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		# Tell the HUD (our run manager) to bank one spin for the slot machine.
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("add_spin_token"):
			hud.add_spin_token()
		queue_free()


func _process(_delta: float) -> void:
	# Shine only in the dark (GameState.blackout), and only the FOG-OF-WAR way:
	# bright when the Moki is close, invisible when far.
	glow.energy = GameState.blackout * GLOW_MAX * _vision()

	# Remove ourselves once we have scrolled off behind the screen.
	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	if camera != null and global_position.x < camera.global_position.x - cleanup_behind:
		queue_free()


# Fog of war: how visible we are based on distance to the Moki.
# 1.0 when within VISION_NEAR, ramping down to 0.0 by VISION_FAR.
func _vision() -> float:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		return 1.0   # no Moki yet - don't hide things
	var d := global_position.distance_to(player.global_position)
	return clamp(1.0 - (d - VISION_NEAR) / (VISION_FAR - VISION_NEAR), 0.0, 1.0)
