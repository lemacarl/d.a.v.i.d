class_name ActorChargeLane
extends Node2D
## The bear's warning lane: a red band across the floor with bright edges and chevrons that run
## the way the bear will charge. Origin is the lane's left end on its centre line.
## `strong` (Watchful Eyes) makes it brighter and bolder; `dimmed` quiets it while the bear runs.

const FILL: Color = Color(1.0, 0.12, 0.1)
const EDGE: Color = Color(1.0, 0.85, 0.15)
const CHEVRON: Color = Color(1.0, 0.95, 0.75)
const SPACING: float = 170.0
const SLIDE_PX_PER_SEC: float = 420.0

var length: float = 1728.0
var half_height: float = 100.0
var dir: float = 1.0
var strong: bool = false
var dimmed: bool = false
var _t: float = 0.0


func show_lane(active: bool) -> void:
	visible = active
	set_process(active)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_t * 9.0)
	var base: float = 0.38 if not strong else 0.58
	var a: float = (base + 0.14 * pulse) * (0.5 if dimmed else 1.0)
	draw_rect(Rect2(0, -half_height, length, half_height * 2.0), Color(FILL.r, FILL.g, FILL.b, a))
	var edge_a: float = 0.95 * (0.6 if dimmed else 1.0)
	var ew: float = 10.0 if strong else 7.0
	draw_line(Vector2(0, -half_height), Vector2(length, -half_height), Color(EDGE.r, EDGE.g, EDGE.b, edge_a), ew)
	draw_line(Vector2(0, half_height), Vector2(length, half_height), Color(EDGE.r, EDGE.g, EDGE.b, edge_a), ew)
	var arm: float = 56.0 if strong else 44.0
	var cw: float = 12.0 if strong else 9.0
	var cc: Color = Color(CHEVRON.r, CHEVRON.g, CHEVRON.b, 0.9 * (0.55 if dimmed else 1.0))
	var n: int = int(length / SPACING)
	var slide: float = _t * SLIDE_PX_PER_SEC
	for i in n:
		var x: float = fposmod(slide + float(i) * SPACING, length)
		if dir < 0.0:
			x = length - x
		var tip: Vector2 = Vector2(x, 0)
		draw_line(tip, Vector2(x - dir * arm * 0.7, -arm), cc, cw)
		draw_line(tip, Vector2(x - dir * arm * 0.7, arm), cc, cw)
