extends RefCounted
## Stage 2.5 (stealth, the brook): stones carried 0..5, pushback, Lamb has no scouts.

const U := preload("res://tests/ch2-util.gd")


func run(t: TestRunner) -> void:
	_stones(t)
	_exit_with_fewer(t)
	_run_state_carry(t)
	_hiding_and_pushback(t)
	_modes(t)
	_outcomes(t)


func _make(mode: RunModel.Mode, blessing: String = "") -> Array:
	var s: StageStealth = StageStealth.new()
	var rec: Dictionary = U.build(s, U.stage_def("2-5-brook", mode), mode, blessing)
	return [s, rec]


func _pick_all(s: StageStealth, count: int) -> void:
	for i in count:
		s.david.position = s.pickups[i].position
		s.tick(U.STEP)


func _stones(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.LAMB)
	var s: StageStealth = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	t.eq(s.pickups.size(), 5, "five glowing stones in the stream")
	t.eq(s.collected, 0, "starts with none")
	for i in 5:
		s.david.position = s.pickups[i].position
		s.tick(U.STEP)
		t.eq(s.collected, i + 1, "stone %d picked up by walking onto it" % (i + 1))
		t.eq(rec["collected"], i + 1, "stone_collected emitted for stone %d" % (i + 1))
		t.eq((rec["ids"] as Array).count(&"c2-5-each-stone"), i + 1, "each stone gets its line (%d)" % (i + 1))
	t.eq((rec["ids"] as Array).count(&"c2-5-five"), 1, "five stones: the narrator line, once")
	s.tick(U.STEP)
	t.eq(rec["collected"], 5, "a stone is never collected twice")
	t.falsy(s.is_finished(), "collecting the last stone does not end the stage by itself")
	s.free()


func _exit_with_fewer(t: TestRunner) -> void:
	for mode in U.modes():
		var pair: Array = _make(mode)
		var s: StageStealth = pair[0]
		var rec: Dictionary = pair[1]
		s.begin()
		_pick_all(s, 2)
		s.david.position = s.exit_rect.get_center()
		s.tick(U.STEP)
		var key: String = RunModel.mode_key(mode)
		t.eq(rec["won"], 1, "%s: the exit is reachable with fewer than five stones" % key)
		t.eq(rec["collected"], 2, "%s: only the collected stones are carried" % key)
		s.free()
	# The far corner of the field (where the D-pad clamps David) counts as the exit.
	var corner: Array = _make(RunModel.Mode.NORMAL)
	var cs: StageStealth = corner[0]
	cs.begin()
	cs.david.position = StagePlayBase.FIELD.end
	cs.tick(U.STEP)
	t.eq(corner[1]["won"], 1, "the exit's corner at the field edge counts")
	cs.free()
	# Zero stones: still a win (the boss fails over to the brook later).
	var pair0: Array = _make(RunModel.Mode.NORMAL)
	var s0: StageStealth = pair0[0]
	s0.begin()
	s0.david.position = s0.exit_rect.get_center()
	s0.tick(U.STEP)
	t.eq(pair0[1]["won"], 1, "Normal: leaving with no stones is allowed")
	s0.free()


func _run_state_carry(t: TestRunner) -> void:
	# The host adds each collected stone to RunModel.stones (the single source), 0..5.
	var rs: Node = U.new_run_state()
	rs.call("start_chapter", 2, RunModel.Mode.NORMAL)
	U.go_to(rs, "2-5-brook")
	var model: RunModel = rs.get("model") as RunModel
	t.eq(model.stones, 0, "stones start at 0 in the brook")
	var s: StageStealth = StageStealth.new()
	U.build(s, rs.get("current_stage") as StageDef, RunModel.Mode.NORMAL)
	s.stone_collected.connect(rs.get("add_stones").bind(1))
	s.begin()
	_pick_all(s, 5)
	t.eq(model.stones, 5, "five stones collected = RunModel.stones 5")
	s.free()
	rs.free()


