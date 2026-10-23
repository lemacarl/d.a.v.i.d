extends RefCounted
## D2: story lines are queued and shown in order; a stage win waits for the queue to drain.

const STEP: float = 0.1


func run(t: TestRunner) -> void:
	_order_and_hold(t)
	_same_frame_pair(t)
	_sticky_and_clear(t)
	_stages_show_every_line(t)
	_gold_waits_its_turn(t)
	_repeated_pending_line_deduped(t)


func _recorder(q: LineQueue) -> Array:
	var shown: Array = []
	q.line_started.connect(func(_s: StringName, text: String, _r: String, _h: float, _st: bool) -> void: shown.append(text))
	return shown


func _order_and_hold(t: TestRunner) -> void:
	var q: LineQueue = LineQueue.new()
	var shown: Array = _recorder(q)
	var done: Array = [0]
	q.push(&"narrator", "one")
	q.push(&"david", "two")
	q.when_drained(func() -> void: done[0] = int(done[0]) + 1)
	t.eq(shown, ["one"], "first line shows at once")
	q.tick(2.9)
	t.eq(shown, ["one"], "line held for 3 s")
	q.tick(0.2)
	t.eq(shown, ["one", "two"], "second line follows after the first hold")
	t.eq(done[0], 0, "drain callback waits while a line is still held")
	q.tick(3.1)
	t.eq(done[0], 1, "drain callback runs once after the last line was held")
	t.truthy(q.is_idle(), "queue idle afterwards")
	var long_text: String = "x".repeat(100)
	t.near(LineQueue.hold_for(long_text), 6.0, "long line held 0.06 s per character")
	var q2: LineQueue = LineQueue.new()
	var now: Array = [0]
	q2.when_drained(func() -> void: now[0] = int(now[0]) + 1)
	t.eq(now[0], 1, "idle queue runs the callback immediately")


func _same_frame_pair(t: TestRunner) -> void:
	# 1.6 opening: narrator then servant line in the same frame, both must be seen in order.
	var q: LineQueue = LineQueue.new()
	var shown: Array = _recorder(q)
	q.request(&"narrator", "King Saul was troubled, and his heart was dark.")
	q.request(&"servant", "second")
	t.eq(shown.size(), 1, "same-frame pair: only the first shown at first")
	t.eq(shown[0], "King Saul was troubled, and his heart was dark.", "narrator line shown first")
	q.tick(3.05)
	t.eq(shown.size(), 2, "same-frame pair: second line shown after the first hold")


func _sticky_and_clear(t: TestRunner) -> void:
	var q: LineQueue = LineQueue.new()
	var shown: Array = _recorder(q)
	q.request(&"narrator", "a")
	q.request(&"narrator", "b")
	q.request(&"ui", "prompt")
	t.eq(shown, ["a"], "a prompt queues behind waiting story lines")
	q.tick(3.05)
	q.tick(3.05)
	t.eq(shown, ["a", "b", "prompt"], "prompt shown after the lines before it")
	q.request(&"narrator", "c")
	t.eq(shown, ["a", "b", "prompt", "c"], "a normal line replaces a sticky prompt at once")
	var ran: Array = [0]
	q.when_drained(func() -> void: ran[0] = 1)
	q.clear()
	q.tick(10.0)
	t.eq(ran[0], 0, "clear drops the drain callback (stage replaced)")
	t.truthy(q.is_idle(), "clear leaves the queue idle")


## Plays a stage with a host-like queue. Returns {shown, advance_at_shown (lines shown when advance ran), advanced}.
func _play(stage: StageBase, max_sec: float) -> Dictionary:
	var q: LineQueue = LineQueue.new()
	var shown: Array = _recorder(q)
	var res: Dictionary = {"shown": shown, "at_advance": -1, "advanced": 0, "queued": 0}
	stage.line_requested.connect(func(sp: StringName, tx: String, rf: String, id: StringName) -> void:
		if sp != &"caption":
			res["queued"] = int(res["queued"]) + 1
		q.request(sp, tx, rf, id))
	stage.stage_won.connect(func() -> void:
		q.when_drained(func() -> void:
			res["advanced"] = int(res["advanced"]) + 1
			res["at_advance"] = shown.size()))
	stage.begin()
	var el: float = 0.0
	while el < max_sec and int(res["advanced"]) == 0:
		stage.call("tick", STEP)
		q.tick(STEP)
		el += STEP
	return res


func _def(stage_id: String, mode: RunModel.Mode) -> StageDef:
	for d in StageDef.load_chapter(1, mode):
		if d.id == StringName(stage_id):
			return d
	return null


func _stages_show_every_line(t: TestRunner) -> void:
	# Night: the sunrise line emitted right before win is shown before advance.
	var d: StageDef = _def("1-2-night-1", RunModel.Mode.LAMB)
	var s: StageProtectFlock = StageProtectFlock.new()
	var rm: RunModel = RunModel.new()
	rm.mode = RunModel.Mode.LAMB
	s.setup(d, rm, ModifierStack.new(RunModel.Mode.LAMB))
	var r: Dictionary = _play(s, 200.0)
	t.eq(r["advanced"], 1, "night: advance ran after the queue drained")
	t.eq(r["at_advance"], r["queued"], "night: every requested line was shown before advance")
	t.truthy((r["shown"] as Array).size() >= 2, "night: start and sunrise lines both shown")
	s.free()
	# Harp: opening pair and the closing lines (Saul line, narrator, end card).
	var h: StageDef = _def("1-6-harp", RunModel.Mode.NORMAL)
	var hs: StageRhythm = StageRhythm.new()
	var hm: RunModel = RunModel.new()
	hs.setup(h, hm, ModifierStack.new(RunModel.Mode.NORMAL))
	var hr: Dictionary = _play(hs, 200.0)
	t.eq(hr["advanced"], 1, "harp: advance ran")
	t.eq(hr["at_advance"], hr["queued"], "harp: every requested line was shown before advance")
	var texts: Array = hr["shown"] as Array
	t.truthy(texts.size() >= 4, "harp: opening pair plus closing lines shown (%d)" % texts.size())
	t.eq(texts[0], "King Saul was troubled, and his heart was dark.", "harp: troubled narrator line is first")
	hs.free()


func _gold_waits_its_turn(t: TestRunner) -> void:
	var q: LineQueue = LineQueue.new()
	var shown: Array = _recorder(q)
	var gold: Array = []
	q.gold_started.connect(func(text: String, _r: String, _s: float) -> void: gold.append(text))
	q.push(&"narrator", "first")
	q.request_gold("gold words", "ref", 4.0)
	t.eq(gold, [], "gold light waits behind the line that is showing")
	q.tick(3.1)
	t.eq(gold, ["gold words"], "gold light starts on its turn")
	t.eq(shown, ["first"], "gold light is not a subtitle line")


func _repeated_pending_line_deduped(t: TestRunner) -> void:
	var q: LineQueue = LineQueue.new()
	var shown: Array = _recorder(q)
	q.push(&"david", "busy", "", false, &"a")
	q.push(&"david", "Got you!", "", false, &"saved")
	q.push(&"david", "Got you!", "", false, &"saved")
	q.push(&"david", "Got you!", "", false, &"saved")
	q.tick(3.1)
	q.tick(3.1)
	q.tick(3.1)
	t.eq(shown, ["busy", "Got you!"], "identical pending lines are queued once")
