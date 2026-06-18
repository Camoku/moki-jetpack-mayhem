# ==========================================================
#  spawner.gd - drops hazards in waves, ramping up over time
# ==========================================================
#  Two ideas drive the pacing:
#
#  1) DIFFICULTY: a single 0.0 -> 1.0 number based on how far the
#     world has scrolled. Higher difficulty = faster spawns + more lasers.
#
#  2) WAVES: instead of a non-stop onslaught, we alternate between a
#     BUSY stretch (hazards) and a CALM breather (nothing), each with
#     a randomised length. Plus we jitter the spawn timing so it never
#     feels like a metronome.
#
#  Everything is measured against the CAMERA now (the world scroller),
#  not the Moki, since the Moki roams around the screen freely.
# ==========================================================

extends Node2D

# The three hazard scenes (wired up in Main.tscn).
@export var obstacle_scene: PackedScene          # asteroid
@export var vertical_laser_scene: PackedScene
@export var horizontal_laser_scene: PackedScene
@export var coin_scene: PackedScene              # collectible coin
@export var beam_obstacle_scene: PackedScene     # floating capped laser bar
@export var ring_scene: PackedScene              # fly-through boost ring
@export var missile_scene: PackedScene           # warning-then-strike missile

# Missiles fire from the right during normal play (once unlocked via progression).
# They get more frequent (and sometimes double up) the deeper you go.
@export var missile_interval_early: float = 8.0  # Gap between missiles early on...
@export var missile_interval_deep: float = 3.0   # ...and once fully ramped (more frequent).
@export var missile_double_chance: float = 0.6   # Max chance of a 2-missile wave (at full difficulty).

# Of the non-laser hazards, how often we drop a beam gate instead of an asteroid.
@export var beam_chance: float = 0.3

# --- Extra obstacles (mixed into normal play once unlocked via progression) ---
@export var orb_scene: PackedScene             # bouncing orb
@export var crusher_scene: PackedScene          # slamming gate
@export var drone_scene: PackedScene            # homing drone
@export var orb_chance: float = 0.25            # Chance a non-beam hazard is an orb (once unlocked).
@export var drone_chance: float = 0.25          # Chance a non-beam/orb hazard is a drone (once unlocked).
@export var crusher_interval_min: float = 7.0   # Crusher gates arrive on their own slow timer...
@export var crusher_interval_max: float = 13.0  # ...somewhere in this range (one at a time).
@export var crusher_clear_window: float = 4.5   # Seconds of "no other hazards" while a gate passes.

# Celebration fireworks (popped on the HUD when you clear an event / beat a boss).
@export var fireworks_scene: PackedScene
# Boost rings appear on their own slow, random timer (only in normal play).
@export var ring_interval_min: float = 6.0
@export var ring_interval_max: float = 11.0

@export var spawn_ahead: float = 1050.0   # How far right of the camera centre to spawn.

# --- Coins (spawn on their own timer, even during breathers) ---
@export var coin_interval: float = 2.2    # Seconds between coin rows.
@export var coin_row_min: int = 3         # A row has this many coins...
@export var coin_row_max: int = 6         # ...up to this many.
@export var coin_spacing: float = 60.0    # Gap between coins in a row.
@export var coin_min_y: float = 90.0      # Coin height range.
@export var coin_max_y: float = 560.0

# --- Powerups (rare special pickups) ---
@export var powerup_scene: PackedScene
# The list of powerups that can appear. Add more here as we build them.
@export var powerup_types: Array[String] = ["shield", "magnet", "doubler", "ghost"]
@export var powerup_interval_min: float = 9.0   # Random gap between powerups...
@export var powerup_interval_max: float = 15.0  # ...somewhere in this range.

# Spawning speeds up as difficulty climbs from start_interval to min_interval.
@export var start_interval: float = 1.6   # Seconds between spawns at the start.
@export var min_interval: float = 0.85    # Fastest spawning (late game).
@export var ramp_distance: float = 13000.0 # Distance to reach full difficulty (smoother ramp).
@export var interval_jitter: float = 0.35 # +/- randomness on each spawn's timing.

# Hard cap on persistent hazards (asteroids + beams) on screen at once, so it
# never becomes a cluttered mess. The cap itself scales up with difficulty.
@export var max_hazards_min: int = 3      # Cap early in a run.
@export var max_hazards_max: int = 8      # Cap once fully ramped.

@export var min_y: float = 90.0           # Asteroid height range.
@export var max_y: float = 600.0

# Lasers stay rare-ish: a minimum gap between them so two never trap you.
@export var laser_cooldown: float = 3.0

# How far left/right of centre a vertical laser can appear on screen.
@export var vertical_spread: float = 350.0

# --- Wave timing (the breather system) ---
@export var busy_min: float = 6.0         # A BUSY stretch lasts this long...
@export var busy_max: float = 11.0        # ...up to this long (randomised).
@export var breather_min: float = 2.5     # A CALM breather lasts this long...
@export var breather_max: float = 4.5     # ...up to this long (randomised).

# --- Events: shared selection (which event, if any, follows a breather) ---
@export var event_chance: float = 0.55     # Chance a breather leads to an event (else normal play).
@export var highway_weight: float = 0.6    # Highway is picked a bit less often (no danger); others = 1.0.

# --- Laser Frenzy (special event: pattern lasers, no asteroids/coins) ---
@export var frenzy_duration: float = 10.0      # Capped at 10s; deeper runs get HARDER, not longer.
@export var frenzy_combo_difficulty: float = 0.6 # Combined V+H patterns appear past this difficulty.
@export var frenzy_intro_time: float = 1.5     # Calm "incoming!" warning before formations start.
# Formations come faster the deeper you are: this interval early -> deep.
@export var frenzy_formation_interval: float = 2.6       # Time between formations early on.
@export var frenzy_formation_interval_deep: float = 1.9  # ...and once fully ramped.
@export var frenzy_charge: float = 1.0         # Charge time for frenzy lasers.
@export var frenzy_fire: float = 1.1           # Fire time for frenzy lasers.
@export var reward_time: float = 5.0           # The coin-block victory window after a frenzy.
@export var reward_breath: float = 1.0         # Calm pause before the bonus block appears.

# --- Asteroid Storm (event: a burst of fast meteors from the right) ---
@export var storm_duration: float = 8.0        # How long a storm lasts.
@export var storm_intro_time: float = 1.2      # "Incoming!" beat before meteors start.
@export var storm_spawn_interval: float = 0.65 # Time between meteors early on...
@export var storm_spawn_interval_deep: float = 0.4 # ...and once fully ramped (harder).
@export var storm_asteroid_speed: float = 220.0 # Extra leftward speed of storm meteors.

# --- Missile Barrage (event: telegraphed volleys of missiles) ---
@export var barrage_duration: float = 8.0      # How long a barrage lasts.
@export var barrage_intro_time: float = 1.2    # "Incoming!" beat before the first volley.
@export var barrage_volley_interval: float = 1.8      # Time between volleys early on...
@export var barrage_volley_interval_deep: float = 1.3 # ...and once fully ramped (harder).

# --- Boost Highway (event: a flowing chain of boost rings, no hazards) ---
@export var highway_duration: float = 8.0      # How long rings keep spawning.
@export var highway_ring_gap: float = 0.7      # Seconds between rings (spread out).
@export var highway_center: float = 325.0      # Middle height of the wavy ring path.
@export var highway_amplitude: float = 180.0   # How far the path waves up/down.
@export var highway_wave_speed: float = 0.45   # Path curve per ring (radians).
@export var highway_boost_time: float = 5.0    # Highway rings boost LONGER than normal...
@export var highway_boost_multiplier: float = 2.3  # ...and STRONGER (vs 1.8 normal).

