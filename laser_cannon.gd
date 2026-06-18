# ==========================================================
#  laser_cannon.gd - the Laser Cannon mini-boss
# ==========================================================
#  A recurring set-piece (every 3rd event). The Moki has no weapon, so the
#  "fight" works like this: the cannon ATTACKS with telegraphed beams you must
#  dodge, then OVERHEATS - exposing a glowing core you fly into to damage it.
#  Knock its HP to zero to destroy it (big reward); if you can't in time, it
#  just retreats.
#
#  The state machine mirrors the laser scripts' simple style:
#     INTRO -> (ATTACK <-> OVERHEAT) -> DYING / RETREAT
#
#  The spawner creates us, hands us the laser scenes + current difficulty, and
#  waits for us to call boss_defeated() / boss_failed() back. We report our HP
#  to the HUD so it can draw the boss health bar.
# ==========================================================

extends Node2D

enum State { INTRO, ATTACK, OVERHEAT, DYING, RETREAT }

@export var max_hp: int = 5            # Flying into the core this many times destroys it.
@export var intro_time: float = 2.8    # "Boss incoming" beat: announcement, then it drops in.
@export var arrive_delay: float = 1.8  # Stay off-screen this long (while the banner shows), THEN slide in.
@export var attack_time: float = 2.5   # Length of each beam-attack window.
@export var overheat_time: float = 2.2 # Length of each vulnerable (core exposed) window.
@export var max_time: float = 34.0     # Safety cap: only catches a stuck player. Must leave
                                       # enough overheat windows to land all max_hp hits (~4.7s/cycle).
@export var sweep_speed: float = 240.0 # Base px/sec for sweeping beams (< player move_speed = escapable).
@export var hit_cooldown: float = 0.35 # Min gap between core hits (stops one pass scoring many).
@export var offset_x: float = 0.0      # Screen-x offset from the camera centre (top-centre by default).
@export var top_y: float = 74.0        # Resting height of the turret top (kept clear of the HUD boss bar).

# Handed to us by the spawner the instant we are created.
var vertical_laser_scene: PackedScene
var horizontal_laser_scene: PackedScene
var difficulty: float = 0.0

const COLOR_CORE_COLD := Color(0.5, 0.15, 0.15, 1.0)  # sealed (don't bother)
const COLOR_CORE_HOT := Color(1.0, 0.75, 0.2, 1.0)    # exposed (fly in!)

var state: int = State.INTRO
var hp: int = 0
var _t: float = 0.0          # time spent in the current state
var _life: float = 0.0       # total time alive (for the max_time cap)
var _hit_cd: float = 0.0     # cooldown left before the core can be hit again
var _pulse: float = 0.0      # drives the exposed-core glow pulse
var _last_pattern: String = ""
var _core_vulnerable: bool = false
var camera: Node2D

@onready var housing: ColorRect = $Housing
@onready var core: Area2D = $Core
@onready var core_rect: ColorRect = $Core/CoreRect


func _ready() -> void:
	add_to_group("boss")
	hp = max_hp
	core.body_entered.connect(_on_core_entered)
	_set_core_vulnerable(false)
	# (HP bar stays hidden until the fight actually starts - see _enter_attack -
	# so it doesn't clutter the screen under the announcement banner.)


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
	elif state == State.DYING or state == State.RETREAT:
		y = lerp(top_y, top_y - 260.0, clamp(_t / 0.7, 0.0, 1.0))
	if camera != null:
		global_position = Vector2(camera.global_position.x + offset_x, y)

	match state:
		State.INTRO:
			if _t >= intro_time:
				_enter_attack()
		State.ATTACK:
			# Beams were fired on entry; just wait the window out, then overheat.
			if _t >= attack_time:
				_enter_overheat()
		State.OVERHEAT:
			_pulse_core(delta)
			if _t >= overheat_time:
				_enter_attack()
		State.DYING, State.RETREAT:
			if _t >= 0.7:
				queue_free()

	# Fair time cap: if the fight drags on too long, the cannon gives up.
	if (state == State.ATTACK or state == State.OVERHEAT) and _life >= max_time:
		_fail()


# --- State transitions ------------------------------------------------------

func _enter_attack() -> void:
	state = State.ATTACK
	_t = 0.0
	_set_core_vulnerable(false)
	_report_health()   # (re)show the HP bar now the fight is underway
	_fire_pattern()


func _enter_overheat() -> void:
	state = State.OVERHEAT
	_t = 0.0
	_set_core_vulnerable(true)


func _die() -> void:
	state = State.DYING
	_t = 0.0
	_set_core_vulnerable(false)
	housing.color = Color(1.0, 0.85, 0.4, 1.0)   # flash bright as it blows
	var sp := get_tree().get_first_node_in_group("spawner")
	if sp != null and sp.has_method("boss_defeated"):
		sp.boss_defeated()


func _fail() -> void:
	state = State.RETREAT
	_t = 0.0
	_set_core_vulnerable(false)
	var sp := get_tree().get_first_node_in_group("spawner")
	if sp != null and sp.has_method("boss_failed"):
		sp.boss_failed()


# --- The core (weak point) --------------------------------------------------

func _set_core_vulnerable(v: bool) -> void:
	_core_vulnerable = v
	core_rect.color = COLOR_CORE_HOT if v else COLOR_CORE_COLD
	core_rect.modulate.a = 1.0


# Make the exposed core pulse so it clearly reads as "hit me now".
func _pulse_core(delta: float) -> void:
	_pulse += delta * 8.0
	core_rect.modulate.a = 0.65 + 0.35 * sin(_pulse)


func _on_core_entered(body: Node) -> void:
	# A hit only counts while the core is exposed and off cooldown.
	if body.is_in_group("player") and state == State.OVERHEAT and _core_vulnerable and _hit_cd <= 0.0:
		_take_hit()


func _take_hit() -> void:
	hp -= 1
	_hit_cd = hit_cooldown
	core_rect.color = Color(1, 1, 1, 1)   # white flash; the pulse restores the hot colour
	_report_health()
	if hp <= 0:
		_die()


func _report_health() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("set_boss_health"):
		hud.set_boss_health(hp, max_hp)


# --- Attacks (reuse the existing laser scenes) ------------------------------

func _fire_pattern() -> void:
	if vertical_laser_scene == null and horizontal_laser_scene == null:
		return
	# Pick a pattern, never the same one twice in a row.
	var patterns: Array[String] = ["sweep", "lanes"]
	if patterns.has(_last_pattern):
		patterns.erase(_last_pattern)
	var choice: String = patterns.pick_random()
	_last_pattern = choice
	match choice:
		"sweep": _fire_sweep()
		"lanes": _fire_lanes()


# A full-height vertical beam that sweeps across from one side - flee to the
# far side. Deeper runs add a second beam (same direction, staggered, leaving a
# moving gap to ride).
func _fire_sweep() -> void:
	if vertical_laser_scene == null:
		_fire_lanes()
		return
	var from_left := randf() < 0.5
	var start_x := -560.0 if from_left else 560.0
	var dir := 1.0 if from_left else -1.0
	var spd: float = lerp(sweep_speed, sweep_speed * 1.5, difficulty)

	var v := vertical_laser_scene.instantiate()
	v.offset_x = start_x
	v.sweep_speed = dir * spd
	v.charge_time = 0.8
	v.fire_time = 2.2
	get_parent().add_child(v)

	if difficulty >= 0.5:
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
