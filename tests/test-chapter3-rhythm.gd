extends RefCounted
## Stage 3.2: harp rhythm with Saul's spear dodge. 3 dodges win; 3 hits restart only in Normal;
## Shepherd never fails; Lamb has no spears. Story lines never change with mode or Blessing.

const U := preload("res://tests/ch3-camp-util.gd")

var _made: Array[Node] = []


func run(t: TestRunner) -> void:
	_data(t)
	_dodging_wins(t)
	_three_hits_lose(t)
	_shepherd_and_lamb(t)
	_glow_before_flight(t)
	_harp_continues(t)
	_bounded_nodes(t)
	_outcomes(t)
	for n in _made:
		n.free()


func _make(mode: RunModel.Mode, blessing: String = "") -> Array:
	var s: StageRhythm = StageRhythm.new()
	_made.append(s)
	var rec: Dictionary = U.build(s, U.stage_def("3-2-spear", mode), mode, blessing)
	return [s, rec]


## Steps out of the lane as soon as a spear is aimed at it. Returns simulated seconds.
func _dodge_bot(s: StageRhythm, max_sec: float = 200.0) -> float:
	var el: float = 0.0
	while el < max_sec and not s.is_finished():
		s.tick(U.STEP)
		el += U.STEP
		if s.spear_phase == StageRhythm.Spear.GLOW and s.lane == s.spear_lane:
			s.step_lane(1 if s.lane == 0 else -1)
	return el


func _data(t: TestRunner) -> void:
	var d: StageDef = U.stage_def("3-2-spear", RunModel.Mode.NORMAL)
	t.eq(d.type, &"rhythm", "3.2 is a rhythm stage")
	t.eq(d.param_int("spearDodge.count"), 3, "three dodges to escape")
	t.eq(d.win_kind(), &"count-reached", "the win is count-reached (dodges)")
	t.eq(int(d.lose_for(&"spear-hits")["count"]), 3, "three spear hits lose")
	t.eq(d.on_lose_for(&"spear-hits")["target"], "restart-stage", "the loss restarts the stage")
	for key in ["spearFlightSec", "spearLaneOffsetPx", "campGathererCount", "arrowFlightSec", "arrowWaitSec", "companionStones"]:
		t.truthy(BalanceData.feel(key) > 0.0, "feel.%s exists" % key)


func _dodging_wins(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StageRhythm = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	t.truthy(s.spears_enabled(), "Normal throws spears")
	var el: float = _dodge_bot(s)
	t.eq(s.dodges, 3, "three dodges")
	t.eq(int(rec["won"]), 1, "three dodges win the stage once")
	t.eq(int(rec["failed"]), 0, "no failure")
	t.eq(int(rec["hits"]), 0, "no hit taken")
	t.truthy(el < 90.0, "the escape comes before the stage ceiling (%.1f s)" % el)
	t.eq(rec["ids"], [&"c3-2-saul", &"c3-2-david"], "Saul's line at the first spear, David's line at the escape")


func _three_hits_lose(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StageRhythm = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	U.run_for(s, 120.0)
	t.eq(s.spear_hits, 3, "standing still: three hits")
	t.eq(int(rec["hits"]), 3, "each hit goes through take_hit")
	t.eq(int(rec["failed"]), 1, "three hits end the stage")
	t.eq(rec["reason"], &"spear-hits", "the reason is spear-hits")
	t.eq(int(rec["won"]), 0, "no win")


func _shepherd_and_lamb(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.SHEPHERD)
	var s: StageRhythm = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	U.run_for(s, 120.0)
	t.truthy(s.spear_hits >= 3, "Shepherd: spears still fly and hit")
	t.eq(int(rec["failed"]), 0, "Shepherd never fails")
	t.eq(int(rec["won"]), 1, "Shepherd wins when the song ends")
	var pair2: Array = _make(RunModel.Mode.LAMB)
	var l: StageRhythm = pair2[0]
	var rec2: Dictionary = pair2[1]
	l.begin()
	t.falsy(l.spears_enabled(), "Lamb removes the spears")
	var el: float = 0.0
	while el < 100.0 and not l.is_finished():
		l.tick(U.STEP)
		el += U.STEP
	t.eq(l.spears_thrown, 0, "Lamb: no spear is ever thrown")
	t.eq(int(rec2["hits"]), 0, "Lamb: no hit")
	t.eq(int(rec2["won"]), 1, "Lamb wins on duration")
	t.truthy(absf(el - 60.0) < 1.5, "Lamb: about 60 s (%.1f)" % el)
	t.eq(rec2["ids"], [&"c3-2-saul", &"c3-2-david"], "Lamb keeps Saul's and David's lines")
	# Shepherd's glow is longer (data).
	var d1: StageDef = U.stage_def("3-2-spear", RunModel.Mode.NORMAL)
	var d2: StageDef = U.stage_def("3-2-spear", RunModel.Mode.SHEPHERD)
	t.truthy(d2.param_float("spearDodge.glowSec") > d1.param_float("spearDodge.glowSec"), "Shepherd glow is longer")


func _glow_before_flight(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StageRhythm = pair[0]
	s.begin()
	var glow_ticks: int = 0
	var seen_fly: bool = false
	var el: float = 0.0
	while el < 40.0 and not seen_fly:
		s.tick(U.STEP)
		el += U.STEP
		if s.spear_phase == StageRhythm.Spear.GLOW:
			glow_ticks += 1
		elif s.spear_phase == StageRhythm.Spear.FLY:
			seen_fly = true
	var glow_sec: float = U.stage_def("3-2-spear", RunModel.Mode.NORMAL).param_float("spearDodge.glowSec")
	t.truthy(seen_fly, "the spear flies after the glow")
	t.truthy(absf(float(glow_ticks) * U.STEP - glow_sec) < 0.25, "the lane glows for glowSec (%.1f s)" % [float(glow_ticks) * U.STEP])
	# D-pad steps clamp to the lanes.
	s.step_lane(-1)
	s.step_lane(-1)
	t.eq(s.lane, 0, "left of the left lane stays")
	s.step_lane(1)
	s.step_lane(1)
	t.eq(s.lane, 1, "right of the right lane stays")


func _harp_continues(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StageRhythm = pair[0]
	s.begin()
	var el: float = 0.0
	while el < 30.0 and s.hits < 3:
		s.tick(U.STEP)
		el += U.STEP
		if s.note_in_window():
			s.on_action_tap()
		if s.spear_phase == StageRhythm.Spear.GLOW and s.lane == s.spear_lane:
			s.step_lane(1)
	t.truthy(s.hits >= 3, "OK on the notes still hits while spears fly")
	t.truthy(s.brightness > 0.0, "the room brightens")


func _bounded_nodes(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StageRhythm = pair[0]
	s.begin()
	var before: int = s.world.get_child_count()
	_dodge_bot(s)
	t.eq(s.world.get_child_count(), before, "no node is created while playing")


func _outcomes(t: TestRunner) -> void:
	var baseline: Array = []
	for mode in U.modes():
		for b in U.blessings():
			var pair: Array = _make(mode, b)
			var s: StageRhythm = pair[0]
			var rec: Dictionary = pair[1]
			s.begin()
			_dodge_bot(s)
			var tag: String = U.tag(mode, b)
			t.eq(int(rec["won"]), 1, "%s: 3.2 is won" % tag)
			t.eq(int(rec["failed"]), 0, "%s: 3.2 never fails when dodging" % tag)
			if baseline.is_empty():
				baseline = (rec["ids"] as Array).duplicate()
			t.eq(rec["ids"], baseline, "%s: the story lines are identical" % tag)
