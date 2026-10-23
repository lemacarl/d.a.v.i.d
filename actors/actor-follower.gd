class_name ActorFollower
extends Node2D
## Placeholder camp follower (one figure stands for about twenty men). The stage places it on a ring
## around the cave; `ring` is its unscaled offset, scaled by the follow-distance modifier.

const CLOAKS: Array[Color] = [Color(0.55, 0.4, 0.28), Color(0.4, 0.45, 0.55), Color(0.5, 0.5, 0.35), Color(0.55, 0.35, 0.35)]
const SKIN: Color = Color(0.82, 0.62, 0.45)

var radius: float = 20.0
## Unscaled offset from the cave mouth.
var ring: Vector2 = Vector2.ZERO
var tone: int = 0


func _draw() -> void:
	draw_rect(Rect2(-radius * 0.7, -radius * 0.2, radius * 1.4, radius * 1.1), CLOAKS[tone % CLOAKS.size()])
	draw_circle(Vector2(0, -radius * 0.55), radius * 0.5, SKIN)