# --- Coin Rush (event: a flowing stream of coins; collect them all!) ---
@export var coinrush_duration: float = 8.0     # How long coins keep streaming.
@export var coinrush_speed_mult: float = 1.4   # World scrolls this much FASTER during a coin rush (harder).
@export var coinrush_gap: float = 0.4          # Seconds between coins in the stream.
@export var coinrush_center: float = 325.0     # Middle height of the wavy coin path.
@export var coinrush_amplitude: float = 250.0  # How far the path waves up/down (bigger swings = harder).
@export var coinrush_wave_speed: float = 0.78  # Path curve per coin (radians; faster = wigglier/harder).

# --- Narrowing Cave (event: thread a winding tunnel) ---
@export var cave_wall_scene: PackedScene       # one slice of the cave tunnel
@export var cave_duration: float = 8.0         # How long the tunnel keeps streaming.
@export var cave_intro_time: float = 1.2       # "Incoming!" beat before the walls.
@export var cave_wall_gap: float = 0.15        # Seconds between wall slices (smaller = finer/smoother edge).
@export var cave_center: float = 325.0         # Middle height the gap snakes around.
@export var cave_amplitude: float = 120.0      # How far the gap snakes up/down (gentler now).
@export var cave_wave_speed: float = 0.15      # Tunnel curve per slice (radians; gentler slope).
@export var cave_gap_early: float = 260.0      # Gap height early on...
@export var cave_gap_deep: float = 210.0       # ...and once ramped (still roomy).

# --- Blackout (event: the lights go out - only coins/hazards glow) ---
@export var blackout_duration: float = 7.0     # How long the lights stay out.
@export var blackout_fade: float = 0.6         # Seconds to fade the dark in / back out.
@export var blackout_intro_time: float = 1.2   # Calm beat (lights dimming) before hazards start.
@export var blackout_asteroid_interval: float = 1.1      # Gap between glowing asteroids early on...
@export var blackout_asteroid_interval_deep: float = 0.75 # ...and once fully ramped (harder).
@export var blackout_coin_interval: float = 1.6 # Gap between glowing coin rows (the reward for braving it).

# --- Bosses (scheduled set-pieces; the boss slot is every Nth event) ---
# Three mini-bosses (cannon / frigate / golem) appear in turn; once all three are
# defeated, the next boss slot is the MAIN boss (the Dreadnought). Beating it grants
# a huge bonus and flips the run into "overdrive" - harder regular events, and the
# boss rotation keeps recurring (buffed). All of this is per-run.
@export var boss_scene: PackedScene            # the generic Boss scene (kind picks which)
@export var boss_min_time: float = 30.0        # No bosses until this many seconds in.
@export var boss_every: int = 3                # Every Nth event is a boss instead of a random one.
@export var main_recur_every: int = 4          # After the main boss, every Nth boss slot is the main again.
@export var boss_bonus_coins: int = 250        # Coin payout for destroying the main boss.
@export var boss_bonus_mult: float = 0.5       # Run-long score-multiplier bump from the main boss.

const MINI_BOSSES: Array[String] = ["cannon", "frigate", "golem"]

# --- Progression (milestone-gated unlocks) ---
# Obstacles/events aren't unlocked by a clock - they're EARNED. A per-run
# `_progress` counter rises as you clear challenges (each event survived = +1,
# each boss beaten = a +boss_progress_bonus surge), and each thing becomes
# available once _progress reaches its level below. So the run opens up the more
# you prove yourself; intensity itself still ramps with distance (_difficulty()).
@export var boss_progress_bonus: int = 2       # Progress gained per boss defeat (a surge of unlocks).
@export var boss_power_step: float = 0.1       # Each mini-boss beaten nudges spawn intensity up by this.

# Progress level each thing needs (absent = 0 = available from the very start, e.g.
# asteroids/beams/coins/rings and the starter events Storm + Coin Rush).
const UNLOCK_LEVEL := {
	"orbs": 1, "missiles": 1,
	"lasers": 2, "frenzy": 2,
	"drones": 3, "highway": 3,
	"barrage": 4,
	"cave": 5,
	"crushers": 6,
	"blackout": 7,
}

enum Phase { BUSY, BREATHER, FRENZY_INTRO, FRENZY, REWARD, STORM, BARRAGE, HIGHWAY, COIN_RUSH, CAVE, BLACKOUT, BOSS }

var _phase: int = Phase.BUSY
var _phase_time_left: float = 0.0
var _time_since_spawn: float = 0.0
var _next_interval: float = 1.0
var _time_since_laser: float = 999.0   # big start value = first laser allowed
var _time_since_coins: float = 0.0
var _time_to_powerup: float = 0.0
var _time_to_ring: float = 0.0
var _time_to_missile: float = 0.0
var _time_to_crusher: float = 0.0
var _crusher_clear: float = 0.0    # >0 while a crusher gate is passing (pauses other hazards)
var _formation_timer: float = 0.0
var _last_formation: String = ""        # the previous pattern, so we don't repeat it
var _reward_block_timer: float = 0.0
var _reward_block_spawned: bool = false
var _storm_spawn_timer: float = 0.0
var _barrage_volley_timer: float = 0.0
var _highway_spawn_timer: float = 0.0
var _highway_phase: float = 0.0
var _highway_spawning: bool = false
var _highway_total: int = 0       # how many rings this highway will have
var _highway_spawned: int = 0
var _highway_resolved: int = 0
var _highway_hit: int = 0
var _highway_perfect: bool = true
var _rush_spawn_timer: float = 0.0
var _rush_phase: float = 0.0
var _rush_spawning: bool = false
var _rush_total: int = 0
var _rush_spawned: int = 0
var _rush_resolved: int = 0
var _rush_collected: int = 0
var _rush_perfect: bool = true
var _cave_wall_timer: float = 0.0
var _cave_phase: float = 0.0
var _blackout_asteroid_timer: float = 0.0
var _blackout_coin_timer: float = 0.0
var _last_event: String = ""            # the last event we ran, so we don't repeat it
var _had_event: bool = false            # the FIRST event is guaranteed; later ones roll the dice
var _events_since_boss: int = 0         # counts events so every Nth one is a boss
var _bosses_defeated: Array[String] = []  # which mini-bosses have been beaten this run
var _last_boss: String = ""             # last boss kind, so we don't repeat back-to-back
var _main_defeated: bool = false        # has the main boss been beaten this run?
var _boss_slots_since_main: int = 0     # counts post-main boss slots (for main recurrence)
var _main_defeat_x: float = 0.0         # camera x when the main boss died (drives overdrive)
var _progress: int = 0                  # milestone counter: rises per event survived / boss beaten
var _boss_power: float = 0.0            # intensity bump accumulated from mini-boss kills
var _run_time: float = 0.0
var _start_x: float = 0.0
var _have_start: bool = false

var camera: Node2D


