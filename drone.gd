# ==========================================================
#  drone.gd - a small homing MISSILE that slowly tracks your height
# ==========================================================
#  Drifts in from the right and slowly creeps toward the Moki's height,
#  applying gentle, constant pressure that forces you to keep moving
#  (unlike a straight missile, which commits to a line). It tracks SLOWLY
#  - far slower than the Moki can fly - so a sharp move jukes it. Once it
#  passes you it commits (stops tracking), so it can never camp on you.
#  Touch it and you crash.
#
#  Juice: a green exhaust particle trail + a pulsing danger glow at the
#  engine, a "seeking" weave, and the nose tilts toward whoever it tracks.
# ==========================================================

extends Area2D

@export var cleanup_behind: float = 760.0
@export var extra_speed: float = 115.0   # leftward drift on top of the world scroll (closes on you)
@export var home_speed: float = 150.0    # max vertical tracking (px/sec); kept well under the Moki's speed
@export var body_size: float = 34.0      # for keeping pickups clear
@export var art_scale: float = 0.32      # missile sprite scale (tune to taste)
@export var wobble_amp: float = 34.0     # gentle vertical "seeking" weave (px/sec)
@export var wobble_freq: float = 3.2     # how fast it weaves

var camera: Node2D
var player: Node2D
var _committed: bool = false   # true once we have passed the player (stop homing)
var _t: float = 0.0
# Where the engine sits relative to the body centre (nose points LEFT, so the
# exhaust is on the RIGHT). Scales with the art so the trail + glow stay on the
# tail no matter how chonky the missile is.
var _engine_off: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $Sprite
var flame: CPUParticles2D
var glow: PointLight2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("asteroid")   # generic persistent-hazard group (cap + coin clearance)
	sprite.scale = Vector2(art_scale, art_scale)
	sprite.play("fly")         # flickering exhaust
	_engine_off = Vector2(130.0 * art_scale, 0.0)   # tail follows the art size
	_build_flame()
	_build_glow()


func clear_radius() -> float:
	return body_size * 0.5 + 8.0


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.crash()


func _process(delta: float) -> void:
	_t += delta

	# Drift left a little faster than the scroll so it closes on you.
	position.x -= extra_speed * delta

	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	# Slowly home toward the Moki's height (with a gentle weave so it reads as a
	# live "seeking" missile) - but only until we have drifted past them, after
	# which we commit and stop tracking (no camping).
	var vy: float = 0.0
	if player != null and not _committed:
		if global_position.x <= player.global_position.x:
			_committed = true
		else:
			var dy: float = player.global_position.y - global_position.y
			var step: float = clamp(dy, -home_speed * delta, home_speed * delta)
			var weave: float = cos(_t * wobble_freq) * wobble_amp * delta
			position.y += step + weave
			vy = (step + weave) / delta

	# Tilt the nose toward where it is tracking (the art points LEFT at rest, so
	# a small rotation against its leftward speed noses it up/down = "seeking").
	var vx_mag: float = extra_speed
	if camera != null and camera.has_method("current_speed"):
		vx_mag += camera.current_speed()
	var target_tilt: float = clamp(-vy / maxf(vx_mag, 1.0), -0.35, 0.35)
	sprite.rotation = lerpf(sprite.rotation, target_tilt, 0.12)

	# Pulse the danger glow (and keep the exhaust pointing straight back).
	if glow != null:
		glow.energy = 1.0 + 0.35 * (0.5 + 0.5 * sin(_t * 12.0))

	if camera != null and global_position.x < camera.global_position.x - cleanup_behind:
		queue_free()


# --- Juice builders (configured in code, like jet_flame.gd / fireworks.gd) ---

# A green exhaust plume that streams out the back. local_coords = false so the
# sparks are left behind in the world as the missile races forward = a trail.
func _build_flame() -> void:
	flame = CPUParticles2D.new()
	flame.position = _engine_off
	flame.z_index = -1               # behind the missile body
	flame.local_coords = false       # stay in the world (trail), don't glue to us
	flame.amount = 24
	flame.lifetime = 0.4
	flame.explosiveness = 0.0        # steady stream
	flame.direction = Vector2(1, 0)  # blow backwards (to the right; nose faces left)
	flame.spread = 16.0
	flame.gravity = Vector2.ZERO
	flame.initial_velocity_min = 30.0
	flame.initial_velocity_max = 80.0
	flame.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 3.0
	flame.scale_amount_min = 2.0
	flame.scale_amount_max = 3.4
	flame.scale_amount_curve = _shrink_curve()
	flame.color_ramp = _exhaust_ramp()
	flame.texture = _dot_texture()
	add_child(flame)
	flame.emitting = true


# A green PointLight2D danger glow at the engine, pulsed in _process.
func _build_glow() -> void:
	glow = PointLight2D.new()
	glow.position = _engine_off
	glow.color = Color(0.45, 1.0, 0.4)
	glow.energy = 1.1
	glow.texture = _glow_texture()
	glow.texture_scale = 0.5
	add_child(glow)


func _shrink_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c


# Hot white-green core -> green -> transparent over each spark's life.
func _exhaust_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 1.0, 0.7, 1.0))
	g.add_point(0.45, Color(0.4, 1.0, 0.35, 0.9))
	g.set_color(1, Color(0.25, 0.8, 0.2, 0.0))
	return g


# A soft round dot (white centre fading out), used for both particles + light.
func _dot_texture() -> GradientTexture2D:
	return _radial(16)


func _glow_texture() -> GradientTexture2D:
	return _radial(128)


func _radial(size: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = size
	t.height = size
	return t
