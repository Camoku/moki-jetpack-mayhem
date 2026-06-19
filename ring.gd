# ==========================================================
#  ring.gd - a boost ring
# ==========================================================
#  Fly the Moki through the opening to kick the world into a higher gear.
#  Highway rings are stronger/longer and report back to the spawner
#  whether they were hit (for the "BOOST MASTER!" clean-sweep reward).
# ==========================================================

extends Area2D

# Same spark burst the powerups/celebrations use - popped when flown through.
const FIREWORKS := preload("res://Fireworks.tscn")
# The booster's signature aqua-green (cooler than the Dash gate's lime).
const TRAIL_COLOR := Color(0.35, 1.0, 0.65, 0.5)

@export var boost_time: float = 3.0
@export var boost_multiplier: float = -1.0   # -1 = camera's default strength
@export var cleanup_behind: float = 760.0

var from_highway: bool = false   # set by the spawner for highway rings
var camera: Node2D
var _collected: bool = false
var _pulse_t: float = 0.0        # drives the neon glow pulse / shimmer / breathe

@onready var glow: PointLight2D = $Glow
# The four bright inner highlights, in clockwise order, so we can chase a glow
# "current" around the ring (Top -> Right -> Bottom -> Left).
@onready var _his: Array = [$TopHi, $RightHi, $BottomHi, $LeftHi]


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("ring")   # so coins/powerups/hazards keep clear of us


# How far other things should stay from our centre (the ring is ~96 across).
func clear_radius() -> float:
	return 50.0


func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if body.is_in_group("player"):
		_collected = true
		var cam := get_tree().get_first_node_in_group("camera")
		if cam != null:
			cam.add_boost(boost_time, boost_multiplier)
			if cam.has_method("shake"):
				cam.shake(5.0)         # a small kick as you punch through
		if from_highway:
			_notify_resolved(true)   # tell the highway we got this one
		else:
			# Normal rings flash feedback; highway rings stay quiet (the event
			# has its own banner).
			var hud := get_tree().get_first_node_in_group("hud")
			if hud != null:
				hud.show_banner("SPEED BOOST!", Color(0.4, 1.0, 0.8), 1.2)
		# Moki gets a short aqua speed-trail whoosh as he blasts through (a cooler
		# tint than the Dash powerup's lime, so the two read as related but distinct).
		if body.has_method("speed_trail"):
			body.speed_trail(0.5, TRAIL_COLOR)
		_pop()


# "Smash through" flourish: an aqua spark burst, then the four edge bars BURST
# OUTWARD and the whole frame fades - distinct from the Dash gate, which just
# flares and scales up on the spot.
func _pop() -> void:
	set_deferred("monitoring", false)   # can't be triggered again mid-pop

	var fw := FIREWORKS.instantiate()
	fw.fw_color = Color(TRAIL_COLOR.r, TRAIL_COLOR.g, TRAIL_COLOR.b)   # solid for the burst
	get_parent().add_child(fw)
	fw.global_position = global_position

	glow.energy = 2.6
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	# Each edge (bar + its highlight) flies off in its own outward direction.
	var spread := 60.0
	var edges := [
		[$Top, $TopHi, Vector2(0, -spread)],
		[$Bottom, $BottomHi, Vector2(0, spread)],
		[$Left, $LeftHi, Vector2(-spread, 0)],
		[$Right, $RightHi, Vector2(spread, 0)],
	]
	for e in edges:
		tw.tween_property(e[0], "position", e[0].position + e[2], 0.22)
		tw.tween_property(e[1], "position", e[1].position + e[2], 0.22)
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	tw.tween_property(glow, "energy", 0.0, 0.22)
	await tw.finished
	queue_free()


func _process(delta: float) -> void:
	if _collected:
		return   # the pop tween owns our scale/fade now

	# Animated neon idle, so the ring reads as a live, energetic gate:
	_pulse_t += delta * 4.0
	# 1) the whole frame breathes gently,
	var s := 1.0 + 0.04 * sin(_pulse_t * 1.3)
	scale = Vector2(s, s)
	# 2) the glow halo pulses,
	glow.energy = 1.0 + 0.4 * (0.5 + 0.5 * sin(_pulse_t))
	# 3) and a bright "current" chases around the four inner edges.
	for i in _his.size():
		var a := 0.55 + 0.45 * (0.5 + 0.5 * sin(_pulse_t * 2.0 - i * PI * 0.5))
		_his[i].modulate.a = a

	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	if camera != null and global_position.x < camera.global_position.x - cleanup_behind:
		if from_highway and not _collected:
			_notify_resolved(false)   # a highway ring we flew right past
		queue_free()


func _notify_resolved(hit: bool) -> void:
	var sp := get_tree().get_first_node_in_group("spawner")
	if sp != null and sp.has_method("highway_ring_resolved"):
		sp.highway_ring_resolved(hit)