func _ready() -> void:
	add_to_group("spawner")   # so highway rings can report back to us
	# Lights ON at the start of every run. GameState is an autoload, so this
	# value survives a scene reload - we must clear it or a new run could
	# start mid-blackout if the last run died in the dark.
	GameState.blackout = 0.0
	# Begin with a BUSY wave, then roll the first spawn delay.
	_phase_time_left = randf_range(busy_min, busy_max)
	_roll_next_interval()
	_time_to_powerup = randf_range(powerup_interval_min, powerup_interval_max)
	_time_to_ring = randf_range(ring_interval_min, ring_interval_max)
	_time_to_missile = missile_interval_early
	_time_to_crusher = randf_range(crusher_interval_min, crusher_interval_max)


func _process(delta: float) -> void:
	# Find the camera (our reference point) once it exists.
	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
		return
	if not _have_start:
		_start_x = camera.global_position.x
		_have_start = true

	_run_time += delta
	_time_since_laser += delta

	# Coins spawn on their own steady timer during normal play and breathers.
	# (Frenzy is a clean dodge challenge; the reward phase has its own shower.)
	if _phase == Phase.BUSY or _phase == Phase.BREATHER:
		_time_since_coins += delta
		if coin_scene != null and _time_since_coins >= coin_interval:
			_time_since_coins = 0.0
			_spawn_coin_row()

		# Boost rings show up on their own timer during normal play.
		_time_to_ring -= delta
		if ring_scene != null and _time_to_ring <= 0.0:
			_time_to_ring = randf_range(ring_interval_min, ring_interval_max)
			_spawn_ring()

	# Powerups appear on their own slow, random timer during normal play only.
	# (Frenzy/intro stay clean; the reward phase has its single bonus powerup.)
	if (_phase == Phase.BUSY or _phase == Phase.BREATHER) and powerup_scene != null and not powerup_types.is_empty():
		_time_to_powerup -= delta
		if _time_to_powerup <= 0.0:
			_time_to_powerup = randf_range(powerup_interval_min, powerup_interval_max)
			_spawn_powerup()

	# Count down the current phase; switch to the next one when it ends.
	_phase_time_left -= delta
	if _phase_time_left <= 0.0:
		_advance_phase()

	# Each phase does its own thing.
	if _phase == Phase.BUSY:
		if _crusher_clear > 0.0:
			_crusher_clear -= delta

		# Normal hazards + missiles PAUSE while a crusher gate is on its way
		# through, so the gate gets a clear lane to time (no lasers/missiles
		# parked in front of it - the gate IS the challenge for that beat).
		if _crusher_clear <= 0.0:
			_time_since_spawn += delta
			if _time_since_spawn >= _next_interval:
				_time_since_spawn = 0.0
				_spawn_something()
				_roll_next_interval()

			# Missiles fire from the right on their own timer (once unlocked).
			if missile_scene != null and _unlocked("missiles"):
				_time_to_missile -= delta
				if _time_to_missile <= 0.0:
					# Shorter gaps the deeper you are (and tighter still in a surge), with jitter.
					_time_to_missile = lerp(missile_interval_early, missile_interval_deep, _difficulty()) * lerp(1.0, 0.65, _surge()) * randf_range(0.85, 1.15)
					_spawn_missile_wave()

		# Crusher gates arrive on their own slow timer - but only when unlocked AND
		# the lane is currently clear, so two never stack up.
		if crusher_scene != null and _unlocked("crushers") and _crusher_clear <= 0.0:
			_time_to_crusher -= delta
			if _time_to_crusher <= 0.0:
				_time_to_crusher = randf_range(crusher_interval_min, crusher_interval_max) * lerp(1.0, 0.7, _surge())
				_spawn_crusher()
	elif _phase == Phase.FRENZY:
		# Show how long is left to survive, and emit laser formations.
		_set_status("SURVIVE  %ds" % ceili(_phase_time_left))
		_formation_timer -= delta
		if _formation_timer <= 0.0:
			# Formations arrive faster the deeper you are = harder, same length.
			_formation_timer = lerp(frenzy_formation_interval, frenzy_formation_interval_deep, _difficulty())
			_spawn_laser_formation()
	elif _phase == Phase.REWARD:
		# Wait a short breath, then drop the bonus coin block.
		if not _reward_block_spawned:
			_reward_block_timer -= delta
			if _reward_block_timer <= 0.0:
				_reward_block_spawned = true
				_spawn_reward_block()
	elif _phase == Phase.STORM:
		# Show the survival timer and rain fast meteors in (after a brief beat).
		_set_status("SURVIVE  %ds" % ceili(_phase_time_left))
		_storm_spawn_timer -= delta
		if obstacle_scene != null and _storm_spawn_timer <= 0.0:
			_storm_spawn_timer = lerp(storm_spawn_interval, storm_spawn_interval_deep, _difficulty())
			_spawn_storm_asteroid()
	elif _phase == Phase.BARRAGE:
		# Show the survival timer and fire telegraphed missile volleys.
		_set_status("SURVIVE  %ds" % ceili(_phase_time_left))
		_barrage_volley_timer -= delta
		if missile_scene != null and _barrage_volley_timer <= 0.0:
			_barrage_volley_timer = lerp(barrage_volley_interval, barrage_volley_interval_deep, _difficulty())
			_spawn_missile_volley()
	elif _phase == Phase.HIGHWAY:
		# Show the live ring counter, lay down the chain, then once every ring
		# is resolved, judge whether it was a clean sweep ("BOOST MASTER!").
		_set_status("RINGS  %d / %d" % [_highway_hit, _highway_total])
		if _highway_spawning:
			_highway_spawn_timer -= delta
			if ring_scene != null and _highway_spawn_timer <= 0.0:
				_highway_spawn_timer = highway_ring_gap
				_spawn_highway_ring()
				if _highway_spawned >= _highway_total:
					_highway_spawning = false
		elif _highway_resolved >= _highway_spawned:
			_finish_highway()
	elif _phase == Phase.COIN_RUSH:
		# Show the live coin counter, stream coins along a wavy path, then once
		# every coin is resolved, judge the clean sweep ("COIN MASTER!").
		_set_status("COINS  %d / %d" % [_rush_collected, _rush_total])
		if _rush_spawning:
			_rush_spawn_timer -= delta
			if coin_scene != null and _rush_spawn_timer <= 0.0:
				_rush_spawn_timer = coinrush_gap
				_spawn_rush_coin()
				if _rush_spawned >= _rush_total:
					_rush_spawning = false
		elif _rush_resolved >= _rush_spawned:
			_finish_coin_rush()
	elif _phase == Phase.CAVE:
		# Show the survival timer and stream the winding tunnel slices in.
		_set_status("SURVIVE  %ds" % ceili(_phase_time_left))
		_cave_wall_timer -= delta
		if cave_wall_scene != null and _cave_wall_timer <= 0.0:
			_cave_wall_timer = cave_wall_gap
			_spawn_cave_wall()
	elif _phase == Phase.BLACKOUT:
		# Lights are out: show the timer, and feed in glowing asteroids to dodge
		# plus glowing coin rows to grab by their light alone.
		_set_status("SURVIVE  %ds" % ceili(_phase_time_left))
		_blackout_asteroid_timer -= delta
		if obstacle_scene != null and _blackout_asteroid_timer <= 0.0:
			# Asteroids arrive faster the deeper you are = harder, same length.
			_blackout_asteroid_timer = lerp(blackout_asteroid_interval, blackout_asteroid_interval_deep, _difficulty())
			_spawn_asteroid(_difficulty())
		_blackout_coin_timer -= delta
		if coin_scene != null and _blackout_coin_timer <= 0.0:
			_blackout_coin_timer = blackout_coin_interval
			_spawn_coin_row()


