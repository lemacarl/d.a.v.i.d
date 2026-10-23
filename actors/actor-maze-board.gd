class_name ActorMazeBoard
extends Node2D
## 4.3: the stone floor and walls of the Jerusalem tunnels and the water shaft. Drawn once from a flat
## wall array (1 = wall); no per-frame work and no nodes per tile.

const FLOOR: Color = Color(0.42, 0.36, 0.28)
const FLOOR_ALT: Color = Color(0.46, 0.4, 0.31)
const WALL: Color = Color(0.2, 0.18, 0.2)
const WALL_TOP: Color = Color(0.3, 0.27, 0.3)
const SHAFT: Color = Color(0.05, 0.12, 0.2)
const WATER: Color = Color(0.25, 0.55, 0.85)
const RUNG: Color = Color(0.6, 0.45, 0.25)

var cols: int = 0
var rows: int = 0
var tile: float = 80.0
var walls: PackedByteArray = PackedByteArray()
var goal_cell: Vector2i = Vector2i(-1, -1)


func configure(wall_data: PackedByteArray, c: int, r: int, tile_px: float, goal: Vector2i) -> void:
	walls = wall_data
	cols = c
	rows = r
	tile = tile_px
	goal_cell = goal
	queue_redraw()


func _draw() -> void:
	for y in rows:
		for x in cols:
			var rect: Rect2 = Rect2(float(x) * tile, float(y) * tile, tile, tile)
			if walls[y * cols + x] != 0:
				draw_rect(rect, WALL)
				draw_rect(Rect2(rect.position, Vector2(tile, tile * 0.18)), WALL_TOP)
			else:
				draw_rect(rect, FLOOR if (x + y) % 2 == 0 else FLOOR_ALT)
	if goal_cell.x < 0:
		return
	var c: Vector2 = (Vector2(goal_cell) + Vector2(0.5, 0.5)) * tile
	draw_rect(Rect2(c - Vector2(tile, tile) * 0.5, Vector2(tile, tile)), SHAFT)
	draw_circle(c, tile * 0.36, WATER)
	draw_circle(c, tile * 0.24, SHAFT)
	for i in 3:
		var y: float = c.y - tile * 0.2 + float(i) * tile * 0.2
		draw_line(Vector2(c.x - tile * 0.24, y), Vector2(c.x + tile * 0.24, y), RUNG, 4.0)
