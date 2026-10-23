extends RefCounted
## Stage simulation tests: stages are stepped with tick(delta), no scene tree needed.

const STEP: float = 0.1


func run(t: TestRunner) -> void:
	_night_length(t)
	_night_sheep_rules(t)
	_night_predators(t)
	_lion(t)
	_bear(t)
	_boss_lamb(t)
	_rhythm(t)
	_cutscenes(t)
	_modes_never_fail(t)


func _def(stage_id: String, mode: RunModel.Mode) -> StageDef:
	for d in StageDef.load_chapter(1, mode):
		if d.id == StringName(stage_id):
			return d
	return null


## Builds a stage, wires a recorder and calls setup. Does not call begin().
func _build(stage: StageBase, def: StageDef, mode: RunModel.Mode) -> Dictionary:
	var rec: Dictionary = {"won": 0, "failed": 0, "reason": &"", "hits": 0, "lines": 0, "gold": 0, "thrown": 0, "saved": 0}
	stage.stage_won.connect(func() -> void: rec["won"] = int(rec["won"]) + 1)
	stage.stage_failed.connect(func(r: StringName) -> void:
		rec["failed"] = int(rec["failed"]) + 1
		rec["reason"] = r)
	stage.hit_taken.connect(func(_n: int) -> void: rec["hits"] = int(rec["hits"]) + 1)
	stage.line_requested.connect(func(_s: StringName, _tx: String, _r: String, _id: StringName) -> void: rec["lines"] = int(rec["lines"]) + 1)
	stage.gold_light_requested.connect(func(_tx: String, _r: String, _sec: float) -> void: rec["gold"] = int(rec["gold"]) + 1)
	stage.stone_thrown.connect(func() -> void: rec["thrown"] = int(rec["thrown"]) + 1)
	stage.sheep_saved.connect(func() -> void: rec["saved"] = int(rec["saved"]) + 1)
	var rm: RunModel = RunModel.new()
	rm.mode = mode
	stage.setup(def, rm, ModifierStack.new(mode))
	return rec


func _night(stage_id: String, mode: RunModel.Mode, predators: bool) -> StageProtectFlock:
	var d: StageDef = _def(stage_id, mode)
	if not predators:
		d.params["predators"] = []
	return StageProtectFlock.new()


## Runs until finished or max_sec. Returns elapsed simulated seconds.
func _run_until_done(stage: Object, max_sec: float) -> float:
	var t: float = 0.0
	while t < max_sec and not (stage as StageBase).is_finished():
		stage.call("tick", STEP)
		t += STEP
	return t


func _night_length(t: TestRunner) -> void:
	# AC-1.2a: the night ends at 90 s (no predators so the outcome is deterministic).
	var d: StageDef = _def("1-2-night-1", RunModel.Mode.NORMAL)
	d.params["predators"] = []
	var s: StageProtectFlock = StageProtectFlock.new()
	var rec: Dictionary = _build(s, d, RunModel.Mode.NORMAL)
	s.begin()
	var secs: float = _run_until_done(s, 120.0)
	t.truthy(absf(secs - 90.0) <= 1.0, "AC-1.2a night ends at 90 s (got %s)" % secs)
	t.eq(rec["won"], 1, "night won exactly once")
	t.eq(rec["failed"], 0, "night did not fail")
	t.truthy(int(rec["lines"]) >= 2, "night start and sunrise narration requested")
	s.tick(STEP)
	t.eq(rec["won"], 1, "no processing after win")
	s.free()


