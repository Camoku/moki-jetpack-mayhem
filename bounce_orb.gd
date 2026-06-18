# ==========================================================
#  bounce_orb.gd - a ball that bounces between roof and floor
# ==========================================================
#  Sits in the world (the camera scrolls past it, like an asteroid) and
#  bounces straight up and down between two heights, reflecting at each
#  end. The motion is LINEAR (constant speed, no gravity) on purpose:
#  a clean, predictable zig-zag you can read from across the screen and
#  time your way through. Touch it and you crash.
# ==========================================================

extends Area2D

@export var cleanup_behind: float = 760.0
@export var bounce_top: float = 70.0       # highest the orb rises to
@export var bounce_bottom: float = 650.0   # lowest it falls to
@export var orb_radius: float = 20.0       # for keeping pickups clear

# Vertical speed (px/sec). The spawner sets this; the SIGN is the start
# direction (positive = moving down first).
var vy: float = 260.0
# Leftward drift (px/sec, on top of the world scroll). Combined with the
# vertical bounce this makes the orb trace a diagonal ZIG-ZAG across the screen
# instead of a straight up/down column. The spawner sets it (negative = left).
var vx: float = -120.0
var camera: Node2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("asteroid")   # generic persistent-hazard group (cap + coin clearance)


# Keep coins/powerups clear of the orb's body.
func clear_radius() -> float:
	return orb_radius + 8.0


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.crash()


func _process(delta: float) -> void:
	# Drift left while bouncing up/down -> a diagonal zig-zag path.
	position.x += vx * delta

	# Travel up/down, flipping direction at each bound (a clean bounce).
	position.y += vy * delta
	if position.y <= bounce_top:
		position.y = bounce_top
		vy = absf(vy)        # head back down
	elif position.y >= bounce_bottom:
		position.y = bounce_bottom
		vy = -absf(vy)       # head back up

	# Remove ourselves once we have scrolled off behind the screen.
	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	if camera != null and global_position.x < camera.global_position.x - cleanup_behind:
		queue_free()
