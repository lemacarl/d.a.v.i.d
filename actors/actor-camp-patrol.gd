class_name ActorCampPatrol
extends Node2D
## One of Saul's patrols: two soldiers who walk onto the field, look around and leave.
## The stage owns the path and the noticing; this is a body plus a flag for the warning.

enum Phase { AWAY, IN, LOOK, OUT }

const ARMOR: Color = Color(0.55, 0.15, 0.15)
const HELM: Color = Color(0.7, 0.7, 0.75)
const SIGHT: Color = Color(1.0, 0.3, 0.3, 0.12)

var phase: Phase = Phase.AWAY
var sight_px: float = 0.0
var look_left: float = 0.0
var exposure: float = 0.0
## The y row this patrol walks along.
var lane_y: float = 0.0


func is_present() -> bool:
	return phase != Phase.AWAY


func _draw() -> void:
	if sight_px > 0.0:
		draw_circle(Vector2.ZERO, sight_px, SIGHT)
	for i in 2:
		var o: Vector2 = Vector2(float(i) * 44.0, float(i) * 16.0)
		draw_rect(Rect2(o.x - 18.0, o.y - 6.0, 36.0, 44.0), ARMOR)
		draw_circle(o + Vector2(0, -16.0), 15.0, HELM)
