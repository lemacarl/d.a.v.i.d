extends RefCounted
## Stage 2.6 (boss, weak-point variant): a hit during the glow always wins; a miss costs one stone;
## no stones restarts the brook in Normal only; Shepherd and Lamb refill.

const U := preload("res://tests/ch2-util.gd")


func run(t: TestRunner) -> void:
	_hit_wins_everywhere(t)
	_glow_window(t)
	_miss_costs_a_stone(t)
	_out_of_stones(t)
	_refill_modes(t)
	_spears(t)
	_phase_one(t)
	_lamb(t)
	_stone_flow(t)
	_glow_guarantee(t)
	_entry_gate(t)


func _make(mode: RunModel.Mode, blessing: String = "", stones: int = 5) -> Array:
	var s: StageGoliath = StageGoliath.new()
	var rec: Dictionary = U.build(s, U.stage_def("2-6-goliath", mode), mode, blessing, stones)
	return [s, rec]


## Ticks until the given phase (or the stage ends). Returns simulated seconds.
func _until(s: StageGoliath, phase: StageGoliath.Phase, max_sec: float = 90.0) -> float:
	var el: float = 0.0
	while el < max_sec and s.phase != phase and not s.is_finished():
		s.tick(U.STEP)
		el += U.STEP
	return el


func _hit_wins_everywhere(t: TestRunner) -> void:
	for mode in U.modes():
		for blessing in U.blessings():
			var tag: String = U.tag(mode, blessing)
			var pair: Array = _make(mode, blessing, 5)
			var s: StageGoliath = pair[0]
			var rec: Dictionary = pair[1]
			s.begin()
			# A bot that stands still and presses OK the moment the forehead glows.
			_until(s, StageGoliath.Phase.GLOW)
			t.truthy(s.glow_active(), "%s: the forehead glows" % tag)
			s.on_action_tap()
			U.run_for(s, 6.0)
			t.eq(rec["won"], 1, "%s: a hit during the glow wins" % tag)
			t.eq(rec["failed"], 0, "%s: ...and nothing fails" % tag)
			t.eq(rec["spent"], 0, "%s: a hit spends no stone" % tag)
			s.free()


func _glow_window(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL, "", 5)
	var s: StageGoliath = pair[0]
	s.begin()
	var lead: float = _until(s, StageGoliath.Phase.GLOW)
	var glow: float = 0.0
	while s.glow_active() and glow < 10.0:
		s.tick(U.STEP)
		glow += U.STEP
	t.truthy(absf(glow - 2.0) <= 0.15, "the forehead glows for glowSec = 2 s (got %s)" % glow)
	t.truthy(lead > 10.0, "phase 1 (spears) comes first (glow after %s s)" % lead)
	s.free()


func _miss_costs_a_stone(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL, "", 3)
	var s: StageGoliath = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	_until(s, StageGoliath.Phase.LAUGH)
	s.tick(U.STEP)
	t.eq(s.phase, StageGoliath.Phase.LAUGH, "Goliath laughs after the spears")
	s.on_action_tap()
	t.eq(s.stones_left, 2, "a miss uses one stone")
	t.eq(rec["spent"], 1, "stone_spent emitted once")
	t.eq((rec["ids"] as Array).count(&"c2-6-miss"), 1, "the miss line is requested")
	t.eq(rec["failed"], 0, "a miss with stones left does not fail")
	t.falsy(s.is_finished(), "the fight goes on after a miss")
	s.free()


