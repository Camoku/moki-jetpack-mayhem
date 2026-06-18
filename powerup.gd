# ==========================================================
#  powerup.gd - a collectible powerup
# ==========================================================
#  One script for every powerup type. The "type" string decides how it
#  looks AND what it does to the Moki when grabbed. Adding a new powerup
#  later = add a case in _apply_look() here and one in player.gain_powerup().
# ==========================================================

extends Area2D

# Which powerup this is. The spawner sets this before adding us to the scene.
@export var type: String = "shield"
@export var cleanup_behind: float = 760.0

var camera: Node2D

@onready var box: ColorRect = $Box
@onready var label: Label = $Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("powerup")
	_apply_look()


# Style the badge based on the type, so each powerup is recognisable.
func _apply_look() -> void:
	match type:
		"shield":
			box.color = Color(0.3, 0.7, 1.0, 1.0)
			label.text = "S"
		"magnet":
			box.color = Color(0.8, 0.4, 1.0, 1.0)
			label.text = "M"
		"doubler":
			box.color = Color(1.0, 0.82, 0.2, 1.0)
			label.text = "x2"
		"ghost":
			box.color = Color(0.85, 0.9, 1.0, 1.0)
			label.text = "G"
		_:
			box.color = Color(0.7, 0.7, 0.7, 1.0)
			label.text = "?"


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.gain_powerup(type)   # hand the effect to the Moki
		queue_free()


func _process(_delta: float) -> void:
	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	if camera != null and global_position.x < camera.global_position.x - cleanup_behind:
		queue_free()
