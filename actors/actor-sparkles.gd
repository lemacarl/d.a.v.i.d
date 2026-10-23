class_name ActorSparkles
extends Node2D
## A fixed pool of gold sparkles (four-point stars) that rise and fade. Bounded count, no per-frame
## allocation. The owner calls `advance(delta)`; `burst(...)` restarts a few of them.

const COUNT: int = 28
const LIFE_SEC: float = 1.6
const GOLD: Color = Color(1.0, 0.86, 0.35)

var _pos: PackedVector2Array = PackedVector2Array()
var _vel: PackedVector2Array = PackedVector2Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _size: PackedFloat32Array = PackedFloat32Array()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next: int = 0
var alive_count: int = 0


func _init() -> void:
	_rng.seed = 11
	_pos.resize(COUNT)
	_vel.resize(COUNT)
	_life.resize(COUNT)
	_size.resize(COUNT)


## Starts `n` sparkles (at most COUNT alive at once; the oldest are recycled) around `origin`.
func burst(origin: Vector2, spread: float, n: int) -> void:
	for i in mini(n, COUNT):
		var k: int = _next
		_next = (_next + 1) % COUNT
		_pos[k] = origin + Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread * 0.5, spread * 0.5))
		_vel[k] = Vector2(_rng.randf_range(-30.0, 30.0), _rng.randf_range(-90.0, -30.0))
		_life[k] = LIFE_SEC * _rng.randf_range(0.6, 1.0)
		_size[k] = _rng.randf_range(10.0, 22.0)
	_recount()


func advance(delta: float) -> void:
	if alive_count == 0:
		return
	for k in COUNT:
		if _life[k] > 0.0:
			_life[k] = maxf(_life[k] - delta, 0.0)
			_pos[k] += _vel[k] * delta
	_recount()
	queue_redraw()


func _recount() -> void:
	var n: int = 0
	for k in COUNT:
		if _life[k] > 0.0:
			n += 1
	alive_count = n


func _draw() -> void:
	for k in COUNT:
		if _life[k] <= 0.0:
			continue
		var a: float = clampf(_life[k] / LIFE_SEC * 1.6, 0.0, 1.0)
		var c: Color = Color(GOLD.r, GOLD.g, GOLD.b, a)
		var s: float = _size[k]
		draw_line(_pos[k] + Vector2(-s, 0.0), _pos[k] + Vector2(s, 0.0), c, 4.0)
		draw_line(_pos[k] + Vector2(0.0, -s), _pos[k] + Vector2(0.0, s), c, 4.0)
		draw_circle(_pos[k], s * 0.35, Color(1.0, 0.97, 0.8, a))
