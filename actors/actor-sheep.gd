class_name ActorSheep
extends Node2D
## Placeholder sheep: a white oval with a dark head. The stage owns flock behaviour; the sheep
## walks itself back to the flock after a rescue (`rescue`) and shows a brief gold sparkle ring.

enum State { FLOCK, LOST, GONE }

const WOOL: Color = Color(0.95, 0.95, 0.92)
const HEAD: Color = Color(0.2, 0.2, 0.22)
const SPARKLE: Color = Color(1.0, 0.85, 0.3)
const SPARKLE_SEC: float = 0.8
const ARRIVE_PX: float = 4.0

var radius: float = 26.0
var state: State = State.FLOCK
## Resting spot the flock drifts around.
var home: Vector2 = Vector2.ZERO
var wander_phase: float = 0.0
## Offset from the flock centre (or from David with Shepherd's Staff).
var ring: Vector2 = Vector2.ZERO
## True while walking straight back to the flock after a rescue.
var returning: bool = false

var _return_target: Vector2 = Vector2.ZERO
var _return_speed: float = 0.0
var _sparkle_left: float = 0.0


func set_state(s: State) -> void:
	state = s
	visible = s != State.GONE
	modulate = Color(1.0, 0.85, 0.6) if s == State.LOST else Color.WHITE
	if s != State.FLOCK:
		returning = false


func is_alive() -> bool:
	return state != State.GONE


## Rescued: back in the flock at once, walking straight to `target` at `speed` px/s with a gold
## sparkle ring. In the tree the sheep walks itself; outside it (tests) call `advance_return`.
func rescue(target: Vector2, speed: float) -> void:
	set_state(State.FLOCK)
	home = target
	_return_target = target
	_return_speed = speed
	returning = position.distance_to(target) > ARRIVE_PX
	_sparkle_left = SPARKLE_SEC
	set_process(true)
	queue_redraw()


## Moves one step toward the flock. Returns true while still walking.
func advance_return(delta: float) -> bool:
	if not returning:
		return false
	position = position.move_toward(_return_target, _return_speed * delta)
	if position.distance_to(_return_target) <= ARRIVE_PX:
		position = _return_target
		returning = false
	return returning


func _process(delta: float) -> void:
	if returning:
		advance_return(delta)
	if _sparkle_left > 0.0:
		_sparkle_left = maxf(0.0, _sparkle_left - delta)
		queue_redraw()
	if not returning and _sparkle_left <= 0.0:
		set_process(false)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, WOOL)
	draw_circle(Vector2(radius * 0.9, -radius * 0.2), radius * 0.4, HEAD)
	if _sparkle_left > 0.0:
		var k: float = 1.0 - _sparkle_left / SPARKLE_SEC
		var r: float = radius * (1.3 + 2.2 * k)
		var c: Color = Color(SPARKLE.r, SPARKLE.g, SPARKLE.b, 1.0 - k)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, c, 6.0)
		for i in 6:
			draw_circle(Vector2.from_angle(TAU * float(i) / 6.0 + k * 1.5) * r, 7.0 * (1.0 - k) + 2.0, c)
