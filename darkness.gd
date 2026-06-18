# ==========================================================
#  darkness.gd - dims the whole world during the Blackout event
# ==========================================================
#  This lives on a CanvasModulate node. A CanvasModulate MULTIPLIES the
#  colour of EVERYTHING on the main world canvas (background, asteroids,
#  coins, the Moki) by its `color`. White (1,1,1) means "no change";
#  a near-black colour means "make the world almost pitch dark".
#
#  Crucially, CanvasModulate does NOT touch:
#    - the HUD (it is a separate CanvasLayer), so the UI stays readable, and
#    - 2D Lights (PointLight2D), which are ADDED on top afterwards. That is
#      the whole trick: we dim the world to black, then the little glow
#      lights on the coins and hazards are the only thing you can see.
#
#  We simply read GameState.blackout (0 = day, 1 = full dark) every frame
#  and slide our colour between white and `dark_color` to match.
# ==========================================================

extends CanvasModulate

# The colour the world fades to at full blackout. Not pure black, so a hint
# of the floor/stars survives - tweak darker/lighter to taste.
@export var dark_color: Color = Color(0.05, 0.05, 0.09)


func _process(_delta: float) -> void:
	# lerp() blends from white (no dimming) toward dark_color as blackout
	# climbs from 0 to 1.
	color = Color(1, 1, 1).lerp(dark_color, GameState.blackout)
