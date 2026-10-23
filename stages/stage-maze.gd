class_name StageMaze
extends StagePlayBase
## Stage type `maze` (4.3, Jerusalem). A tile maze made deterministically from `mazeSeed`; the water shaft
## (the goal) is the cell farthest from the start, so every maze is solvable. Guards stand on the top wall
## and drop rocks on marked tiles of the route: the tile flashes (telegraph, longer with Watchful Eyes), then
## a rock falls at `rockSpeed` px/s and a rock that lands on David's tile costs `rockHitHearts`. Lamb
## (`rockDropEnabled` false, or enemies off) has the guards but no rocks. Hidden arrows on the floor fade in
## near David and point along the way to the shaft. A guard is passed when David gets beyond its last marked
## tile without one of its rocks having hit him: `report_spared()`, once per guard. Reaching the shaft wins.
## Params: gridCols, gridRows (or grid{w,h}), mazeSeed, walkSpeed, goal, hintArrows, rockDropEnabled,
## rockTiles{count} (or a number), rockDropIntervalSec, rockSpeed, rockHitHearts, guardCount,
## rockTelegraphSec, rockFallPx. Events: `enter`, `win`. All nodes are made in setup and reused.

const TILE: float = 80.0
## Half the size of David's collision box (the corridor is one tile wide).
const HALF: float = 22.0
const GUARD_MAX: int = 6
const ROCK_TILE_MAX: int = 16
const ARROW_MAX: int = 24
const DEFAULT_COLS: int = 15
const DEFAULT_ROWS: int = 11
const DEFAULT_WALK: float = 280.0
const DEFAULT_ROCK_SPEED: float = 260.0
const DEFAULT_FALL_PX: float = 260.0
const DEFAULT_TELEGRAPH_SEC: float = 1.2
const DEFAULT_INTERVAL_SEC: float = 3.0
const LAND_SEC: float = 0.5
const REVEAL_PX: float = 230.0
const GOAL_REACH: float = 34.0
const HOLD_MAX_SEC: float = 25.0
const ORIGIN_Y: float = 150.0

enum GuardState { IDLE, WARN, FALL, LAND }

var cols: int = DEFAULT_COLS
var rows: int = DEFAULT_ROWS
var walls: PackedByteArray = PackedByteArray()
var start_cell: Vector2i = Vector2i(1, 1)
var goal_cell: Vector2i = Vector2i(1, 1)
## Cells from the start to the shaft, inclusive.
var solution: Array[Vector2i] = []
var rock_cells: Array[Vector2i] = []
var guards: Array[ActorGuard] = []
var rocks: Array[ActorMazeRock] = []
var arrows: Array[Polygon2D] = []
var marks: Array[Polygon2D] = []
var drops_enabled: bool = true
var spared_count: int = 0
var rocks_landed: int = 0
var rock_hits: int = 0
var progress: int = 0

var _origin: Vector2 = Vector2.ZERO
var _prog: PackedInt32Array = PackedInt32Array()
var _board: ActorMazeBoard = null
var _guard_tiles: Array = []
var _guard_last_prog: PackedInt32Array = PackedInt32Array()
var _guard_done: PackedByteArray = PackedByteArray()
var _guard_hit: PackedByteArray = PackedByteArray()
var _gstate: PackedInt32Array = PackedInt32Array()
var _gtimer: PackedFloat32Array = PackedFloat32Array()
var _gtile: PackedInt32Array = PackedInt32Array()
var _rock_speed: float = DEFAULT_ROCK_SPEED
var _fall_px: float = DEFAULT_FALL_PX
var _telegraph: float = DEFAULT_TELEGRAPH_SEC
var _interval: float = DEFAULT_INTERVAL_SEC
var _hit_hearts: int = 1
var _lines_ready: bool = true
var _hold_clock: float = 0.0


