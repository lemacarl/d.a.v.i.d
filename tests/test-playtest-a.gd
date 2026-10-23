extends RefCounted
## Family playtest fixes A: a rescued sheep walks back to the flock, stone hits emit the `hit`
## cue on the hit frame, and the bear's charge is readable (warning lane, windup, slip glow).

const STEP: float = 0.05


func run(t: TestRunner) -> void:
	_sheep_returns(t)
	_hit_cue_flock(t)
	_hit_cue_bosses(t)
	_hit_cue_data(t)
	_bear_readable(t)


func _def(stage_id: String, mode: RunModel.Mode) -> StageDef:
	for d in StageDef.load_chapter(1, mode):
		if d.id == StringName(stage_id):
			return d
	return null


func _build(stage: StageBase, d: StageDef, mode: RunModel.Mode) -> Dictionary:
	var rec: Dictionary = {"saved": 0, "sfx": []}
	stage.sheep_saved.connect(func() -> void: rec["saved"] = int(rec["saved"]) + 1)
	stage.sfx_requested.connect(func(cue: StringName) -> void: (rec["sfx"] as Array).append(cue))
	var rm: RunModel = RunModel.new()
	rm.mode = mode
	stage.setup(d, rm, ModifierStack.new(mode))
	return rec


func _sheep_returns(t: TestRunner) -> void:
	for mode in [RunModel.Mode.NORMAL, RunModel.Mode.SHEPHERD]:
		var tag: String = RunModel.mode_key(mode)
		var d: StageDef = _def("1-2-night-1", mode)
		d.params["predators"] = []
		var s: StageProtectFlock = StageProtectFlock.new()
		var rec: Dictionary = _build(s, d, mode)
		s.begin()
		var sheep: ActorSheep = s._sheep[0]
		var spot: Vector2 = StagePlayBase.FIELD.get_center() + sheep.ring
		sheep.set_state(ActorSheep.State.LOST)
		sheep.position = StagePlayBase.FIELD.position + Vector2(40, 40)
		s.david.position = sheep.position + Vector2(20, 0)
		var start_d: float = sheep.position.distance_to(spot)
		s.tick(STEP)
		t.eq(rec["saved"], 1, "%s: rescue reports the sheep saved" % tag)
		t.eq(sheep.state, ActorSheep.State.FLOCK, "%s: rescued sheep is in the flock at once" % tag)
		t.truthy(sheep.returning, "%s: rescued sheep walks back" % tag)
		s.david.position = StagePlayBase.FIELD.end
		var d_before: float = sheep.position.distance_to(spot)
		s.tick(STEP)
		t.truthy(sheep.position.distance_to(spot) < d_before, "%s: the sheep moves toward the flock" % tag)
		var guard: int = 0
		while sheep.returning and guard < 400:
			s.tick(STEP)
			guard += 1
		t.falsy(sheep.returning, "%s: the sheep arrives (%.0f px walked in %d steps)" % [tag, start_d, guard])
		t.truthy(sheep.position.distance_to(spot) < 120.0, "%s: sheep rejoined the flock" % tag)
		for i in 60:
			s.tick(STEP)
		t.truthy(sheep.position.distance_to(spot) < 160.0, "%s: sheep stays with the flock" % tag)
		t.eq(rec["saved"], 1, "%s: saved is reported once" % tag)
		s.free()


func _hit_cue_flock(t: TestRunner) -> void:
	var d: StageDef = _def("1-2-night-1", RunModel.Mode.NORMAL)
	var s: StageProtectFlock = StageProtectFlock.new()
	var rec: Dictionary = _build(s, d, RunModel.Mode.NORMAL)
	s.begin()
	var p: ActorPredator = s._predators[0]
	p.activate(&"jackal", s.david.position + Vector2(400, 0), 0.0)
	s.on_action_tap()
	t.falsy((rec["sfx"] as Array).has(&"hit"), "no hit cue at the throw")
	var guard: int = 0
	while not (rec["sfx"] as Array).has(&"hit") and guard < 100:
		s.tick(0.02)
		guard += 1
	t.truthy((rec["sfx"] as Array).has(&"hit"), "hit cue when the stone lands on a jackal")
	t.truthy(guard > 1, "the cue comes on the hit frame, after the flight")
	t.eq(p.state, ActorPredator.State.FLEE, "the jackal runs off")
	s.free()


func _hit_cue_bosses(t: TestRunner) -> void:
	for id in ["1-3-lion", "1-4-bear"]:
		var d: StageDef = _def(id, RunModel.Mode.NORMAL)
		var s: StageBoss = StageBoss.new()
		var rec: Dictionary = _build(s, d, RunModel.Mode.NORMAL)
		s.begin()
		s.boss.visible = true
		s._on_stone_hit(s.boss)
		t.truthy((rec["sfx"] as Array).has(&"hit"), "%s: hit cue on a stone hit" % id)
		s.free()


func _hit_cue_data(t: TestRunner) -> void:
	t.truthy(Audio.cue_ids().has("hit"), "audio data has the hit cue")
	var paths: PackedStringArray = Audio.cue_paths(&"hit")
	t.truthy(paths.size() >= 2, "hit cue has variants")
	for p in paths:
		t.truthy(ResourceLoader.exists(p), "hit cue file exists: %s" % p)


func _bear_readable(t: TestRunner) -> void:
	var d: StageDef = _def("1-4-bear", RunModel.Mode.NORMAL)
	var s: StageBoss = StageBoss.new()
	_build(s, d, RunModel.Mode.NORMAL)
	s.begin()
	var bear: ActorBear = s.boss as ActorBear
	t.truthy(bear.radius >= 90.0, "the bear is large")
	var guard: int = 0
	while s._bear_state != StageBoss.BearState.WINDUP and guard < 200:
		s.tick(STEP)
		guard += 1
	t.eq(s._bear_state, StageBoss.BearState.WINDUP, "the bear winds up")
	t.truthy(s._band.visible, "the warning lane shows before the charge")
	t.truthy(s._band.half_height > bear.hit_radius(), "the lane covers the danger zone")
	s.tick(0.3)
	t.truthy(bear.windup > 0.0, "the bear leans back and rumbles during the windup")
	guard = 0
	while s._bear_state == StageBoss.BearState.WINDUP and guard < 200:
		s.tick(STEP)
		guard += 1
	t.eq(s._bear_state, StageBoss.BearState.CHARGE, "then it charges")
	t.truthy(bear.charging, "the charge pose is set")
	# Slip: the bear stops at the rocks, glows, and a hit counts double.
	s._rock_x = bear.position.x
	s._rock.position.x = bear.position.x
	s._rock.visible = true
	s.tick(STEP)
	t.eq(s._bear_state, StageBoss.BearState.SLIPPED, "the bear slips on the rocks")
	t.truthy(bear.slipped, "the golden glow marks the double-hit window")
	t.truthy(s._rock.visible, "the rocks stay drawn while the bear stumbles")
	s._on_stone_hit(bear)
	t.eq(s.hits, 2, "a hit in the glow counts double")
	t.falsy(bear.slipped, "the glow ends after the hit")
	s.free()
