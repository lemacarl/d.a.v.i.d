extends RefCounted
## 4.4 Rephaim (patience): OK before the rustle only makes David's men say "Not yet!", the stage never
## fails, the rustle window is 1.5 s in Normal and 3.0 s in Shepherd and Lamb, a missed window repeats the
## rustle, and no mode or Blessing changes the story.

const U := preload("res://tests/ch4-play-util.gd")
const ID: String = "4-4-rephaim"
const NOT_YET: StringName = &"c4-4-not-yet"

var _made: Array[Node] = []


func run(t: TestRunner) -> void:
	_early_press(t)
	_never_fails(t)
	_window_per_mode(t)
	_miss_repeats(t)
	_press_and_tap(t)
	_charge(t)
	_sounds_and_visuals(t)
	_seeded(t)
	_outcome_matrix(t)
	for n in _made:
		n.free()


func _make(mode: RunModel.Mode, blessing: String = "") -> Array:
	var s: StagePatience = StagePatience.new()
	_made.append(s)
	var rec: Dictionary = U.build(s, ID, mode, blessing)
	return [s, rec]


func _count(ids: Array, id: StringName) -> int:
	var n: int = 0
	for i in ids:
		if i == id:
			n += 1
	return n


## Ticks until the rustle starts (at most 30 s). Returns the seconds it took.
func _to_rustle(s: StagePatience) -> float:
	var secs: float = 0.0
	while s.phase != StagePatience.Phase.RUSTLE and secs < 30.0 and not s.is_finished():
		s.tick(U.STEP)
		secs += U.STEP
	return secs