func setup(stage_def: StageDef, run_model: RunModel, stack: ModifierStack) -> void:
	super(stage_def, run_model, stack)
	_walk_speed_base = def.param_float("walkSpeed", DEFAULT_WALK)
	cols = maxi(5, def.param_int("gridCols", def.param_int("grid.w", DEFAULT_COLS)))
	rows = maxi(5, def.param_int("gridRows", def.param_int("grid.h", DEFAULT_ROWS)))
	var seed_value: int = def.param_int("mazeSeed", absi(String(def.id).hash()))
	_rng.seed = seed_value
	drops_enabled = def.param_bool("rockDropEnabled", true) and enemies_enabled()
	_rock_speed = maxf(def.param_float("rockSpeed", DEFAULT_ROCK_SPEED), 1.0)
	_fall_px = def.param_float("rockFallPx", DEFAULT_FALL_PX)
	_interval = def.param_float("rockDropIntervalSec", DEFAULT_INTERVAL_SEC)
	_telegraph = def.param_float("rockTelegraphSec", DEFAULT_TELEGRAPH_SEC) + maxf(float(get_feature(&"enemyTelegraphSec", 0.0)), 0.0)
	_hit_hearts = maxi(1, def.param_int("rockHitHearts", 1))
	spared_count = 0
	rocks_landed = 0
	rock_hits = 0
	progress = 0
	_hold_clock = 0.0
	_lines_ready = not wait_for_lines
	solution.clear()
	rock_cells.clear()
	guards.clear()
	rocks.clear()
	arrows.clear()
	marks.clear()
	_origin = Vector2((StageUtil.SCREEN.x - float(cols) * TILE) * 0.5, ORIGIN_Y)
	walls = StageMaze.generate(cols, rows, seed_value)
	start_cell = Vector2i(1, rows - 2 - (1 - rows % 2))
	goal_cell = _farthest_from(start_cell)
	_build_route()
	backdrop.color = Color(0.16, 0.14, 0.16)
	_board = ActorMazeBoard.new()
	_board.position = _origin
	_board.configure(walls, cols, rows, TILE, goal_cell)
	world.add_child(_board)
	_build_marks()
	_build_arrows()
	_build_guards()
	david.position = tile_center(start_cell)
	world.move_child(david, -1)
	for r in rocks:
		world.move_child(r, -1)


func _on_begin() -> void:
	spawn_companion_if_blessed()
	_apply_visuals(play_event(&"enter"))


func on_lines_drained() -> void:
	_lines_ready = true


# ---- Maze data -------------------------------------------------------------------------------------

## A perfect maze with a few extra openings, as a flat array (1 = wall) of `c` x `r` tiles. Cells sit at odd
## coordinates, so an even size leaves a wall border on the far side. Same seed, same maze.
static func generate(c: int, r: int, seed_value: int) -> PackedByteArray:
	var w: PackedByteArray = PackedByteArray()
	w.resize(c * r)
	w.fill(1)
	var cw: int = (c - 1) / 2
	var ch: int = (r - 1) / 2
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(cw * ch)
	var stack: Array[Vector2i] = [Vector2i(0, 0)]
	seen[0] = 1
	w[1 * c + 1] = 0
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not stack.is_empty():
		var cur: Vector2i = stack[stack.size() - 1]
		var options: Array[Vector2i] = []
		for d in dirs:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.y >= 0 and n.x < cw and n.y < ch and seen[n.y * cw + n.x] == 0:
				options.append(d)
		if options.is_empty():
			stack.pop_back()
			continue
		var pick: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		var nxt: Vector2i = cur + pick
		w[(2 * cur.y + 1 + pick.y) * c + (2 * cur.x + 1 + pick.x)] = 0
		w[(2 * nxt.y + 1) * c + (2 * nxt.x + 1)] = 0
		seen[nxt.y * cw + nxt.x] = 1
		stack.append(nxt)
	# A few loops so there is more than one way round (a wall between two floor tiles).
	var extra: int = (cw * ch) / 8
	var tries: int = 0
	while extra > 0 and tries < 200:
		tries += 1
		var x: int = rng.randi_range(1, c - 2)
		var y: int = rng.randi_range(1, r - 2)
		if (x + y) % 2 == 1 and w[y * c + x] == 1 and x % 2 != y % 2 and _floor_both_sides(w, c, x, y):
			w[y * c + x] = 0
			extra -= 1
	return w


