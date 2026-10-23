class_name ActorSheep
extends Node2D
## Placeholder sheep: a white oval with a dark head. The stage owns all behaviour.

enum State { FLOCK, LOST, GONE }

const WOOL: Color = Color(0.95, 0.95, 0.92)
const HEAD: Color = Color(0.2, 0.2, 0.22)

var radius: float = 26.0
var state: State = State.FLOCK
## Resting spot the flock drifts around.
var home: Vector2 = Vector2.ZERO
var wander_phase: float = 0.0


func set_state(s: State) -> void:
	state = s
	visible = s != State.GONE
	modulate = Color(1.0, 0.85, 0.6) if s == State.LOST else Color.WHITE


func is_alive() -> bool:
	return state != State.GONE


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, WOOL)
	draw_circle(Vector2(radius * 0.9, -radius * 0.2), radius * 0.4, HEAD)