func _out_of_stones(t: TestRunner) -> void:
	# Normal: the last stone missed = stones-out. The restart at 2-5 is RunState's job (below).
	var pair: Array = _make(RunModel.Mode.NORMAL, "", 2)
	var s: StageGoliath = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	_until(s, StageGoliath.Phase.LAUGH)
	s.tick(U.STEP)
	s.on_action_tap()
	U.run_for(s, 0.5)
	t.eq(rec["failed"], 0, "one stone left: still fighting")
	s.on_action_tap()
	t.eq(rec["failed"], 1, "no stones left and not won = stones-out")
	t.eq(rec["reason"], &"stones-out", "failure reason is stones-out")
	s.free()
	# Zero stones carried (nothing collected at the brook) fails at once.
	var zero: Array = _make(RunModel.Mode.NORMAL, "", 0)
	var zs: StageGoliath = zero[0]
	zs.begin()
	zs.tick(U.STEP)
	t.eq(zero[1]["reason"], &"stones-out", "Normal with no stones fails at once")
	zs.free()
	# The restart goes to the brook, keeps Blessings and shows the scripted line.
	var rs: Node = U.new_run_state()
	var msgs: Array = []
	rs.connect("run_failed", func(m: String) -> void: msgs.append(m))
	rs.call("start_chapter", 2, RunModel.Mode.NORMAL)
	U.go_to(rs, "2-2-road")
	rs.call("advance")
	rs.call("add_blessing", &"quick-feet")
	U.go_to(rs, "2-5-brook")
	rs.call("add_stones", 4)
	rs.call("advance")
	rs.call("skip_blessing")
	t.eq(U.cur(rs), "2-6-goliath", "the brook leads to Goliath")
	t.eq((rs.get("model") as RunModel).stones, 4, "stones carry from 2.5 into 2.6")
	var outcome: StringName = rs.call("fail_stage", &"stones-out")
	t.eq(outcome, &"goto-stage", "stones-out sends Normal to another stage")
	t.eq(U.cur(rs), "2-5-brook", "...the brook")
	t.eq((rs.get("model") as RunModel).stones, 0, "stones are reset when 2-5 restarts")
	t.eq((rs.get("model") as RunModel).blessings.size(), 1, "Blessings are kept")
	t.eq(msgs.back(), "line:c2-6-go-back", "the scripted go-back line is shown")
	rs.free()


func _refill_modes(t: TestRunner) -> void:
	for mode in [RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB]:
		for stones in [0, 1]:
			var key: String = "%s/%d stones" % [RunModel.mode_key(mode), stones]
			var pair: Array = _make(mode, "", stones)
			var s: StageGoliath = pair[0]
			var rec: Dictionary = pair[1]
			s.begin()
			for i in 6:
				_until(s, StageGoliath.Phase.LAUGH)
				s.tick(U.STEP)
				s.on_action_tap()
				U.run_for(s, 0.5)
			t.eq(rec["failed"], 0, "%s: stones never run out" % key)
			t.eq(rec["spent"], 0, "%s: a miss spends nothing (refill)" % key)
			t.truthy(s.misses >= 3, "%s: misses happened (%d)" % [key, s.misses])
			t.falsy(s.is_finished(), "%s: still fighting" % key)
			_until(s, StageGoliath.Phase.GLOW)
			s.on_action_tap()
			U.run_for(s, 6.0)
			t.eq(rec["won"], 1, "%s: the forehead hit still wins" % key)
			s.free()
	# RunState: Shepherd and Lamb ignore stones-out.
	for mode in [RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB]:
		var rs: Node = U.new_run_state()
		rs.call("start_chapter", 2, mode)
		U.go_to(rs, "2-6-goliath")
		t.eq(rs.call("fail_stage", &"stones-out"), &"ignored", "%s: stones-out is ignored" % RunModel.mode_key(mode))
		t.eq(U.cur(rs), "2-6-goliath", "%s: stays at Goliath" % RunModel.mode_key(mode))
		rs.free()


func _spears(t: TestRunner) -> void:
	var normal: Array = _make(RunModel.Mode.NORMAL)
	var shep: Array = _make(RunModel.Mode.SHEPHERD)
	var ns: StageGoliath = normal[0]
	var ss: StageGoliath = shep[0]
	t.near(ss._spear_speed, ns._spear_speed * 0.6, "Shepherd: spears fly at 0.6x")
	# A spear down David's lane hits him once (invulnerable after).
	ns.begin()
	ns.david.position = Vector2(300.0, ns._lane_y(0))
	var hits: int = 0
	var el: float = 0.0
	while el < 40.0 and int(normal[1]["hits"]) == 0:
		ns.david.position = Vector2(300.0, ns._lane_y(ns._tele_lane if ns._tele_lane >= 0 else 0))
		ns.tick(U.STEP)
		el += U.STEP
	hits = int(normal[1]["hits"])
	t.truthy(hits >= 1, "a spear down David's lane hits him")
	# Dodging: step out of the lane once the warning shows and nothing hits.
	var dodge: Array = _make(RunModel.Mode.NORMAL)
	var ds: StageGoliath = dodge[0]
	ds.begin()
	el = 0.0
	while el < 40.0 and ds.phase == StageGoliath.Phase.SPEARS:
		ds.david.position = Vector2(300.0, ds._lane_y(_safe_lane(ds)))
		ds.tick(U.STEP)
		el += U.STEP
	t.eq(dodge[1]["hits"], 0, "stepping out of the warned lane dodges every spear")
	t.truthy(ds.spears_thrown >= 4, "a round throws one spear per lane (%d)" % ds.spears_thrown)
	ns.free()
	ss.free()
	ds.free()


