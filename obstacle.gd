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
# Spawn at the LEFT edge and rush RIGHT instead (the golem boss fires from both
# sides). We add back 2x the scroll so its on-screen speed matches the right ones.
@export var from_left: bool = false

var camera: Node2D   # the world scroller; we delete once we are behind it.
var _base_y: float = 0.0   # the height we drift around.
var _time: float = 0.0

# Our danger glow for the Blackout event. How bright it gets at full dark.
const GLOW_MAX := 1.8
# Fog of war: a hazard only glows when near the Moki. Fully bright within
# VISION_NEAR px, fading to nothing by VISION_FAR px. Hazards reveal a touch
# EARLIER than coins (bigger radius) so dodging stays fair, not cheap.
const VISION_NEAR := 180.0
const VISION_FAR := 380.0
@onready var glow: PointLight2D = $Glow
@onready var sprite: Sprite2D = $Sprite
var player: Node2D

# Gentle tumble: each asteroid spins a little, at a random speed/direction, so a
# field of them looks alive instead of like identical frozen copies.
@export var max_spin: float = 0.8   # radians/second (either direction)
var _spin: float = 0.0


func _ready() -> void:
	# body_entered fires whenever a physics body (our Moki) enters us.
	body_entered.connect(_on_body_entered)
	add_to_group("asteroid")   # so the spawner can keep coins off us
	_base_y = position.y   # remember our starting height for drifting.
	# Variety: a random starting angle + maybe-mirror + a slow tumble. This only
	# rotates the SPRITE, never the square collision box, so dodging is unchanged.
	sprite.rotation = randf() * TAU
	sprite.flip_h = randf() < 0.5
	_spin = randf_range(-max_spin, max_spin)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.crash()


# How far pickups should stay from our centre (we're ~56px across).
func clear_radius() -> float:
	return 34.0


# Fog of war: how visible we are based on distance to the Moki.
# 1.0 when within VISION_NEAR, ramping down to 0.0 by VISION_FAR.
func _vision() -> float:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		return 1.0   # no Moki yet - don't hide things
	var d := global_position.distance_to(player.global_position)
	return clamp(1.0 - (d - VISION_NEAR) / (VISION_FAR - VISION_NEAR), 0.0, 1.0)


func _process(delta: float) -> void:
	# Glow only in the dark (GameState.blackout), and only the FOG-OF-WAR way:
	# ominous red when the Moki is close, invisible when far. _vision() = 1 near, 0 far.
	glow.energy = GameState.blackout * GLOW_MAX * _vision()

	# Slow tumble (purely cosmetic - the collision box doesn't rotate).
	sprite.rotation += _spin * delta

	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")

	# Storm meteors rush under their own steam (on top of the scroll). Right ones
	# fly left; left ones fly right with 2x the scroll added so they cross the screen
	# at the same pace (else flying WITH the scroll makes them look sluggish).
	if extra_speed != 0.0:
		if from_left:
			var sc: float = camera.current_speed() if (camera != null and camera.has_method("current_speed")) else 0.0
			position.x += (extra_speed + 2.0 * sc) * delta
		else:
			position.x -= extra_speed * delta

	# Optional gentle floating: ride a sine wave around our base height.
	if drift_amplitude > 0.0:
		_time += delta
		position.y = _base_y + sin(_time * drift_speed) * drift_amplitude

	# Once we have flown well off the far side of the screen, remove ourselves.
	if camera != null:
		var gone: bool = (global_position.x > camera.global_position.x + cleanup_behind) if from_left \
			else (global_position.x < camera.global_position.x - cleanup_behind)
		if gone:
			queue_free()
