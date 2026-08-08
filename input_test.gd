extends Node

## Drop this on any node and run. Hold Q, then P, then both.
##
## Watch the AXIS values. Holding Q and P together should give:
##     axisL=+1.0  axisR=+1.0
##
## If it gives axisL=0.0 axisR=0.0, a key is bound to BOTH the up and the
## down action for that side, and they are cancelling each other out.
## The DOWN columns will show which key is the culprit.

var _last := ""


func _process(_delta: float) -> void:
	var lu := Input.is_action_pressed("bar_left_up")
	var ld := Input.is_action_pressed("bar_left_down")
	var ru := Input.is_action_pressed("bar_right_up")
	var rd := Input.is_action_pressed("bar_right_down")

	var axis_l := Input.get_axis("bar_left_down", "bar_left_up")
	var axis_r := Input.get_axis("bar_right_down", "bar_right_up")

	var line := "keys Q=%s A=%s P=%s L=%s | actions LU=%s LD=%s RU=%s RD=%s | axisL=%+.1f axisR=%+.1f" % [
		Input.is_key_pressed(KEY_Q),
		Input.is_key_pressed(KEY_A),
		Input.is_key_pressed(KEY_P),
		Input.is_key_pressed(KEY_L),
		lu, ld, ru, rd,
		axis_l, axis_r,
	]

	if line != _last:
		_last = line
		print(line)
