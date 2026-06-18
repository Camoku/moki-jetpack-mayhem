# ==========================================================
#  ring.gd - a boost ring
# ==========================================================
#  Fly the Moki through the opening to kick the world into a higher gear.
#  Highway rings are stronger/longer and report back to the spawner
#  whether they were hit (for the "BOOST MASTER!" clean-sweep reward).
# ==========================================================

extends Area2D

@export var boost_time: float = 3.0
@export var boost_multiplier: float = -1.0   # -1 = camera's default strength
@export var cleanup_behind: float = 760.0

var from_highway: bool = false   # set by the spawner for highway rings
var camera: Node2D
var _collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("ring")   # so coins/powerups/hazards keep clear of us


# How far other things should stay from our centre (the ring is ~96 across).
func clear_radius() -> float:
	return 50.0


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_collected = true
		var cam := get_tree().get_first_node_in_group("camera")
		if cam != null:
			cam.add_boost(boost_time, boost_multiplier)
		if from_highway:
			_notify_resolved(true)   # tell the highway we got this one
		else:
			# Normal rings flash feedback; highway rings stay quiet (the event
			# has its own banner).
			var hud := get_tree().get_first_node_in_group("hud")
			if hud != null:
				hud.show_banner("SPEED BOOST!", Color(0.4, 1.0, 0.8), 1.2)
		queue_free()


func _process(_delta: float) -> void:
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
