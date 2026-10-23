class_name ActorTarget
extends Node2D
## Placeholder practice target for the throw tutorial: a wooden post with a round board.
## The node origin is the centre of the board (that is where the stone flies). `hit()` pops it.

const POP_SEC: float = 0.6
const BOARD_RADIUS: float = 52.0

var _pop_left: float = 0.0
var _pop_color: Color = Color(1.0, 0.85, 0.3)


## Plays the hit pop (a burst of rays and a wobble). `color` is the burst colour.
func hit(color: Color = Color(1.0, 0.85, 0.3)) -> void:
	_pop_left = POP_SEC
	_pop_color = color
	queue_redraw()


func is_popping() -> bool:
	return _pop_left > 0.0


func advance(delta: float) -> void:
	if _pop_left <= 0.0:
		return
	_pop_left = maxf(_pop_left - delta, 0.0)
	rotation = sin(_pop_left * 40.0) * 0.12 * (_pop_left / POP_SEC)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-12.0, BOARD_RADIUS - 6.0, 24.0, 150.0), Color(0.5, 0.33, 0.15))
	draw_circle(Vector2.ZERO, BOARD_RADIUS + 6.0, Color(0.35, 0.22, 0.1))
	draw_circle(Vector2.ZERO, BOARD_RADIUS, Color(0.85, 0.2, 0.2))
	draw_circle(Vector2.ZERO, BOARD_RADIUS * 0.7, Color(0.97, 0.95, 0.9))
	draw_circle(Vector2.ZERO, BOARD_RADIUS * 0.42, Color(0.85, 0.2, 0.2))
	draw_circle(Vector2.ZERO, BOARD_RADIUS * 0.16, Color(0.97, 0.95, 0.9))
	if _pop_left > 0.0:
		var k: float = 1.0 - _pop_left / POP_SEC
		var c: Color = Color(_pop_color.r, _pop_color.g, _pop_color.b, 1.0 - k)
		for i in 10:
			var d: Vector2 = Vector2.from_angle(TAU * float(i) / 10.0)
			draw_line(d * (BOARD_RADIUS * (0.9 + k)), d * (BOARD_RADIUS * (1.5 + k * 1.3)), c, 7.0)
		draw_arc(Vector2.ZERO, BOARD_RADIUS * (1.0 + k * 1.2), 0.0, TAU, 24, c, 5.0)
