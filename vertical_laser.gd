# ==========================================================
#  vertical_laser.gd - a solid, full-height laser (screen-locked)
# ==========================================================
#  The mirror image of the horizontal laser: it fills the whole play
#  HEIGHT at a fixed spot on the screen. It charges (faint + pulsing)
#  then FIRES (solid + deadly) for a moment, then switches off.
#
#  Because the Moki can now fly freely left/right, you dodge this by
#  being to the LEFT or RIGHT of it when it fires.
#
#  It is "screen-locked": it rides along with the camera at a fixed
#  horizontal offset, so it sits still on screen while the world scrolls.
#
#  Stages: CHARGING -> FIRING.
# ==========================================================

extends Area2D

enum State { CHARGING, FIRING }

@export var beam_width: float = 44.0      # How thick the beam is.
@export var area_top: float = 0.0         # Top of the play area.
@export var area_bottom: float = 610.0    # Bottom (the floor surface).
@export var offset_x: float = 0.0         # Screen offset from camera centre (set by spawner).
@export var charge_time: float = 1.0      # Warning time before firing.
@export var fire_time: float = 1.1        # How long it stays deadly.
# Optional horizontal sweep: pixels/sec the beam slides across the screen
# (the mini-boss sets this so its beams sweep). 0 = a normal, still beam.
@export var sweep_speed: float = 0.0

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

	# Build the full-height beam (visual + collision) in code.
	var height: float = area_bottom - area_top
	beam.color = COLOR_BEAM
	beam.offset_left = -beam_width * 0.5
	beam.offset_right = beam_width * 0.5
	beam.offset_top = area_top
	beam.offset_bottom = area_bottom

	var rs := RectangleShape2D.new()
	rs.size = Vector2(beam_width, height)
	shape.shape = rs
	shape.position = Vector2(0.0, area_top + height * 0.5)

	modulate.a = 0.35   # faint while charging


func _process(delta: float) -> void:
	# Optionally drift our screen offset so the beam sweeps sideways over time.
	offset_x += sweep_speed * delta

	# Stay locked to a fixed spot on the screen as the world scrolls.
	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	if camera != null:
		global_position = Vector2(camera.global_position.x + offset_x, 0.0)

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
	# Catch the Moki if it is already inside the beam the instant we fire.
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			body.crash()


# Remove any boost rings overlapping the live beam, so a ring never sits
# inside a deadly laser tempting you in.
func _vaporize_rings() -> void:
	for area in get_overlapping_areas():
		if area.is_in_group("ring"):
			area.queue_free()


func _on_body_entered(body: Node) -> void:
	if deadly and body.is_in_group("player"):
		body.crash()
