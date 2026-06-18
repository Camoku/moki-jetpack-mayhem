# ==========================================================
#  background.gd - slowly recolors deep space as you travel
# ==========================================================
#  This script lives on the "Space" ColorRect (the black backdrop).
#  As the Moki flies farther to the right, we gently shift the
#  background tint, so long runs feel like a journey through space.
#
#  We keep every colour value LOW (dark) on purpose, so the stars
#  always stay visible on top.
# ==========================================================

extends ColorRect

# How far (in pixels) the Moki travels for the colour to move through
# roughly one full "mood". Bigger number = slower, subtler change.
@export var cycle_distance: float = 2000.0

# Where to find the Moki in the scene tree, so we can read its distance.
# (Space -> SpaceLayer -> Background -> Main -> Player)
@export var player_path: NodePath = ^"../../../Player"

# Grab the Moki once when the scene starts. get_node_or_null() returns
# null instead of crashing if the path is wrong - handy while learning.
@onready var player: Node2D = get_node_or_null(player_path)


# _process() runs every drawn frame - perfect for smooth visual tweaks.
func _process(_delta: float) -> void:
	if player == null:
		return  # No Moki found? Do nothing rather than error.

	# How far we have travelled, turned into an angle for sin().
	# sin() smoothly wanders between -1 and 1, giving an endless,
	# gentle colour drift instead of a one-way fade.
	var phase: float = player.global_position.x / cycle_distance

	# Build a dark colour that slowly breathes through deep blues/purples.
	# The "+2.0" and "+4.0" offsets make red, green and blue peak at
	# different times, so the hue shifts instead of just brightening.
	var r: float = 0.03 + 0.03 * sin(phase)
	var g: float = 0.03 + 0.03 * sin(phase + 2.0)
	var b: float = 0.07 + 0.05 * sin(phase + 4.0)

	color = Color(r, g, b, 1.0)
