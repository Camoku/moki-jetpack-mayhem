# ==========================================================
#  boss.gd - every boss in the game (one scene, `kind` picks the fight)
# ==========================================================
#  Bosses are scheduled set-pieces (the boss slot is every 3rd event). The
#  Moki has no weapon, so every boss works the same way: it ATTACKS with a
#  telegraphed hazard you must dodge, then OVERHEATS - exposing a glowing core
#  you fly into to damage it. Knock its HP to zero to destroy it; if you can't
#  in time, it retreats.
#
#  State machine (shared by all kinds):
#     INTRO -> (ATTACK <-> OVERHEAT) -> DYING / RETREAT
#
#  Only `kind` changes what the ATTACK does and how it looks/lasts - the same
#  "one scene, a `kind`/`type` switch picks the behaviour" idea the Powerup uses:
#     cannon  - sweeping / lane laser beams      (LASER CANNON)
#     frigate - telegraphed missile volleys       (MISSILE FRIGATE)
#     golem   - waves of fast asteroids            (METEOR GOLEM)
#     main    - cycles through ALL three, tougher  (DREADNOUGHT)
#
#  The spawner creates us, hands us the hazard scenes + difficulty + overdrive,
#  and waits for us to call boss_defeated(kind) / boss_failed(kind) back.
# ==========================================================

extends Node2D

enum State { INTRO, ATTACK, OVERHEAT, DYING, RETREAT }

# Which boss this is (set by the spawner before we are added to the tree).
var kind: String = "cannon"

@export var intro_time: float = 2.8    # "Boss incoming" beat: announcement, then it drops in.
@export var arrive_delay: float = 1.8  # Stay off-screen this long (while the banner shows), THEN slide in.
@export var attack_time: float = 2.5   # Length of each attack window.
@export var frigate_volley_interval: float = 1.1  # Frigate fires a fresh missile volley this often DURING its attack.
@export var frigate_volley_cutoff: float = 1.5    # ...but stops this many seconds before the attack ends, so the last missiles clear before the core opens.
@export var overheat_time: float = 2.2 # Length of each vulnerable (core exposed) window.
@export var hit_cooldown: float = 0.35 # Min gap between core hits (stops one pass scoring many).
@export var offset_x: float = 0.0      # Screen-x offset from the camera centre (top-centre by default).
@export var top_y: float = 74.0        # Resting height of the turret top (kept clear of the HUD boss bar).
@export var sweep_speed: float = 240.0 # Base px/sec for sweeping beams (< player move_speed = escapable).

# These are set per-kind in _configure_for_kind(); the values here are the
# mini-boss baseline.
var max_hp: int = 5
var max_time: float = 34.0
var boss_name: String = "LASER CANNON"

# Handed to us by the spawner the instant we are created.
var vertical_laser_scene: PackedScene
var horizontal_laser_scene: PackedScene
var missile_scene: PackedScene
var obstacle_scene: PackedScene
var difficulty: float = 0.0
var overdrive: float = 0.0   # >0 only for bosses that recur after the main boss (buffs them)

var state: int = State.INTRO
var hp: int = 0
var _t: float = 0.0          # time spent in the current state
var _life: float = 0.0       # total time alive (for the max_time cap)
var _hit_cd: float = 0.0     # cooldown left before the core can be hit again
var _pulse: float = 0.0      # drives the exposed-core glow pulse
var _last_pattern: String = ""
var _last_formation: String = ""  # previous frenzy formation, so the main boss doesn't repeat it
var _main_attack_index: int = 0   # round-robins the main boss through its three attacks
var _core_vulnerable: bool = false
var _flash_t: float = 0.0    # brief white flash on the cannon body when the core is hit
var _shake_t: float = 0.0    # transient body-shake timer (fire / hit / death)
var _shake_mag: float = 0.0  # current shake magnitude in px
var _fire_flash: float = 0.0 # brief flare of the boss's lights the moment it fires
var _die_burst_cd: float = 0.0  # spacing between explosion bursts during the death sequence
var _volley_cd: float = 0.0     # frigate: time until the next extra missile volley this attack
var _smoke_cd: float = 0.0      # spacing between damage-spark pops once the boss is wounded
var camera: Node2D

@onready var body_sprite: Sprite2D = $Body
@onready var body_glow: Sprite2D = $Body/Glow   # additive overlay; its alpha = how lit the boss looks
@onready var housing: ColorRect = $Housing
@onready var barrel: ColorRect = $Barrel
@onready var core: Area2D = $Core
@onready var core_ring: Sprite2D = $Core/CoreRing

