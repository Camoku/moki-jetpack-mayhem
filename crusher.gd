# ==========================================================
#  crusher.gd - a gate whose two blocks slam open and shut
# ==========================================================
#  A thin vertical gate sitting in the world (the camera scrolls past it).
#  A block from the ceiling and a block from the floor slide toward each
#  other to SHUT (no gap), then retract to OPEN (a wide safe gap), on a
#  steady cycle. Both blocks are deadly. You hover in front (the Moki can
#  fly left faster than the world scrolls) and dart through on the open
#  beat - pure timing/rhythm.
#
#  The blocks are fixed-height rectangles taller than the play area, so
#  they always cover right to the roof/floor; we just slide them in Y to
#  resize the gap between them (no per-frame shape rebuilding).
#
#  Cycle: OPEN (hold) -> CLOSING -> SHUT (hold) -> OPENING -> repeat.
# ==========================================================

extends Area2D

@export var area_top: float = 0.0
@export var area_bottom: float = 660.0
@export var gate_width: float = 60.0
@export var gap_center: float = 330.0    # middle of the gap (set by the spawner)
@export var gap_open: float = 240.0      # gap height when fully open
@export var open_time: float = 1.3       # hold open (your window to slip through)
@export var closed_time: float = 0.7     # hold shut
@export var move_time: float = 0.45      # time to slide open<->shut
@export var cleanup_behind: float = 800.0

# Blocks are taller than the screen so they always reach the edges.
const BLOCK_H := 760.0

var camera: Node2D
var _phase: String = "open"
var _phase_t: float = 0.0
var _halfgap: float = 120.0

@onready var top_shape: CollisionShape2D = $TopShape
@onready var bottom_shape: CollisionShape2D = $BottomShape
@onready var top_wall: ColorRect = $TopWall
@onready var bottom_wall: ColorRect = $BottomWall


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("asteroid")   # generic persistent-hazard group (coin clearance)

	# Build the two fixed-size block collision shapes once.
	var ts := RectangleShape2D.new()
	ts.size = Vector2(gate_width, BLOCK_H)
	top_shape.shape = ts
	var bs := RectangleShape2D.new()
	bs.size = Vector2(gate_width, BLOCK_H)
	bottom_shape.shape = bs

	_halfgap = gap_open * 0.5
	_apply_gap()


# The gate is full-height, so keep all pickups well clear of the whole column.
func clear_radius() -> float:
	return (area_bottom - area_top) * 0.5


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.crash()


func _process(delta: float) -> void:
	_phase_t += delta
	match _phase:
		"open":
			_halfgap = gap_open * 0.5
			if _phase_t >= open_time:
				_phase = "closing"
				_phase_t = 0.0
		"closing":
			_halfgap = lerp(gap_open * 0.5, 0.0, clamp(_phase_t / move_time, 0.0, 1.0))
			if _phase_t >= move_time:
				_phase = "shut"
				_phase_t = 0.0
		"shut":
			_halfgap = 0.0
			if _phase_t >= closed_time:
				_phase = "opening"
				_phase_t = 0.0
		"opening":
			_halfgap = lerp(0.0, gap_open * 0.5, clamp(_phase_t / move_time, 0.0, 1.0))
			if _phase_t >= move_time:
				_phase = "open"
				_phase_t = 0.0
	_apply_gap()

	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	if camera != null and global_position.x < camera.global_position.x - cleanup_behind:
		queue_free()


# Place both blocks from the current half-gap. Each block's INNER edge sits at
# gap_center ± _halfgap; the block extends away from there (off-screen) by BLOCK_H.
func _apply_gap() -> void:
	var top_edge: float = gap_center - _halfgap      # bottom edge of the top block
	var bottom_edge: float = gap_center + _halfgap   # top edge of the bottom block

	top_shape.position = Vector2(0.0, top_edge - BLOCK_H * 0.5)
	top_wall.offset_left = -gate_width * 0.5
	top_wall.offset_right = gate_width * 0.5
	top_wall.offset_top = top_edge - BLOCK_H
	top_wall.offset_bottom = top_edge

	bottom_shape.position = Vector2(0.0, bottom_edge + BLOCK_H * 0.5)
	bottom_wall.offset_left = -gate_width * 0.5
	bottom_wall.offset_right = gate_width * 0.5
	bottom_wall.offset_top = bottom_edge
	bottom_wall.offset_bottom = bottom_edge + BLOCK_H
