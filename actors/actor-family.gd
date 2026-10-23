class_name ActorFamily
extends Node2D
## Placeholder family at Ziklag: a few small figures. Tied until freed; once freed they follow
## David as a helper for the rest of the stage. The stage owns all behaviour.

const COATS: Array[Color] = [Color(0.8, 0.55, 0.3), Color(0.35, 0.6, 0.7), Color(0.75, 0.4, 0.5)]
const SKIN: Color = Color(0.87, 0.68, 0.5)

var radius: float = 36.0
var freed: bool = false:
	set(v):
		if freed != v:
			freed = v
			queue_redraw()
## Offset in the follower ring around David (set by the stage when freed).
var ring_angle: float = 0.0
var ring_index: int = 0
var throw_left: float = 0.0


func _draw() -> void:
	for i in COATS.size():
		var x: float = (float(i) - 1.0) * radius * 0.7
		var h: float = radius * (0.9 if i == 1 else 0.65)
		draw_rect(Rect2(x - radius * 0.2, -h * 0.2, radius * 0.4, h), COATS[i])
		draw_circle(Vector2(x, -h * 0.35), radius * 0.22, SKIN)
	if freed:
		draw_arc(Vector2.ZERO, radius * 1.2, 0.0, TAU, 20, Color(1.0, 0.9, 0.4, 0.5), 3.0)
	else:
		# Tied hands: a small dark band across the group.
		draw_line(Vector2(-radius, radius * 0.25), Vector2(radius, radius * 0.25), Color(0.3, 0.22, 0.12), 4.0)
