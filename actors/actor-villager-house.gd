class_name ActorVillagerHouse
extends Node2D
## 4.7: Mephibosheth's house. The node origin is the middle of the door at ground level. The door glows
## once the way is open. Placeholder shapes.

const WALL: Color = Color(0.72, 0.62, 0.45)
const ROOF: Color = Color(0.5, 0.3, 0.2)

var open: bool = false:
	set(v):
		if open != v:
			open = v
			queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-130.0, -170.0, 260.0, 170.0), WALL)
	draw_colored_polygon(PackedVector2Array([Vector2(-160.0, -170.0), Vector2(160.0, -170.0), Vector2(0.0, -280.0)]), ROOF)
	draw_rect(Rect2(-35.0, -110.0, 70.0, 110.0), Color(1.0, 0.88, 0.45) if open else Color(0.25, 0.17, 0.12))
	if open:
		draw_arc(Vector2(0.0, -55.0), 80.0, 0.0, TAU, 24, Color(1.0, 0.9, 0.5, 0.5), 6.0)