func _night_sheep_rules(t: TestRunner) -> void:
	# AC-1.2b: Normal wins only with at least 3 of 10 sheep alive.
	var d: StageDef = _def("1-2-night-1", RunModel.Mode.NORMAL)
	d.params["predators"] = []
	var s: StageProtectFlock = StageProtectFlock.new()
	var rec: Dictionary = _build(s, d, RunModel.Mode.NORMAL)
	s.begin()
	t.eq(s.alive_sheep(), 10, "ten sheep at the start")
	s.remove_sheep(7)
	t.eq(s.alive_sheep(), 3, "three sheep left")
	_run_until_done(s, 120.0)
	t.eq(rec["won"], 1, "AC-1.2b wins with 3 of 10 alive")
	t.eq(rec["failed"], 0, "AC-1.2b no failure with 3 alive")
	s.free()

	var d2: StageDef = _def("1-2-night-1", RunModel.Mode.NORMAL)
	d2.params["predators"] = []
	var s2: StageProtectFlock = StageProtectFlock.new()
	var rec2: Dictionary = _build(s2, d2, RunModel.Mode.NORMAL)
	s2.begin()
	s2.remove_sheep(8)
	t.eq(rec2["failed"], 1, "AC-1.2b fails with 2 of 10 alive")
	t.eq(rec2["reason"], &"sheep-below-min", "fail reason is sheep-below-min")
	t.eq(rec2["won"], 0, "no win after failure")
	s2.free()

	for mode in [RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB]:
		var d3: StageDef = _def("1-2-night-1", mode)
		var s3: StageProtectFlock = StageProtectFlock.new()
		var rec3: Dictionary = _build(s3, d3, mode)
		s3.begin()
		s3.remove_sheep(10)
		_run_until_done(s3, 120.0)
		t.eq(rec3["failed"], 0, "mode %d never fails with every sheep gone" % mode)
		t.eq(rec3["won"], 1, "mode %d still wins the night (minAlive 0)" % mode)
		s3.free()


func _night_predators(t: TestRunner) -> void:
	var d: StageDef = _def("1-2-night-3", RunModel.Mode.NORMAL)
	var s: StageProtectFlock = StageProtectFlock.new()
	var rec: Dictionary = _build(s, d, RunModel.Mode.NORMAL)
	s.begin()
	var peak: int = 0
	var secs: float = 0.0
	while secs < 120.0 and not s.is_finished():
		s.tick(STEP)
		s.on_action_tap()
		peak = maxi(peak, s.live_predators())
		secs += STEP
	t.truthy(peak > 0, "predators spawn in Normal")
	t.truthy(peak <= s.def.param_int("maxPredators", 0), "live predators stay under the cap")
	t.truthy(s.is_finished(), "night finishes")
	t.eq(int(rec["won"]) + int(rec["failed"]), 1, "exactly one outcome")
	t.truthy(int(rec["thrown"]) > 0, "stones were thrown at predators")
	s.free()

	# Lamb: no predators, from data and from the modifier even if data listed some.
	var dl: StageDef = _def("1-2-night-3", RunModel.Mode.LAMB)
	var sl: StageProtectFlock = StageProtectFlock.new()
	_build(sl, dl, RunModel.Mode.LAMB)
	sl.begin()
	var lamb_peak: int = 0
	for i in 900:
		sl.tick(STEP)
		lamb_peak = maxi(lamb_peak, sl.live_predators())
	t.eq(lamb_peak, 0, "Lamb night has no predators")
	sl.free()
	var dn: StageDef = _def("1-2-night-3", RunModel.Mode.NORMAL)
	var sn: StageProtectFlock = StageProtectFlock.new()
	_build(sn, dn, RunModel.Mode.LAMB)
	sn.begin()
	lamb_peak = 0
	for i in 900:
		sn.tick(STEP)
		lamb_peak = maxi(lamb_peak, sn.live_predators())
	t.eq(lamb_peak, 0, "Lamb modifier suppresses spawns even if data lists predators")
	sn.free()

	# Returning a lost sheep reports it.
	var dr: StageDef = _def("1-2-night-1", RunModel.Mode.NORMAL)
	dr.params["predators"] = []
	var sr: StageProtectFlock = StageProtectFlock.new()
	var recr: Dictionary = _build(sr, dr, RunModel.Mode.NORMAL)
	sr.begin()
	var lost: ActorSheep = sr._sheep[0]
	lost.set_state(ActorSheep.State.LOST)
	lost.position = Vector2(300, 300)
	sr.david.position = Vector2(310, 300)
	sr.tick(STEP)
	t.eq(recr["saved"], 1, "walking near a lost sheep returns it")
	t.eq(lost.state, ActorSheep.State.FLOCK, "returned sheep rejoins the flock")
	sr.free()


