extends RefCounted
## Stage 2.2 (delivery): timer only in Normal, loaves >= 1 to win, floor in Shepherd and Lamb.

const U := preload("res://tests/ch2-util.gd")


func run(t: TestRunner) -> void:
	_timer(t)
	_win_needs_loaves(t)
	_floor_and_loss(t)
	_bump_rules(t)
	_hazards(t)
	_events(t)


func _make(mode: RunModel.Mode, hazards: bool = true, blessing: String = "") -> Array:
	var d: StageDef = U.stage_def("2-2-road", mode)
	if not hazards:
		d.params["hazards"] = []
	var s: StageDelivery = StageDelivery.new()
	var rec: Dictionary = U.build(s, d, mode, blessing)
	return [s, rec]


func _timer(t: TestRunner) -> void:
	for mode in U.modes():
		var pair: Array = _make(mode)
		var s: StageDelivery = pair[0]
		var rec: Dictionary = pair[1]
		s.begin()
		U.run_for(s, 125.0)
		var key: String = RunModel.mode_key(mode)
		if mode == RunModel.Mode.NORMAL:
			t.eq(rec["failed"], 1, "%s: the 120 s limit fails the stage" % key)
			t.eq(rec["reason"], &"timeout", "%s: reason is timeout" % key)
			t.truthy(s.elapsed >= 119.9 and s.elapsed <= 121.0, "%s: fails at 120 s (got %s)" % [key, s.elapsed])
			var shown: bool = false
			for c in (rec["counters"] as Array):
				if (c as Array)[0] == &"time" and int((c as Array)[1]) > 0:
					shown = true
			t.truthy(shown, "Normal shows the time left")
		else:
			t.eq(rec["failed"], 0, "%s: the time limit is ignored" % key)
			t.falsy(s.is_finished(), "%s: stage keeps running past 120 s" % key)
			var hidden: bool = true
			for c in (rec["counters"] as Array):
				if (c as Array)[0] == &"time" and int((c as Array)[1]) >= 0:
					hidden = false
			t.truthy(hidden, "%s: no timer shown" % key)
		s.free()


func _walk_to_camp(s: StageDelivery, max_sec: float) -> void:
	var el: float = 0.0
	while el < max_sec and not s.is_finished():
		s.input_dir = Vector2.RIGHT
		s.tick(U.STEP)
		el += U.STEP
	s.input_dir = Vector2.ZERO


func _win_needs_loaves(t: TestRunner) -> void:
	for mode in U.modes():
		for blessing in U.blessings():
			var tag: String = U.tag(mode, blessing)
			# No hazards: the walk always arrives, with every loaf, in every mode and Blessing.
			var clear: Array = _make(mode, false, blessing)
			var s: StageDelivery = clear[0]
			var rec: Dictionary = clear[1]
			s.begin()
			_walk_to_camp(s, 60.0)
			t.eq(rec["won"], 1, "%s: reaching the camp wins" % tag)
			t.eq(rec["failed"], 0, "%s: no failure on a clear road" % tag)
			t.truthy(s.loaves >= 1, "%s: arrives with at least one loaf" % tag)
			s.free()
			# With hazards the walk ends in exactly one outcome; a win always has >= 1 loaf.
			var busy: Array = _make(mode, true, blessing)
			var bs: StageDelivery = busy[0]
			var brec: Dictionary = busy[1]
			bs.begin()
			_walk_to_camp(bs, 100.0)
			t.eq(int(brec["won"]) + int(brec["failed"]), 1, "%s: a hazard walk has one outcome" % tag)
			if int(brec["won"]) == 1:
				t.truthy(bs.loaves >= 1, "%s: a win keeps at least one loaf" % tag)
			if mode != RunModel.Mode.NORMAL:
				t.eq(brec["won"], 1, "%s: Shepherd and Lamb always arrive" % tag)
				t.truthy(bs.loaves >= 1, "%s: loaves never below the floor" % tag)
			bs.free()


