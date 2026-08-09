extends RigidBody3D

## The ball on the Ice Cold Beer playfield.
##
## The real cabinet's playfield is tilted backward, so gravity has a component
## that presses the ball against the back panel. That "into the board" pressure
## is what makes the ball drop through a hole once the bar lines it up with one.
##
## We model the playfield as a vertical plane: real gravity (−Y) rolls the ball
## down onto the bar, but nothing pushes it into the board (−Z). Without that
## push the ball just skims across every hole and never falls in. This script
## supplies the missing into-the-board force so the holes actually catch it.

## Constant force pressing the ball toward the backboard (−Z, world space).
## Higher = the board grabs the ball more eagerly: easier to sink a goal, but
## the traps bite harder too. Tune it against the −Y gravity, whose magnitude
## is 9.8 * gravity_scale.
@export var board_pull: float = 10.0


func _ready() -> void:
	# constant_force is applied in global space every physics step and persists
	# until changed, so the ball's own rolling rotation never turns it. This is
	# what makes the ball settle against the backboard and fall through a hole
	# the instant the bar lines it up with one.
	constant_force = Vector3(0.0, 0.0, -board_pull)
