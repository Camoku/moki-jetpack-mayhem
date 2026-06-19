# ==========================================================
#  cave_wall.gd - one vertical slice of the cave tunnel
# ==========================================================
#  A top + bottom rock wall with a gap between them. Touch a wall and
#  you crash. The spawner streams these tightly together with the gap
#  snaking up/down to form a continuous winding tunnel to thread.
# ==========================================================

extends Area2D

@export var gap_center: float = 325.0     # middle of the safe gap (set by spawner)
@export var gap_height: float = 220.0     # how tall the gap is (set by spawner)
@export var wall_width: float = 52.0      # slice thickness (slightly overlaps neighbours)
@export var area_top: float = 0.0
@export var area_bottom: float = 610.0
@export var cleanup_behind: float = 760.0

var camera: Node2D

@onready var top_shape: CollisionShape2D = $TopShape
@onready var bottom_shape: CollisionShape2D = $BottomShape
@onready var top_wall: TextureRect = $TopWall
@onready var bottom_wall: TextureRect = $BottomWall


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("asteroid")   # so post-cave coins keep clear of leftover walls
	_build()


# Keep pickups well clear of the whole column (walls are full height).
func clear_radius() -> float:
	return (area_bottom - area_top) * 0.5


func _build() -> void:
	var gap_top: float = gap_center - gap_height * 0.5
	var gap_bottom: float = gap_center + gap_height * 0.5
	var top_h: float = max(0.0, gap_top - area_top)
	var bottom_h: float = max(0.0, area_bottom - gap_bottom)

	top_wall.offset_left = -wall_width * 0.5
	top_wall.offset_right = wall_width * 0.5
	top_wall.offset_top = area_top
	top_wall.offset_bottom = gap_top

	bottom_wall.offset_left = -wall_width * 0.5
	bottom_wall.offset_right = wall_width * 0.5
	bottom_wall.offset_top = gap_bottom
	bottom_wall.offset_bottom = area_bottom

	var ts := RectangleShape2D.new()
	ts.size = Vector2(wall_width, top_h)
	top_shape.shape = ts
	top_shape.position = Vector2(0.0, area_top + top_h * 0.5)

	var bs := RectangleShape2D.new()
	bs.size = Vector2(wall_width, bottom_h)
	bottom_shape.shape = bs
	bottom_shape.position = Vector2(0.0, gap_bottom + bottom_h * 0.5)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.crash()


func _process(_delta: float) -> void:
	if camera == null:
		camera = get_tree().get_first_node_in_group("camera")
	if camera != null and global_position.x < camera.global_position.x - cleanup_behind:
		queue_free()