func _throw_until(stage: StagePlayBase, rec: Dictionary, hits_wanted: int, boss: StageBoss) -> void:
	var guard: int = 0
	while boss.hits < hits_wanted and not boss.is_finished() and guard < 6000:
		boss.on_action_tap()
		boss.tick(0.05)
		guard += 1


func _lion(t: TestRunner) -> void:
	var d: StageDef = _def("1-3-lion", RunModel.Mode.NORMAL)
	var s: StageBoss = StageBoss.new()
	var rec: Dictionary = _build(s, d, RunModel.Mode.NORMAL)
	s.begin()
	t.truthy(int(rec["lines"]) >= 1, "lion enter line requested")
	_throw_until(s, rec, 1, s)
	t.eq(s.hits, 1, "one stone hit counted")
	var thrown_before: int = int(rec["thrown"])
	s.on_action_tap()
	t.eq(int(rec["thrown"]), thrown_before, "no throw while the lion is stunned")
	t.falsy(s.lamb_dropped, "lamb still held after 1 hit")
	_throw_until(s, rec, 3, s)
	t.eq(s.hits, 3, "AC-1.3 three hits")
	t.truthy(s.lamb_dropped, "AC-1.3 lion drops the lamb after 3 hits")
	t.falsy(s.is_finished(), "AC-1.3 lion has not fled at 3 hits")
	_throw_until(s, rec, 6, s)
	t.eq(s.hits, 6, "AC-1.3 six hits")
	t.truthy(s.fled, "AC-1.3 lion flees after 6 hits")
	t.eq(rec["won"], 1, "lion stage won after 6 hits")
	s.free()

	# Contact damage with a cooldown.
	var d2: StageDef = _def("1-3-lion", RunModel.Mode.NORMAL)
	var s2: StageBoss = StageBoss.new()
	var rec2: Dictionary = _build(s2, d2, RunModel.Mode.NORMAL)
	s2.begin()
	s2.tick(STEP)
	s2.david.position = s2.boss.position
	s2.tick(STEP)
	s2.david.position = s2.boss.position
	s2.tick(STEP)
	t.eq(rec2["hits"], 1, "lion contact deals one hit, then invulnerability")
	s2.free()


func _bear(t: TestRunner) -> void:
	var d: StageDef = _def("1-4-bear", RunModel.Mode.NORMAL)
	var s: StageBoss = StageBoss.new()
	var rec: Dictionary = _build(s, d, RunModel.Mode.NORMAL)
	s.begin()
	var guard: int = 0
	while not s.is_finished() and guard < 20000:
		s.on_action_tap()
		s.tick(0.05)
		guard += 1
	t.eq(rec["won"], 1, "bear stage won by slinging stones")
	t.truthy(s.hits >= 6, "bear needs six total hits")
	s.free()

	# Slip double hit.
	var d2: StageDef = _def("1-4-bear", RunModel.Mode.NORMAL)
	var s2: StageBoss = StageBoss.new()
	_build(s2, d2, RunModel.Mode.NORMAL)
	s2.begin()
	s2._bear_state = StageBoss.BearState.SLIPPED
	s2.boss.visible = true
	s2._on_stone_hit(s2.boss)
	t.eq(s2.hits, 2, "a hit on a slipped bear counts double")
	s2.free()


func _boss_lamb(t: TestRunner) -> void:
	for pair in [["1-3-lion", 1], ["1-4-bear", 3]]:
		var d: StageDef = _def(pair[0], RunModel.Mode.LAMB)
		var s: StageBoss = StageBoss.new()
		var rec: Dictionary = _build(s, d, RunModel.Mode.LAMB)
		s.begin()
		t.truthy(s.boss == null, "%s has no boss in Lamb mode" % pair[0])
		t.eq(s.lambs.size(), pair[1], "%s gather count" % pair[0])
		for l in s.lambs:
			s.david.position = l.position
			s.tick(STEP)
		t.eq(rec["won"], 1, "%s Lamb wins by gathering" % pair[0])
		t.eq(rec["failed"], 0, "%s Lamb never fails" % pair[0])
		s.free()


