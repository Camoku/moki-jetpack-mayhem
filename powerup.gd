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
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var backing: Sprite2D = $Backing
@onready var glow: PointLight2D = $Glow


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("powerup")
	_apply_look()


# Powerups that use real sprite art (instead of a coloured letter badge). Each
# entry: the SpriteFrames, the animation to play, the glow-halo colour, and the
# sprite scale. The art shows on the AnimatedSprite2D with a dark contrast disc
# (Backing) + a glow (PointLight2D) so it stands out; the sprite's light_mask = 2
# keeps the glow from tinting the art itself. Giving a powerup art = add a row here.
const SPRITE_ART := {
	"magnet": {"frames": "res://sprites/powerups/magnet_frames.tres", "anim": "shimmer", "glow": Color(0.4, 1.0, 0.7), "scale": 0.16},
	"doubler": {"frames": "res://sprites/powerups/x2_frames.tres", "anim": "idle", "glow": Color(0.5, 1.0, 0.45), "scale": 0.17},
}


# Style the pickup based on its type. Types with real art (SPRITE_ART) show the
# glowing sprite; the rest are simple coloured letter badges.
func _apply_look() -> void:
	if SPRITE_ART.has(type):
		var art: Dictionary = SPRITE_ART[type]
		box.visible = false
		label.visible = false
		backing.visible = true   # dark disc so the green art pops on the green city
		glow.visible = true      # + a glow halo for extra pop
		glow.color = art["glow"]
		sprite.sprite_frames = load(art["frames"])
		sprite.scale = Vector2(art["scale"], art["scale"])
		sprite.visible = true
		sprite.play(art["anim"])
		return

	match type:
		"shield":
			box.color = Color(0.3, 0.7, 1.0, 1.0)
			label.text = "S"
		"ghost":
			box.color = Color(0.85, 0.9, 1.0, 1.0)
			label.text = "G"
		"dash":
			box.color = Color(1.0, 0.5, 0.2, 1.0)
			label.text = ">>"
		"tiny":
			box.color = Color(0.5, 1.0, 0.5, 1.0)
			label.text = "T"
		"secondchance":
			box.color = Color(1.0, 0.4, 0.6, 1.0)
			label.text = "+1"
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
