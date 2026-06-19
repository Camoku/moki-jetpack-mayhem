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
var _t: float = 0.0   # drives the bob + glow pulse

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var glow: PointLight2D = $Glow


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("chest")
	if big:
		# The GRAND (boss) chest: fancier gold art, a richer glow, and bigger -
		# scaling the whole node grows its grab area too.
		sprite.sprite_frames = load("res://sprites/chests/chest_grand_frames.tres")
		sprite.play("idle")
		glow.color = Color(1.0, 0.8, 0.25, 1.0)
		glow.texture_scale = 0.8
		scale = Vector2(1.5, 1.5)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	Audio.play("chest")
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


func _process(delta: float) -> void:
	# Gently bob + pulse the glow so the reward chest reads as a live, enticing pickup.
	_t += delta
	sprite.position.y = sin(_t * 2.5) * 4.0
	glow.energy = (1.5 if big else 1.0) + 0.45 * (0.5 + 0.5 * sin(_t * 2.0))

	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	if camera != null and global_position.x < camera.global_position.x - cleanup_behind:
		queue_free()
