extends RefCounted
## 4.3 Jerusalem (maze): every maze is solvable, rocks fall only in Normal and Shepherd, a rock on David's
## tile costs a heart, a guard passed unhit is spared once, the shaft wins, no Blessing changes the outcome.

const U := preload("res://tests/ch4-play-util.gd")
const ID: String = "4-3-jerusalem"

var _made: Array[Node] = []


func run(t: TestRunner) -> void:
	_generation(t)
	_layout_and_bounds(t)
	_walls_block(t)
	_modes_and_rocks(t)
	_rock_hits(t)
	_spare_once_per_guard(t)
	_arrows(t)
	_telegraph(t)
	_hearts_rules(t)
	_win_path(t)
	_outcome_matrix(t)
	for n in _made:
		n.free()


func _make(mode: RunModel.Mode, blessing: String = "") -> Array:
	var s: StageMaze = StageMaze.new()
	_made.append(s)
	var rec: Dictionary = U.build(s, ID, mode, blessing)
	return [s, rec]


## Walks the route cell by cell. Rock timers are parked first when `quiet` so no rock falls.
func _walk_route(s: StageMaze, quiet: bool) -> void:
	if quiet:
		s._gtimer.fill(99999.0)
	for c in s.solution:
		U.walk_to(s, s.tile_center(c))
		if s.is_finished():
			return


func _generation(t: TestRunner) -> void:
	var sizes: Array[Vector2i] = [Vector2i(15, 11), Vector2i(9, 7), Vector2i(21, 13), Vector2i(14, 10), Vector2i(5, 5)]
	for sz in sizes:
		for seed_value in [1, 2, 3, 4301, 99, 123456]:
			var w: PackedByteArray = StageMaze.generate(sz.x, sz.y, seed_value)
			var start: Vector2i = Vector2i(1, 1)
			var dist: PackedInt32Array = StageMaze.distances(w, sz.x, sz.y, start)
			var floors: int = 0
			var reached: int = 0
			for i in w.size():
				if w[i] == 0:
					floors += 1
					if dist[i] >= 0:
						reached += 1
			t.eq(reached, floors, "maze %s seed %d: every floor tile is reachable" % [sz, seed_value])
			t.truthy(floors > sz.x, "maze %s seed %d has corridors" % [sz, seed_value])
			t.eq(StageMaze.generate(sz.x, sz.y, seed_value), w, "maze %s seed %d is deterministic" % [sz, seed_value])
	t.truthy(StageMaze.generate(15, 11, 1) != StageMaze.generate(15, 11, 2), "different seeds give different mazes")
	# The stage's own maze from data: the shaft is reachable from the start.
	var s: StageMaze = _make(RunModel.Mode.NORMAL)[0]
	t.truthy(StageMaze.is_solvable(s.walls, s.cols, s.rows, s.start_cell, s.goal_cell), "the data maze is solvable")
	t.eq(s.cols, 15, "grid is 15 wide (data)")
	t.eq(s.rows, 11, "grid is 11 tall (data)")
	t.eq(s.solution[0], s.start_cell, "the route starts at the start")
	t.eq(s.solution[s.solution.size() - 1], s.goal_cell, "the route ends at the shaft")
	t.truthy(s.solution.size() > 12, "the way to the shaft is not trivial")


func _layout_and_bounds(t: TestRunner) -> void:
	var s: StageMaze = _make(RunModel.Mode.NORMAL)[0]
	s.begin()
	t.eq(s.rock_cells.size(), 10, "ten marked rock tiles (data rockTiles.count)")
	for c in s.rock_cells:
		t.truthy(s.solution.has(c), "marked tile %s lies on the route" % c)
	t.eq(s.guards.size(), 4, "four guards (data guardCount)")
	t.eq(s.rocks.size(), 4, "one reusable rock per guard")
	t.truthy(s.arrows.size() > 0 and s.arrows.size() <= StageMaze.ARROW_MAX, "hint arrows are bounded")
	var before: int = s.world.get_child_count()
	U.run_for(s, 40.0)
	t.eq(s.world.get_child_count(), before, "no nodes are created while the stage runs")
	var covered: int = 0
	for g in s._guard_tiles.size():
		covered += s.guard_tile_count(g)
	t.eq(covered, s.rock_cells.size(), "every marked tile belongs to one guard")


