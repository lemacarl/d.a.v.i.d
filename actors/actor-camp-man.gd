class_name ActorCampMan
extends Node2D
## A man of the camp who can be sent to gather food or water. The stage drives the trip.

enum State { IDLE, SELECTED, OUT, WORK, BACK }

const CLOAK: Color = Color(0.6, 0.45, 0.25)
const SKIN: Color = Color(0.82, 0.62, 0.45)
const RING: Color = Color(1.0, 0.85, 0.3)

var radius: float = 26.0
var state: State = State.IDLE
## Where he waits in camp.
var home: Vector2 = Vector2.ZERO
## Where he is going on a trip and what he carries back (&"food" or &"water").
var goal: Vector2 = Vector2.ZERO
var kind: StringName = &""
var work_left: float = 0.0
var spot: int = -1


func is_out() -> bool:
	return state == State.OUT or state == State.WORK or state == State.BACK


func set_state(s: State) -> void:
	state = s
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-radius * 0.7, -radius * 0.2, radius * 1.4, radius * 1.2), CLOAK)
	draw_circle(Vector2(0, -radius * 0.55), radius * 0.5, SKIN)
	if state == State.SELECTED:
		draw_arc(Vector2.ZERO, radius * 1.5, 0.0, TAU, 24, RING, 5.0)
	elif state == State.WORK or state == State.BACK:
		var c: Color = Color(0.4, 0.75, 0.35) if kind == &"food" else Color(0.35, 0.6, 0.9)
		draw_circle(Vector2(radius * 0.9, 0), radius * 0.35, c)