func _early_press(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StagePatience = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	t.eq(_count(rec["ids"], NOT_YET), 0, "no 'Not yet!' before OK is pressed")
	s.tick(U.STEP)
	s.on_action_tap()
	t.eq(_count(rec["ids"], NOT_YET), 1, "an early OK makes David's men say 'Not yet!'")
	t.eq(rec["failed"], 0, "an early OK never fails")
	t.eq(rec["won"], 0, "an early OK does not win")
	t.eq(rec["hits"], 0, "an early OK costs nothing")
	t.eq(s.phase, StagePatience.Phase.WAIT, "the stage keeps waiting")
	# Mashing OK inside the cooldown adds no more lines.
	for i in 5:
		s.on_action_tap()
		s.tick(U.STEP)
	t.eq(_count(rec["ids"], NOT_YET), 1, "mashing OK does not flood the line queue")
	U.run_for(s, 1.6)
	s.on_action_tap()
	t.eq(_count(rec["ids"], NOT_YET), 2, "after the cooldown 'Not yet!' can be said again")
	var l: Dictionary = LineBook.line(NOT_YET)
	t.eq(str(l.get("speaker", "")), "david-men", "the line is spoken by David's men (data)")
	t.eq(str(l.get("text", "")), "Not yet!", "the line text is the data text")


func _never_fails(t: TestRunner) -> void:
	for mode in U.modes():
		var pair: Array = _make(mode)
		var s: StagePatience = pair[0]
		var rec: Dictionary = pair[1]
		s.begin()
		U.run_for(s, 400.0)
		t.eq(rec["failed"], 0, "%s: 400 s of waiting never fails" % RunModel.mode_key(mode))
		t.eq(rec["hits"], 0, "%s: nothing hurts David" % RunModel.mode_key(mode))
		t.truthy(s.rustles >= 20, "%s: the rustle keeps coming (%d)" % [RunModel.mode_key(mode), s.rustles])
		t.eq(s.misses, s.rustles - (1 if s.phase == StagePatience.Phase.RUSTLE else 0), "%s: each unanswered rustle is a miss" % RunModel.mode_key(mode))
	var d: StageDef = U.stage_def(ID, RunModel.Mode.NORMAL)
	t.eq(d.lose.size(), 0, "the data has no lose condition")


func _window_per_mode(t: TestRunner) -> void:
	var expect: Dictionary = {RunModel.Mode.NORMAL: 1.5, RunModel.Mode.SHEPHERD: 3.0, RunModel.Mode.LAMB: 3.0}
	for mode in U.modes():
		var w: float = expect[mode]
		var s: StagePatience = _make(mode)[0]
		t.near(s.window_sec, w, "%s: rustle window %s s (data)" % [RunModel.mode_key(mode), w])
		# OK just inside the window wins.
		var pair: Array = _make(mode)
		var s2: StagePatience = pair[0]
		s2.begin()
		var took: float = _to_rustle(s2)
		t.truthy(took >= 8.0 - U.STEP and took <= 14.0 + U.STEP, "%s: rustle after 8 to 14 s (got %s)" % [RunModel.mode_key(mode), took])
		U.run_for(s2, w - 0.3)
		t.eq(s2.phase, StagePatience.Phase.RUSTLE, "%s: still inside the window" % RunModel.mode_key(mode))
		s2.on_action_tap()
		U.run_for(s2, 4.0)
		t.eq(pair[1]["won"], 1, "%s: OK inside the window wins" % RunModel.mode_key(mode))
		t.eq(_count(pair[1]["ids"], NOT_YET), 0, "%s: no 'Not yet!' for the right press" % RunModel.mode_key(mode))
		# OK just after the window is late: no win, the line, and the rustle comes again.
		var pair3: Array = _make(mode)
		var s3: StagePatience = pair3[0]
		s3.begin()
		_to_rustle(s3)
		U.run_for(s3, w + 0.25)
		t.eq(s3.phase, StagePatience.Phase.WAIT, "%s: the window has closed" % RunModel.mode_key(mode))
		s3.on_action_tap()
		t.eq(pair3[1]["won"], 0, "%s: a late OK does not win" % RunModel.mode_key(mode))
		t.eq(pair3[1]["failed"], 0, "%s: a late OK does not fail" % RunModel.mode_key(mode))
		t.eq(_count(pair3[1]["ids"], NOT_YET), 1, "%s: a late OK is just 'Not yet!'" % RunModel.mode_key(mode))
	t.truthy(expect[RunModel.Mode.SHEPHERD] > expect[RunModel.Mode.NORMAL], "Shepherd's window is wider")


func _miss_repeats(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StagePatience = pair[0]
	s.begin()
	_to_rustle(s)
	U.run_for(s, 1.7)
	t.eq(s.misses, 1, "a missed window is counted")
	t.eq(s.phase, StagePatience.Phase.WAIT, "...and the stage waits again")
	var again: float = _to_rustle(s)
	t.truthy(again >= 7.8 and again <= 8.3, "the rustle repeats after the shortest delay (got %s)" % again)
	t.eq(s.rustles, 2, "second rustle")
	s.on_action_tap()
	U.run_for(s, 4.0)
	t.eq(pair[1]["won"], 1, "OK in the second window wins")
	t.eq(pair[1]["failed"], 0, "a miss never fails")


func _press_and_tap(t: TestRunner) -> void:
	# Non-Lamb: the press acts at once, the tap that follows on release is dropped.
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StagePatience = pair[0]
	s.begin()
	s.on_action_press()
	s.on_action_tap()
	t.eq(s.early_presses, 1, "press then release counts once")
	_to_rustle(s)
	s.on_action_press()
	t.eq(s.phase, StagePatience.Phase.CHARGE, "OK on the press inside the window starts the charge")
	s.on_action_tap()
	t.eq(pair[1]["won"], 0, "the charge plays before the win")
	U.run_for(s, 3.0)
	t.eq(pair[1]["won"], 1, "the stage is won once the army has charged")
	s.on_action_tap()
	s.on_action_press()
	t.eq(pair[1]["won"], 1, "extra presses after the win do nothing")


func _charge(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.LAMB)
	var s: StagePatience = pair[0]
	s.begin()
	var foe_x: float = s.foes[0].position.x
	var man_x: float = s.men[0].position.x
	_to_rustle(s)
	s.on_action_tap()
	U.run_for(s, 1.0)
	t.truthy(s.men[0].position.x > man_x + 200.0, "David's men run forward")
	t.truthy(s.foes[0].position.x > foe_x + 200.0, "the Philistines run away")
	t.eq(pair[1]["failed"], 0, "no failure")
	t.eq(s.trees.size(), StagePatience.TREE_COUNT, "trees are bounded")


func _sounds_and_visuals(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StagePatience = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	t.truthy(rec["sfx"].has(&"wind"), "the wind plays from the start (data windSfx)")
	var before: int = s.world.get_child_count()
	U.run_for(s, 12.0)
	t.truthy(_count(rec["sfx"], &"wind") >= 2, "the wind blows again now and then")
	var tilt: float = 0.0
	for tr in s.trees:
		tilt = maxf(tilt, absf(tr.rotation))
	t.truthy(tilt > 0.0, "the trees sway")
	_to_rustle(s)
	t.truthy(rec["sfx"].has(&"marching"), "the rustle plays a marching sound")
	t.truthy(s.trees[0].lit, "the treetops light up while they rustle")
	s.tick(U.STEP)
	var rustle_tilt: float = 0.0
	for tr in s.trees:
		rustle_tilt = maxf(rustle_tilt, absf(tr.rotation))
	t.truthy(rustle_tilt > 0.05, "the treetops shake harder during the rustle")
	t.eq(s.world.get_child_count(), before, "no nodes are created while waiting")
	U.run_for(s, 2.0)
	t.falsy(s.trees[0].lit, "the glow ends with the window")
	# Enter lines: David's question and the gold light.
	var gold: Array = []
	var p2: Array = _make(RunModel.Mode.NORMAL)
	(p2[0] as StagePatience).gold_light_requested.connect(func(tx: String, _r: String, _sec: float) -> void: gold.append(tx))
	(p2[0] as StagePatience).begin()
	t.eq(p2[1]["ids"], [&"c4-4-david"], "David's line plays on entering")
	t.eq(gold.size(), 1, "the gold-light line plays on entering")


func _seeded(t: TestRunner) -> void:
	var a: StagePatience = _make(RunModel.Mode.NORMAL)[0]
	var b: StagePatience = _make(RunModel.Mode.NORMAL)[0]
	a.begin()
	b.begin()
	t.near(_to_rustle(a), _to_rustle(b), "the same seed gives the same delay")
	# The hold while the host shows the opening lines.
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StagePatience = pair[0]
	s.wait_for_lines = true
	s.setup(U.stage_def(ID, RunModel.Mode.NORMAL), pair[1]["run"], U.U3.stack(RunModel.Mode.NORMAL, ""))
	s.begin()
	U.run_for(s, 20.0)
	t.eq(s.rustles, 0, "no rustle while the opening lines are showing")
	s.on_lines_drained()
	U.run_for(s, 15.0)
	t.truthy(s.rustles >= 1, "the rustle comes once the lines are done")
	# And never for ever: the hold ends by itself.
	var p3: Array = _make(RunModel.Mode.NORMAL)
	var s3: StagePatience = p3[0]
	s3.wait_for_lines = true
	s3.setup(U.stage_def(ID, RunModel.Mode.NORMAL), p3[1]["run"], U.U3.stack(RunModel.Mode.NORMAL, ""))
	s3.begin()
	U.run_for(s3, 60.0)
	t.truthy(s3.rustles >= 1, "the stage never stalls if the host never reports the lines")


func _outcome_matrix(t: TestRunner) -> void:
	var baseline: Array = []
	for mode in U.modes():
		for b in U.blessings():
			var pair: Array = _make(mode, b)
			var s: StagePatience = pair[0]
			var rec: Dictionary = pair[1]
			var tag: String = U.tag(mode, b)
			s.begin()
			s.on_action_tap()
			_to_rustle(s)
			s.on_action_press()
			s.on_action_tap()
			s.on_action_hold()
			U.run_for(s, 4.0)
			t.eq(rec["won"], 1, "%s: the patience stage is won" % tag)
			t.eq(rec["failed"], 0, "%s: no failure" % tag)
			t.eq(rec["hits"], 0, "%s: no hit" % tag)
			if baseline.is_empty():
				baseline = (rec["ids"] as Array).duplicate()
			t.eq(rec["ids"], baseline, "%s: the story lines never change" % tag)