func _walls_block(t: TestRunner) -> void:
	var s: StageMaze = _make(RunModel.Mode.LAMB)[0]
	s.begin()
	s.input_dir = Vector2(-1, -1)
	for i in 80:
		s.tick(U.STEP)
	t.truthy(s.is_floor(s.cell_of(s.david.position)), "David never ends inside a wall")
	s.input_dir = Vector2(1, 1)
	for i in 200:
		s.tick(U.STEP)
		t.truthy(s._free_at(s.david.position), "David's box stays on floor tiles")
		if not s._free_at(s.david.position):
			break
	s.input_dir = Vector2.ZERO


func _modes_and_rocks(t: TestRunner) -> void:
	var n: StageMaze = _make(RunModel.Mode.NORMAL)[0]
	var sh: StageMaze = _make(RunModel.Mode.SHEPHERD)[0]
	var l: Array = _make(RunModel.Mode.LAMB)
	var lamb: StageMaze = l[0]
	t.truthy(n.drops_enabled, "Normal drops rocks")
	t.truthy(sh.drops_enabled, "Shepherd drops rocks")
	t.falsy(lamb.drops_enabled, "Lamb drops no rocks")
	t.truthy(sh._rock_speed < n._rock_speed, "Shepherd rocks are slower (%s < %s)" % [sh._rock_speed, n._rock_speed])
	t.eq(n._rock_speed, 260.0, "Normal rockSpeed comes from data")
	t.eq(sh._rock_speed, 156.0, "Shepherd rockSpeed comes from data")
	lamb.begin()
	U.run_for(lamb, 60.0)
	t.eq(lamb.rocks_landed, 0, "no rock lands in Lamb")
	for r in lamb.rocks:
		t.falsy(r.visible, "no rock is shown in Lamb")
	t.eq(l[1]["hits"], 0, "no hit in Lamb")
	for m in lamb.marks:
		t.falsy(m.visible, "no rock marks in Lamb")
	n.begin()
	U.run_for(n, 30.0)
	t.truthy(n.rocks_landed > 0, "rocks land in Normal")


func _stand_on_tile(s: StageMaze, tile: int) -> void:
	s.david.position = s.tile_center(s.rock_cells[tile])


func _rock_hits(t: TestRunner) -> void:
	for mode in [RunModel.Mode.NORMAL, RunModel.Mode.SHEPHERD]:
		var pair: Array = _make(mode)
		var s: StageMaze = pair[0]
		var rec: Dictionary = pair[1]
		s.begin()
		# Only guard 0 drops, and always on its first tile; David stands there.
		s._gtimer.fill(99999.0)
		s._gtimer[0] = 0.1
		s._guard_tiles[0] = [0] as Array[int]
		_stand_on_tile(s, 0)
		var warn_secs: float = 0.0
		var saw_warn: bool = false
		var secs: float = 0.0
		while secs < 12.0 and int(rec["hits"]) == 0:
			s.david.position = s.tile_center(s.rock_cells[0])
			s.tick(U.STEP)
			secs += U.STEP
			if s.guard_state(0) == StageMaze.GuardState.WARN:
				saw_warn = true
				warn_secs += U.STEP
		t.truthy(saw_warn, "%s: the tile flashes before the rock falls" % RunModel.mode_key(mode))
		t.truthy(warn_secs >= 1.1, "%s: telegraph lasts about 1.2 s (got %s)" % [RunModel.mode_key(mode), warn_secs])
		t.eq(rec["hits"], 1, "%s: a rock landing on David's tile costs one hit" % RunModel.mode_key(mode))
		t.eq(s.rock_hits, 1, "%s: one rock hit counted" % RunModel.mode_key(mode))
		t.truthy(rec["sfx"].has(&"thud"), "%s: the landing thuds" % RunModel.mode_key(mode))
		# The invulnerable window protects against a second hit from the next rock.
		t.eq(rec["failed"], 0, "%s: a hit is not a failure from inside the stage" % RunModel.mode_key(mode))
	# Stepping aside while the tile flashes is safe.
	var pair2: Array = _make(RunModel.Mode.NORMAL)
	var s2: StageMaze = pair2[0]
	s2.begin()
	s2._gtimer.fill(99999.0)
	s2._gtimer[0] = 0.1
	s2._guard_tiles[0] = [0] as Array[int]
	s2.david.position = s2.tile_center(s2.rock_cells[0]) + Vector2(0, 2)
	var landed_before: int = s2.rocks_landed
	var secs2: float = 0.0
	while secs2 < 8.0 and s2.rocks_landed == landed_before:
		if s2.guard_state(0) == StageMaze.GuardState.WARN:
			s2.david.position = s2.tile_center(s2.start_cell)
		s2.tick(U.STEP)
		secs2 += U.STEP
	t.truthy(s2.rocks_landed > landed_before, "the rock lands")
	t.eq(pair2[1]["hits"], 0, "leaving the marked tile during the flash avoids the rock")