# Move to the next phase. Busy and frenzy both rest into a breather; after a
# breather we usually go busy, but sometimes launch a laser frenzy instead.
func _advance_phase() -> void:
	match _phase:
		Phase.BUSY:
			_enter_breather()
		Phase.FRENZY_INTRO:
			_enter_frenzy()    # warning beat over -> formations begin
		Phase.FRENZY:
			_event_survived()  # "EVENT CLEARED!" banner like the other events
			_enter_reward()    # frenzy ends -> coin-shower victory window
		Phase.REWARD:
			_enter_busy()      # then straight back into the action (fast transition)
		Phase.STORM:
			_event_survived()
			_enter_breather()  # meteors done -> calm, then normal play
		Phase.BARRAGE:
			_event_survived()
			_enter_breather()  # volleys done -> calm, then normal play
		Phase.HIGHWAY:
			_finish_highway()  # safety: judge + exit if the timer ran out
		Phase.COIN_RUSH:
			_finish_coin_rush()  # safety: judge + exit if the timer ran out
		Phase.CAVE:
			_event_survived()
			_enter_breather()  # tunnel done -> calm (leftover walls finish here)
		Phase.BLACKOUT:
			_event_survived()
			_fade_blackout(0.0)  # bring the lights back up...
			_enter_breather()    # ...then a calm beat before normal play
		Phase.BOSS:
			boss_failed(_last_boss)  # safety: the boss's own timer should end it first
		Phase.BREATHER:
			# The first event is guaranteed (so it shows up promptly); after that, a
			# breather leads to an event 'event_chance' of the time (more in overdrive).
			if not _had_event or randf() < lerp(event_chance, 0.85, _surge()):
				# Every Nth event is a scheduled boss (not a random pick).
				if boss_scene != null and _run_time >= boss_min_time and _events_since_boss + 1 >= boss_every:
					_events_since_boss = 0
					_had_event = true
					_enter_boss()
				else:
					# Otherwise a fair, never-repeating random event (or normal
					# play if none are eligible yet).
					var ev := _pick_event()
					if ev != "":
						_had_event = true
						_events_since_boss += 1
					match ev:
						"frenzy": _enter_frenzy_intro()
						"storm": _enter_storm()
						"barrage": _enter_barrage()
						"highway": _enter_highway()
						"coinrush": _enter_coin_rush()
						"cave": _enter_cave()
						"blackout": _enter_blackout()
						_: _enter_busy()
			else:
				_enter_busy()


# Choose which event to run: equal weight for each (highway a bit less),
# only ones that are unlocked + have their scene, and never the last one again.
func _pick_event() -> String:
	var candidates: Array = []   # each entry is [name, weight]
	if vertical_laser_scene != null and horizontal_laser_scene != null \
			and _unlocked("frenzy") and _last_event != "frenzy":
		candidates.append(["frenzy", 1.0])
	if obstacle_scene != null and _unlocked("storm") and _last_event != "storm":
		candidates.append(["storm", 1.0])
	if missile_scene != null and _unlocked("barrage") and _last_event != "barrage":
		candidates.append(["barrage", 1.0])
	if ring_scene != null and _unlocked("highway") and _last_event != "highway":
		candidates.append(["highway", highway_weight])
	if coin_scene != null and _unlocked("coinrush") and _last_event != "coinrush":
		candidates.append(["coinrush", highway_weight])   # calm event, weighted like highway
	if cave_wall_scene != null and _unlocked("cave") and _last_event != "cave":
		candidates.append(["cave", 1.0])
	# Blackout needs both glowing asteroids AND glowing coins to make sense.
	if obstacle_scene != null and coin_scene != null \
			and _unlocked("blackout") and _last_event != "blackout":
		candidates.append(["blackout", 1.0])

	if candidates.is_empty():
		return ""

	# Weighted random pick.
	var total := 0.0
	for c in candidates:
		total += c[1]
	var roll := randf() * total
	for c in candidates:
		roll -= c[1]
		if roll <= 0.0:
			return c[0]
	return candidates[-1][0]


func _enter_breather() -> void:
	_phase = Phase.BREATHER
	_phase_time_left = randf_range(breather_min, breather_max)
	_set_status("")   # make sure any event status line is hidden


# A burst of fast meteors from the right. Telegraphed, then a flurry to dodge.
func _enter_storm() -> void:
	_phase = Phase.STORM
	_last_event = "storm"
	_phase_time_left = storm_duration
	_storm_spawn_timer = storm_intro_time   # brief "incoming!" beat first
	_show_banner(">>  ASTEROID STORM  <<", Color(1.0, 0.7, 0.3), 2.0)


func _spawn_storm_asteroid() -> void:
	var a := obstacle_scene.instantiate()
	a.position = Vector2(camera.global_position.x + 720.0, randf_range(90.0, 560.0))
	a.extra_speed = storm_asteroid_speed   # rush left fast
	if randf() < 0.3:
		a.drift_amplitude = randf_range(30.0, 70.0)
		a.drift_speed = randf_range(1.5, 3.0)
	add_child(a)


# A telegraphed volley of missiles at several heights, leaving gaps to thread.
# More missiles per volley the deeper you are.
func _enter_barrage() -> void:
	_phase = Phase.BARRAGE
	_last_event = "barrage"
	_phase_time_left = barrage_duration
	_barrage_volley_timer = barrage_intro_time   # brief "incoming!" beat first
	_show_banner(">>  MISSILE BARRAGE  <<", Color(1.0, 0.55, 0.2), 2.0)


func _spawn_missile_volley() -> void:
	if missile_scene == null:
		return
	var rows := [110.0, 220.0, 330.0, 440.0, 550.0]
	rows.shuffle()
	# Fire at this many of the rows; the rest stay open as safe gaps.
	var count := roundi(lerp(2.0, 4.0, _difficulty()))
	for i in count:
		_spawn_missile_at(rows[i])


# A speed-flow event: a chain of boost rings on a gentle wavy path. Chasing
# them keeps the boost topped up, so the world (and your score) zooms.
func _enter_highway() -> void:
	_phase = Phase.HIGHWAY
	_last_event = "highway"
	_highway_phase = 0.0
	_highway_spawn_timer = 0.3   # first ring arrives quickly
	_highway_spawning = true
	# A fixed number of rings, so the "x / y" counter has a known total.
	_highway_total = maxi(1, roundi(highway_duration / highway_ring_gap))
	_highway_spawned = 0
	_highway_resolved = 0
	_highway_hit = 0
	_highway_perfect = true
	_phase_time_left = highway_duration + 10.0   # generous safety cap; we exit earlier
	_show_banner(">>  BOOST HIGHWAY  <<", Color(0.4, 1.0, 0.8), 2.0)


func _spawn_highway_ring() -> void:
	# Walk a sine path so consecutive rings form a smooth, flyable curve.
	_highway_phase += highway_wave_speed
	var y := highway_center + highway_amplitude * sin(_highway_phase)
	var r := ring_scene.instantiate()
	r.position = Vector2(camera.global_position.x + spawn_ahead, y)
	r.from_highway = true
	r.boost_time = highway_boost_time
	r.boost_multiplier = highway_boost_multiplier
	add_child(r)
	_highway_spawned += 1


# Judge the highway once every ring is resolved: a clean sweep earns the
# "BOOST MASTER!" coin reward; otherwise just return to normal play.
func _finish_highway() -> void:
	_event_survived()   # progression tick + celebration burst
	if _highway_spawned > 0 and _highway_perfect:
		_show_banner("BOOST MASTER!", Color(0.4, 1.0, 0.8), 2.5)
		_enter_reward()
	else:
		_enter_breather()