## A lane with no spear in it and no warning on it.
func _safe_lane(s: StageGoliath) -> int:
	for i in 4:
		if i == s._tele_lane:
			continue
		var busy: bool = false
		for sp in s.spears:
			if sp.active and absf(sp.position.y - s._lane_y(i)) < 1.0:
				busy = true
		if not busy:
			return i
	return 0


func _phase_one(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL, "", 3)
	var s: StageGoliath = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	t.eq(s.phase, StageGoliath.Phase.SPEARS, "Normal starts with the shield-bearer and spears")
	t.truthy(s.shield.visible, "the shield-bearer is in front")
	s.tick(U.STEP)
	s.on_action_tap()
	t.eq(s.stones_left, 3, "a stone that bounces off the shield costs nothing")
	t.eq(rec["spent"], 0, "no stone spent in phase 1")
	t.eq((rec["ids"] as Array).count(&"c2-6-miss"), 0, "bouncing is not a miss")
	for i in 20:
		s.tick(U.STEP)
	t.truthy((rec["sfx"] as Array).has(&"bounce"), "the stone bounces off the shield (sfx)")
	s.free()


func _lamb(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.LAMB, "", 0)
	var s: StageGoliath = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	t.eq(s.phase, StageGoliath.Phase.LAUGH, "Lamb: Goliath stands and laughs from the start")
	t.falsy(s.shield.visible, "Lamb: no shield-bearer")
	U.run_for(s, 20.0)
	t.eq(s.spears_thrown, 0, "Lamb: no spears")
	t.eq(rec["hits"], 0, "Lamb: David is never hit")
	t.truthy((rec["ids"] as Array).has(&"c2-6-laugh"), "Lamb: the laugh line plays")
	_until(s, StageGoliath.Phase.GLOW)
	s.on_action_tap()
	U.run_for(s, 5.0)
	t.eq(rec["won"], 1, "Lamb: OK on the glow wins")
	s.free()


func _stone_flow(t: TestRunner) -> void:
	var rs: Node = U.new_run_state()
	rs.call("start_chapter", 2, RunModel.Mode.NORMAL)
	var model: RunModel = rs.get("model") as RunModel
	U.go_to(rs, "2-5-brook")
	t.eq(model.stones, 0, "no stones before the brook")
	rs.call("add_stones", 3)
	rs.call("advance")
	rs.call("skip_blessing")
	t.eq(model.stones, 3, "3.. stones persist into 2.6")
	# Pause-menu restart of 2.6 keeps the stones the player carried in.
	rs.call("spend_stone")
	rs.call("restart_stage")
	t.eq(U.cur(rs), "2-6-goliath", "restart stays at Goliath")
	t.eq(model.stones, 3, "restarting 2.6 restores the stones carried in")
	# After the fight the stones are gone (they persist from 2.5 into 2.6 only).
	rs.call("advance")
	t.eq(U.cur(rs), "2-7-victory", "winning leads to the victory cutscene")
	t.eq(model.stones, 0, "stones do not persist past 2.6")
	rs.call("start_chapter", 2, RunModel.Mode.NORMAL)
	t.eq(model.stones, 0, "stones reset when the chapter starts")
	rs.free()


## Moves the stage to the last tenth of a second of the laugh, so the next tick opens the glow.
func _to_laugh_end(s: StageGoliath) -> void:
	_until(s, StageGoliath.Phase.LAUGH)
	s.tick(U.STEP)
	s._phase_left = 0.05


