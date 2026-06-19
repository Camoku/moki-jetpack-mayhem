# ==========================================================
#  missile.gd - a warning-then-strike missile from the right
# ==========================================================
#  Two stages:
#    WARNING - hovers at the right edge of the screen, flashing a "!"
#              at its height so you know where it will come from.
#    FLYING  - launches left across the screen, fast and deadly.
#  Dodge by moving off its height during the warning.
# ==========================================================

extends Area2D

enum State { WARNING, FLYING }

@export var warn_time: float = 1.0        # How long the "!" warns before launch.
@export var missile_speed: float = 520.0  # How fast it flies left (on top of the scroll).
@export var warn_x_offset: float = 600.0  # Where it waits during the warning (near the right edge).
@export var cleanup_behind: float = 760.0
@export var from_left: bool = false       # spawn at the LEFT edge and fly RIGHT (frigate fires from both sides)

var state: int = State.WARNING
var deadly: bool = false
var _t: float = 0.0
var camera: Node2D

@onready var missile_sprite: AnimatedSprite2D = $Sprite   # the missile art (hidden until launch)
@onready var glow: PointLight2D = $Glow   # the red danger glow (shown while flying)
@onready var warn_bg: Panel = $WarnBg   # the circular "!" badge


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("missile")   # so the Choice Gate can clear us when a RISK run is survived
	missile_sprite.visible = false
	glow.visible = false
	warn_bg.visible = true
	# Left-side missiles are mirrored: nose points RIGHT, exhaust trails left.
	if from_left:
		missile_sprite.flip_h = true
		missile_sprite.position.x = -missile_sprite.position.x


func _process(delta: float) -> void:
	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	_t += delta

	match state:
		State.WARNING:
			# Hover at our edge (left or right, following the camera) and blink the "!".
			if camera != null:
				var edge: float = -warn_x_offset if from_left else warn_x_offset
				global_position.x = camera.global_position.x + edge
			warn_bg.visible = int(_t * 8) % 2 == 0
			if _t >= warn_time:
				_launch()
		State.FLYING:
			# Move at the same speed ACROSS THE SCREEN in both directions. A right
			# missile flies against the scroll (so the scroll adds to its on-screen
			# speed); a left missile flies with it, so we add 2x the scroll back to
			# keep its screen speed equal - otherwise it looks sluggish.
			var spd: float = missile_speed
			if from_left and camera != null and camera.has_method("current_speed"):
				spd += 2.0 * camera.current_speed()
			var dir: float = 1.0 if from_left else -1.0
			global_position.x += dir * spd * delta
			glow.energy = 1.0 + 0.5 * (0.5 + 0.5 * sin(_t * 18.0))   # fast danger flicker
			if camera != null:
				# Clean up once it has flown off the far side of the screen.
				var gone: bool = (global_position.x > camera.global_position.x + cleanup_behind) if from_left \
					else (global_position.x < camera.global_position.x - cleanup_behind)
				if gone:
					queue_free()


func _launch() -> void:
	state = State.FLYING
	deadly = true
	Audio.play("missile")
	warn_bg.visible = false
	missile_sprite.visible = true
	glow.visible = true
	# Catch the Moki if it is somehow already in the way the instant we launch.
	for hit in get_overlapping_bodies():
		if hit.is_in_group("player"):
			hit.crash()


func _on_body_entered(hit: Node) -> void:
	if deadly and hit.is_in_group("player"):
		hit.crash()