# Called by each highway ring when it is collected (hit=true) or flown past
# (hit=false).
func highway_ring_resolved(hit: bool) -> void:
	if _phase != Phase.HIGHWAY:
		return
	_highway_resolved += 1
	if hit:
		_highway_hit += 1
	else:
		_highway_perfect = false


# A calm reward event: a stream of coins along a wavy path. Grab them ALL for
# the "COIN MASTER!" bonus.
func _enter_coin_rush() -> void:
	_phase = Phase.COIN_RUSH
	_last_event = "coinrush"
	_rush_phase = 0.0
	_rush_spawn_timer = 0.3   # first coin arrives quickly
	_rush_spawning = true
	_rush_total = maxi(1, roundi(coinrush_duration / coinrush_gap))
	_rush_spawned = 0
	_rush_resolved = 0
	_rush_collected = 0
	_rush_perfect = true
	_phase_time_left = coinrush_duration + 10.0   # generous safety cap; we exit earlier
	# Speed the WHOLE world up for the duration so the coin stream rushes by faster
	# (reuses the camera's boost gear). Makes the perfect sweep a real challenge.
	if camera != null and camera.has_method("add_boost"):
		camera.add_boost(coinrush_duration + 6.0, coinrush_speed_mult)
	_show_banner(">>  COIN RUSH  <<", Color(1.0, 0.85, 0.3), 2.0)


func _spawn_rush_coin() -> void:
	# Walk a sine path so consecutive coins form a smooth, flyable stream.
	_rush_phase += coinrush_wave_speed
	var y := coinrush_center + coinrush_amplitude * sin(_rush_phase)
	var c := coin_scene.instantiate()
	c.position = Vector2(camera.global_position.x + spawn_ahead, y)
	c.from_rush = true
	add_child(c)
	_rush_spawned += 1


# Judge the coin rush once every coin is resolved: a clean sweep earns the
# "COIN MASTER!" reward; otherwise just return to normal play.
func _finish_coin_rush() -> void:
	_event_survived()   # progression tick + celebration burst
	if _rush_spawned > 0 and _rush_perfect:
		_show_banner("COIN MASTER!", Color(1.0, 0.85, 0.3), 2.5)
		_enter_reward()
	else:
		_enter_breather()


# Called by each rush coin when it is collected (hit=true) or flown past (false).
func coin_rush_resolved(hit: bool) -> void:
	if _phase != Phase.COIN_RUSH:
		return
	_rush_resolved += 1
	if hit:
		_rush_collected += 1
	else:
		_rush_perfect = false


# An environmental event: a winding rock tunnel to thread, full-height walls
# with a snaking gap. Survive to the end.
func _enter_cave() -> void:
	_phase = Phase.CAVE
	_last_event = "cave"
	_phase_time_left = cave_duration
	_cave_wall_timer = cave_intro_time   # walls start after the warning beat
	_cave_phase = 0.0
	_show_banner(">>  NARROW CAVE  <<", Color(0.78, 0.68, 0.58), 2.0)


func _spawn_cave_wall() -> void:
	# Snake the gap up and down on a sine path to make a flyable tunnel.
	_cave_phase += cave_wave_speed
	var c := cave_wall_scene.instantiate()
	c.position = Vector2(camera.global_position.x + 760.0, 0.0)
	c.gap_center = cave_center + cave_amplitude * sin(_cave_phase)
	c.gap_height = lerp(cave_gap_early, cave_gap_deep, _difficulty())
	add_child(c)


# The lights-out event: the world fades to near-black and the only things you
# can see are the gold shine of the coins and the red glow of the asteroids
# (and a faint hint of your own Moki). Survive to the end.
func _enter_blackout() -> void:
	_phase = Phase.BLACKOUT
	_last_event = "blackout"
	_phase_time_left = blackout_duration
	# A brief beat with the lights dimming before any hazards arrive.
	_blackout_asteroid_timer = blackout_intro_time
	_blackout_coin_timer = blackout_intro_time + 0.4
	_fade_blackout(1.0)   # smoothly kill the lights
	_show_banner(">>  BLACKOUT  <<", Color(0.55, 0.55, 0.95), 2.0)


# Smoothly slide the world darkness toward 'target' (0 = lights on, 1 = full
# dark) over blackout_fade seconds. Every coin/asteroid/player glow and the
# CanvasModulate all read GameState.blackout, so this one tween drives it all.
func _fade_blackout(target: float) -> void:
	var tw := create_tween()
	tw.tween_property(GameState, "blackout", target, blackout_fade)


# A boss: a scheduled set-piece. We pick which kind to send, spawn it, hand it
# what it needs, and wait for boss_defeated()/boss_failed() back. _phase_time_left
# is only a generous safety net (the boss ends the fight itself).
func _enter_boss() -> void:
	_phase = Phase.BOSS
	_last_event = "boss"
	_phase_time_left = 70.0
	_set_status("")
	var kind := _pick_boss_kind()
	_last_boss = kind
	if boss_scene != null:
		var boss := boss_scene.instantiate()
		boss.kind = kind
		boss.vertical_laser_scene = vertical_laser_scene
		boss.horizontal_laser_scene = horizontal_laser_scene
		boss.missile_scene = missile_scene
		boss.obstacle_scene = obstacle_scene
		boss.difficulty = _difficulty()
		boss.overdrive = _surge()   # mini-boss power + post-main overdrive (buffs later bosses)
		add_child(boss)
	_show_banner(_boss_label(kind), Color(1.0, 0.5, 0.4), 1.7)


# Which boss to send next. Pre-main: the next undefeated mini-boss, or the main
# boss once all three are down. Post-main: recurring mini-bosses, with the main
# boss returning every 'main_recur_every' boss slots.
func _pick_boss_kind() -> String:
	if not _main_defeated:
		var undefeated := MINI_BOSSES.filter(func(k): return not _bosses_defeated.has(k))
		if undefeated.is_empty():
			return "main"   # all three mini-bosses beaten -> the climax
		return _pick_avoiding_last(undefeated)
	_boss_slots_since_main += 1
	if _boss_slots_since_main % main_recur_every == 0:
		return "main"
	return _pick_avoiding_last(MINI_BOSSES)


# Random pick from 'options', avoiding the last boss when there's a choice.
func _pick_avoiding_last(options: Array) -> String:
	var pool := options.duplicate()
	if pool.size() > 1 and pool.has(_last_boss):
		pool.erase(_last_boss)
	return str(pool[randi() % pool.size()])


func _boss_label(kind: String) -> String:
	match kind:
		"frigate": return ">>  MINI-BOSS: MISSILE FRIGATE  <<"
		"golem": return ">>  MINI-BOSS: METEOR GOLEM  <<"
		"main": return ">>>  BOSS: DREADNOUGHT  <<<"
		_: return ">>  MINI-BOSS: LASER CANNON  <<"


