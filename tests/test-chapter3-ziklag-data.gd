extends RefCounted
## The real Chapter 3 data for 3.9 Ziklag driven by a bot: every mode x every Chapter 3 Blessing.

const U := preload("res://tests/ch3-stages-util.gd")


func run(t: TestRunner) -> void:
	var pool: Array = [""]
	var ch: Dictionary = BalanceData.read_json("res://data/chapters/ch3.json")
	for b in (ch.get("blessingPool", []) as Array):
		pool.append(str(b))
	for mode in U.modes():
		var def: StageDef = null
		for d in StageDef.load_chapter(3, mode):
			if d.id == &"3-9-ziklag":
				def = d
		if def == null:
			t.skip("Chapter 3 stage data not present: real 3.9 not driven")
			return
		for blessing in pool:
			_drive(t, def, mode, blessing)


func _drive(t: TestRunner, def: StageDef, mode: RunModel.Mode, blessing: String) -> void:
	var s: StageZiklag = StageZiklag.new()
	var rec: Dictionary = {"won": 0, "failed": 0, "followers": 0}
	s.stage_won.connect(func() -> void: rec["won"] = int(rec["won"]) + 1)
	s.stage_failed.connect(func(_r: StringName) -> void: rec["failed"] = int(rec["failed"]) + 1)
	s.follower_added.connect(func(n: int) -> void: rec["followers"] = int(rec["followers"]) + n)
	var rm: RunModel = RunModel.new()
	rm.mode = mode
	rm.rng_seed = 5
	s.setup(def, rm, U.stack(mode, blessing))
	s.begin()
	var tag: String = "3.9 data " + U.tag(mode, blessing)
	var guard: int = 0
	while not s.is_finished() and guard < 20:
		var best: int = -1
		var best_d: float = INF
		for i in s.families.size():
			if not s.families[i].freed:
				var dd: float = s.families[i].position.distance_to(s.david.position)
				if dd < best_d:
					best_d = dd
					best = i
		if best < 0:
			break
		U.walk_to(s, s.families[best].position + Vector2(-50.0, 0.0), 30.0)
		s.on_action_tap()
		guard += 1
	t.eq(rec["won"], 1, "%s: won" % tag)
	t.eq(rec["failed"], 0, "%s: never fails" % tag)
	t.eq(rec["followers"], s.family_total * def.param_int("helperPerFamily", 1), "%s: a follower per family" % tag)
	t.eq(s.raiders.size(), 0 if mode == RunModel.Mode.LAMB else def.param_int("raiders", 0), "%s: raiders per mode" % tag)
	s.free()
