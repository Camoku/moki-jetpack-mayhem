# ==========================================================
#  coin.gd - a collectible coin
# ==========================================================
#  Sits out in the world and scrolls along with everything else.
#  When the Moki touches it, it tells the HUD to add a coin, then
#  removes itself.
#
#  Coins spawned by the Coin Rush event report back to the spawner
#  whether they were collected (for the "COIN MASTER!" clean sweep).
# ==========================================================

extends Area2D

@export var cleanup_behind: float = 760.0

var from_rush: bool = false   # set by the spawner for Coin Rush coins
var camera: Node2D
var _collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("coin")   # so the spawner can keep asteroids off us


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_collected = true
		# Ask the Moki how much this coin is worth (Doubler makes it 2),
		# then tell the HUD (our run manager).
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null:
			hud.add_coin(body.coin_value())
		if from_rush:
			_notify_resolved(true)
		queue_free()


func _process(_delta: float) -> void:
	# Remove ourselves once we have scrolled off behind the screen.
	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	if camera != null and global_position.x < camera.global_position.x - cleanup_behind:
		if from_rush and not _collected:
			_notify_resolved(false)   # a rush coin we flew past
		queue_free()


func _notify_resolved(hit: bool) -> void:
	var sp := get_tree().get_first_node_in_group("spawner")
	if sp != null and sp.has_method("coin_rush_resolved"):
		sp.coin_rush_resolved(hit)
