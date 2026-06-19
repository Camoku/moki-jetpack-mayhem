# ==========================================================
#  bounce_orb.gd - a plasma ball that bounces between roof and floor
# ==========================================================
#  Sits in the world (the camera scrolls past it, like an asteroid) and
#  bounces straight up and down between two heights, reflecting at each
#  end. The motion is LINEAR (constant speed, no gravity) on purpose:
#  a clean, predictable zig-zag you can read from across the screen and
#  time your way through. Touch it and you crash.
#
#  Juice: a slow spin + pulsing glow, a crackling electric spark trail, and
#  an impact pop (scale + glow flare) each time it slams a roof/floor.
# ==========================================================

extends Area2D

@export var cleanup_behind: float = 760.0
@export var bounce_top: float = 34.0       # highest the orb rises to (near the ceiling at y=0)
@export var bounce_bottom: float = 590.0   # lowest it falls to (just on the floor surface)
@export var orb_radius: float = 20.0       # for keeping pickups clear
@export var orb_scale: float = 0.13        # plasma ball size (chonky = threatening)
@export var spin_speed: float = 2.6        # how fast the plasma ball rotates (rad/sec)

# Vertical speed (px/sec). The spawner sets this; the SIGN is the start
# direction (positive = moving down first).
var vy: float = 260.0
# Leftward drift (px/sec, on top of the world scroll). Combined with the
# vertical bounce this makes the orb trace a diagonal ZIG-ZAG across the screen
# instead of a straight up/down column. The spawner sets it (negative = left).
var vx: float = -120.0
var camera: Node2D
var _t: float = 0.0
var _pop: float = 1.0     # impact scale-pop (decays back to 1)
var _flare: float = 0.0   # impact glow flare (decays back to 0)

@onready var sprite: Sprite2D = $Sprite
@onready var glow: PointLight2D = $Glow
var sparks: CPUParticles2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("asteroid")   # generic persistent-hazard group (cap + coin clearance)
	sprite.scale = Vector2(orb_scale, orb_scale)
	_build_sparks()


# Keep coins/powerups clear of the orb's body.
func clear_radius() -> float:
	return orb_radius + 8.0


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.crash()


func _process(delta: float) -> void:
	_t += delta

	# Juice: spin the plasma ball; decay the impact pop + glow flare back to rest.
	sprite.rotation += spin_speed * delta
	_pop = move_toward(_pop, 1.0, delta * 2.2)
	_flare = move_toward(_flare, 0.0, delta * 4.0)
	sprite.scale = Vector2(orb_scale, orb_scale) * _pop
	glow.energy = 1.0 + 0.35 * (0.5 + 0.5 * sin(_t * 6.0)) + _flare

	# Drift left while bouncing up/down -> a diagonal zig-zag path.
	position.x += vx * delta

	# Travel up/down, flipping direction at each bound (a clean bounce).
	position.y += vy * delta
	if position.y <= bounce_top:
		position.y = bounce_top
		vy = absf(vy)        # head back down
		_bounce()
	elif position.y >= bounce_bottom:
		position.y = bounce_bottom
		vy = -absf(vy)       # head back up
		_bounce()

	# Remove ourselves once we have scrolled off behind the screen.
	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	if camera != null and global_position.x < camera.global_position.x - cleanup_behind:
		queue_free()


# A roof/floor slam: pop the scale and flare the glow (the crackle trail runs
# continuously, so the impact reads as a bright flash + squashy bounce).
func _bounce() -> void:
	_pop = 1.32
	_flare = 1.8
	# Soft bounce blip - only when on-screen, so off-screen orbs don't spam.
	if camera != null and absf(global_position.x - camera.global_position.x) < 700.0:
		Audio.play_varied("bounce", 0.12, -6.0)


# --- Juice builders (configured in code, like jet_flame.gd) ---

# A crackling electric spark trail left in the world, so the orb reads as a live,
# dangerous plasma ball tracing a sparking path.
func _build_sparks() -> void:
	sparks = CPUParticles2D.new()
	sparks.z_index = -1
	sparks.local_coords = false   # sparks stay in the world = a crackling wake
	sparks.amount = 22
	sparks.lifetime = 0.4
	sparks.explosiveness = 0.0
	sparks.spread = 180.0          # spit in every direction
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 25.0
	sparks.initial_velocity_max = 75.0
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 6.0
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.0
	sparks.scale_amount_curve = _shrink_curve()
	sparks.color_ramp = _spark_ramp()
	sparks.texture = _dot_texture()
	add_child(sparks)
	sparks.emitting = true


func _shrink_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c


# Hot white-purple core -> violet -> transparent.
func _spark_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(0.95, 0.85, 1.0, 1.0))
	g.add_point(0.4, Color(0.7, 0.3, 1.0, 0.9))
	g.set_color(1, Color(0.5, 0.15, 0.9, 0.0))
	return g


func _dot_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 16
	t.height = 16
	return t
