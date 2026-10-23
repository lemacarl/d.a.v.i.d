class_name ActorRaider
extends Node2D
## Placeholder Amalekite raider at Ziklag. A hit makes him run away (no gore). The stage owns the
## behaviour; this node only stores state and draws.

enum State { CHASE, AFRAID, AWAY, GONE }

const BODY: Color = Color(0.4, 0.18, 0.18)
const SKIN: Color = Color(0.8, 0.6, 0.45)
const WRAP: Color = Color(0.75, 0.7, 0.55)

var radius: float = 34.0
var state: State = State.CHASE
## Seconds left in the current state (AFRAID, or the wait before returning once AWAY).
var timer: float = 0.0
## Direction he runs in once hit (set by the stage).
var away: Vector2 = Vector2.RIGHT
var glow: bool = false:
	set(v):
		if glow != v:
			glow = v
			queue_redraw()


func is_hostile() -> bool:
	return state == State.CHASE


func _draw() -> void:
	if glow:
		draw_circle(Vector2.ZERO, radius * 1.6, Color(1.0, 0.8, 0.2, 0.25))
	draw_rect(Rect2(-radius * 0.7, -radius * 0.2, radius * 1.4, radius * 1.3), BODY)
	draw_circle(Vector2(0, -radius * 0.55), radius * 0.45, SKIN)
	draw_rect(Rect2(-radius * 0.55, -radius * 1.0, radius * 1.1, radius * 0.35), WRAP)
