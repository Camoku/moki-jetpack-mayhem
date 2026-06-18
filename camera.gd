# ==========================================================
#  camera.gd - the world auto-scroller (with a boost gear)
# ==========================================================
#  The camera glides right at a constant speed - THIS is what scrolls
#  the world. Flying through a Boost Ring kicks in a temporary higher
#  gear. Boosts can vary in STRENGTH: highway rings push harder than
#  the normal ones.
#
#  The Moki reads current_speed() so it keeps pace, boost and all.
# ==========================================================

extends Camera2D

@export var scroll_speed: float = 280.0     # Normal world speed.
@export var boost_multiplier: float = 1.8   # Default boost strength (normal rings).

var _boost_time: float = 0.0   # seconds of boost remaining
var _boost_mult: float = 1.0   # strength of the active boost (1.0 = none)


func _ready() -> void:
	add_to_group("camera")


# The speed we are actually moving at right now (boosted or not).
func current_speed() -> float:
	return scroll_speed * (_boost_mult if _boost_time > 0.0 else 1.0)


# Called by a Boost Ring. 'multiplier' < 0 means "use the default strength".
# The strongest active boost wins, and the timer refreshes to the longer one.
func add_boost(duration: float, multiplier: float = -1.0) -> void:
	if multiplier < 0.0:
		multiplier = boost_multiplier
	_boost_time = maxf(_boost_time, duration)
	_boost_mult = maxf(_boost_mult, multiplier)


func _physics_process(delta: float) -> void:
	if _boost_time > 0.0:
		_boost_time -= delta
		if _boost_time <= 0.0:
			_boost_mult = 1.0   # back to normal speed when the boost ends
	# Slide right at the current speed. We never touch Y (vertical view stays
	# locked, floor pinned to the bottom).
	global_position.x += current_speed() * delta