func _rhythm(t: TestRunner) -> void:
	var d: StageDef = _def("1-6-harp", RunModel.Mode.NORMAL)
	var s: StageRhythm = StageRhythm.new()
	var rec: Dictionary = _build(s, d, RunModel.Mode.NORMAL)
	s.begin()
	var secs: float = _run_until_done(s, 120.0)
	t.truthy(absf(secs - 60.0) <= 0.2, "AC-1.6 rhythm lasts 60 s (got %s)" % secs)
	t.eq(rec["won"], 1, "AC-1.6 all misses still wins")
	t.eq(rec["failed"], 0, "AC-1.6 misses never fail")
	t.eq(s.hits, 0, "no hits when never pressing")
	t.truthy(s.misses > 0, "notes were missed")
	t.truthy(int(rec["lines"]) >= 4, "enter and win lines plus the end card were requested")
	s.free()

	var s2: StageRhythm = StageRhythm.new()
	var rec2: Dictionary = _build(s2, _def("1-6-harp", RunModel.Mode.NORMAL), RunModel.Mode.NORMAL)
	s2.begin()
	var guard: int = 0
	while not s2.is_finished() and guard < 5000:
		s2.tick(0.05)
		if s2.note_in_window():
			s2.on_action_tap()
		guard += 1
	t.truthy(s2.hits > 0, "OK on the gold line is a hit")
	t.truthy(s2.brightness > 0.0, "hits brighten the room")
	t.eq(rec2["won"], 1, "rhythm with hits wins")
	s2.free()


func _cutscenes(t: TestRunner) -> void:
	for id in ["1-1-opening", "1-5-samuel"]:
		var d: StageDef = _def(id, RunModel.Mode.NORMAL)
		var expect_lines: int = 0
		var expect_gold: int = 0
		for b in d.cutscene_beats():
			var bt: String = str((b as Dictionary).get("type", ""))
			if bt == "narration" or bt == "dialogue" or bt == "caption" or bt == "tutorial":
				expect_lines += 1
				var beat_line: Dictionary = LineBook.line(StringName(str((b as Dictionary).get("line", ""))))
				if not str(beat_line.get("caption", "")).is_empty():
					expect_lines += 1  # the verse caption is emitted as its own line
			elif bt == "gold-light":
				expect_gold += 1
		var s: StageCutscene = StageCutscene.new()
		var rec: Dictionary = _build(s, d, RunModel.Mode.NORMAL)
		s.begin()
		var guard: int = 0
		while not s.is_finished() and guard < 5000:
			s.input_dir = Vector2.ZERO
			if s.waiting == StageCutscene.Wait.TUTORIAL:
				match s._until:
					"david-moved":
						s.input_dir = Vector2(1, 0)
					"sheep-returned":
						s.david.position = s._stray.position
					"stone-thrown":
						s.on_action_tap()
			s.tick(0.5)
			guard += 1
		t.eq(rec["won"], 1, "%s cutscene wins at the end" % id)
		t.eq(rec["lines"], expect_lines, "%s every line beat requested in order" % id)
		t.eq(rec["gold"], expect_gold, "%s gold-light beats" % id)
		s.free()


func _modes_never_fail(t: TestRunner) -> void:
	for mode in [RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB]:
		for id in ["1-3-lion", "1-4-bear"]:
			var s: StageBoss = StageBoss.new()
			var rec: Dictionary = _build(s, _def(id, mode), mode)
			s.begin()
			if s.boss != null:
				s.david.position = s.boss.position
			for i in 300:
				s.tick(STEP)
			t.eq(rec["failed"], 0, "%s mode %d never calls fail" % [id, mode])
			s.free()