# The Body sprite's resting position (the boss hover-bobs around this); filled in
# per-kind from ART below.
var _body_x: float = 0.0
var _body_y: float = 35.0

# Per-kind boss art: which sprite to show, how to place/scale it, and where its
# weak-point Core sits over it (measured from the art). Kinds NOT listed here keep
# the placeholder Housing/Barrel rects. Adding a boss's art = one row here.
const ART := {
	"cannon": {
		"tex": preload("res://sprites/bosses/lasercannon.png"),
		"scale": Vector2(0.52, 0.34),
		"pos": Vector2(0, 35),
		"core": Vector2(4, 34),
	},
	"frigate": {
		"tex": preload("res://sprites/bosses/missileboss.png"),
		"scale": Vector2(0.45, 0.34),
		"pos": Vector2(0, 52),
		"core": Vector2(1, 64),
	},
}

# Explosion spark-bursts reused for a boss's death (world-space pops).
const FIREWORKS := preload("res://Fireworks.tscn")
const DEATH_COLORS: Array[Color] = [Color(1, 0.6, 0.2), Color(1, 0.85, 0.3), Color(1, 0.35, 0.2), Color(0.6, 1.0, 0.5)]


func _ready() -> void:
	add_to_group("boss")
	_configure_for_kind()
	hp = max_hp
	core.body_entered.connect(_on_core_entered)
	_set_core_vulnerable(false)
	# (HP bar stays hidden until the fight actually starts - see _enter_attack -
	# so it doesn't clutter the screen under the announcement banner.)


# Set this boss's looks + stats from its `kind`. The mini-bosses share the
# baseline; the main boss is bigger, tougher and longer.
func _configure_for_kind() -> void:
	match kind:
		"frigate":
			boss_name = "MISSILE FRIGATE"
			_apply_art("frigate")   # real art (the placeholder rects are hidden)
			attack_time = 3.8       # a longer dodge window (it ceasefires before the end)...
			overheat_time = 2.8     # ...then a calmer, safer window to fly in and hit the core
		"golem":
			boss_name = "METEOR GOLEM"
			housing.color = Color(0.36, 0.3, 0.26, 1.0)    # rocky brown
		"main":
			boss_name = "DREADNOUGHT"
			max_hp = 8
			max_time = 52.0
			attack_time = 3.0   # room for a full frenzy formation to charge + fire before overheat
			housing.color = Color(0.5, 0.12, 0.14, 1.0)    # menacing red
			# A wider hull so the main boss reads as bigger.
			housing.offset_left = -180.0
			housing.offset_right = 180.0
			housing.offset_bottom = 84.0
		_:
			boss_name = "LASER CANNON"
			_apply_art("cannon")

	# Recurring bosses after the main fight are buffed: extra HP.
	max_hp += int(round(overdrive * 2.0))


# Show a kind's real sprite (Body) + its additive light overlay (Body/Glow), place
# the weak-point Core over the art's glowing core, and hide the placeholder rects.
func _apply_art(art_key: String) -> void:
	var cfg: Dictionary = ART[art_key]
	body_sprite.texture = cfg["tex"]
	body_sprite.scale = cfg["scale"]
	body_sprite.position = cfg["pos"]
	body_sprite.visible = true
	body_glow.texture = cfg["tex"]   # the breathing/flare overlay is the same art, drawn additively
	core.position = cfg["core"]
	_body_x = cfg["pos"].x
	_body_y = cfg["pos"].y
	housing.visible = false
	barrel.visible = false


