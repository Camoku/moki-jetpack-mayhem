# ==========================================================
#  jet_flame.gd - the Moki's jetpack exhaust
# ==========================================================
#  A small, soft particle flame that streams downward from under the Moki.
#  player.gd switches it ON (emitting) only while the boost button is held, so
#  you see thrust exactly when you fire the jetpack. It configures itself in
#  code, the same beginner-friendly way the fireworks do (see fireworks.gd).
#
#  Because it's a CHILD of the Moki sprite (which tilts), the whole flame tilts
#  with the body - the thrust naturally swings down-and-back as you rise.
# ==========================================================

extends CPUParticles2D


func _ready() -> void:
	emitting = false           # player.gd turns this on while boosting
	one_shot = false           # a continuous stream, not a single burst
	local_coords = true        # stay glued under the Moki (tilt with the body)
	amount = 28
	lifetime = 0.45            # live a bit longer so the plume reaches further down
	explosiveness = 0.0        # steady stream (0), not a single pop (1)
	direction = Vector2(0, 1)  # blow downward (the Moki faces right; thrust goes down/back)
	spread = 12.0              # a slight fan so it isn't a rigid line
	gravity = Vector2(0, 420)  # accelerate the sparks on downward (stretches the tail)
	initial_velocity_min = 110.0
	initial_velocity_max = 220.0
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 4.0   # a small round base, so the flame has some width
	scale_amount_min = 2.5
	scale_amount_max = 4.0
	scale_amount_curve = _shrink_curve()   # each spark tapers to nothing over its life
	color_ramp = _flame_ramp()             # hot yellow-white -> orange -> transparent
	texture = _dot_texture()               # a soft round dot (no hard edges)
	emitting = false


# Each spark starts full size and shrinks to a point as it ages (1.0 -> 0.0).
func _shrink_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c


# The flame's colour over a spark's life: a hot near-white core that cools to
# orange and fades out.
func _flame_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.55, 1.0))   # hot core
	g.add_point(0.5, Color(1.0, 0.45, 0.1, 0.95))  # orange middle
	g.set_color(1, Color(1.0, 0.2, 0.0, 0.0))      # fade out
	return g


# A soft round dot: white centre fading to transparent at the edge (same trick
# the fireworks use), so each particle is a soft blob, not a hard square.
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