func _spare_once_per_guard(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.LAMB)
	var s: StageMaze = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	_walk_route(s, true)
	t.eq(rec["won"], 1, "Lamb: walking the route wins")
	t.eq(rec["spared"], s.guards.size(), "each guard is spared exactly once (%d)" % s.guards.size())
	t.eq(s.spared_count, s.guards.size(), "stage counter matches")
	# Walking back and forth does not spare again.
	var pair2: Array = _make(RunModel.Mode.NORMAL)
	var s2: StageMaze = pair2[0]
	s2.begin()
	s2._gtimer.fill(99999.0)
	for c in s2.solution:
		if s2.solution.find(c) > s2.solution.size() - 4:
			break
		U.walk_to(s2, s2.tile_center(c))
	var first: int = int(pair2[1]["spared"])
	for k in 3:
		U.walk_to(s2, s2.tile_center(s2.solution[0]))
		U.walk_to(s2, s2.tile_center(s2.solution[s2.solution.size() - 6]))
	t.eq(pair2[1]["spared"], first, "re-walking a stretch never spares a guard twice")
	t.truthy(first <= s2.guards.size(), "never more than one spare per guard")
	# A guard whose rock hit David is not spared.
	var pair3: Array = _make(RunModel.Mode.NORMAL)
	var s3: StageMaze = pair3[0]
	s3.begin()
	s3._gtimer.fill(99999.0)
	s3._gtimer[0] = 0.1
	s3._guard_tiles[0] = [0] as Array[int]
	var hits: int = 0
	var secs: float = 0.0
	while secs < 12.0 and int(pair3[1]["hits"]) == 0:
		s3.david.position = s3.tile_center(s3.rock_cells[0])
		s3.tick(U.STEP)
		secs += U.STEP
	hits = pair3[1]["hits"]
	t.eq(hits, 1, "setup: guard 0 hit David")
	s3._gtimer.fill(99999.0)
	_walk_route(s3, false)
	t.eq(pair3[1]["won"], 1, "the stage is still won after a hit")
	t.eq(pair3[1]["spared"], s3.guards.size() - 1, "the guard who hit David is not spared; the others are")


func _arrows(t: TestRunner) -> void:
	var s: StageMaze = _make(RunModel.Mode.NORMAL)[0]
	s.begin()
	s.tick(U.STEP)
	var a: Polygon2D = s.arrows[0]
	s.david.position = a.position + Vector2(600, 0)
	s.tick(U.STEP)
	t.eq(a.modulate.a, 0.0, "arrows are hidden when David is far")
	s.david.position = a.position
	s.tick(U.STEP)
	t.truthy(a.modulate.a > 0.9, "an arrow shows when David stands on it")
	# Every arrow points from its tile to the next tile on the route.
	for ar in s.arrows:
		var c: Vector2i = s.cell_of(ar.position)
		var i: int = s.solution.find(c)
		t.truthy(i >= 0 and i < s.solution.size() - 1, "arrow sits on the route")
		var dir: Vector2 = Vector2(s.solution[i + 1] - s.solution[i])
		t.truthy(absf(angle_difference(ar.rotation, dir.angle())) < 0.01, "arrow points toward the shaft")


func _telegraph(t: TestRunner) -> void:
	var plain: StageMaze = _make(RunModel.Mode.NORMAL)[0]
	var eyes: StageMaze = _make(RunModel.Mode.NORMAL, "watchful-eyes")[0]
	t.near(eyes._telegraph, plain._telegraph + 1.0, "Watchful Eyes lengthens the rock telegraph by 1 s")
	var quick: StageMaze = _make(RunModel.Mode.NORMAL, "quick-feet")[0]
	t.near(quick.walk_speed(), plain.walk_speed() * 1.2, "Quick Feet walks 20% faster")
	var men: StageMaze = _make(RunModel.Mode.NORMAL, "mighty-men")[0]
	men.begin()
	t.eq(men.companion_count(), 1, "Mighty Men walks with David")
	men.tick(U.STEP)


