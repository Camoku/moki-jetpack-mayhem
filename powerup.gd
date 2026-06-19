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

# A little spark burst we pop when grabbed (same one the celebrations use).
const FIREWORKS := preload("res://Fireworks.tscn")

var camera: Node2D

# Sprite-art powerups gently float + pulse their glow so they read as live
# pickups (set true in _apply_look for SPRITE_ART types).
const BOB_SPEED := 3.0
const BOB_AMP := 5.0
var _is_art: bool = false
var _bob_t: float = 0.0
# Some art pickups also slowly spin (the speed-gate ring) - set from SPRITE_ART.
var _spin_speed: float = 0.0
# True once grabbed, so the idle bob/spin stops and the pickup can't fire twice
# while its fly-through pop animation plays out.
var _grabbed: bool = false

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
	"shield": {"frames": "res://sprites/powerups/shield_frames.tres", "anim": "idle", "glow": Color(0.5, 1.0, 0.65), "scale": 0.08},
	"tiny": {"frames": "res://sprites/powerups/shrink_frames.tres", "anim": "idle", "glow": Color(0.5, 1.0, 0.55), "scale": 0.12},
	"dash": {"frames": "res://sprites/powerups/speedgate_frames.tres", "anim": "idle", "glow": Color(0.55, 1.0, 0.45), "scale": 0.11, "spin": 1.3},
	"ghost": {"frames": "res://sprites/powerups/ghost_frames.tres", "anim": "float", "glow": Color(0.5, 1.0, 0.6), "scale": 0.21},
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
		_spin_speed = art.get("spin", 0.0)   # 0 = no spin (most pickups)
		_is_art = true
		return

	match type:
		"secondchance":
			box.color = Color(1.0, 0.4, 0.6, 1.0)
			label.text = "+1"
		_:
			box.color = Color(0.7, 0.7, 0.7, 1.0)
			label.text = "?"


func _on_body_entered(body: Node) -> void:
	if _grabbed:
		return                      # already grabbed - ignore (pop is still playing)
	if body.is_in_group("player"):
		body.gain_powerup(type)     # hand the effect to the Moki
		_pickup_juice()


# When grabbed, pop a spark burst and (for art pickups) play a quick "fly-through"
# flourish - the gate flares, scales up and fades - instead of just blinking out.
func _pickup_juice() -> void:
	_grabbed = true
	set_deferred("monitoring", false)   # can't be grabbed again mid-pop

	# Green spark burst at the pickup's spot.
	var fw := FIREWORKS.instantiate()
	fw.fw_color = glow.color if _is_art else Color(0.6, 1.0, 0.5)
	get_parent().add_child(fw)
	fw.global_position = global_position

	if _is_art:
		glow.energy = 2.6           # a bright flare on grab
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(sprite, "scale", sprite.scale * 2.2, 0.22)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.22)
		tw.tween_property(glow, "energy", 0.0, 0.22)
		tw.tween_property(backing, "modulate:a", 0.0, 0.18)
		await tw.finished
	queue_free()


func _process(delta: float) -> void:
	# Sprite powerups gently float up/down and pulse their glow, so they read as
	# live collectibles rather than background art. (The dark disc stays put.)
	# Skip once grabbed - the pop tween owns the sprite from then on.
	if _is_art and not _grabbed:
		_bob_t += delta * BOB_SPEED
		var dy := sin(_bob_t) * BOB_AMP
		sprite.position.y = dy
		glow.position.y = dy
		glow.energy = 1.0 + 0.35 * (0.5 + 0.5 * sin(_bob_t * 1.4))
		if _spin_speed != 0.0:
			sprite.rotation += delta * _spin_speed   # the speed-gate ring rotates

	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	if camera != null and global_position.x < camera.global_position.x - cleanup_behind:
		queue_free()
