# ==========================================================
#  fireworks.gd - a one-shot celebration spark burst
# ==========================================================
#  A little burst of glowing dots that fly out, fall, and fade - popped on
#  the HUD (screen space) when you clear an event (one small burst) or beat
#  a boss (several big, colourful bursts). It configures itself in code so
#  the spawner can set the colour + size, then frees itself once done.
# ==========================================================

extends CPUParticles2D

var fw_color: Color = Color(1, 1, 1, 1)   # set by the spawner before adding us
var fw_big: bool = false                   # bigger/longer burst for boss kills


func _ready() -> void:
	emitting = false
	one_shot = true
	explosiveness = 1.0                     # all at once = a burst, not a stream
	amount = 44 if fw_big else 22
	lifetime = 1.1 if fw_big else 0.85
	direction = Vector2(0, -1)
	spread = 180.0                          # fire in every direction
	gravity = Vector2(0, 520)               # then rain back down
	initial_velocity_min = 170.0
	initial_velocity_max = 480.0 if fw_big else 350.0
	scale_amount_min = 2.0
	scale_amount_max = 4.5 if fw_big else 3.2
	color = fw_color
	color_ramp = _fade_ramp()               # fade each spark out over its life
	texture = _dot_texture()                # a soft round dot
	emitting = true

	# Remove ourselves once the burst has fully died out.
	await get_tree().create_timer(lifetime + 0.5).timeout
	queue_free()


func _fade_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
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
