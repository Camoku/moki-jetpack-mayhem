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

var state: int = State.WARNING
var deadly: bool = false
var _t: float = 0.0
var camera: Node2D

@onready var missile_body: ColorRect = $Body
@onready var tip: ColorRect = $Tip
@onready var warn_bg: Panel = $WarnBg   # the circular "!" badge


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("missile")   # so the Choice Gate can clear us when a RISK run is survived
	missile_body.visible = false
	tip.visible = false
	warn_bg.visible = true


func _process(delta: float) -> void:
	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	_t += delta

	match state:
		State.WARNING:
			# Hover at the right edge (follow the camera) and blink the "!".
			if camera != null:
				global_position.x = camera.global_position.x + warn_x_offset
			warn_bg.visible = int(_t * 8) % 2 == 0
			if _t >= warn_time:
				_launch()
		State.FLYING:
			global_position.x -= missile_speed * delta
			if camera != null and global_position.x < camera.global_position.x - cleanup_behind:
				queue_free()


func _launch() -> void:
	state = State.FLYING
	deadly = true
	warn_bg.visible = false
	missile_body.visible = true
	tip.visible = true
	# Catch the Moki if it is somehow already in the way the instant we launch.
	for hit in get_overlapping_bodies():
		if hit.is_in_group("player"):
			hit.crash()


func _on_body_entered(hit: Node) -> void:
	if deadly and hit.is_in_group("player"):
		hit.crash()