func _hiding_and_pushback(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StageStealth = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	_pick_all(s, 2)
	var sc: ActorScout = s.scouts[0]
	# In plain view, close to a scout: seen for sightSec (1.5 s) -> pushed back to the near bank.
	var spot: Vector2 = Vector2(sc.position.x, sc.position.y + 150.0)
	s.david.position = spot
	var secs: float = 0.0
	while s.pushbacks == 0 and secs < 4.0:
		s.david.position.x = sc.position.x
		s.david.position.y = spot.y
		s.tick(U.STEP)
		secs += U.STEP
	t.eq(s.pushbacks, 1, "being seen for sightSec pushes David back")
	t.truthy(secs >= 1.4 and secs <= 1.8, "pushed back after about 1.5 s (got %s)" % secs)
	t.truthy(s.david.position.y > 700.0, "pushback puts David on the near bank")
	t.eq(rec["failed"], 0, "being seen is not a failure")
	t.eq(s.collected, 2, "no stone is lost to a pushback")
	t.falsy(s.is_finished(), "the stage keeps running after a pushback")
	# Standing just below a rock hides David, however long he stays.
	var rock: ColorRect = s.rocks[0]
	var behind: Vector2 = Vector2(rock.position.x + rock.size.x * 0.5, rock.position.y + rock.size.y + 40.0)
	s._hit_cd = 0.0
	sc.position.x = behind.x
	sc.position.y = 190.0
	for i in 40:
		s.david.position = behind
		sc.position.x = behind.x
		s.tick(U.STEP)
	t.truthy(s.is_hidden(), "David is hidden just below a rock")
	t.eq(s.pushbacks, 1, "hidden David is never pushed back")
	s.free()


func _modes(t: TestRunner) -> void:
	var n: Array = _make(RunModel.Mode.NORMAL)
	var sh: Array = _make(RunModel.Mode.SHEPHERD)
	var lb: Array = _make(RunModel.Mode.LAMB)
	var ns: StageStealth = n[0]
	var ss: StageStealth = sh[0]
	var ls: StageStealth = lb[0]
	t.eq(ns.scouts.size(), 3, "Normal: three scouts on the far bank")
	t.near(ss.scouts[0].speed, ns.scouts[0].speed * 0.6, "Shepherd: scouts walk at 0.6x")
	t.near(ss.sight_sec, ns.sight_sec * 2.0, "Shepherd: sightSec is doubled")
	t.eq(ls.scouts.size(), 0, "Lamb: scouts are removed")
	# Shepherd: still unseen after the Normal sightSec, pushed back after the doubled one.
	ss.begin()
	var sc: ActorScout = ss.scouts[0]
	var secs: float = 0.0
	while ss.pushbacks == 0 and secs < 6.0:
		ss.david.position = Vector2(sc.position.x, 340.0)
		ss.tick(U.STEP)
		secs += U.STEP
	t.truthy(secs >= 2.9 and secs <= 3.3, "Shepherd: pushed back after about 3 s (got %s)" % secs)
	# Lamb: nothing sees David wherever he stands.
	ls.begin()
	for i in 80:
		ls.david.position = Vector2(960, 340)
		ls.tick(U.STEP)
	t.eq(ls.pushbacks, 0, "Lamb: never pushed back")
	ns.free()
	ss.free()
	ls.free()


func _outcomes(t: TestRunner) -> void:
	# Every mode x Chapter 2 Blessing: a bot that gathers all stones and leaves wins with five.
	for mode in U.modes():
		for blessing in U.blessings():
			var pair: Array = _make(mode, blessing)
			var s: StageStealth = pair[0]
			var rec: Dictionary = pair[1]
			s.begin()
			_pick_all(s, 5)
			s.david.position = s.exit_rect.get_center()
			s.tick(U.STEP)
			var tag: String = U.tag(mode, blessing)
			t.eq(rec["won"], 1, "%s: brook is won" % tag)
			t.eq(rec["failed"], 0, "%s: brook never fails" % tag)
			t.eq(rec["collected"], 5, "%s: five stones carried" % tag)
			s.free()
