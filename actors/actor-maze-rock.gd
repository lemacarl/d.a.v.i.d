class_name ActorMazeRock
extends Node2D
## 4.3: a rock that falls onto a marked tile. Placeholder grey boulder; the stage moves it.

const BODY: Color = Color(0.46, 0.44, 0.43)
const SHADE: Color = Color(0.32, 0.3, 0.3)

var radius: float = 28.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, SHADE)
	draw_circle(Vector2(-radius * 0.1, -radius * 0.12), radius * 0.86, BODY)
	draw_circle(Vector2(radius * 0.25, radius * 0.1), radius * 0.2, SHADE)