func _process(delta: float) -> void:
	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	_life += delta
	_t += delta
	if _hit_cd > 0.0:
		_hit_cd -= delta

	# Screen-lock just below the top of the view (clear of the HUD boss bar). During
	# the intro we wait OFF-SCREEN while the announcement banner plays, then drop in
	# once it has cleared. We slide back out when dying/retreating.
	var y := top_y
	if state == State.INTRO:
		if _t < arrive_delay:
			y = top_y - 240.0   # parked above the screen while the banner is up
		else:
			y = lerp(top_y - 240.0, top_y, clamp((_t - arrive_delay) / maxf(0.01, intro_time - arrive_delay), 0.0, 1.0))
	elif state == State.DYING:
		y = lerp(top_y, top_y - 260.0, clamp((_t - 0.35) / 0.5, 0.0, 1.0))   # blow up in place, THEN fly out
	elif state == State.RETREAT:
		y = lerp(top_y, top_y - 260.0, clamp(_t / 0.7, 0.0, 1.0))
	if camera != null:
		global_position = Vector2(camera.global_position.x + offset_x, y)

	match state:
		State.INTRO:
			if _t >= intro_time:
				if camera != null:
					camera.shake(10.0)   # arrival slam as it locks into place
				_enter_attack()
		State.ATTACK:
			# The attack fired on entry. The frigate keeps lobbing fresh volleys
			# through the whole window so the missiles come thick and fast.
			if kind == "frigate" and _t < attack_time - frigate_volley_cutoff:
				_volley_cd -= delta
				if _volley_cd <= 0.0:
					_volley_cd = frigate_volley_interval
					_attack_missiles()
			if _t >= attack_time:
				_enter_overheat()
		State.OVERHEAT:
			_pulse_core(delta)
			if _t >= overheat_time:
				_enter_attack()
		State.DYING:
			# Rapid-fire explosion pops all over the body while it blows up.
			_die_burst_cd -= delta
			if _die_burst_cd <= 0.0 and _t < 0.7:
				_die_burst_cd = 0.09
				var off := Vector2(randf_range(-130.0, 130.0), randf_range(-30.0, 110.0))
				_spawn_burst(off, DEATH_COLORS[randi() % DEATH_COLORS.size()], randf() < 0.5)
			if _t >= 0.85:
				queue_free()
		State.RETREAT:
			if _t >= 0.7:
				queue_free()

	# Fair time cap: if the fight drags on too long, the boss gives up.
	if (state == State.ATTACK or state == State.OVERHEAT) and _life >= max_time:
		_fail()

	# Cannon boss juice: hover bob + a recoil kick when it fires, a frantic tremble
	# while it overheats, a white flash when its core is hit, and a strobing shake as
	# it blows up. (The other kinds use the static Housing rect.)
	if body_sprite.visible:
		var ox := 0.0
		var oy := 0.0
		if _shake_t > 0.0:                                  # transient shake (fire / hit / death)
			_shake_t -= delta
			ox += randf_range(-_shake_mag, _shake_mag)
			oy += randf_range(-_shake_mag, _shake_mag)
		body_sprite.position = Vector2(_body_x + ox, _body_y + sin(_life * 2.0) * 4.0 + oy)

		# Animate the boss's lights via the additive overlay: a gentle idle "breathing",
		# a faster/brighter flare while it overheats, and a sharp flash when it fires.
		var glow_a := 0.12 + 0.07 * sin(_life * 3.0)
		if state == State.OVERHEAT:
			glow_a = 0.30 + 0.22 * sin(_life * 12.0)
		if _fire_flash > 0.0:
			_fire_flash -= delta
			glow_a = maxf(glow_a, (_fire_flash / 0.2) * 0.85)
		body_glow.modulate.a = glow_a

		if state == State.DYING:
			_shake_mag = 7.0                                # keep it rattling the whole death
			_shake_t = maxf(_shake_t, 0.05)
			var strobe := 1.7 + 0.7 * sin(_life * 70.0)     # flash bright as it detonates
			body_sprite.modulate = Color(strobe, strobe, strobe, 1.0)
		elif _flash_t > 0.0:
			_flash_t -= delta
			body_sprite.modulate = Color(1, 1, 1, 1).lerp(Color(2.2, 2.2, 2.2, 1), clampf(_flash_t / 0.15, 0.0, 1.0))
		else:
			body_sprite.modulate = Color(1, 1, 1, 1)

		# Wounded: once its HP is low, the boss spits sparks from random spots so
		# you can see it's badly hurt as you close in for the kill.
		if (state == State.ATTACK or state == State.OVERHEAT) and hp <= maxi(1, int(round(max_hp * 0.4))):
			_smoke_cd -= delta
			if _smoke_cd <= 0.0:
				_smoke_cd = randf_range(0.35, 0.7)
				var soff := Vector2(randf_range(-95.0, 95.0), randf_range(-30.0, 70.0))
				_spawn_burst(soff, Color(1.0, 0.5, 0.25), false)


# --- State transitions ------------------------------------------------------

func _enter_attack() -> void:
	state = State.ATTACK
	_t = 0.0
	_volley_cd = frigate_volley_interval   # next extra volley (frigate only)
	_set_core_vulnerable(false)
	_report_health()   # (re)show the HP bar now the fight is underway
	_fire_pattern()


