extends Node3D

## Spawns all holes on the Ice Cold Beer playfield using CSG.
##
## The playfield is one uniform, hex-packed grid of identical holes, exactly
## like the real cabinet. Ten of those grid holes are the numbered goals (1–10):
## ordinary holes marked with a ring and a number — not larger, not specially
## placed. Every other hole is a trap.
##
## Builds a physical backboard (CSGCombiner3D) with a cylindrical cutout for
## every hole. Where there's a hole there's no collision, so the ball falls
## through. Also spawns an Area3D detector behind each hole to tell goals from
## traps when the ball drops in.

## Radius of every hole — goals and traps alike, since the real board is uniform.
@export var hole_radius: float = 0.2

## Hex-grid spacing. Odd rows are offset by half a column; the row pitch is a bit
## under spacing_x so the packing stays tight, like the photo's thin walls.
@export var spacing_x: float = 0.5
@export var spacing_y: float = 0.44

## Playfield extents the grid fills (X left/right, Y bottom/top).
@export var pf_left: float = -2.3
@export var pf_right: float = 2.3
@export var pf_bottom: float = -1.9
@export var pf_top: float = 2.8

## Backboard dimensions. The backboard is the ball's only back wall (the Frame's
## WallBack collision is disabled so holes can open through it), so it must span
## the whole playfield or the ball falls off the unbacked edges once the
## into-board force presses it back. See GameScene / ball.gd.
@export var wall_width: float = 7.8
@export var wall_height: float = 6.4
@export var wall_thickness: float = 0.2
@export var wall_z: float = -0.15

## Colors.
@export var wall_color: Color = Color(0.65, 0.55, 0.25)  # Gold, like the cabinet.
@export var goal_ring_color: Color = Color(0.15, 0.15, 0.15)

var _hole_script: GDScript = preload("res://hole.gd")


# ── Goal targets, read off the cabinet photo (numbers 1–10, bottom to top).
# Each target is snapped to the nearest grid hole, so goals always sit ON the
# grid rather than floating between holes. ──

const GOAL_TARGETS: Array[Dictionary] = [
	{ "number": 1,  "x": -0.2, "y": -1.5 },
	{ "number": 2,  "x":  1.0, "y": -1.3 },
	{ "number": 3,  "x": -1.3, "y": -1.0 },
	{ "number": 4,  "x":  0.4, "y": -0.4 },
	{ "number": 5,  "x": -0.7, "y":  0.1 },
	{ "number": 6,  "x":  1.1, "y":  0.7 },
	{ "number": 7,  "x": -0.1, "y":  1.1 },
	{ "number": 8,  "x": -1.2, "y":  1.5 },
	{ "number": 9,  "x":  0.6, "y":  1.9 },
	{ "number": 10, "x": -0.5, "y":  2.4 },
]


func _ready() -> void:
	var holes := _build_grid()
	_assign_goals(holes)

	# ── Build the CSG backboard with a cutout per hole ──
	_build_csg_wall(holes)

	# ── Spawn an Area3D detector behind each hole ──
	for data in holes:
		_create_detector(data)


## Builds the uniform hex grid of holes that fills the playfield.
func _build_grid() -> Array[Dictionary]:
	var holes: Array[Dictionary] = []
	var row := 0
	var y := pf_bottom
	while y <= pf_top + 0.0001:
		# Offset every other row by half a column for hexagonal packing.
		var x_offset := 0.0 if row % 2 == 0 else spacing_x * 0.5
		var x := pf_left + x_offset
		while x <= pf_right + 0.0001:
			holes.append({ "x": x, "y": y, "number": 0 })
			x += spacing_x
		y += spacing_y
		row += 1
	return holes


