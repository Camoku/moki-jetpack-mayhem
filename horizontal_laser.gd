# ==========================================================
#  horizontal_laser.gd - a charging beam that sweeps across
# ==========================================================
#  A full-width horizontal laser at a set height. It charges
#  (faint + pulsing) then FIRES (solid + deadly) for a short time.
#  Dodge by flying ABOVE or BELOW it while it is firing.
#
#  It follows the Moki horizontally, so you cannot outrun it - you
#  have to get to a safe height before it fires. Pure timing.
# ==========================================================

extends Area2D

enum State { CHARGING, FIRING }

@export var beam_y: float = 300.0         # Height of the beam (set by the spawner).
@export var beam_thickness: float = 64.0  # How tall the deadly zone is.
@export var beam_width: float = 1700.0    # Wide enough to cover the whole screen.
@export var charge_time: float = 1.0      # Warning time before firing.
@export var fire_time: float = 1.4        # How long it stays deadly.

const COLOR_BEAM := Color(1.0, 0.3, 0.25, 1.0)

var state: int = State.CHARGING
var deadly: bool = false
var _t: float = 0.0
var _pulse: float = 0.0
var camera: Node2D

@onready var beam: ColorRect = $Beam
@onready var shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Size the beam visual and its collision box.
	beam.color = COLOR_BEAM
	beam.offset_left = -beam_width * 0.5
	beam.offset_right = beam_width * 0.5
	beam.offset_top = -beam_thickness * 0.5
	beam.offset_bottom = beam_thickness * 0.5

	var rs := RectangleShape2D.new()
	rs.size = Vector2(beam_width, beam_thickness)
	shape.shape = rs

	modulate.a = 0.35   # faint while charging


func _process(delta: float) -> void:
	# Stay centred on the screen (follow the camera), fixed at our height.
	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	if camera != null:
		global_position = Vector2(camera.global_position.x, beam_y)

	_t += delta
	match state:
		State.CHARGING:
			_pulse += delta * 12.0
			modulate.a = 0.3 + 0.25 * sin(_pulse)
			if _t >= charge_time:
				_start_firing()
		State.FIRING:
			_vaporize_rings()   # zap any boost rings caught in the beam
			if _t >= fire_time:
				queue_free()   # beam switches off and disappears


func _start_firing() -> void:
	state = State.FIRING
	deadly = true
	_t = 0.0
	modulate.a = 1.0
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			body.crash()


func _on_body_entered(body: Node) -> void:
	if deadly and body.is_in_group("player"):
		body.crash()


# Remove any boost rings overlapping the live beam, so a ring never sits
# inside a deadly laser tempting you in.
func _vaporize_rings() -> void:
	for area in get_overlapping_areas():
		if area.is_in_group("ring"):
			area.queue_free()
