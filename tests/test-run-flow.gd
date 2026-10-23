extends RefCounted
## RunState behaviour with injected synthetic chapters (no dependence on data/chapters or data/stages).


func run(t: TestRunner) -> void:
	_blessings_reset(t)
	_sword(t)
	_normal_fail(t)
	_shepherd(t)
	_lamb(t)
	_completion(t)


func _stage(id: String, next: Variant, blessing: bool, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {
		"id": id, "chapter": 1, "type": "protect-flock", "params": {},
		"lose": [{"cond": "hearts-zero"}, {"cond": "timeout", "onLose": {"target": "restart-stage", "message": "pool:p"}}],
		"onLose": {"target": "chapter-start", "message": "pool:david-falls"},
		"blessingAfter": blessing, "next": next,
	}
	d.merge(extra, true)
	return d


func _make(chapter: int = 1) -> Node:
	var rs: Node = load("res://autoload/run-state.gd").new() as Node
	var stages: Array = [
		_stage("s-a", "s-b", false, {"type": "cutscene", "lose": []}),
		_stage("s-b", "s-c", true),
		_stage("s-c", "s-d", true),
		_stage("s-d", null, false),
	]
	var ch: Dictionary = {"id": "t", "number": chapter, "stages": ["s-a", "s-b", "s-c", "s-d"], "restartStage": "s-b"}
	rs.call("set_chapter_data", chapter, ch, stages)
	rs.call("set_seed", 12345)
	return rs


func _cur(rs: Node) -> String:
	return String((rs.get("current_stage") as StageDef).id)


func _model(rs: Node) -> RunModel:
	return rs.get("model") as RunModel


func _blessings_reset(t: TestRunner) -> void:
	var rs: Node = _make(1)
	rs.call("set_chapter_data", 2, {"number": 2, "stages": ["s-a"], "restartStage": "s-a"}, [_stage("s-a", null, false)])
	rs.call("start_chapter", 1, RunModel.Mode.NORMAL)
	rs.call("add_blessing", &"quick-feet")
	rs.call("add_blessing", &"smooth-stones")
	t.eq(_model(rs).blessings, [&"quick-feet", &"smooth-stones"] as Array[StringName], "blessings added in pick order")
	var stack: ModifierStack = rs.get("mods") as ModifierStack
	t.near(stack.apply(&"walk-speed", 100.0), 120.0, "Quick Feet is x1.2 walk-speed")
	t.near(stack.apply(&"stone-speed", 100.0), 125.0, "Smooth Stones is x1.25 stone-speed")
	rs.call("start_chapter", 2, RunModel.Mode.NORMAL)
	t.eq(_model(rs).blessings.size(), 0, "blessings reset when a chapter starts")
	t.near(stack.apply(&"walk-speed", 100.0), 100.0, "modifier stack cleared with chapter")
	rs.call("add_blessing", &"quick-feet")
	rs.call("add_blessing", &"quick-feet")
	t.eq(_model(rs).blessings.size(), 1, "duplicate blessing ignored")
	rs.call("add_blessing", &"not-a-card")
	t.eq(_model(rs).blessings.size(), 1, "unknown blessing ignored")
	rs.free()


func _sword(t: TestRunner) -> void:
	var rs: Node = _make(3)
	rs.call("start_chapter", 3, RunModel.Mode.NORMAL)
	t.falsy(_model(rs).sword_unlocked, "sword locked at chapter 3 start")
	var offered: Array = rs.call("available_blessings")
	var ids: Array = []
	for c in offered:
		ids.append((c as Dictionary)["id"])
	t.falsy(ids.has("goliaths-sword"), "sword not offered before Nob")
	rs.call("unlock_sword")
	ids.clear()
	for c in rs.call("available_blessings"):
		ids.append((c as Dictionary)["id"])
	t.truthy(ids.has("goliaths-sword"), "sword offered once unlocked")
	rs.call("set_chapter_data", 4, {"number": 4, "stages": ["s-a"]}, [_stage("s-a", null, false)])
	rs.call("start_chapter", 4, RunModel.Mode.NORMAL)
	t.truthy(_model(rs).sword_unlocked, "sword carries into chapter 4 (per run)")
	rs.call("start_chapter", 3, RunModel.Mode.NORMAL)
	t.falsy(_model(rs).sword_unlocked, "new chapter 3 run clears the sword")
	rs.call("unlock_sword")
	rs.call("end_run")
	t.falsy(_model(rs).sword_unlocked, "end_run clears the sword")
	rs.free()


func _normal_fail(t: TestRunner) -> void:
	var rs: Node = _make()
	var log: Dictionary = {"failed": 0, "msg": ""}
	rs.connect("run_failed", func(m: String) -> void:
		log["failed"] = int(log["failed"]) + 1
		log["msg"] = m)
	rs.call("start_chapter", 1, RunModel.Mode.NORMAL)
	t.eq(_cur(rs), "s-a", "chapter starts at first stage")
	rs.call("advance")
	t.eq(_cur(rs), "s-b", "advance follows next")
	rs.call("add_blessing", &"quick-feet")
	rs.call("apply_hit", 1)
	t.eq(_model(rs).hearts, 2, "hit costs a heart")
	var r: StringName = rs.call("fail_stage", &"hearts-zero")
	t.eq(r, &"restart-chapter", "Normal hearts-zero restarts the chapter")
	t.eq(_cur(rs), "s-b", "restart lands on restartStage (opening cutscene not replayed)")
	t.eq(_model(rs).blessings.size(), 0, "chapter restart resets blessings")
	t.eq(_model(rs).hearts, _model(rs).hearts_max, "chapter restart refills hearts")
	t.eq(log["msg"], "pool:david-falls", "run_failed carries the onLose message")
	rs.call("advance")
	t.truthy(rs.get("awaiting_blessing"), "blessingAfter stage waits for a pick")
	rs.call("add_blessing", &"quick-feet")
	t.eq(_cur(rs), "s-c", "picking a blessing continues to next stage")
	r = rs.call("fail_stage", &"timeout")
	t.eq(r, &"restart-stage", "Normal timeout restarts the stage")
	t.eq(_cur(rs), "s-c", "stage restart stays on stage")
	t.eq(_model(rs).blessings.size(), 1, "stage restart keeps blessings")
	# hitting zero hearts in Normal fails the chapter
	rs.call("apply_hit", 3)
	t.eq(_cur(rs), "s-b", "Normal zero hearts restarts at chapter start")
	rs.free()


func _shepherd(t: TestRunner) -> void:
	var rs: Node = _make()
	var log: Dictionary = {"failed": 0, "tired": 0.0, "rested": 0}
	rs.connect("run_failed", func(_m: String) -> void: log["failed"] = int(log["failed"]) + 1)
	rs.connect("tired", func(s: float) -> void: log["tired"] = s)
	rs.connect("rested", func() -> void: log["rested"] = int(log["rested"]) + 1)
	rs.call("start_chapter", 1, RunModel.Mode.SHEPHERD)
	rs.call("advance")
	rs.call("apply_hit", 1)
	rs.call("apply_hit", 1)
	rs.call("apply_hit", 1)
	t.eq(_model(rs).hearts, 0, "Shepherd hearts reach zero")
	t.near(float(log["tired"]), 3.0, "Shepherd rests 3 s (from balance.json)")
	t.eq(int(log["failed"]), 0, "Shepherd never fails at zero hearts")
	t.eq(_cur(rs), "s-b", "Shepherd stays on the stage")
	rs.call("apply_hit", 1)
	t.eq(_model(rs).hearts, 0, "no further damage while tired")
	t.eq(rs.call("fail_stage", &"hearts-zero"), &"ignored", "Shepherd ignores stage failure")
	t.eq(rs.call("fail_stage", &"timeout"), &"ignored", "Shepherd ignores timeout")
	rs.call("end_rest")
	t.eq(_model(rs).hearts, _model(rs).hearts_max, "rest refills hearts")
	t.eq(int(log["rested"]), 1, "rested emitted")
	t.eq(int(log["failed"]), 0, "still no failure")
	rs.free()


func _lamb(t: TestRunner) -> void:
	var rs: Node = _make()
	var failed: Array = [0]
	rs.connect("run_failed", func(_m: String) -> void: failed[0] = int(failed[0]) + 1)
	rs.call("start_chapter", 1, RunModel.Mode.LAMB)
	rs.call("advance")
	for i in 5:
		rs.call("apply_hit", 1)
	t.eq(_model(rs).hearts, _model(rs).hearts_max, "Lamb takes no damage")
	t.eq(rs.call("fail_stage", &"hearts-zero"), &"ignored", "Lamb ignores failure")
	t.eq(rs.call("fail_stage", &"stones-out"), &"ignored", "Lamb ignores stones-out")
	t.eq(failed[0], 0, "Lamb never fails")
	var stack: ModifierStack = rs.get("mods") as ModifierStack
	t.near(stack.apply(&"enemy-spawn-enabled", 1.0), 0.0, "Lamb removes enemy spawns")
	t.truthy(stack.apply_bool(&"stones-refill", false), "Lamb refills stones")
	t.falsy(stack.apply_bool(&"timer-enabled", true), "Lamb ignores timers")
	rs.free()


func _completion(t: TestRunner) -> void:
	var rs: Node = _make()
	var done: Array = []
	rs.connect("chapter_completed", func(c: int) -> void: done.append(c))
	rs.call("start_chapter", 1, RunModel.Mode.NORMAL)
	rs.call("advance")
	rs.call("advance")
	rs.call("skip_blessing")
	rs.call("advance")
	rs.call("skip_blessing")
	t.eq(_cur(rs), "s-d", "reached last stage")
	rs.call("advance")
	t.eq(done, [1], "last stage completes the chapter")
	rs.free()