func _hearts_rules(t: TestRunner) -> void:
	var d: StageDef = U.stage_def(ID, RunModel.Mode.NORMAL)
	t.truthy(d.has_lose(&"hearts-zero"), "Normal: hearts-zero is a lose condition")
	t.eq(d.on_lose_for(&"hearts-zero").get("target", ""), "restart-stage", "Normal: out of hearts restarts the stage")
	# The stage never fails by itself and never takes more than rockHitHearts per rock.
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StageMaze = pair[0]
	s.begin()
	var amounts: Array[int] = []
	s.hit_taken.connect(func(n: int) -> void: amounts.append(n))
	s._gtimer.fill(99999.0)
	s._gtimer[0] = 0.1
	s._guard_tiles[0] = [0] as Array[int]
	var secs: float = 0.0
	while secs < 12.0 and amounts.is_empty():
		s.david.position = s.tile_center(s.rock_cells[0])
		s.tick(U.STEP)
		secs += U.STEP
	t.eq(amounts, [1], "a rock costs exactly one heart")
	# Through the run state: Normal zero hearts restarts the stage, Shepherd rests, Lamb takes nothing.
	var rs: Node = load("res://autoload/run-state.gd").new()
	rs.call("start_chapter", 4, RunModel.Mode.NORMAL)
	for i in 10:
		if str(rs.get("current_stage").id) == ID:
			break
		rs.call("advance")
		if rs.get("awaiting_blessing"):
			rs.call("skip_blessing")
	var model: RunModel = rs.get("model")
	rs.call("apply_hit", 1)
	t.eq(model.hearts, model.hearts_max - 1, "Normal: a hit takes a heart in the maze")
	rs.call("apply_hit", model.hearts_max)
	t.eq(str(rs.get("current_stage").id), ID, "Normal: out of hearts replays the maze stage")
	t.eq(model.hearts, model.hearts_max, "...with hearts refilled")
	rs.free()
	var rs2: Node = load("res://autoload/run-state.gd").new()
	rs2.call("start_chapter", 4, RunModel.Mode.LAMB)
	for i in 10:
		if str(rs2.get("current_stage").id) == ID:
			break
		rs2.call("advance")
		if rs2.get("awaiting_blessing"):
			rs2.call("skip_blessing")
	var m2: RunModel = rs2.get("model")
	rs2.call("apply_hit", 1)
	t.eq(m2.hearts, m2.hearts_max, "Lamb: no damage")
	rs2.free()


func _win_path(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StageMaze = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	t.truthy((rec["ids"] as Array).has(&"c4-3-guards"), "the guards' line plays on entering")
	t.falsy(rec["ids"].has(&"c4-3-narr"), "the win line waits for the shaft")
	_walk_route(s, true)
	t.eq(rec["won"], 1, "reaching the shaft wins")
	t.truthy((rec["ids"] as Array).has(&"c4-3-narr"), "the win line plays")
	t.eq(rec["failed"], 0, "no failure on the way")
	# Rocks held while the host plays the opening lines.
	var p2: Array = _make(RunModel.Mode.NORMAL)
	var s2: StageMaze = p2[0]
	s2.wait_for_lines = true
	s2.setup(U.stage_def(ID, RunModel.Mode.NORMAL), p2[1]["run"], U.U3.stack(RunModel.Mode.NORMAL, ""))
	s2.begin()
	U.run_for(s2, 10.0)
	t.eq(s2.rocks_landed, 0, "no rock falls while the opening lines are still showing")
	s2.on_lines_drained()
	U.run_for(s2, 12.0)
	t.truthy(s2.rocks_landed > 0, "rocks start once the lines are done")


func _outcome_matrix(t: TestRunner) -> void:
	for mode in U.modes():
		for b in U.blessings():
			var pair: Array = _make(mode, b)
			var s: StageMaze = pair[0]
			var rec: Dictionary = pair[1]
			var tag: String = U.tag(mode, b)
			s.begin()
			_walk_route(s, true)
			t.eq(rec["won"], 1, "%s: the maze is won" % tag)
			t.eq(rec["failed"], 0, "%s: no failure" % tag)
			t.eq(rec["ids"], [&"c4-3-guards", &"c4-3-narr"], "%s: the story lines never change" % tag)
			t.eq(s.spared_count, s.guards.size(), "%s: every guard passed unhit" % tag)
			s.on_action_tap()
			s.on_action_hold()
