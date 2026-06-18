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
@export var beam_thickness: float = 18.0    # how thick the red line is
@export var block_size: float = 34.0        # the grey end caps
@export var cleanup_behind: float = 760.0

var camera: Node2D

@onready var col: CollisionShape2D = $CollisionShape2D
@onready var beam: ColorRect = $Beam
@onready var cap1: ColorRect = $Cap1
@onready var cap2: ColorRect = $Cap2


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("asteroid")   # so coins/powerups keep clear of us too
	_build()


func _build() -> void:
	var half := beam_length * 0.5
	var rect := RectangleShape2D.new()

	if horizontal:
		# Red line runs left-right; caps sit at the left and right ends.
		_set_rect(beam, -half, -beam_thickness * 0.5, half, beam_thickness * 0.5)
		_set_rect(cap1, -half - block_size * 0.5, -block_size * 0.5, -half + block_size * 0.5, block_size * 0.5)
		_set_rect(cap2, half - block_size * 0.5, -block_size * 0.5, half + block_size * 0.5, block_size * 0.5)
		rect.size = Vector2(beam_length + block_size, maxf(beam_thickness, block_size))
	else:
		# Red line runs up-down; caps sit at the top and bottom ends.
		_set_rect(beam, -beam_thickness * 0.5, -half, beam_thickness * 0.5, half)
		_set_rect(cap1, -block_size * 0.5, -half - block_size * 0.5, block_size * 0.5, -half + block_size * 0.5)
		_set_rect(cap2, -block_size * 0.5, half - block_size * 0.5, block_size * 0.5, half + block_size * 0.5)
		rect.size = Vector2(maxf(beam_thickness, block_size), beam_length + block_size)

	col.shape = rect


# Small helper to position a ColorRect by its four edges (local space).
func _set_rect(r: ColorRect, left: float, top: float, right: float, bottom: float) -> void:
	r.offset_left = left
	r.offset_top = top
	r.offset_right = right
	r.offset_bottom = bottom


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