func _enter_overheat() -> void:
	state = State.OVERHEAT
	_t = 0.0
	_set_core_vulnerable(true)
	if camera != null:
		camera.shake(3.5)   # the core bursts open - a little jolt says "now's your chance"


# The boss reacts to firing: its lights flare and it shudders + shakes the screen.
# Called on every volley (so the frigate's repeated volleys each punch).
func _fire_juice() -> void:
	if not body_sprite.visible:
		return
	_fire_flash = 0.2
	_shake_body(3.5, 0.2)
	if camera != null:
		camera.shake(4.5)


func _die() -> void:
	state = State.DYING
	_t = 0.0
	_set_core_vulnerable(false)
	housing.color = Color(1.0, 0.85, 0.4, 1.0)   # flash bright as it blows (other kinds)
	body_sprite.modulate = Color(2.2, 2.2, 2.2, 1.0)    # the cannon sprite flares bright
	# Kick off the explosion: a big central pop, a hard rattle and a heavy screen shake.
	_die_burst_cd = 0.0
	_shake_body(8.0, 0.85)
	_spawn_burst(Vector2(0, 40), Color(1, 0.95, 0.6), true)
	if camera != null:
		camera.shake(16.0)
	var sp := get_tree().get_first_node_in_group("spawner")
	if sp != null and sp.has_method("boss_defeated"):
		sp.boss_defeated(kind)


func _fail() -> void:
	state = State.RETREAT
	_t = 0.0
	_set_core_vulnerable(false)
	var sp := get_tree().get_first_node_in_group("spawner")
	if sp != null and sp.has_method("boss_failed"):
		sp.boss_failed(kind)


# --- The core (weak point) --------------------------------------------------

func _set_core_vulnerable(v: bool) -> void:
	_core_vulnerable = v
	# No telegraph while sealed - the core just shows the boss's own green art.
	# When exposed, a white ring pings outward (driven by _pulse_core) = "fly in now".
	core_ring.visible = v


# Make the exposed core unmistakable: a white ring that pings outward then resets.
func _pulse_core(delta: float) -> void:
	_pulse += delta * 8.0
	var grow: float = fmod(_pulse * 0.16, 1.0)   # 0->1 sawtooth ping
	core_ring.scale = Vector2.ONE * (0.30 + grow * 0.55)
	core_ring.modulate = Color(1, 1, 1, 1.0 - grow)


func _on_core_entered(body: Node) -> void:
	# A hit only counts while the core is exposed and off cooldown.
	if body.is_in_group("player") and state == State.OVERHEAT and _core_vulnerable and _hit_cd <= 0.0:
		_take_hit()


# Start a transient body shake (fire / hit / death). Magnitude in px, dur in sec.
func _shake_body(mag: float, dur: float) -> void:
	_shake_mag = mag
	_shake_t = dur


# Pop a world-space explosion spark-burst at a position relative to the boss.
func _spawn_burst(offset: Vector2, color: Color, big: bool) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var fw := FIREWORKS.instantiate()
	fw.fw_big = big
	fw.fw_color = color
	parent.add_child(fw)
	fw.global_position = global_position + offset


func _take_hit() -> void:
	hp -= 1
	_hit_cd = hit_cooldown
	_flash_t = 0.15                          # flash the cannon body white on a hit
	if body_sprite.visible:                  # jolt + a little spark pop at the core
		_shake_body(5.0, 0.18)
		_spawn_burst(core.position, Color(0.7, 1.0, 0.7), false)
		if camera != null:
			camera.shake(4.0)
	_report_health()
	if hp <= 0:
		_die()


func _report_health() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("set_boss_health"):
		hud.set_boss_health(hp, max_hp, boss_name)


# --- Attacks ----------------------------------------------------------------

# How hard the current attack hits: difficulty plus any post-main overdrive.
func _power() -> float:
	return clamp(difficulty + overdrive, 0.0, 1.3)


# Pick this beat's attack based on our kind. The main boss rotates through all
# three so every phase feels different.
func _fire_pattern() -> void:
	match kind:
		"frigate":
			_attack_missiles()
		"golem":
			_attack_meteors()
		"main":
			# The main boss rotates through its three signatures: the full Laser
			# Frenzy walls, missile volleys, and meteor waves.
			match _main_attack_index % 3:
				0: _attack_frenzy()
				1: _attack_missiles()
				2: _attack_meteors()
			_main_attack_index += 1
		_:
			_attack_beams()