## R2-1 / R2-22: a forehead hit in the glow always wins.
func _glow_guarantee(t: TestRunner) -> void:
	# (a) A press that began in the glow counts when released after the glow closed.
	var late: Array = _make(RunModel.Mode.NORMAL, "", 5)
	var ls: StageGoliath = late[0]
	ls.begin()
	_until(ls, StageGoliath.Phase.GLOW)
	ls.on_action_press()
	U.run_for(ls, 2.5)
	t.falsy(ls.glow_active(), "the glow has closed before the release")
	ls.on_action_tap()
	U.run_for(ls, 5.0)
	t.eq(late[1]["won"], 1, "press in the glow, release after it: a hit")
	t.eq(late[1]["spent"], 0, "...and it spends no stone")
	ls.free()
	# A press made before the glow, released after it, is a plain miss (it began outside the glow).
	var early: Array = _make(RunModel.Mode.NORMAL, "", 5)
	var es: StageGoliath = early[0]
	es.begin()
	_to_laugh_end(es)
	es.on_action_press()
	U.run_for(es, 3.0)
	es.on_action_tap()
	U.run_for(es, 1.0)
	t.eq(early[1]["won"], 0, "a press that began before the glow does not win after it")
	es.free()
	# (b) A miss thrown just before the glow does not swallow the glow tap (cooldown bypass).
	for mode in [RunModel.Mode.NORMAL, RunModel.Mode.LAMB]:
		var key: String = RunModel.mode_key(mode)
		var cd: Array = _make(mode, "", 5)
		var cs: StageGoliath = cd[0]
		cs.begin()
		_to_laugh_end(cs)
		cs.on_action_tap()
		t.eq(cs.misses, 1, "%s: a miss was thrown just before the glow" % key)
		cs.tick(U.STEP)
		t.truthy(cs.glow_active(), "%s: the glow is open" % key)
		t.truthy(cs._throw_cd > 0.0, "%s: the throw cooldown is still running" % key)
		cs.on_action_tap()
		U.run_for(cs, 5.0)
		t.eq(cd[1]["won"], 1, "%s: a glow tap during the cooldown wins" % key)
		cs.free()
	# The same through the press/release path used outside Lamb.
	var pr: Array = _make(RunModel.Mode.NORMAL, "", 5)
	var ps: StageGoliath = pr[0]
	ps.begin()
	_to_laugh_end(ps)
	ps.on_action_press()
	ps.on_action_tap()
	ps.tick(U.STEP)
	ps.on_action_press()
	ps.on_action_tap()
	U.run_for(ps, 5.0)
	t.eq(pr[1]["won"], 1, "miss then glow tap on release during the cooldown wins")
	ps.free()
	# All four pooled stones busy (misses in flight): the hit is still granted.
	var busy: Array = _make(RunModel.Mode.NORMAL, "", 5)
	var bs: StageGoliath = busy[0]
	bs.begin()
	_until(bs, StageGoliath.Phase.GLOW)
	for st in bs._stones:
		st.active = true
	bs.on_action_tap()
	t.eq(busy[1]["won"], 1, "no free stone: the glow hit still wins")
	bs.free()
	# (c) A hold that becomes the Song of Courage harp is never a throw, hit or miss.
	for phase in [StageGoliath.Phase.GLOW, StageGoliath.Phase.LAUGH]:
		var hp: Array = _make(RunModel.Mode.NORMAL, "song-of-courage", 5)
		var hs: StageGoliath = hp[0]
		hs.begin()
		_until(hs, phase)
		hs.tick(U.STEP)
		hs.on_action_press()
		hs.on_action_hold()
		hs.on_action_tap()
		U.run_for(hs, 0.5)
		t.eq(hp[1]["won"], 0, "a harp hold is not a hit (phase %d)" % phase)
		t.eq(hs.misses, 0, "a harp hold is not a miss (phase %d)" % phase)
		t.eq(hp[1]["spent"], 0, "a harp hold spends no stone (phase %d)" % phase)
		t.truthy((hp[1]["sfx"] as Array).has(&"harp"), "the hold plays the harp (phase %d)" % phase)
		hs.free()


## D-1: with the host queue gating, no phase starts until the entry lines were shown.
func _entry_gate(t: TestRunner) -> void:
	for mode in [RunModel.Mode.NORMAL, RunModel.Mode.LAMB]:
		var key: String = RunModel.mode_key(mode)
		var pair: Array = _make(mode, "", 5)
		var s: StageGoliath = pair[0]
		s.wait_for_lines = true
		s.begin()
		var start_phase: StageGoliath.Phase = s.phase
		U.run_for(s, 40.0)
		t.eq(s.phase, start_phase, "%s: the phase does not move while the entry lines are unread" % key)
		t.eq(s.spears_thrown, 0, "%s: no spear flies while the entry lines are unread" % key)
		s.on_action_tap()
		t.eq(s.misses, 0, "%s: OK does nothing while the entry lines are unread" % key)
		t.falsy(s.is_finished(), "%s: the stage cannot be won over unread lines" % key)
		s.on_lines_drained()
		U.run_for(s, 40.0)
		t.truthy(s.phase != start_phase or s.spears_thrown > 0 or s.glow_active(), "%s: the phases run once the lines are drained" % key)
		s.free()
	# Without the host flag (tests, tools) nothing is held.
	var free_run: Array = _make(RunModel.Mode.LAMB, "", 5)
	var fs: StageGoliath = free_run[0]
	fs.begin()
	_until(fs, StageGoliath.Phase.GLOW, 20.0)
	t.truthy(fs.glow_active(), "no gating without the host flag")
	fs.free()
