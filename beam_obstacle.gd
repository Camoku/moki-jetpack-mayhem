# ==========================================================
#  beam_obstacle.gd - a floating laser bar capped by two blocks
# ==========================================================
#  A deadly bar that floats in mid-screen (it does NOT span the whole
#  screen), so you route around it - over, under, or to the sides.
#  Adds a different hazard SHAPE to the mix vs plain asteroids.
#
#  It can be horizontal or vertical (the spawner decides), and its
#  length is randomised, so the geometry is built in code.
# ==========================================================

extends Area2D

@export var horizontal: bool = false        # set by the spawner
@export var beam_length: float = 220.0      # length of the bar (set by spawner)
@export var beam_thickness: float = 38.0    # how thick the green beam is
@export var block_size: float = 46.0        # the metal end caps (also the hitbox thickness)
@export var cleanup_behind: float = 760.0

var camera: Node2D

@onready var col: CollisionShape2D = $CollisionShape2D
@onready var beam: AnimatedSprite2D = $Beam
@onready var cap1: Sprite2D = $Cap1
@onready var cap2: Sprite2D = $Cap2


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("asteroid")   # so coins/powerups keep clear of us too
	_build()


func _build() -> void:
	# We always build a HORIZONTAL bar, then rotate the whole node a quarter turn
	# for a vertical one - so the sprite layout + collision are written just once.
	var half := beam_length * 0.5

	# Beam: stretch the crackling energy slice to span the length, scaled to
	# beam_thickness tall. Start on a random frame so beams don't flicker in sync.
	var btex := beam.sprite_frames.get_frame_texture(&"crackle", 0)
	beam.scale = Vector2(beam_length / float(btex.get_width()),
		beam_thickness / float(btex.get_height()))
	beam.position = Vector2.ZERO
	beam.frame = randi() % beam.sprite_frames.get_frame_count(&"crackle")

	# Caps: one metal emitter at each end, scaled (uniform) to block_size tall.
	var cap_scale := block_size / float(cap1.texture.get_height())
	cap1.scale = Vector2(cap_scale, cap_scale)
	cap2.scale = Vector2(cap_scale, cap_scale)
	cap1.position = Vector2(-half, 0.0)
	cap2.position = Vector2(half, 0.0)

	# Deadly box covering the whole bar (cap-height thick, like before).
	var rect := RectangleShape2D.new()
	rect.size = Vector2(beam_length + block_size, maxf(beam_thickness, block_size))
	col.shape = rect

	rotation = 0.0 if horizontal else PI * 0.5


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.crash()


# Beams are long, so keep pickups clear of the WHOLE bar, not just the centre.
func clear_radius() -> float:
	return beam_length * 0.5 + block_size


func _process(_delta: float) -> void:
	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	if camera != null and global_position.x < camera.global_position.x - cleanup_behind:
		queue_free()