## Turns the grid hole nearest each photo target into that numbered goal.
func _assign_goals(holes: Array[Dictionary]) -> void:
	for target in GOAL_TARGETS:
		var target_pos := Vector2(target["x"], target["y"])
		var best := -1
		var best_dist := INF
		for i in holes.size():
			if holes[i]["number"] != 0:
				continue  # Already claimed by another goal.
			var d := Vector2(holes[i]["x"], holes[i]["y"]).distance_to(target_pos)
			if d < best_dist:
				best_dist = d
				best = i
		if best != -1:
			holes[best]["number"] = target["number"]


func _build_csg_wall(holes: Array[Dictionary]) -> void:
	var combiner := CSGCombiner3D.new()
	combiner.name = "Backboard"
	combiner.use_collision = true
	combiner.collision_layer = 1   # "world"
	combiner.collision_mask = 0
	combiner.position = Vector3(0.0, 0.0, wall_z)
	add_child(combiner)

	# Base wall slab.
	var base := CSGBox3D.new()
	base.name = "Wall"
	base.size = Vector3(wall_width, wall_height, wall_thickness)
	base.operation = CSGShape3D.OPERATION_UNION

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = wall_color
	base.material = wall_mat
	combiner.add_child(base)

	# Cut a cylinder for each hole. All holes are the same size.
	for data in holes:
		var cut := CSGCylinder3D.new()
		cut.radius = hole_radius
		cut.height = wall_thickness + 0.1  # Slightly taller to cut clean through.
		cut.sides = 20
		cut.operation = CSGShape3D.OPERATION_SUBTRACTION
		cut.position = Vector3(data["x"], data["y"], 0.0)
		# The wall lies in X-Y, so rotate the (Y-aligned) cylinder to bore along Z.
		cut.rotation.x = deg_to_rad(90.0)
		combiner.add_child(cut)


## Creates an Area3D detector behind a hole for goal/trap identification.
func _create_detector(data: Dictionary) -> void:
	var number: int = data["number"]
	var is_goal := number > 0

	var hole := Area3D.new()
	hole.set_script(_hole_script)
	hole.hole_number = number
	hole.hole_radius = hole_radius
	# Place the detector just behind the wall so the ball trips it as it passes
	# through the cutout.
	hole.position = Vector3(data["x"], data["y"], wall_z - wall_thickness * 0.5 - 0.1)

	hole.monitoring = true
	hole.monitorable = false
	hole.collision_layer = 0
	hole.collision_mask = 2  # "ball"

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = hole_radius
	shape.height = 0.3
	col.shape = shape
	col.rotation.x = deg_to_rad(90.0)
	hole.add_child(col)

	# Goal hole extras: ring and label on the wall surface.
	if is_goal:
		_add_ring(hole, hole_radius)
		_add_label(hole, number, hole_radius)

	hole.name = "Goal%d" % number if is_goal else "Trap_%d_%d" % [
		int(data["x"] * 100), int(data["y"] * 100)
	]
	add_child(hole)


func _add_ring(hole: Area3D, inner_radius: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = inner_radius
	# Keep the ring thin so it doesn't spill into neighbouring holes.
	torus.outer_radius = inner_radius + 0.035
	torus.rings = 24
	torus.ring_segments = 12
	ring.mesh = torus
	# Sit the ring on the wall's front face. The detector is (wall_thickness + 0.1)
	# behind that face, so offset by that much (plus a hair) to land just proud of it.
	ring.position = Vector3(0.0, 0.0, wall_thickness + 0.1 + 0.02)
	ring.rotation.x = deg_to_rad(90.0)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = goal_ring_color
	ring.material_override = ring_mat
	hole.add_child(ring)


func _add_label(hole: Area3D, number: int, radius: float) -> void:
	var label := Label3D.new()
	label.text = str(number)
	label.font_size = 40
	# Just above the ring and just proud of the wall's front face (see _add_ring).
	label.position = Vector3(0.0, radius + 0.07, wall_thickness + 0.1 + 0.03)
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.modulate = Color.WHITE
	label.outline_size = 8
	label.outline_modulate = Color.BLACK
	hole.add_child(label)