# Called by a boss when its HP hits zero. The main boss also grants the huge
# bonus and flips the run into overdrive; mini-bosses are marked defeated.
func boss_defeated(kind: String) -> void:
	_hide_boss_bar()
	if kind == "main":
		_main_defeated = true
		_main_defeat_x = camera.global_position.x   # overdrive ramps from here
		_grant_main_bonus()
		_show_banner("DREADNOUGHT DESTROYED!  +%d COINS" % boss_bonus_coins, Color(1.0, 0.85, 0.4), 3.0)
	else:
		if not _bosses_defeated.has(kind):
			_bosses_defeated.append(kind)
		_boss_power += boss_power_step   # mini-boss kill nudges intensity up
		_show_banner("%s DESTROYED!" % _boss_short(kind), Color(1.0, 0.85, 0.4), 2.5)
	# Beating a boss is a big milestone: a progress SURGE (unlocks several things
	# at once - the new hazards just start showing up) and the big celebration blast.
	_add_progress(boss_progress_bonus)
	_celebrate(true)
	_enter_reward()


# Called by a boss if it survives its time cap (or via the safety above): it
# retreats, no reward. A failed mini-boss is NOT marked defeated, so it recurs
# until you beat it (you must clear all three to unlock the main boss).
func boss_failed(_kind: String) -> void:
	_hide_boss_bar()
	_enter_breather()


func _boss_short(kind: String) -> String:
	match kind:
		"frigate": return "FRIGATE"
		"golem": return "GOLEM"
		_: return "CANNON"


# The main-boss reward: a big coin payout (banks + jumps the multiplier), a
# run-long score-multiplier bump, and a free shield - on top of the usual block.
func _grant_main_bonus() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		if hud.has_method("add_coin"):
			hud.add_coin(boss_bonus_coins)
		if hud.has_method("add_bonus_multiplier"):
			hud.add_bonus_multiplier(boss_bonus_mult)
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("gain_powerup"):
		player.gain_powerup("shield")


# 0 until the main boss is beaten, then ramps 0 -> 1 over the next ramp_distance
# of travel. Drives the post-main "overdrive": harder regular play + buffed bosses.
func _overdrive() -> float:
	if not _main_defeated or camera == null:
		return 0.0
	return clamp((camera.global_position.x - _main_defeat_x) / ramp_distance, 0.0, 1.0)


# The combined intensity surge folded into spawn aggression: mini-boss kills
# (_boss_power) plus the post-main overdrive. 0..1.
func _surge() -> float:
	return clamp(_boss_power + _overdrive(), 0.0, 1.0)


# Is this obstacle/event unlocked yet? (Anything not in the table is level 0 =
# available from the start.)
func _unlocked(key: String) -> bool:
	return _progress >= int(UNLOCK_LEVEL.get(key, 0))


# Advance the milestone counter (unlocks happen silently - the newly available
# obstacles/events simply start showing up).
func _add_progress(amount: int) -> void:
	_progress += amount


# Called when the player clears any event: progression tick + a small "nice!" burst
# (speed pop + shake) + a "cleared" banner. Pass "" for the banner when the caller
# already shows its own (e.g. the frenzy's "COMPLETE!").
func _event_survived(banner: String = "EVENT CLEARED!") -> void:
	_add_progress(1)
	_celebrate(false)
	if banner != "":
		_show_banner(banner, Color(0.6, 1.0, 0.7, 1.0), 1.6)


# A celebration burst - the payoff "brain go brr" moment. A speed surge + a screen
# flash + a screen shake, scaled up BIG for a boss kill (the "YOU DID IT" blast)
# and lighter for clearing an event.
func _celebrate(big: bool) -> void:
	if camera != null:
		if camera.has_method("add_boost"):
			camera.add_boost(3.0 if big else 1.2, 2.3 if big else 1.4)
		if camera.has_method("shake"):
			camera.shake(15.0 if big else 5.0)
	# A gold screen-flash ONLY for boss kills (the event flash was too jarring).
	if big:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("flash"):
			hud.flash(Color(1.0, 0.92, 0.5, 0.5))
	_burst_fireworks(big)


const FW_COLORS: Array[Color] = [Color(1, 0.35, 0.35), Color(0.4, 0.65, 1.0), Color(1, 0.85, 0.3), Color(0.5, 1.0, 0.6), Color(1, 0.55, 1.0)]

# Pop celebration fireworks on the HUD, placed SYMMETRICALLY (screen is 1280 wide,
# centre x = 640): an event fires one from each side; a boss fires both sides PLUS
# the middle. Mirrored pairs share a colour so it reads as symmetric.
func _burst_fireworks(big: bool) -> void:
	if fireworks_scene == null:
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	var cx := 640.0
	if big:
		var c_mid := FW_COLORS[randi() % FW_COLORS.size()]
		var c_in := FW_COLORS[randi() % FW_COLORS.size()]
		var c_out := FW_COLORS[randi() % FW_COLORS.size()]
		_pop_firework(hud, Vector2(cx, 150.0), c_mid, true)            # middle
		_pop_firework(hud, Vector2(cx - 290.0, 200.0), c_in, true)     # inner pair
		_pop_firework(hud, Vector2(cx + 290.0, 200.0), c_in, true)
		_pop_firework(hud, Vector2(cx - 540.0, 250.0), c_out, true)    # outer pair
		_pop_firework(hud, Vector2(cx + 540.0, 250.0), c_out, true)
	else:
		var c := FW_COLORS[randi() % FW_COLORS.size()]
		_pop_firework(hud, Vector2(cx - 300.0, 190.0), c, false)       # left
		_pop_firework(hud, Vector2(cx + 300.0, 190.0), c, false)       # right


func _pop_firework(hud: Node, pos: Vector2, color: Color, big: bool) -> void:
	var fw := fireworks_scene.instantiate()
	fw.fw_big = big
	fw.fw_color = color
	fw.position = pos
	hud.add_child(fw)


func _hide_boss_bar() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("hide_boss_bar"):
		hud.hide_boss_bar()


func _enter_busy() -> void:
	_phase = Phase.BUSY
	_phase_time_left = randf_range(busy_min, busy_max)
	_time_since_spawn = _next_interval   # spawn promptly when action resumes


# A short calm "incoming!" beat: the warning banner shows, but no lasers yet,
# so you get a moment to brace before the formations start.
func _enter_frenzy_intro() -> void:
	_phase = Phase.FRENZY_INTRO
	_last_event = "frenzy"
	_phase_time_left = frenzy_intro_time
	_show_banner(">>  LASER FRENZY  <<", Color(1.0, 0.4, 0.3), frenzy_intro_time + 0.5)


func _enter_frenzy() -> void:
	_phase = Phase.FRENZY
	_phase_time_left = frenzy_duration   # consistent length; difficulty changes the patterns
	_formation_timer = 0.4   # first formation arrives just after the intro


# A short, calm victory window right after a frenzy: grab a Magnet/Doubler,
# THEN plough into a big block of coins with it active.
func _enter_reward() -> void:
	# Shared coin-block reward (used by both the frenzy and a perfect highway).
	# The caller shows its own banner first.
	_phase = Phase.REWARD
	_phase_time_left = reward_time
	_reward_block_timer = reward_breath   # short pause before the bonus drops
	_reward_block_spawned = false
	_set_status("")   # hide the status line


