# ==========================================================
#  Moki Jetpack Mayhem - Player (our mischievous Moki!)
# ==========================================================
#  This script lives on the Player node (a CharacterBody2D).
#  A CharacterBody2D is a body WE move ourselves with code,
#  and Godot helps it slide along floors and walls.
#
#  Everything the Moki does boils down to a few ideas:
#    1) Gravity always pulls the Moki DOWN.
#    2) Holding Space / Left-Click fires the jetpack UP.
#    3) The Moki always drifts forward, and you can speed up or
#       slow down with Left/Right (A/D or arrow keys) - handy for
#       timing your way past the solid vertical lasers.
# ==========================================================

extends CharacterBody2D


# --- Tunable numbers ---------------------------------------
# These are marked @export so you can tweak them live in the
# Godot Inspector (click the Player node and look on the right).
# Try changing them and re-running - it is the best way to learn!

@export var gravity: float = 1200.0       # Downward pull. Bigger = heavier Moki.
@export var boost_power: float = 2400.0   # Jetpack strength. Bigger = zoomier.
@export var forward_speed: float = 280.0  # Fallback drift if the camera is missing.
@export var move_speed: float = 460.0     # Left/Right flying speed within the screen.
@export var edge_margin: float = 36.0     # Keep this far from the screen's left/right edges.

# --- Look / juice (the animated Moki sprite) ---
@export var max_tilt: float = 0.35        # Most the Moki tilts (radians, ~20°) when rising/falling.
@export var tilt_ref_speed: float = 600.0 # Vertical speed that maps to a full tilt.
@export var tilt_smooth: float = 10.0     # How quickly the tilt eases toward its target (bigger = snappier).

@export var max_fall_speed: float = 900.0 # Cap on how fast we can plummet.
@export var max_rise_speed: float = 900.0 # Cap on how fast the jetpack lifts us.

# Screen limits. The camera is locked vertically to show world Y 0..720,
# so these keep the Moki fully on screen:
#   - ceiling_y 32  -> the Moki's top edge touches the roof (screen top).
#   - floor_y  628  -> the Moki's bottom edge rests on the floor strip
#                      (the floor surface sits at Y 660, half the 64px Moki
#                       above that is 660 - 32 = 628).
@export var ceiling_y: float = 32.0       # Roof: highest the Moki can go.
@export var floor_y: float = 628.0        # Floor: lowest the Moki can go.

# How long the Moki is invincible (and flashing) right after a shield
# breaks, giving you a moment to escape the hazard you just hit.
@export var shield_invuln_time: float = 1.2

# --- Timed powerup settings ---
@export var magnet_time: float = 5.0        # Magnet: how long coins are pulled.
@export var magnet_range: float = 360.0     # Magnet: how close a coin must be.
@export var magnet_pull_speed: float = 650.0 # Magnet: how fast coins fly in.
@export var doubler_time: float = 5.0       # Doubler: how long coins count double.
@export var ghost_time: float = 5.0         # Ghost: how long we phase through hazards.
@export var ghost_invuln_time: float = 1.2  # Grace (blinking i-frames) right after Ghost ends.

# --- New powerups ---
@export var dash_time: float = 2.0          # Dash: seconds of invincible rocket-boost.
@export var dash_boost_mult: float = 2.6    # Dash: how hard the world rockets past.
@export var tiny_scale: float = 0.55        # Tiny Moki: shrink factor (smaller = slip through more).
@export var tiny_time: float = 6.0          # Tiny Moki: how long you stay small.
@export var second_chance_invuln: float = 1.6  # Second Chance: i-frames granted by a revive.
@export var revive_invuln_time: float = 2.0    # Slot-machine REVIVE: i-frames after coming back.

# A reference to the flame node so we can show/hide it. The $ is shorthand
# for get_node(): $Flame finds the child named "Flame". @onready waits until
# the node is actually in the scene before grabbing it.
@onready var flame: CPUParticles2D = $Moki/Flame

# The shield "bubble" visual, shown only while a shield is active.
@onready var shield_visual: ColorRect = $Shield

# A faint self-glow so the Moki is just visible during a Blackout event.
# Kept dim on purpose (full dark is the whole point). GLOW_MAX = brightness
# at full blackout.
@onready var glow: PointLight2D = $Glow
const GLOW_MAX := 1.1

# The animated Moki body (AnimatedSprite2D). We swap its idle/boost animation and
# tilt it for juice. It's a child of the Player, so we tilt IT (not the Player),
# keeping the collision box square.
@onready var moki: AnimatedSprite2D = $Moki

# Becomes true the moment we crash, so we only crash once.
var dead: bool = false

# Shield powerup state.
var has_shield: bool = false
var invuln: float = 0.0   # seconds of post-shield invincibility remaining

# A held Second Chance revive token.
var _has_second_chance: bool = false

# Set by the spawner during the Choice-Gate RISK gauntlet: a hit here FAILS the
# event (the spawner ends it, no reward) instead of ending the whole run.
var protected: bool = false

# Timed powerups: a name -> seconds-remaining table. A powerup is active
# while its entry exists; when its time hits zero we remove it.
var timers: Dictionary = {}

