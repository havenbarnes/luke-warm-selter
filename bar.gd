extends AnimatableBody3D

## Ice Cold Beer bar controller.
##
## The two anchors are pinned to fixed X positions (-anchor_span/2 and
## +anchor_span/2) and slide only along Y. Because the horizontal span never
## changes but the ends move independently, the bar telescopes: its length is
## hypot(anchor_span, height_difference).
##
## Q / A raise and lower the LEFT anchor.
## P / L raise and lower the RIGHT anchor.

@export var anchor_span: float = 8.0
@export var speed: float = 3.0
@export var min_height: float = -2.5
@export var max_height: float = 2.5

## Where both anchors sit when the game starts. The script owns position.y, so
## the Bar's transform in the editor is ignored — set the start height here.
@export var start_height: float = -2.5
@export var bar_thickness: float = 0.1
@export var bar_depth: float = 0.3

## Depth (Z) the bar rides at. It sits in FRONT of the ball's rest depth (~0.10,
## against the backboard) so the ball is cradled between the backboard and the
## bar and never leans on the front glass. See ball.gd's into-board force.
@export var bar_z: float = 0.18

## Caps how far apart the two ends may get. Set to 0.0 for no limit.
@export var max_height_difference: float = 1.0

## How quickly each anchor's velocity responds to input (units/sec²).
## Higher = snappier direction changes. Lower = mushier, heavier feel.
@export var acceleration: float = 3.0

## How quickly each anchor decelerates when input stops or reverses (units/sec²).
## Set higher than acceleration for a tight, responsive reversal.
@export var deceleration: float = 10

## Prints anchor positions and bar length every time the bar moves.
@export var debug_print: bool = false

var left_height: float = -2.5
var right_height: float = -2.5
var _left_velocity: float = 0.0
var _right_velocity: float = 0.0

var _collision: CollisionShape3D
var _mesh_instance: MeshInstance3D
var _shape: CylinderShape3D
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

	_shape = CylinderShape3D.new()
	_collision.shape = _shape
	_collision.rotation.z = deg_to_rad(90.0)

	_mesh = CylinderMesh.new()
	_mesh_instance.mesh = _mesh
	_mesh_instance.rotation.z = deg_to_rad(90.0)

	_apply()


func _physics_process(delta: float) -> void:
	var left_input := Input.get_axis("bar_left_down", "bar_left_up")
	var right_input := Input.get_axis("bar_right_down", "bar_right_up")

	_left_velocity = _accelerate(_left_velocity, left_input, delta)
	_right_velocity = _accelerate(_right_velocity, right_input, delta)

	if is_zero_approx(_left_velocity) and is_zero_approx(_right_velocity):
		return

	left_height += _left_velocity * delta
	right_height += _right_velocity * delta

	left_height = clampf(left_height, min_height, max_height)
	right_height = clampf(right_height, min_height, max_height)

	# Zero velocity when clamped against the limit so it doesn't "store" speed.
	if left_height == min_height or left_height == max_height:
		_left_velocity = 0.0
	if right_height == min_height or right_height == max_height:
		_right_velocity = 0.0

	# Snapshot heights before the limit correction.
	var lh_before := left_height
	var rh_before := right_height

	_limit_difference()

	# If the limiter pulled a height back, kill that side's velocity.
	# Without this, stored velocity "pops" the bar on the next frame.
	if not is_equal_approx(left_height, lh_before):
		_left_velocity = 0.0
	if not is_equal_approx(right_height, rh_before):
		_right_velocity = 0.0

	_apply()


## Smoothly ramps velocity toward the target speed based on input direction.
## Uses deceleration rate when input opposes current velocity (direction change)
## or when input is released.
func _accelerate(current_vel: float, input: float, delta: float) -> float:
	var target := input * speed

	# Pick rate: decelerate when reversing, stopping, or overshooting.
	var rate: float
	if is_zero_approx(input):
		rate = deceleration
	elif signf(input) != signf(current_vel) and not is_zero_approx(current_vel):
		rate = deceleration
	else:
		rate = acceleration

	return move_toward(current_vel, target, rate * delta)


func _limit_difference() -> void:
	if max_height_difference <= 0.0:
		return

	var diff := right_height - left_height
	if absf(diff) <= max_height_difference:
		return

	var overshoot := absf(diff) - max_height_difference
	var direction := signf(diff)

	# Use velocity to decide which side caused the overshoot.
	# The side that's moving gets pulled back; the idle side stays put.
	var left_moving := not is_zero_approx(_left_velocity)
	var right_moving := not is_zero_approx(_right_velocity)

	if left_moving and right_moving:
		left_height += overshoot * 0.5 * direction
		right_height -= overshoot * 0.5 * direction
	elif left_moving:
		# Left caused it — pull left back, leave right alone.
		left_height += overshoot * direction
	elif right_moving:
		# Right caused it — pull right back, leave left alone.
		right_height -= overshoot * direction
	else:
		# Neither moving (shouldn't happen, but be safe) — split evenly.
		left_height += overshoot * 0.5 * direction
		right_height -= overshoot * 0.5 * direction

	left_height = clampf(left_height, min_height, max_height)
	right_height = clampf(right_height, min_height, max_height)


func _apply() -> void:
	var half := anchor_span * 0.5
	var rise := right_height - left_height
	var length := sqrt(anchor_span * anchor_span + rise * rise)

	position = Vector3(0.0, (left_height + right_height) * 0.5, bar_z)
	rotation = Vector3(0.0, 0.0, atan2(rise, anchor_span))

	_shape.height = length
	_shape.radius = bar_thickness * 0.5

	_mesh.height = length
	_mesh.top_radius = bar_thickness * 0.5
	_mesh.bottom_radius = bar_thickness * 0.5

	if debug_print:
		print("lh=%+.3f rh=%+.3f | vel L=%+.3f R=%+.3f | y=%+.3f rot=%+.3f" % [
			left_height, right_height,
			_left_velocity, _right_velocity,
			position.y, rotation.z,
		])


func get_anchor_positions() -> Array[Vector3]:
	var half := anchor_span * 0.5
	return [
		Vector3(-half, left_height, position.z),
		Vector3(half, right_height, position.z),
	]
