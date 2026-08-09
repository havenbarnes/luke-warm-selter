extends Area3D

## A single hole on the Ice Cold Beer playfield.
## Goal holes have a number (1–10) and are the objective.
## Trap holes (number = 0) cost you a life.
##
## When the ball overlaps this hole, its collisions are disabled so it
## physically falls through the bar under gravity.

signal ball_entered_hole(hole: Area3D)

## 0 = trap hole. 1–10 = goal hole.
@export var hole_number: int = 0

## Visual radius of the hole.
@export var hole_radius: float = 0.2

var is_goal: bool:
	get: return hole_number > 0

## Prevents re-triggering while the ball is already falling.
var _triggered := false


func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _triggered:
		return
	if body.name != "Ball" or not body is RigidBody3D:
		return

	_triggered = true
	var ball := body as RigidBody3D

	# Kill the ball's sideways velocity so it drops straight down.
	ball.linear_velocity = Vector3(0.0, ball.linear_velocity.y, 0.0)

	# Disable all collision — the ball falls through the bar and everything.
	ball.collision_layer = 0
	ball.collision_mask = 0

	ball_entered_hole.emit(self)

	if is_goal:
		print("GOAL! Reached hole %d" % hole_number)
	else:
		print("TRAP! Fell into a trap hole.")


## Call this from your game manager when resetting the ball.
func reset() -> void:
	_triggered = false