# --- Beam attack (cannon) ---------------------------------------------------

func _attack_beams() -> void:
	if vertical_laser_scene == null and horizontal_laser_scene == null:
		return
	# Pick a pattern, never the same one twice in a row.
	var patterns: Array[String] = ["sweep", "lanes"]
	# The crossing pattern needs both orientations: vertical AND horizontal beams
	# at once, leaving a single safe pocket - the toughest beam attack.
	if vertical_laser_scene != null and horizontal_laser_scene != null:
		patterns.append("cross")
	if patterns.size() > 1 and patterns.has(_last_pattern):
		patterns.erase(_last_pattern)
	var choice: String = patterns.pick_random()
	_last_pattern = choice
	match choice:
		"sweep": _fire_sweep()
		"lanes": _fire_lanes()
		"cross": _fire_cross()
	_fire_juice()


# A full-height vertical beam that sweeps across from one side - flee to the
# far side. Tougher fights add a second beam (staggered, leaving a moving gap).
func _fire_sweep() -> void:
	if vertical_laser_scene == null:
		_fire_lanes()
		return
	var from_left := randf() < 0.5
	var start_x := -560.0 if from_left else 560.0
	var dir := 1.0 if from_left else -1.0
	var spd: float = lerp(sweep_speed, sweep_speed * 1.5, _power())

	var v := vertical_laser_scene.instantiate()
	v.offset_x = start_x
	v.sweep_speed = dir * spd
	v.charge_time = 0.8
	v.fire_time = 2.2
	get_parent().add_child(v)

	if _power() >= 0.5:
		# A trailing beam that keeps a gap between itself and the first.
		var v2 := vertical_laser_scene.instantiate()
		v2.offset_x = start_x - dir * 360.0
		v2.sweep_speed = dir * spd
		v2.charge_time = 1.1
		v2.fire_time = 2.2
		get_parent().add_child(v2)


# A fast "leave one lane open" formation (vertical columns or horizontal rows),
# the same fair idea the spawner's frenzy uses.
func _fire_lanes() -> void:
	if vertical_laser_scene != null and (horizontal_laser_scene == null or randf() < 0.5):
		var lanes := [-440.0, -160.0, 160.0, 440.0]
		var safe := randi() % lanes.size()
		for i in lanes.size():
			if i == safe:
				continue
			var v := vertical_laser_scene.instantiate()
			v.offset_x = lanes[i]
			v.charge_time = 0.9
			v.fire_time = 1.2
			get_parent().add_child(v)
	elif horizontal_laser_scene != null:
		var rows := [150.0, 330.0, 510.0]
		var safe := randi() % rows.size()
		for j in rows.size():
			if j == safe:
				continue
			var h := horizontal_laser_scene.instantiate()
			h.beam_y = rows[j]
			h.beam_thickness = 50.0
			h.charge_time = 1.0
			h.fire_time = 1.2
			get_parent().add_child(h)


# A CROSS of vertical AND horizontal beams firing together, leaving a single safe
# POCKET (where the open column meets the open row) to thread to. The cannon's
# toughest beam pattern - mixes its attacks up with a "reach the exact spot" beat.
func _fire_cross() -> void:
	if vertical_laser_scene == null or horizontal_laser_scene == null:
		_fire_lanes()
		return
	var cols := [-440.0, -160.0, 160.0, 440.0]
	var rows := [150.0, 330.0, 510.0]
	var safe_col := randi() % cols.size()
	var safe_row := randi() % rows.size()
	var charge: float = lerp(1.4, 1.0, _power())   # higher power = less warning = harder
	for i in cols.size():
		if i == safe_col:
			continue
		var v := vertical_laser_scene.instantiate()
		v.offset_x = cols[i]
		v.charge_time = charge
		v.fire_time = 1.2
		get_parent().add_child(v)
	for j in rows.size():
		if j == safe_row:
			continue
		var h := horizontal_laser_scene.instantiate()
		h.beam_y = rows[j]
		h.beam_thickness = 50.0
		h.charge_time = charge
		h.fire_time = 1.2
		get_parent().add_child(h)


# --- Frenzy attack (main boss) ----------------------------------------------