static func _floor_both_sides(w: PackedByteArray, c: int, x: int, y: int) -> bool:
	if x % 2 == 0:
		return w[y * c + x - 1] == 0 and w[y * c + x + 1] == 0
	return w[(y - 1) * c + x] == 0 and w[(y + 1) * c + x] == 0


## Walking distance in tiles from `from` to every tile (-1 = wall or not reachable).
static func distances(w: PackedByteArray, c: int, r: int, from: Vector2i) -> PackedInt32Array:
	var dist: PackedInt32Array = PackedInt32Array()
	dist.resize(c * r)
	dist.fill(-1)
	if w[from.y * c + from.x] != 0:
		return dist
	var queue: Array[Vector2i] = [from]
	dist[from.y * c + from.x] = 0
	var head: int = 0
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d in dirs:
			var n: Vector2i = cur + d
			if n.x < 0 or n.y < 0 or n.x >= c or n.y >= r:
				continue
			var i: int = n.y * c + n.x
			if w[i] == 0 and dist[i] < 0:
				dist[i] = dist[cur.y * c + cur.x] + 1
				queue.append(n)
	return dist


static func is_solvable(w: PackedByteArray, c: int, r: int, a: Vector2i, b: Vector2i) -> bool:
	return distances(w, c, r, a)[b.y * c + b.x] >= 0


func _farthest_from(from: Vector2i) -> Vector2i:
	var dist: PackedInt32Array = StageMaze.distances(walls, cols, rows, from)
	var best: Vector2i = from
	var best_d: int = 0
	for y in rows:
		for x in cols:
			var d: int = dist[y * cols + x]
			if d > best_d and x % 2 == 1 and y % 2 == 1:
				best_d = d
				best = Vector2i(x, y)
	return best


## The route from the start to the shaft, and for every floor tile how far along the route it branches off.
func _build_route() -> void:
	var dist: PackedInt32Array = StageMaze.distances(walls, cols, rows, start_cell)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var back: Array[Vector2i] = [goal_cell]
	var cur: Vector2i = goal_cell
	while cur != start_cell:
		var d_here: int = dist[cur.y * cols + cur.x]
		for d in dirs:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.y >= 0 and n.x < cols and n.y < rows and dist[n.y * cols + n.x] == d_here - 1:
				cur = n
				break
		back.append(cur)
	for i in range(back.size() - 1, -1, -1):
		solution.append(back[i])
	_prog.resize(cols * rows)
	_prog.fill(-1)
	var queue: Array[Vector2i] = []
	for i in solution.size():
		_prog[solution[i].y * cols + solution[i].x] = i
		queue.append(solution[i])
	var head: int = 0
	while head < queue.size():
		var q: Vector2i = queue[head]
		head += 1
		for d in dirs:
			var n: Vector2i = q + d
			if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows:
				continue
			var i: int = n.y * cols + n.x
			if walls[i] == 0 and _prog[i] < 0:
				_prog[i] = _prog[q.y * cols + q.x]
				queue.append(n)


