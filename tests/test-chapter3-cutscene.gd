extends RefCounted
## Chapter 3 cutscene beats: watch-then-ok (3.3), unlock (3.4), grant (3.7), through the stage and
## through the real StageHost and RunState.

const U := preload("res://tests/ch3-camp-util.gd")

var _made: Array[Node] = []


func run(t: TestRunner) -> void:
	_watch_then_ok(t)
	_cannot_fail(t)
	_faithful_friend_is_visual(t)
	_unlock(t)
	_grant(t)
	_run_state(t)
	_through_host(t)
	for n in _made:
		n.free()
	RunState.end_run()
	RunState.set_followers(0)


func _make(stage_id: String, mode: RunModel.Mode = RunModel.Mode.NORMAL, blessing: String = "") -> Array:
	var s: StageCutscene = StageCutscene.new()
	_made.append(s)
	var rec: Dictionary = U.build(s, U.stage_def(stage_id, mode), mode, blessing)
	return [s, rec]


## Ticks until the stage waits for OK on the arrow (or `limit` seconds pass).
func _to_ok(s: StageCutscene, limit: float = 120.0) -> float:
	var el: float = 0.0
	while el < limit and s.waiting != StageCutscene.Wait.OK and not s.is_finished():
		s.tick(U.STEP)
		if s.waiting == StageCutscene.Wait.LINE:
			s.on_action_tap()
		el += U.STEP
	return el


func _watch_then_ok(t: TestRunner) -> void:
	var pair: Array = _make("3-3-arrows")
	var s: StageCutscene = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	var guard: float = 0.0
	while guard < 30.0 and s.waiting != StageCutscene.Wait.WATCH:
		s.tick(U.STEP)
		if s.waiting == StageCutscene.Wait.LINE:
			s.on_action_tap()
		guard += U.STEP
	t.eq(s.waiting, StageCutscene.Wait.WATCH, "Jonathan's line, then the arrow flies")
	var idx: int = s.beat_index
	# OK and the D-pad do nothing while the arrow is in the air.
	s.input_dir = Vector2.RIGHT
	for i in 5:
		s.tick(U.STEP)
		s.on_action_tap()
	t.eq(s.waiting, StageCutscene.Wait.WATCH, "OK while the arrow flies is ignored")
	t.eq(s.beat_index, idx, "still on the interactive beat")
	var el: float = _to_ok(s)
	t.eq(s.waiting, StageCutscene.Wait.OK, "after the flight the scene waits for OK")
	t.truthy(el < BalanceData.feel("arrowFlightSec") + 2.0, "the arrow flew for about arrowFlightSec")
	t.truthy(s.arrow_x() > s.boy_x() + 300.0, "the arrow lands far past the boy")
	s.input_dir = Vector2.LEFT
	for i in 5:
		s.tick(U.STEP)
	t.eq(s.waiting, StageCutscene.Wait.OK, "the D-pad is ignored while waiting")
	s.on_action_tap()
	t.truthy(s.waiting != StageCutscene.Wait.OK, "OK comes out")
	var guard2: float = 0.0
	while guard2 < 60.0 and not s.is_finished():
		s.tick(U.STEP)
		s.on_action_tap()
		guard2 += U.STEP
	t.eq(int(rec["won"]), 1, "3.3 ends")
	t.eq(rec["ids"], [&"c3-3-jonathan-1", &"c3-3-jonathan-2", &"c3-3-jonathan-3"], "Jonathan's three lines in order")


func _cannot_fail(t: TestRunner) -> void:
	# Nobody presses anything: the beat moves on by itself after arrowWaitSec; nothing fails.
	for mode in U.modes():
		var pair: Array = _make("3-3-arrows", mode)
		var s: StageCutscene = pair[0]
		var rec: Dictionary = pair[1]
		s.begin()
		var el: float = 0.0
		while el < 200.0 and not s.is_finished():
			s.tick(U.STEP)
			if s.waiting == StageCutscene.Wait.LINE:
				s.on_action_tap()
			el += U.STEP
		var key: String = RunModel.mode_key(mode)
		t.eq(int(rec["failed"]), 0, "%s: 3.3 has no failure" % key)
		t.eq(int(rec["hits"]), 0, "%s: no hit" % key)
		t.eq(int(rec["won"]), 1, "%s: 3.3 ends even if OK is never pressed" % key)


func _faithful_friend_is_visual(t: TestRunner) -> void:
	var plain: Array = _make("3-3-arrows")
	var friend: Array = _make("3-3-arrows", RunModel.Mode.NORMAL, "faithful-friend")
	var times: Array = []
	var trails: Array = []
	for pair in [plain, friend]:
		var s: StageCutscene = pair[0]
		s.begin()
		var trail_in_flight: bool = false
		var el: float = 0.0
		while el < 120.0 and s.waiting != StageCutscene.Wait.OK:
			s.tick(U.STEP)
			if s.waiting == StageCutscene.Wait.LINE:
				s.on_action_tap()
			if s.waiting == StageCutscene.Wait.WATCH and s.arrow_trail_shown():
				trail_in_flight = true
			el += U.STEP
		times.append(snappedf(el, 0.01))
		trails.append(trail_in_flight)
		s.on_action_tap()
		while el < 200.0 and not s.is_finished():
			s.tick(U.STEP)
			s.on_action_tap()
			el += U.STEP
	t.eq(trails, [false, true], "Faithful Friend draws a faint trail behind the arrow; nothing without it")
	t.eq(times[0], times[1], "the trail changes nothing about the scene's timing")
	t.eq(plain[1]["ids"], friend[1]["ids"], "the lines are identical with Faithful Friend")
	t.eq(int(plain[1]["won"]), int(friend[1]["won"]), "the outcome is identical")
	# Only in 3.3: no other cutscene draws a trail.
	var other: Array = _make("3-1-song", RunModel.Mode.NORMAL, "faithful-friend")
	(other[0] as StageCutscene).begin()
	U.run_for(other[0], 5.0)
	t.falsy((other[0] as StageCutscene).arrow_trail_shown(), "3.1 never shows an arrow trail")


