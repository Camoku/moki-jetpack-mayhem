# ==========================================================
#  obstacle.gd - a single asteroid hazard
# ==========================================================
#  This sits on an Area2D. An Area2D is a "detector": it does not
#  push things around, it just notices when something overlaps it.
#  When the Moki overlaps us, we tell the Moki to crash.
#
#  Asteroids can optionally DRIFT up and down (set by the spawner on
#  tougher runs) to make them harder to predict.
# ==========================================================

extends Area2D

# How far behind the screen we can drift before we delete ourselves.
@export var cleanup_behind: float = 760.0

# Floating motion. 0 = stays still. Higher amplitude = bigger up/down swing.
@export var drift_amplitude: float = 0.0
@export var drift_speed: float = 2.0

# Extra leftward speed on top of the world scroll. 0 for normal asteroids;
# the Asteroid Storm sets this so meteors rush in fast.
@export var extra_speed: float = 0.0

var camera: Node2D   # the world scroller; we delete once we are behind it.
var _base_y: float = 0.0   # the height we drift around.
var _time: float = 0.0


func _ready() -> void:
	# body_entered fires whenever a physics body (our Moki) enters us.
	body_entered.connect(_on_body_entered)
	add_to_group("asteroid")   # so the spawner can keep coins off us
	_base_y = position.y   # remember our starting height for drifting.


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.crash()


# How far pickups should stay from our centre (we're ~56px across).
func clear_radius() -> float:
	return 34.0


func _process(delta: float) -> void:
	# Storm meteors rush left under their own steam (on top of the scroll).
	if extra_speed != 0.0:
		position.x -= extra_speed * delta

	# Optional gentle floating: ride a sine wave around our base height.
	if drift_amplitude > 0.0:
		_time += delta
		position.y = _base_y + sin(_time * drift_speed) * drift_amplitude

	# Once we have scrolled well behind the camera, remove ourselves.
	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	if camera != null and global_position.x < camera.global_position.x - cleanup_behind:
		queue_free()