func tile_center(cell: Vector2i) -> Vector2:
	return _origin + (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


func cell_of(pos: Vector2) -> Vector2i:
	var p: Vector2 = (pos - _origin) / TILE
	return Vector2i(int(floorf(p.x)), int(floorf(p.y)))


func is_floor(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows and walls[cell.y * cols + cell.x] == 0


# ---- Building ----------------------------------------------------------------------------------------

func _rock_tile_count() -> int:
	var v: Variant = def.param("rockTiles", 6)
	var n: int = 6
	if v is Dictionary:
		n = int((v as Dictionary).get("count", 6))
	elif v is float or v is int:
		n = int(v)
	return clampi(n, 0, mini(ROCK_TILE_MAX, maxi(solution.size() - 6, 0)))


## Marked tiles are spread along the route (never beside the start or the shaft).
func _build_marks() -> void:
	var n: int = _rock_tile_count()
	var span: float = float(solution.size() - 6)
	for i in n:
		var idx: int = 3 + int(floorf(span * (float(i) + 0.5) / float(n)))
		rock_cells.append(solution[idx])
		var m: Polygon2D = Polygon2D.new()
		m.polygon = PackedVector2Array([Vector2(0, -26), Vector2(26, 0), Vector2(0, 26), Vector2(-26, 0)])
		m.color = Color(0.85, 0.22, 0.18, 0.9)
		m.position = tile_center(solution[idx])
		m.modulate.a = 0.3
		m.visible = drops_enabled
		world.add_child(m)
		marks.append(m)


func _build_arrows() -> void:
	if not def.param_bool("hintArrows", true) or solution.size() < 6:
		return
	var step: int = maxi(3, int(ceilf(float(solution.size()) / float(ARROW_MAX))))
	var shape: PackedVector2Array = PackedVector2Array([Vector2(-18, -9), Vector2(2, -9), Vector2(2, -20), Vector2(24, 0), Vector2(2, 20), Vector2(2, 9), Vector2(-18, 9)])
	var i: int = 2
	while i < solution.size() - 1 and arrows.size() < ARROW_MAX:
		var a: Polygon2D = Polygon2D.new()
		a.polygon = shape
		a.color = Color(1.0, 0.88, 0.45, 0.9)
		a.position = tile_center(solution[i])
		a.rotation = Vector2(solution[i + 1] - solution[i]).angle()
		a.modulate.a = 0.0
		world.add_child(a)
		arrows.append(a)
		i += step


func _build_guards() -> void:
	var g: int = mini(def.param_int("guardCount", 3), GUARD_MAX)
	var n: int = rock_cells.size()
	if n > 0:
		g = clampi(g, 1, n)
	else:
		g = maxi(g, 0)
	_guard_tiles.clear()
	for k in g:
		var empty: Array[int] = []
		_guard_tiles.append(empty)
	for j in n:
		var owner_tiles: Array[int] = _guard_tiles[mini(j * g / n, g - 1)]
		owner_tiles.append(j)
	_guard_last_prog.resize(g)
	_guard_done.resize(g)
	_guard_hit.resize(g)
	_gstate.resize(g)
	_gtimer.resize(g)
	_gtile.resize(g)
	_guard_done.fill(0)
	_guard_hit.fill(0)
	_gstate.fill(GuardState.IDLE)
	_gtile.fill(-1)
	for k in g:
		var tiles: Array[int] = _guard_tiles[k]
		var sum: float = 0.0
		var last: int = 0
		for j in tiles:
			sum += tile_center(rock_cells[j]).x
			last = maxi(last, _prog[rock_cells[j].y * cols + rock_cells[j].x])
		var gd: ActorGuard = ActorGuard.new()
		gd.position = Vector2(sum / float(maxi(tiles.size(), 1)), _origin.y + TILE * 0.5)
		world.add_child(gd)
		guards.append(gd)
		_guard_last_prog[k] = last
		_gtimer[k] = 0.8 + float(k) * _interval / float(maxi(g, 1))
		var rk: ActorMazeRock = ActorMazeRock.new()
		rk.visible = false
		rk.z_index = 3
		world.add_child(rk)
		rocks.append(rk)


# ---- Play --------------------------------------------------------------------------------------------

func _move_david(delta: float) -> void:
	if input_dir.length_squared() < 0.0001:
		return
	var dir: Vector2 = input_dir.limit_length(1.0)
	var step: Vector2 = dir * walk_speed() * delta
	var p: Vector2 = david.position
	if absf(step.x) > 0.0:
		var nx: Vector2 = Vector2(p.x + step.x, p.y)
		if _free_at(nx):
			p = nx
		else:
			# Blocked: slide toward the row's middle so a slightly off turn still goes round the corner.
			var mid_y: float = tile_center(cell_of(p)).y
			var np: Vector2 = Vector2(p.x, move_toward(p.y, mid_y, absf(step.x)))
			if _free_at(np):
				p = np
	if absf(step.y) > 0.0:
		var ny: Vector2 = Vector2(p.x, p.y + step.y)
		if _free_at(ny):
			p = ny
		else:
			var mid_x: float = tile_center(cell_of(p)).x
			var np2: Vector2 = Vector2(move_toward(p.x, mid_x, absf(step.y)), p.y)
			if _free_at(np2):
				p = np2
	david.position = p
	david.set_facing(dir)


func _free_at(p: Vector2) -> bool:
	return is_floor(cell_of(p + Vector2(HALF, HALF))) and is_floor(cell_of(p + Vector2(-HALF, HALF))) \
		and is_floor(cell_of(p + Vector2(HALF, -HALF))) and is_floor(cell_of(p + Vector2(-HALF, -HALF)))


func _step(delta: float) -> void:
	var here: Vector2i = cell_of(david.position)
	if is_floor(here):
		progress = maxi(progress, _prog[here.y * cols + here.x])
	_pass_guards()
	_update_arrows()
	if drops_enabled:
		if not _lines_ready:
			_hold_clock += delta
			if _hold_clock >= HOLD_MAX_SEC:
				_lines_ready = true
		else:
			_update_guards(delta)
	if david.position.distance_to(tile_center(goal_cell)) <= GOAL_REACH:
		_apply_visuals(play_event(&"win"))
		win()


func _pass_guards() -> void:
	for k in guards.size():
		if _guard_done[k] == 0 and progress > _guard_last_prog[k]:
			_guard_done[k] = 1
			if _guard_hit[k] == 0:
				spared_count += 1
				report_spared()


func _update_arrows() -> void:
	for a in arrows:
		a.modulate.a = clampf(1.0 - a.position.distance_to(david.position) / REVEAL_PX, 0.0, 1.0)


func _update_guards(delta: float) -> void:
	for k in guards.size():
		var tiles: Array[int] = _guard_tiles[k]
		if tiles.is_empty():
			continue
		match _gstate[k]:
			GuardState.IDLE:
				_gtimer[k] -= delta
				if _gtimer[k] <= 0.0:
					_start_warn(k, tiles)
			GuardState.WARN:
				_gtimer[k] -= delta
				marks[_gtile[k]].modulate.a = 0.55 + 0.45 * sin(elapsed * 14.0)
				if _gtimer[k] <= 0.0:
					_gstate[k] = GuardState.FALL
					guards[k].throwing = false
					rocks[k].position = tile_center(rock_cells[_gtile[k]]) + Vector2(0.0, -_fall_px)
					rocks[k].visible = true
			GuardState.FALL:
				rocks[k].position.y += _rock_speed * delta
				var ground: float = tile_center(rock_cells[_gtile[k]]).y
				if rocks[k].position.y >= ground:
					rocks[k].position.y = ground
					_land(k)
			GuardState.LAND:
				_gtimer[k] -= delta
				if _gtimer[k] <= 0.0:
					rocks[k].visible = false
					_gstate[k] = GuardState.IDLE
					_gtimer[k] = _interval


func _start_warn(k: int, tiles: Array[int]) -> void:
	var pick: int = tiles[_rng.randi_range(0, tiles.size() - 1)]
	if tiles.size() > 1 and pick == _gtile[k]:
		pick = tiles[(tiles.find(pick) + 1) % tiles.size()]
	_gtile[k] = pick
	_gstate[k] = GuardState.WARN
	_gtimer[k] = _telegraph
	guards[k].throwing = true


func _land(k: int) -> void:
	_gstate[k] = GuardState.LAND
	_gtimer[k] = LAND_SEC
	marks[_gtile[k]].modulate.a = 0.3
	rocks_landed += 1
	request_sfx(&"thud")
	var rect: Rect2 = Rect2(tile_center(rock_cells[_gtile[k]]) - Vector2(TILE, TILE) * 0.5, Vector2(TILE, TILE)).grow(-4.0)
	if rect.has_point(david.position) and _contact_hit(_hit_hearts):
		rock_hits += 1
		_guard_hit[k] = 1


## 0 idle, 1 warning (tile flashing), 2 rock falling, 3 landed, for a guard (tests).
func guard_state(k: int) -> int:
	return _gstate[k]


## The marked tile a guard is using now (-1 before the first drop).
func guard_tile(k: int) -> int:
	return _gtile[k]


func guard_tile_count(k: int) -> int:
	var tiles: Array[int] = _guard_tiles[k]
	return tiles.size()
