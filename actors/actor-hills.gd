class_name ActorHills
extends ActorScene
## 1.1: dawn over green hills. A boy (David) sits on a rock with a harp; sheep graze; the sun rises.

const HORIZON_Y: float = 560.0
const SUN_FROM: Vector2 = Vector2(1480, 600)
const SUN_TO: Vector2 = Vector2(1480, 360)
const SUN_RISE_SEC: float = 9.0
## Where a rescued sheep rejoins the flock.
const RETURN_SPOT: Vector2 = Vector2(610, 740)
const SHEEP_SPOTS: Array[Vector2] = [Vector2(740, 700), Vector2(930, 770), Vector2(1170, 690), Vector2(1400, 780), Vector2(1620, 710)]

var boy: ActorFigure = null
var sheep: Array[ActorSheep] = []
var returned_sheep: ActorSheep = null
var _sun: Polygon2D = null
var _halo: Polygon2D = null
var _clock: float = 0.0
var _rising: bool = false


func _init() -> void:
	_halo = StageUtil.make_disc(self, SUN_FROM, 190.0, Color(1.0, 0.85, 0.5, 0.28))
	_sun = StageUtil.make_disc(self, SUN_FROM, 95.0, Color(1.0, 0.93, 0.62))
	boy = ActorFigure.new()
	boy.setup(110.0, Color(0.25, 0.4, 0.75), Color(0.45, 0.28, 0.12))
	boy.harp = true
	boy.seated = true
	boy.position = Vector2(430, 700)
	add_child(boy)
	for p in SHEEP_SPOTS:
		var s: ActorSheep = ActorSheep.new()
		s.position = p
		s.home = p
		s.wander_phase = p.x * 0.01
		add_child(s)
		sheep.append(s)
	returned_sheep = ActorSheep.new()
	returned_sheep.position = RETURN_SPOT
	returned_sheep.visible = false
	add_child(returned_sheep)
	_place_sun(0.0)


func sheep_returned() -> void:
	returned_sheep.visible = true


func play(action: StringName) -> void:
	if action == &"show":
		_rising = true


func begin_play() -> void:
	boy.visible = false


func advance(delta: float) -> void:
	_clock += delta
	if _rising:
		_place_sun(minf(_clock / SUN_RISE_SEC, 1.0))
	# Grazing: a slow nod of every sheep.
	for s in sheep:
		s.position.y = s.home.y + sin(_clock * 1.6 + s.wander_phase) * 3.0
		s.rotation = sin(_clock * 0.9 + s.wander_phase) * 0.05


func _place_sun(k: float) -> void:
	var p: Vector2 = SUN_FROM.lerp(SUN_TO, k)
	_sun.position = p
	_halo.position = p


func _draw() -> void:
	var w: float = SCREEN.x
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, HORIZON_Y), Vector2(0, HORIZON_Y)]),
		PackedColorArray([Color(0.45, 0.62, 0.85), Color(0.45, 0.62, 0.85), Color(1.0, 0.82, 0.55), Color(1.0, 0.82, 0.55)]))
	draw_colored_polygon(_hill(-0.1, 150.0, 2.2, 40.0), Color(0.55, 0.68, 0.55))
	draw_colored_polygon(_hill(1.3, 110.0, 3.1, 90.0), Color(0.4, 0.6, 0.38))
	draw_rect(Rect2(0, HORIZON_Y + 30.0, w, SCREEN.y - HORIZON_Y - 30.0), Color(0.36, 0.6, 0.27))
	draw_rect(Rect2(0, 900, w, 180), Color(0.31, 0.53, 0.23))
	# The rock the boy sits on.
	draw_colored_polygon(PackedVector2Array([Vector2(330, 720), Vector2(360, 672), Vector2(470, 666), Vector2(525, 720)]), Color(0.52, 0.5, 0.48))
	draw_colored_polygon(PackedVector2Array([Vector2(360, 672), Vector2(470, 666), Vector2(445, 682), Vector2(380, 686)]), Color(0.66, 0.64, 0.6))
	for i in 14:
		var gx: float = 120.0 + float(i) * 130.0
		var gy: float = 820.0 + float((i * 47) % 150)
		draw_line(Vector2(gx, gy), Vector2(gx - 8, gy - 22), Color(0.22, 0.45, 0.18), 4.0)
		draw_line(Vector2(gx, gy), Vector2(gx + 8, gy - 20), Color(0.22, 0.45, 0.18), 4.0)


func _hill(phase: float, amp: float, freq: float, lift: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 24
	for i in steps + 1:
		var x: float = SCREEN.x * float(i) / float(steps)
		pts.append(Vector2(x, HORIZON_Y + 60.0 - lift - amp * (0.5 + 0.5 * sin(x / SCREEN.x * freq * PI + phase))))
	pts.append(Vector2(SCREEN.x, HORIZON_Y + 80.0))
	pts.append(Vector2(0.0, HORIZON_Y + 80.0))
	return pts
