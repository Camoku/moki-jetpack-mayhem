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

const OVERSHOOT := 200.0   # how far the beam pokes past the play area (so its ends are off-screen)

var state: int = State.CHARGING
var deadly: bool = false
var _t: float = 0.0
var _pulse: float = 0.0
var camera: Node2D

@onready var beam: AnimatedSprite2D = $Beam
@onready var shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Build it like the horizontal laser - a crackling beam stretched well past the
	# screen edges (no caps - the ends sit off-screen) - then rotate the whole node a
	# quarter-turn so it stands up. (Same build-then-rotate trick the floating beam uses.)
	var length: float = (area_bottom - area_top) + OVERSHOOT * 2.0   # overshoot top + bottom

	# Stretch the crackle frame to span the whole length (along its length).
	var btex: Texture2D = beam.sprite_frames.get_frame_texture(&"crackle", 0)
	beam.scale = Vector2(length / float(btex.get_width()), beam_width / float(btex.get_height()))
	beam.position = Vector2.ZERO
	beam.frame = randi() % beam.sprite_frames.get_frame_count(&"crackle")

	var rs := RectangleShape2D.new()
	rs.size = Vector2(length, beam_width)
	shape.shape = rs
	shape.position = Vector2.ZERO

	rotation = PI * 0.5   # stand the horizontal beam up into a vertical one
	modulate.a = 0.35     # faint while charging


func _process(delta: float) -> void:
	# Optionally drift our screen offset so the beam sweeps sideways over time.
	offset_x += sweep_speed * delta

	# Stay locked to a fixed spot on the screen as the world scrolls.
	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	if camera != null:
		global_position = Vector2(camera.global_position.x + offset_x, (area_top + area_bottom) * 0.5)

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
