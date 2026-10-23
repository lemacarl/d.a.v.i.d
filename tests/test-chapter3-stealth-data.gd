extends RefCounted
## The real Chapter 3 data (3.6 En-gedi and 3.8 camp) driven by bots: every mode x every Chapter 3
## Blessing wins, nobody is hurt, Saul is spared.

const U := preload("res://tests/ch3-stages-util.gd")


func run(t: TestRunner) -> void:
	var pool: Array = [""]
	var ch: Dictionary = BalanceData.read_json("res://data/chapters/ch3.json")
	for b in (ch.get("blessingPool", []) as Array):
		pool.append(str(b))
	for mode in U.modes():
		var defs: Array[StageDef] = StageDef.load_chapter(3, mode)
		var robe: StageDef = _find(defs, "3-6-en-gedi")
		var camp: StageDef = _find(defs, "3-8-camp")
		if robe == null or camp == null:
			t.skip("Chapter 3 stage data not present: real 3.6 / 3.8 not driven")
			return
		for blessing in pool:
			_robe(t, robe, mode, blessing)
			_camp(t, camp, mode, blessing)


func _find(defs: Array[StageDef], id: String) -> StageDef:
	for d in defs:
		if d.id == StringName(id):
			return d
	return null


func _stage(def: StageDef, mode: RunModel.Mode, blessing: String) -> Array:
	var s: StageStealth = StageStealth.new()
	var rec: Dictionary = {"won": 0, "failed": 0, "spared": 0, "hits": 0}
	s.stage_won.connect(func() -> void: rec["won"] = int(rec["won"]) + 1)
	s.stage_failed.connect(func(_r: StringName) -> void: rec["failed"] = int(rec["failed"]) + 1)
	s.spared.connect(func() -> void: rec["spared"] = int(rec["spared"]) + 1)
	s.hit_taken.connect(func(_n: int) -> void: rec["hits"] = int(rec["hits"]) + 1)
	var rm: RunModel = RunModel.new()
	rm.mode = mode
	rm.rng_seed = 3
	s.setup(def, rm, U.stack(mode, blessing))
	return [s, rec]


func _robe(t: TestRunner, def: StageDef, mode: RunModel.Mode, blessing: String) -> void:
	var pair: Array = _stage(def, mode, blessing)
	var s: StageStealth = pair[0]
	var tag: String = "3.6 data " + U.tag(mode, blessing)
	s.begin()
	var top: float = StagePlayBase.FIELD.position.y + 110.0
	U.walk_to(s, Vector2(s.david.position.x + 380.0, top))
	U.walk_to(s, Vector2(s.saul.position.x + 260.0, top))
	U.walk_to(s, s.saul.position + Vector2(72.0, -40.0))
	s.on_action_tap()
	t.eq(pair[1]["won"], 1, "%s: won" % tag)
	t.eq(pair[1]["spared"], 1, "%s: Saul spared" % tag)
	t.eq(pair[1]["failed"], 0, "%s: never fails" % tag)
	t.eq(s.pushbacks, 0, "%s: the wall route is never noticed" % tag)
	s.free()


func _camp(t: TestRunner, def: StageDef, mode: RunModel.Mode, blessing: String) -> void:
	var pair: Array = _stage(def, mode, blessing)
	var s: StageStealth = pair[0]
	var tag: String = "3.8 data " + U.tag(mode, blessing)
	s.begin()
	var total: float = s._path_length()
	var d: float = 0.0
	while d <= total and not s.is_finished():
		var p: Vector2 = s._path_point_at(d)
		for th in s.thorns:
			if p.distance_to(th.position) < th.radius + 90.0:
				var a: Vector2 = s._path_point_at(d - 5.0)
				var b: Vector2 = s._path_point_at(d + 5.0)
				p += (b - a).normalized().orthogonal() * (th.radius + 25.0)
				break
		U.walk_to(s, p, 8.0)
		d += 25.0
	U.walk_to(s, s.path_points[s.path_points.size() - 1], 8.0)
	t.eq(pair[1]["won"], 1, "%s: won without any Blessing needed" % tag)
	t.eq(pair[1]["failed"], 0, "%s: never fails" % tag)
	t.eq(s.items_taken, 2, "%s: spear and jug taken" % tag)
	t.eq(s.pushbacks, 0, "%s: the centre line is never noticed" % tag)
	t.eq(pair[1]["spared"], 1, "%s: nobody woke, spared" % tag)
	s.free()