# Spins the Ghost rainbow effect.
var _ghost_phase: float = 0.0

# The world-scrolling camera. We look it up the first time we need it
# (it may not be ready the instant the Moki is).
var camera: Node2D


func _ready() -> void:
	# Join the "player" group. Asteroids look us up by this group name
	# so they know who to crash.
	add_to_group("player")

	# A slot-machine "SHIELD NEXT RUN!" win sets this flag on GameState (which
	# survives the scene reload between runs). Consume it once, here, so this run
	# starts with a free shield bubble already up.
	if GameState.start_with_shield:
		GameState.start_with_shield = false
		gain_powerup("shield")


# _physics_process() runs at a fixed, steady rate. It is the right
# place for movement and physics. 'delta' is the seconds since the
# last step, so the Moki moves the same speed on a fast or slow PC.
func _physics_process(delta: float) -> void:

	# Find the scrolling camera once it exists (we ride along with it).
	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")

	# Tick down timed powerups (magnet/doubler/ghost), the shield's i-frames,
	# and update how the Moki looks.
	_update_powerups(delta)

	# Light ourselves faintly only when the world goes dark (Blackout event).
	glow.energy = GameState.blackout * GLOW_MAX

	# 1) GRAVITY -------------------------------------------------
	# Add a little downward speed every step. (In 2D, +Y is DOWN.)
	velocity.y += gravity * delta

	# 2) JETPACK BOOST ------------------------------------------
	# is_action_pressed() is TRUE every step the button is HELD,
	# so the longer you hold, the more you rise. (-Y is UP.)
	var boosting := Input.is_action_pressed("boost")
	if boosting:
		velocity.y -= boost_power * delta

	# Fire the jetpack exhaust only while we are actively boosting.
	flame.emitting = boosting

	# Keep the up/down speed inside friendly limits.
	velocity.y = clamp(velocity.y, -max_rise_speed, max_fall_speed)

	# 3) FORWARD CARRY + FREE LEFT/RIGHT ------------------------
	# We always get carried right at the camera's scroll speed (so the
	# world keeps moving no matter what). On TOP of that, Left/Right adds
	# real sideways flying, letting the Moki roam across the screen.
	var carry: float = camera.current_speed() if camera != null else forward_speed
	var move_input := Input.get_axis("move_left", "move_right")
	velocity.x = carry + move_input * move_speed

	# Apply everything above. move_and_slide() reads 'velocity',
	# moves the body, and smoothly slides along any surfaces.
	move_and_slide()

	# Keep the Moki inside the part of the world the camera can see, so it
	# can roam freely but never fly off the left or right edge.
	if camera != null:
		var half_view: float = get_viewport_rect().size.x * 0.5
		var left_edge: float = camera.global_position.x - half_view + edge_margin
		var right_edge: float = camera.global_position.x + half_view - edge_margin
		position.x = clamp(position.x, left_edge, right_edge)

	# --- Soft screen limits (training wheels) ------------------
	# Stop the Moki from leaving the top or bottom of the play area.
	# If we hit a limit, also zero-out the speed pushing us past it
	# so we don't "stick" with built-up momentum.
	if position.y < ceiling_y:
		position.y = ceiling_y
		if velocity.y < 0.0:
			velocity.y = 0.0
	elif position.y > floor_y:
		position.y = floor_y
		if velocity.y > 0.0:
			velocity.y = 0.0

	# Animate + tilt the Moki body for juice (idle vs boost, nose up/down).
	_update_moki_look(delta, boosting)


# Update the Moki's animation + tilt. Boosting plays the energetic "boost" frames;
# otherwise the calm "idle" loop. The body tilts nose-UP while rising and nose-DOWN
# while falling. We rotate the SPRITE (a child), never the Player, so the collision
# box stays square. The Moki art already faces right, so no flipping is needed.
func _update_moki_look(delta: float, boosting: bool) -> void:
	var want := "boost" if boosting else "idle"
	if moki.animation != want:
		moki.play(want)
	# +velocity.y points DOWN, so a positive value tilts the nose down. Map the
	# vertical speed to [-1, 1] of our reference, scale by max_tilt, then ease toward it.
	var target: float = clampf(velocity.y / tilt_ref_speed, -1.0, 1.0) * max_tilt
	moki.rotation = lerp_angle(moki.rotation, target, clampf(delta * tilt_smooth, 0.0, 1.0))


# gain_powerup() is called by a powerup pickup when the Moki grabs it.
# Adding a new powerup later means adding another case here.
func gain_powerup(kind: String) -> void:
	match kind:
		"shield":
			has_shield = true
			shield_visual.visible = true
		"magnet":
			timers["magnet"] = magnet_time
		"doubler":
			timers["doubler"] = doubler_time
		"ghost":
			timers["ghost"] = ghost_time
		"dash":
			# An invincible rocket burst: i-frames + the world boosts past us.
			invuln = maxf(invuln, dash_time)
			if camera != null and camera.has_method("add_boost"):
				camera.add_boost(dash_time, dash_boost_mult)
		"tiny":
			timers["tiny"] = tiny_time
		"secondchance":
			_has_second_chance = true


