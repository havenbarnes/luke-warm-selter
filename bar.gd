extends AnimatableBody3D

@export var anchor_span: float = 4.5
@export var speed: float = 0.6
@export var min_height: float = -2.5
@export var max_height: float = 2.5


@export var start_height: float = -2.5
@export var bar_thickness: float = 0.1
@export var bar_depth: float = 0.3

@export var max_height_difference: float = 0.75

var left_height: float = -2.5
var right_height: float = -2.5

var _collision: CollisionShape3D
var _mesh_instance: MeshInstance3D
var _shape: BoxShape3D
var _mesh: CylinderMesh


func _ready() -> void:
	sync_to_physics = false

	var start := clampf(start_height, min_height, max_height)
	left_height = start
	right_height = start

	for child in get_children():
		if child is CollisionShape3D and _collision == null:
			_collision = child
		elif child is MeshInstance3D and _mesh_instance == null:
			_mesh_instance = child

	if _collision == null:
		push_error("Bar: no CollisionShape3D child found.")
		set_physics_process(false)
		return
	if _mesh_instance == null:
		push_error("Bar: no MeshInstance3D child found.")
		set_physics_process(false)
		return

	_collision.transform = Transform3D.IDENTITY
	_mesh_instance.transform = Transform3D.IDENTITY

	_shape = BoxShape3D.new()
	_collision.shape = _shape

	_mesh = CylinderMesh.new()
	_mesh_instance.mesh = _mesh
	_mesh_instance.rotation.z = deg_to_rad(90.0)

	_apply()


func _physics_process(delta: float) -> void:
	var left_input := Input.get_axis("bar_left_down", "bar_left_up")
	var right_input := Input.get_axis("bar_right_down", "bar_right_up")

	if is_zero_approx(left_input) and is_zero_approx(right_input):
		return

	left_height += left_input * speed * delta
	right_height += right_input * speed * delta

	left_height = clampf(left_height, min_height, max_height)
	right_height = clampf(right_height, min_height, max_height)

	_limit_difference(left_input, right_input)
	_apply()


## Keeps the two ends within max_height_difference. The end that is not being
## driven this frame is the one that gives way.
func _limit_difference(left_input: float, right_input: float) -> void:
	if max_height_difference <= 0.0:
		return

	var diff := right_height - left_height
	if absf(diff) <= max_height_difference:
		return

	var overshoot := absf(diff) - max_height_difference
	var direction := signf(diff)

	var left_active := not is_zero_approx(left_input)
	var right_active := not is_zero_approx(right_input)

	if left_active and right_active:
		# Both ends are being driven, so neither one "gives way" — split the
		# correction evenly and the bar keeps responding to both inputs.
		left_height += overshoot * 0.5 * direction
		right_height -= overshoot * 0.5 * direction
	elif left_active:
		left_height += overshoot * direction
	else:
		right_height -= overshoot * direction

	left_height = clampf(left_height, min_height, max_height)
	right_height = clampf(right_height, min_height, max_height)


## Positions the bar between the two anchors and stretches it to reach both.
func _apply() -> void:
	var half := anchor_span * 0.5
	var rise := right_height - left_height
	var length := sqrt(anchor_span * anchor_span + rise * rise)

	position = Vector3(0.0, (left_height + right_height) * 0.5, position.z)
	rotation = Vector3(0.0, 0.0, atan2(rise, anchor_span))

	_shape.size = Vector3(length, bar_thickness, bar_depth)
	_mesh.height = length
	_mesh.top_radius = bar_thickness * 0.5
	_mesh.bottom_radius = bar_thickness * 0.5


func get_anchor_positions() -> Array[Vector3]:
	var half := anchor_span * 0.5
	return [
		Vector3(-half, left_height, position.z),
		Vector3(half, right_height, position.z),
	]