# Ask the HUD to flash a banner message in the given colour for 'time' seconds.
func _show_banner(text: String, color: Color, time: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.show_banner(text, color, time)


# Update the HUD survival countdown (pass a negative number to hide it).
func _set_status(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.set_status(text)


# 0.0 at the start, climbing to 1.0 after the world scrolls ramp_distance.
func _difficulty() -> float:
	if camera == null:
		return 0.0
	return clamp((camera.global_position.x - _start_x) / ramp_distance, 0.0, 1.0)


# Base seconds between spawns right now (shorter as difficulty rises). After the
# main boss, overdrive squeezes the gap further so regular play keeps escalating.
func _current_interval() -> float:
	return lerp(start_interval, min_interval, _difficulty()) * lerp(1.0, 0.6, _surge())


# Pick the delay until the NEXT spawn, with a bit of randomness so the
# rhythm feels organic instead of mechanical.
func _roll_next_interval() -> void:
	var jitter := randf_range(1.0 - interval_jitter, 1.0 + interval_jitter)
	_next_interval = _current_interval() * jitter


func _spawn_something() -> void:
	var t := _difficulty()

	# Lasers get more common the further you go (up to ~45% of spawns), once
	# unlocked + enough time since the last laser. Lasers are transient +
	# telegraphed, so they ignore the hazard cap below.
	var laser_chance := 0.45 * t
	if _unlocked("lasers") and randf() < laser_chance and _time_since_laser >= laser_cooldown:
		_spawn_laser()
		_time_since_laser = 0.0
		return

	# Persistent hazards (asteroids/beams) respect an on-screen cap that grows
	# with difficulty - so density rises smoothly but never clutters. A surge
	# (mini-boss kills + post-main overdrive) lifts the cap a few notches.
	var cap := roundi(lerp(float(max_hazards_min), float(max_hazards_max), t)) + int(round(_surge() * 3.0))
	if get_tree().get_nodes_in_group("asteroid").size() >= cap:
		return   # plenty on screen already - let it breathe this beat

	# Pick which persistent hazard to drop. Beams first, then the unlockable
	# orb / drone, otherwise a plain asteroid. (All count toward the cap above.)
	if beam_obstacle_scene != null and randf() < beam_chance:
		_spawn_beam()
	elif orb_scene != null and _unlocked("orbs") and randf() < orb_chance:
		_spawn_orb()
	elif drone_scene != null and _unlocked("drones") and randf() < drone_chance:
		_spawn_drone()
	else:
		_spawn_asteroid(t)


func _spawn_asteroid(difficulty: float) -> void:
	if obstacle_scene == null:
		return
	var asteroid := obstacle_scene.instantiate()

	# Pick a height, re-rolling a few times to avoid landing on any pickup
	# (coin / powerup / ring) we already spawned.
	var spawn_x := camera.global_position.x + spawn_ahead
	var y := randf_range(min_y, max_y)
	var tries := 0
	while _overlaps(Vector2(spawn_x, y), RADIUS_ASTEROID, ["coin", "powerup", "ring"]) and tries < 8:
		y = randf_range(min_y, max_y)
		tries += 1
	asteroid.position = Vector2(spawn_x, y)

	# On tougher runs, some asteroids start drifting up and down.
	if randf() < 0.35 * difficulty:
		asteroid.drift_amplitude = randf_range(40.0, 90.0)
		asteroid.drift_speed = randf_range(1.5, 3.0)

	add_child(asteroid)


# A bouncing orb at a clear height, with a difficulty-scaled bounce speed and a
# random starting direction.
func _spawn_orb() -> void:
	if orb_scene == null:
		return
	var orb := orb_scene.instantiate()
	var spawn_x := camera.global_position.x + spawn_ahead
	var y := randf_range(140.0, 520.0)
	var tries := 0
	while _overlaps(Vector2(spawn_x, y), 26.0, ["coin", "powerup", "ring"]) and tries < 8:
		y = randf_range(140.0, 520.0)
		tries += 1
	orb.position = Vector2(spawn_x, y)
	orb.vy = randf_range(290.0, 380.0) * (1.0 + 0.4 * _difficulty())
	if randf() < 0.5:
		orb.vy = -orb.vy   # start heading up instead of down
	orb.vx = -randf_range(110.0, 170.0)   # leftward drift -> diagonal zig-zag
	add_child(orb)


# A homing drone; it tracks the Moki's height, so it just needs a clear spawn.
func _spawn_drone() -> void:
	if drone_scene == null:
		return
	var drone := drone_scene.instantiate()
	var spawn_x := camera.global_position.x + spawn_ahead
	var y := randf_range(140.0, 520.0)
	var tries := 0
	while _overlaps(Vector2(spawn_x, y), 26.0, ["coin", "powerup", "ring"]) and tries < 8:
		y = randf_range(140.0, 520.0)
		tries += 1
	drone.position = Vector2(spawn_x, y)
	drone.home_speed = lerp(160.0, 260.0, _difficulty())   # tracks a bit faster deep in a run
	add_child(drone)


# A slamming crusher gate, with its safe gap at a random height.
func _spawn_crusher() -> void:
	if crusher_scene == null:
		return
	var c := crusher_scene.instantiate()
	c.position = Vector2(camera.global_position.x + spawn_ahead, 0.0)
	c.gap_center = randf_range(250.0, 410.0)
	add_child(c)
	_crusher_clear = crusher_clear_window   # give the gate a clear lane to time


# A floating capped laser bar, horizontal or vertical, at a clear height.
func _spawn_beam() -> void:
	var b := beam_obstacle_scene.instantiate()
	b.horizontal = randf() < 0.5
	b.beam_length = randf_range(170.0, 240.0)
	# Use the beam's own (large) radius so its WHOLE length stays clear of
	# pickups - not just its centre point.
	var my_r: float = b.clear_radius()
	var spawn_x := camera.global_position.x + spawn_ahead
	var y := randf_range(190.0, 470.0)
	var tries := 0
	while _overlaps(Vector2(spawn_x, y), my_r, ["coin", "powerup", "ring"]) and tries < 8:
		y = randf_range(190.0, 470.0)
		tries += 1
	b.position = Vector2(spawn_x, y)
	add_child(b)


# A missile that warns at the right edge, then strikes left across the screen.
func _spawn_missile_at(y: float) -> void:
	var m := missile_scene.instantiate()
	m.position = Vector2(camera.global_position.x + 600.0, y)
	add_child(m)


# Normal-play missiles: one, or (more likely the deeper you are) two at once
# at different heights.
func _spawn_missile_wave() -> void:
	if missile_scene == null:
		return
	var rows := [140.0, 280.0, 420.0, 540.0]
	rows.shuffle()
	var count := 1
	if randf() < _difficulty() * missile_double_chance:
		count = 2
	for i in count:
		_spawn_missile_at(rows[i])


# A boost ring, placed clear of hazards AND other pickups (coins/powerups)
# so it never overlaps anything.
func _spawn_ring() -> void:
	var r := ring_scene.instantiate()
	var spawn_x := camera.global_position.x + spawn_ahead
	var y := randf_range(150.0, 510.0)
	var tries := 0
	while _overlaps(Vector2(spawn_x, y), RADIUS_RING, ["asteroid", "coin", "powerup"]) and tries < 8:
		y = randf_range(150.0, 510.0)
		tries += 1
	r.position = Vector2(spawn_x, y)
	add_child(r)


func _spawn_laser() -> void:
	# Flip a coin for vertical vs horizontal, falling back to whichever
	# scene is actually assigned.
	var want_vertical := randf() < 0.5
	if want_vertical and vertical_laser_scene != null:
		_spawn_vertical_laser()
	elif horizontal_laser_scene != null:
		_spawn_horizontal_laser()
	elif vertical_laser_scene != null:
		_spawn_vertical_laser()
	else:
		_spawn_asteroid(_difficulty())


func _spawn_vertical_laser() -> void:
	# Screen-locked: it picks a spot on the screen (offset from centre) and
	# stays there while it charges and fires. Dodge by being left or right.
	var laser := vertical_laser_scene.instantiate()
	laser.offset_x = randf_range(-vertical_spread, vertical_spread)
	add_child(laser)


func _spawn_horizontal_laser() -> void:
	# Screen-locked: full width at a random height. Dodge by being above/below.
	var laser := horizontal_laser_scene.instantiate()
	laser.beam_y = randf_range(120.0, 520.0)
	add_child(laser)


# A laser frenzy formation: a wall of lasers that leaves ONE safe lane/row.
# All lasers in a formation spawn together, so they charge and fire in sync -
# the player picks the open lane and holds it.
func _spawn_laser_formation() -> void:
	var t := _difficulty()
	var have_both := vertical_laser_scene != null and horizontal_laser_scene != null

	# Which patterns are available right now. Combined V+H joins the mix once
	# you are deep enough into the run.
	var types: Array[String] = ["vertical", "horizontal"]
	if have_both and t >= frenzy_combo_difficulty:
		types.append("combined")

	# Never repeat the previous pattern, so the frenzy keeps changing it up.
	if types.size() > 1 and types.has(_last_formation):
		types.erase(_last_formation)

	var choice: String = types.pick_random()
	_last_formation = choice
	match choice:
		"vertical":
			_spawn_vertical_formation()
		"horizontal":
			_spawn_horizontal_formation()
		"combined":
			_spawn_combined_formation()


# Combined pattern: vertical bars AND horizontal bars at once, leaving ONE
# safe pocket - the crossing of the open column and the open row. You have to
# get to a specific spot, not just a lane. This is the hard, late-run pattern.
func _spawn_combined_formation() -> void:
	if vertical_laser_scene == null or horizontal_laser_scene == null:
		return
	var cols := [-440.0, -160.0, 160.0, 440.0]
	var rows := [150.0, 330.0, 510.0]
	var safe_col := randi() % cols.size()
	var safe_row := randi() % rows.size()
	var combo_charge := frenzy_charge + 0.4   # a touch more time to reach the pocket

	for i in cols.size():
		if i == safe_col:
			continue
		var v := vertical_laser_scene.instantiate()
		v.offset_x = cols[i]
		v.charge_time = combo_charge
		v.fire_time = frenzy_fire
		add_child(v)

	for j in rows.size():
		if j == safe_row:
			continue
		var h := horizontal_laser_scene.instantiate()
		h.beam_y = rows[j]
		h.charge_time = combo_charge
		h.fire_time = frenzy_fire
		add_child(h)


# Vertical bars across the screen with one safe COLUMN to slip into.
func _spawn_vertical_formation() -> void:
	if vertical_laser_scene == null:
		return
	var lanes := [-480.0, -240.0, 0.0, 240.0, 480.0]
	var safe := randi() % lanes.size()
	for i in lanes.size():
		if i == safe:
			continue   # leave this column open
		var laser := vertical_laser_scene.instantiate()
		laser.offset_x = lanes[i]
		laser.charge_time = frenzy_charge
		laser.fire_time = frenzy_fire
		add_child(laser)


# Horizontal bars stacked up the screen with one safe ROW to fly to. Pure
# vertical dodging is tight, so we keep this gentle: fewer, thinner bars and
# a bit more warning, leaving a generous open row.
func _spawn_horizontal_formation() -> void:
	if horizontal_laser_scene == null:
		return
	var rows := [150.0, 330.0, 510.0]
	var safe := randi() % rows.size()
	for i in rows.size():
		if i == safe:
			continue   # leave this row open
		var laser := horizontal_laser_scene.instantiate()
		laser.beam_y = rows[i]
		laser.beam_thickness = 50.0          # thinner than normal -> bigger gaps
		laser.charge_time = frenzy_charge + 0.2  # a touch more time to reach the row
		laser.fire_time = frenzy_fire
		add_child(laser)


# The frenzy reward: a Magnet or Doubler out front, then a 10x10 coin block
# right behind it - so you scoop the powerup first and shred the block with it.
@export var reward_coin_cols: int = 10
@export var reward_coin_rows: int = 10
@export var reward_coin_spacing: float = 50.0

func _spawn_reward_block() -> void:
	var front_x := camera.global_position.x + 700.0

	# The powerup, centred and IN FRONT (smaller x = reached first). Always a
	# Magnet, so you reliably vacuum up the coin block right behind it.
	if powerup_scene != null:
		var p := powerup_scene.instantiate()
		p.type = "magnet"
		p.position = Vector2(front_x, 330.0)
		add_child(p)

	# The coin block, just behind the powerup.
	if coin_scene != null:
		var grid_x := front_x + 200.0
		var top_y := 90.0
		for r in reward_coin_rows:
			for c in reward_coin_cols:
				var coin := coin_scene.instantiate()
				coin.position = Vector2(grid_x + c * reward_coin_spacing, top_y + r * reward_coin_spacing)
				add_child(coin)


func _spawn_coin_row() -> void:
	# A horizontal line of coins at one height, off the right edge, so the
	# Moki can swoop through and collect the whole chain.
	var count := randi_range(coin_row_min, coin_row_max)
	var y := randf_range(coin_min_y, coin_max_y)
	var base_x := camera.global_position.x + spawn_ahead
	for i in count:
		var pos := Vector2(base_x + i * coin_spacing, y)
		# Skip any coin that would sit on a hazard or another pickup - leaves a
		# small gap in the row rather than an unfair, hidden coin.
		if _overlaps(pos, RADIUS_COIN, ["asteroid", "powerup", "ring"]):
			continue
		var coin := coin_scene.instantiate()
		coin.position = pos
		add_child(coin)


func _spawn_powerup() -> void:
	# Find a spot clear of hazards and other pickups; only spawn if we found
	# one, so a powerup is never buried.
	var x := camera.global_position.x + spawn_ahead
	var y := randf_range(coin_min_y, coin_max_y)
	var tries := 0
	while _overlaps(Vector2(x, y), RADIUS_POWERUP, ["asteroid", "coin", "ring"]) and tries < 10:
		y = randf_range(coin_min_y, coin_max_y)
		tries += 1
	if _overlaps(Vector2(x, y), RADIUS_POWERUP, ["asteroid", "coin", "ring"]):
		return   # no clear spot this time - skip rather than overlap

	var p := powerup_scene.instantiate()
	p.type = powerup_types.pick_random()   # choose a random powerup from the list
	p.position = Vector2(x, y)
	add_child(p)


# Approximate sizes (radii) of the things we place. Two objects are "too
# close" if the gap between their centres is less than the SUM of their radii
# (plus a small buffer). Long things (beams) report a big radius via
# clear_radius(), so their whole length stays clear - not just the centre.
const RADIUS_COIN := 20.0
const RADIUS_RING := 56.0
const RADIUS_POWERUP := 28.0
const RADIUS_ASTEROID := 34.0
const RADIUS_DEFAULT := 22.0   # for group members without clear_radius (coins/powerups)
const CLEAR_BUFFER := 14.0


# True if placing something of radius 'my_radius' at 'pos' would overlap any
# node in any of the given groups.
func _overlaps(pos: Vector2, my_radius: float, groups: Array) -> bool:
	for g in groups:
		for node in get_tree().get_nodes_in_group(g):
			var n := node as Node2D
			if n == null:
				continue
			var node_r := RADIUS_DEFAULT
			if n.has_method("clear_radius"):
				node_r = n.clear_radius()
			if pos.distance_to(n.global_position) < my_radius + node_r + CLEAR_BUFFER:
				return true
	return false