# True while the named timed powerup is running.
func is_active(kind: String) -> bool:
	return timers.get(kind, 0.0) > 0.0


# How much a coin is worth right now (Doubler makes it 2).
func coin_value() -> int:
	return 2 if is_active("doubler") else 1


# A short text summary of what is active, for the HUD to display.
func powerup_status() -> String:
	var parts: Array[String] = []
	if has_shield:
		parts.append("Shield")
	if _has_second_chance:
		parts.append("2nd Chance")
	for key in timers:
		parts.append("%s %ds" % [String(key).capitalize(), ceili(timers[key])])
	return "  ".join(parts)


# Run every physics step: tick timers, apply effects, refresh appearance.
func _update_powerups(delta: float) -> void:
	if invuln > 0.0:
		invuln -= delta

	# Tiny Moki: smoothly shrink the whole Moki (collision + visuals) while active,
	# and grow back when it ends.
	var target_scale := tiny_scale if is_active("tiny") else 1.0
	scale = scale.lerp(Vector2(target_scale, target_scale), delta * 10.0)

	# Count each timed powerup down; drop any that have run out.
	# (.keys() gives a copy, so erasing mid-loop is safe.)
	for key in timers.keys():
		timers[key] -= delta
		if timers[key] <= 0.0:
			timers.erase(key)
			# Ending Ghost grants brief i-frames so you don't instantly die
			# if it runs out while you're still inside a hazard.
			if key == "ghost":
				invuln = maxf(invuln, ghost_invuln_time)

	# Magnet drags nearby coins toward us while active.
	if is_active("magnet"):
		_pull_coins(delta)

	# Looks: a fast rainbow pulse while Ghosting (Mario-star style, so it is
	# unmistakable), a quick blink right after a shield break, else normal.
	if is_active("ghost"):
		_ghost_phase += delta * 6.0
		modulate = Color.from_hsv(fmod(_ghost_phase, 1.0), 0.6, 1.0)
	elif invuln > 0.0:
		modulate = Color(1, 1, 1, 0.4) if int(invuln * 10) % 2 == 0 else Color(1, 1, 1, 1)
	else:
		modulate = Color(1, 1, 1, 1)


# Slide every coin within range a little closer to the Moki.
func _pull_coins(delta: float) -> void:
	for node in get_tree().get_nodes_in_group("coin"):
		var coin := node as Node2D
		if coin == null:
			continue
		var offset := global_position - coin.global_position
		if offset.length() < magnet_range:
			coin.global_position += offset.normalized() * magnet_pull_speed * delta


# crash() is called by a hazard when the Moki hits it.
func crash() -> void:
	if dead:
		return  # Already crashed - ignore extra hits.

	# Ghost powerup: phase straight through everything.
	if is_active("ghost"):
		return

	# Just broke a shield? We are briefly invincible - ignore this hit.
	if invuln > 0.0:
		return

	# A shield soaks up the hit instead of ending the run, and grants a
	# short window of invincibility so we can fly clear of the hazard.
	if has_shield:
		has_shield = false
		shield_visual.visible = false
		invuln = shield_invuln_time
		return

	# A held Second Chance revives us once instead of dying - a dramatic save
	# with i-frames to escape the hazard we just hit.
	if _has_second_chance:
		_has_second_chance = false
		invuln = maxf(invuln, second_chance_invuln)
		var hud_sc := get_tree().get_first_node_in_group("hud")
		if hud_sc != null:
			if hud_sc.has_method("show_banner"):
				hud_sc.show_banner("SECOND CHANCE!", Color(1.0, 0.5, 0.7, 1.0), 2.0)
			if hud_sc.has_method("flash"):
				hud_sc.flash(Color(1.0, 0.5, 0.7, 0.45))
		return

	# In the Choice-Gate RISK gauntlet: a hit FAILS that event (no reward), but the
	# RUN continues. i-frames first so co-incident hits this frame are ignored too.
	if protected:
		invuln = maxf(invuln, 2.0)
		var sp := get_tree().get_first_node_in_group("spawner")
		if sp != null and sp.has_method("choice_failed"):
			sp.choice_failed()
		return

	# No shield - this is a real crash.
	dead = true
	set_physics_process(false)
	flame.emitting = false   # cut the thrust; any lingering sparks fade out

	# Hand off to the HUD. It decides what happens next: if we collected any spin
	# tokens this run, it opens the SLOT MACHINE (where a "revive" can bring us
	# back); otherwise it goes straight to the game-over screen.
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.player_crashed()


# revive() is called by the HUD when a slot-machine spin lands on REVIVE. We come
# back to life right where we crashed, with a window of invincibility so we can
# fly clear of whatever got us. The run simply continues (nothing was finalised).
func revive() -> void:
	dead = false
	set_physics_process(true)
	velocity = Vector2.ZERO
	invuln = maxf(invuln, revive_invuln_time)
	# Make sure we're back inside the play area (not clipped into roof/floor).
	position.y = clamp(position.y, ceiling_y, floor_y)