# The main boss's signature: synchronised laser walls that leave exactly ONE
# safe lane / row / pocket - the Laser Frenzy patterns. "combined" is the hard
# one: vertical AND horizontal bars at once, so you must reach a single pocket.
func _attack_frenzy() -> void:
	var have_both := vertical_laser_scene != null and horizontal_laser_scene != null
	var types: Array[String] = []
	if vertical_laser_scene != null:
		types.append("vertical")
	if horizontal_laser_scene != null:
		types.append("horizontal")
	if have_both:
		types.append("combined")
	if types.is_empty():
		return
	# Never repeat the previous formation.
	if types.size() > 1 and types.has(_last_formation):
		types.erase(_last_formation)
	var choice: String = types.pick_random()
	_last_formation = choice
	match choice:
		"vertical": _frenzy_vertical()
		"horizontal": _frenzy_horizontal()
		"combined": _frenzy_combined()


# Vertical bars across the screen with one safe COLUMN to slip into.
func _frenzy_vertical() -> void:
	var lanes := [-480.0, -240.0, 0.0, 240.0, 480.0]
	var safe := randi() % lanes.size()
	for i in lanes.size():
		if i == safe:
			continue
		var v := vertical_laser_scene.instantiate()
		v.offset_x = lanes[i]
		v.charge_time = 1.0
		v.fire_time = 1.1
		get_parent().add_child(v)


# Horizontal bars stacked up the screen with one safe ROW to fly to.
func _frenzy_horizontal() -> void:
	var rows := [150.0, 330.0, 510.0]
	var safe := randi() % rows.size()
	for i in rows.size():
		if i == safe:
			continue
		var h := horizontal_laser_scene.instantiate()
		h.beam_y = rows[i]
		h.beam_thickness = 50.0
		h.charge_time = 1.1
		h.fire_time = 1.1
		get_parent().add_child(h)


# The hard one: vertical bars AND horizontal bars at once, leaving a single safe
# POCKET (the crossing of the open column and open row). A touch more charge time
# so you can fly to the exact spot.
func _frenzy_combined() -> void:
	var cols := [-440.0, -160.0, 160.0, 440.0]
	var rows := [150.0, 330.0, 510.0]
	var safe_col := randi() % cols.size()
	var safe_row := randi() % rows.size()
	var charge := 1.4
	for i in cols.size():
		if i == safe_col:
			continue
		var v := vertical_laser_scene.instantiate()
		v.offset_x = cols[i]
		v.charge_time = charge
		v.fire_time = 1.1
		get_parent().add_child(v)
	for j in rows.size():
		if j == safe_row:
			continue
		var h := horizontal_laser_scene.instantiate()
		h.beam_y = rows[j]
		h.charge_time = charge
		h.fire_time = 1.1
		get_parent().add_child(h)


# --- Missile attack (frigate) -----------------------------------------------

# A telegraphed volley: missiles warn ("!") at several heights then strike left,
# always leaving at least one row open to thread.
func _attack_missiles() -> void:
	if missile_scene == null:
		_attack_beams()
		return
	var rows: Array[float] = [110.0, 220.0, 330.0, 440.0, 550.0]
	rows.shuffle()
	# Fire at this many rows; the rest stay open as safe gaps. Missiles now come
	# from BOTH the left and right edges (alternating) for more pressure.
	var count: int = mini(2 + int(round(_power() * 2.0)), rows.size() - 1)
	for i in count:
		var from_left: bool = (i % 2 == 0)
		var m := missile_scene.instantiate()
		var edge_x: float = -600.0 if from_left else 600.0
		m.position = Vector2(camera.global_position.x + edge_x, rows[i])
		m.from_left = from_left
		get_parent().add_child(m)
	_fire_juice()   # flare + shudder on every volley


# --- Meteor attack (golem) --------------------------------------------------

# A wave of fast asteroids rushing in from the right, spread across heights with
# at least one band left clear.
func _attack_meteors() -> void:
	if obstacle_scene == null:
		_attack_beams()
		return
	var bands: Array[float] = [120.0, 230.0, 340.0, 450.0, 560.0]
	bands.shuffle()
	var count: int = mini(3 + int(round(_power() * 2.0)), bands.size() - 1)
	var speed: float = 220.0 + 140.0 * _power()
	for i in count:
		var a := obstacle_scene.instantiate()
		a.position = Vector2(camera.global_position.x + 720.0, bands[i] + randf_range(-25.0, 25.0))
		a.extra_speed = speed
		get_parent().add_child(a)
