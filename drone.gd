# ==========================================================
#  drone.gd - a small enemy that slowly tracks your height
# ==========================================================
#  Drifts in from the right and slowly creeps toward the Moki's height,
#  applying gentle, constant pressure that forces you to keep moving
#  (unlike a missile, which commits to a straight line). It tracks SLOWLY
#  - far slower than the Moki can fly - so a sharp move jukes it. Once it
#  passes you it commits (stops tracking), so it can never camp on you.
#  Touch it and you crash.
# ==========================================================

extends Area2D

@export var cleanup_behind: float = 760.0
@export var extra_speed: float = 100.0   # leftward drift on top of the world scroll (closes on you)
@export var home_speed: float = 150.0    # max vertical tracking (px/sec); kept well under the Moki's speed
@export var body_size: float = 34.0      # for keeping pickups clear

var camera: Node2D
var player: Node2D
var _committed: bool = false   # true once we have passed the player (stop homing)

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("asteroid")   # generic persistent-hazard group (cap + coin clearance)
	sprite.play("fly")         # flickering exhaust


func clear_radius() -> float:
	return body_size * 0.5 + 8.0


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.crash()


func _process(delta: float) -> void:
	# Drift left a little faster than the scroll so it closes on you.
	position.x -= extra_speed * delta

	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	# Slowly home toward the Moki's height - but only until we have drifted
	# past them, after which we commit and stop tracking (no camping).
	var vy: float = 0.0
	if player != null and not _committed:
		if global_position.x <= player.global_position.x:
			_committed = true
		else:
			var dy: float = player.global_position.y - global_position.y
			var step: float = clamp(dy, -home_speed * delta, home_speed * delta)
			position.y += step
			vy = step / delta

	# Tilt the nose toward where it is tracking (the art points LEFT at rest, so
	# a small rotation against its leftward speed noses it up/down = "seeking").
	var vx_mag: float = extra_speed
	if camera != null and camera.has_method("current_speed"):
		vx_mag += camera.current_speed()
	var target_tilt: float = clamp(-vy / maxf(vx_mag, 1.0), -0.35, 0.35)
	sprite.rotation = lerpf(sprite.rotation, target_tilt, 0.12)

	if camera != null and global_position.x < camera.global_position.x - cleanup_behind:
		queue_free()
