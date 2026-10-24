class_name ActorTree
extends Node2D
## 4.4: a tree in the valley of Rephaim. The node origin is the foot of the trunk. The stage sways it
## (`animate`) and lights the treetop while it rustles with a marching sound. Placeholder shapes.

const TRUNK: Color = Color(0.4, 0.27, 0.15)
const LEAVES: Color = Color(0.2, 0.45, 0.22)
const LEAVES_LIGHT: Color = Color(0.45, 0.7, 0.3)
const GLOW: Color = Color(1.0, 0.92, 0.55, 0.35)

var tree_height: float = 300.0
var phase: float = 0.0
var lit: bool = false:
	set(v):
		if lit != v:
			lit = v
			queue_redraw()


## Sways the tree about its foot: `amount` is the largest angle in radians, `speed` radians per second.
func animate(time_sec: float, amount: float, speed: float) -> void:
	rotation = sin(time_sec * speed + phase) * amount


func _draw() -> void:
	var h: float = tree_height
	draw_rect(Rect2(-h * 0.05, -h * 0.55, h * 0.1, h * 0.55), TRUNK)
	if lit:
		draw_circle(Vector2(0.0, -h * 0.75), h * 0.4, GLOW)
	draw_circle(Vector2(0.0, -h * 0.72), h * 0.3, LEAVES)
	draw_circle(Vector2(-h * 0.16, -h * 0.62), h * 0.2, LEAVES)
	draw_circle(Vector2(h * 0.16, -h * 0.62), h * 0.2, LEAVES)
	draw_circle(Vector2(0.0, -h * 0.82), h * 0.2, LEAVES_LIGHT if lit else LEAVES.lightened(0.1))