func _play_all(s: StageCutscene) -> void:
	var el: float = 0.0
	while el < 300.0 and not s.is_finished():
		s.tick(U.STEP)
		s.on_action_tap()
		el += U.STEP


func _unlock(t: TestRunner) -> void:
	for mode in U.modes():
		var pair: Array = _make("3-4-nob", mode)
		var s: StageCutscene = pair[0]
		var rec: Dictionary = pair[1]
		s.begin()
		_play_all(s)
		var key: String = RunModel.mode_key(mode)
		t.eq(rec["grants"], [[&"goliaths-sword", 1]], "%s: Nob reports the sword unlock once" % key)
		t.eq(int(rec["won"]), 1, "%s: Nob ends" % key)
		t.eq((rec["ids"] as Array).size(), 4, "%s: four Nob lines" % key)


func _grant(t: TestRunner) -> void:
	var pair: Array = _make("3-7-abigail")
	var s: StageCutscene = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	_play_all(s)
	t.eq(rec["grants"], [[&"food", 3]], "Abigail grants 3 food for the next stage")
	t.eq(int(rec["won"]), 1, "Abigail ends")


func _run_state(t: TestRunner) -> void:
	var rs: Node = U.new_run_state()
	rs.call("start_chapter", 3, RunModel.Mode.NORMAL)
	var model: RunModel = rs.get("model")
	rs.call("apply_grant", &"food", 3)
	t.eq(model.next_stage_food, 3, "a food grant sets the food for the next stage")
	rs.call("apply_grant", &"food", 3)
	t.eq(model.next_stage_food, 3, "a replayed scene does not stack the grant")
	# A stage consumes it once; Gift of Abigail adds on top of it.
	var base: StageBase = StageBase.new()
	_made.append(base)
	base.setup(U.stage_def("3-8-camp", RunModel.Mode.NORMAL), model, U.stack(RunModel.Mode.NORMAL, "gift-of-abigail"))
	var first: int = base.take_food_bonus()
	var second: int = base.take_food_bonus()
	t.eq(first, 6, "grant 3 plus Gift of Abigail 3")
	t.eq(model.next_stage_food, 0, "the grant is consumed")
	t.eq(second, 3, "a second call only gets the Blessing part")
	t.falsy(model.sword_unlocked, "no sword yet")
	rs.call("apply_grant", &"goliaths-sword", 1)
	t.truthy(model.sword_unlocked, "the sword unlock is applied")
	# The sword is per run: it survives into chapter 4 and resets on a new chapter 3 start.
	rs.call("start_chapter", 4, RunModel.Mode.NORMAL)
	t.truthy(model.sword_unlocked, "the sword carries into chapter 4")
	rs.call("start_chapter", 3, RunModel.Mode.NORMAL)
	t.falsy(model.sword_unlocked, "a new chapter 3 start resets the sword")
	# Clearing 3-4-nob unlocks it by itself, too.
	U.go_to(rs, "3-5-day-1")
	t.truthy(model.sword_unlocked, "clearing 3-4-nob unlocks the sword")
	rs.call("restart_chapter")
	t.eq(U.cur(rs), "3-2-spear", "restart_chapter returns to 3-2-spear")
	t.falsy(model.sword_unlocked, "...and the sword resets with the chapter")
	rs.free()


func _through_host(t: TestRunner) -> void:
	RunState.start_chapter(3, RunModel.Mode.NORMAL)
	U.go_to(RunState, "3-4-nob")
	var host: StageHost = StageHost.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	host.load_stage(RunState.current_stage)
	var s: StageCutscene = host._stage as StageCutscene
	var el: float = 0.0
	RunState.model.sword_unlocked = false
	while el < 300.0 and not s.is_finished():
		host._process(0.1)
		s.tick(0.1)
		s.on_action_tap()
		el += 0.1
	t.truthy(RunState.model.sword_unlocked, "the host applies the sword unlock")
	host.clear_stage()
	host.free()
	RunState.start_chapter(3, RunModel.Mode.NORMAL)
	U.go_to(RunState, "3-7-abigail")
	var host2: StageHost = StageHost.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host2)
	host2.load_stage(RunState.current_stage)
	var s2: StageCutscene = host2._stage as StageCutscene
	el = 0.0
	while el < 300.0 and not s2.is_finished():
		host2._process(0.1)
		s2.tick(0.1)
		s2.on_action_tap()
		el += 0.1
	t.eq(RunState.model.next_stage_food, 3, "the host stores the 3 food for the next stage")
	host2.clear_stage()
	host2.free()
	Engine.time_scale = 1.0