func _bump_into(s: StageDelivery) -> void:
	var h: ActorHazard = s.hazards[0]
	s.david.position = h.position
	s._hit_cd = 0.0
	s._check_bump()


func _floor_and_loss(t: TestRunner) -> void:
	for mode in U.modes():
		var pair: Array = _make(mode)
		var s: StageDelivery = pair[0]
		var rec: Dictionary = pair[1]
		s.begin()
		var key: String = RunModel.mode_key(mode)
		t.eq(s.loaves, 3, "%s: starts with 3 loaves" % key)
		for i in 6:
			if s.is_finished():
				break
			_bump_into(s)
		if mode == RunModel.Mode.NORMAL:
			t.eq(rec["failed"], 1, "Normal: all loaves lost fails the stage")
			t.eq(rec["reason"], &"loaves-zero", "Normal: reason is loaves-zero")
			t.eq(s.bumps, 3, "Normal: fails on the third bump")
		else:
			t.eq(rec["failed"], 0, "%s: losing loaves never fails" % key)
			t.eq(s.loaves, 1, "%s: loaves stay at the floor" % key)
			t.eq(s.bumps, 6, "%s: every bump counted" % key)
		s.free()


func _bump_rules(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StageDelivery = pair[0]
	s.begin()
	var h: ActorHazard = s.hazards[0]
	s.david.position = h.position + Vector2(10, 0)
	s._check_bump()
	t.eq(s.loaves, 2, "a bump costs lossPerDrop (1) loaf")
	t.truthy(s.david.position.distance_to(h.position) > h.radius + s.david.radius, "David is knocked clear of the hazard")
	var after: Vector2 = s.david.position
	s.david.position = h.position
	s._check_bump()
	t.eq(s.loaves, 2, "no second loss while invulnerable")
	s.david.position = after
	s.free()


func _hazards(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.LAMB)
	var s: StageDelivery = pair[0]
	var expected: int = 0
	for h in s.def.param_array("hazards"):
		expected += int((h as Dictionary).get("count", 0))
	t.truthy(expected > 0, "road data defines hazards")
	t.eq(s.hazards.size(), expected, "Lamb keeps the hazards (they are not enemies)")
	var kinds: Dictionary = {}
	for h in s.hazards:
		kinds[h.kind] = true
	t.eq(kinds.size(), 3, "cart, goat and rolling rock are all present")
	t.truthy(s.hazards.size() <= StageDelivery.MAX_HAZARDS, "hazard count is capped")
	s.begin()
	var before: int = s.world.get_child_count()
	U.run_for(s, 40.0)
	t.eq(s.world.get_child_count(), before, "hazard nodes are reused, none created while playing")
	s.free()
	var big: StageDef = U.stage_def("2-2-road", RunModel.Mode.NORMAL)
	big.params["hazards"] = [{"kind": "cart", "speed": 100, "count": 99}]
	var bs: StageDelivery = StageDelivery.new()
	U.build(bs, big, RunModel.Mode.NORMAL)
	t.eq(bs.hazards.size(), StageDelivery.MAX_HAZARDS, "an oversized hazard list is capped")
	bs.free()


func _events(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL, false)
	var s: StageDelivery = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	var half_seen: int = 0
	var el: float = 0.0
	while el < 60.0 and not s.is_finished():
		s.input_dir = Vector2.RIGHT
		s.tick(U.STEP)
		el += U.STEP
		if s.halfway_done and half_seen == 0:
			half_seen = (rec["ids"] as Array).count(&"c2-2-halfway")
			t.truthy(s.progress >= 0.5 and s.progress < 0.6, "the halfway line plays at about halfway (progress %s)" % s.progress)
	t.eq(half_seen, 1, "halfway line requested once")
	t.eq((rec["ids"] as Array).count(&"c2-2-halfway"), 1, "halfway line never repeats")
	t.eq((rec["ids"] as Array).count(&"c2-2-arrival"), 1, "arrival line requested once")
	t.eq((rec["ids"] as Array).back(), &"c2-2-arrival", "arrival is the last line")
	s.free()
