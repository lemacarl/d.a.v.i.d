extends RefCounted
## Stage 2.7 and the other Chapter 2 cutscenes: no body is ever shown, slow motion always restores
## the clock, the shake is bounded, lines go through the line queue and the host waits for them.

const U := preload("res://tests/ch2-util.gd")
const CUTSCENES: Array[String] = ["2-1-errand", "2-3-challenge", "2-4-saul", "2-7-victory"]


func run(t: TestRunner) -> void:
	_no_body(t)
	_slow_motion(t)
	_shake(t)
	_line_gating(t)
	_thud_on_the_faces(t)
	_outcomes(t)
	t.near(Engine.time_scale, 1.0, "no victory test leaves the clock slowed")
	Engine.time_scale = 1.0


func _make(stage_id: String, mode: RunModel.Mode = RunModel.Mode.NORMAL, blessing: String = "") -> Array:
	var s: StageCutscene = StageCutscene.new()
	var rec: Dictionary = U.build(s, U.stage_def(stage_id, mode), mode, blessing)
	(rec["visuals"] as Array).clear()
	s.visual_requested.connect(func(c: StringName) -> void: (rec["visuals"] as Array).append(c))
	return [s, rec]


## Mashes OK through the whole cutscene. Returns simulated seconds.
func _play(s: StageCutscene, max_sec: float = 300.0) -> float:
	var el: float = 0.0
	while el < max_sec and not s.is_finished():
		s.tick(U.STEP)
		s.on_action_tap()
		el += U.STEP
	return el


func _no_body(t: TestRunner) -> void:
	# The data: no visual cue of any Chapter 2 cutscene names a body, ground or fallen figure.
	for id in CUTSCENES:
		for b in U.stage_def(id, RunModel.Mode.NORMAL).cutscene_beats():
			var cue: String = str((b as Dictionary).get("cue", ""))
			t.falsy(StageUtil.is_body_cue(cue), "%s: cue '%s' is not a body" % [id, cue])
	# The stage: played end to end, 2.7 emits no body cue and never builds a Goliath.
	var pair: Array = _make("2-7-victory")
	var s: StageCutscene = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	var faces_seen: bool = false
	var goliath_drawn: bool = false
	var el: float = 0.0
	while el < 300.0 and not s.is_finished():
		s.tick(U.STEP)
		s.on_action_tap()
		el += U.STEP
		for f in s._faces:
			faces_seen = faces_seen or f.visible
		for c in s.world.get_children():
			if c is ActorGoliath or c is ActorShield:
				goliath_drawn = true
	t.eq(rec["won"], 1, "2.7 finishes")
	t.truthy(rec["visuals"].size() >= 4, "2.7 emitted its visual cues (%d)" % rec["visuals"].size())
	for c in (rec["visuals"] as Array):
		t.falsy(StageUtil.is_body_cue(String(c)), "2.7 emitted no body cue (%s)" % c)
	t.truthy((rec["visuals"] as Array).has(&"soldiers-faces-eyes-wide"), "the soldiers' faces cue is shown")
	t.truthy(faces_seen, "wide-eyed faces were drawn")
	t.falsy(goliath_drawn, "Goliath is never drawn in the cut-away")
	t.eq(s._faces.size(), 3, "three placeholder faces, reused")
	s.free()
	# A cue that names a body would be dropped, not drawn.
	var bad: Array = _make("2-7-victory")
	var bs: StageCutscene = bad[0]
	bs.begin()
	t.falsy(bs._start_visual("goliath-lying-on-the-ground"), "a body cue is refused")
	t.eq((bad[1]["visuals"] as Array).has(&"goliath-lying-on-the-ground"), false, "a body cue is not emitted")
	bs.free()


func _slow_motion(t: TestRunner) -> void:
	# Normal play: the clock slows during the stone flight and is back at 1.0 when the stage ends.
	var pair: Array = _make("2-7-victory")
	var s: StageCutscene = pair[0]
	s.begin()
	var lowest: float = 1.0
	var el: float = 0.0
	while el < 300.0 and not s.is_finished():
		s.tick(U.STEP)
		s.on_action_tap()
		lowest = minf(lowest, Engine.time_scale)
		el += U.STEP
	t.near(lowest, BalanceData.feel("slowMotionScale"), "time scale eases down to the data value")
	t.near(Engine.time_scale, 1.0, "time scale is 1.0 when the stage ends")
	s.free()
	# Quit: freed while slowed (restart and quit-to-title free the stage).
	var q: Array = _make("2-7-victory")
	var qs: StageCutscene = q[0]
	qs.begin()
	_slow_until_active(qs)
	t.truthy(Engine.time_scale < 1.0 and qs.is_slow_motion(), "slow motion is running")
	qs.free()
	t.near(Engine.time_scale, 1.0, "freeing the stage restores 1.0")
	# Leaving the tree (the host removes the stage on restart, quit and every stage change).
	var r: Array = _make("2-7-victory")
	var rs: StageCutscene = r[0]
	t.root.add_child(rs)
	rs.begin()
	_slow_until_active(rs)
	t.truthy(Engine.time_scale < 1.0, "slow motion running in the tree")
	t.root.remove_child(rs)
	t.near(Engine.time_scale, 1.0, "leaving the tree restores 1.0")
	rs.free()
	# Pause menu.
	var p: Array = _make("2-7-victory")
	var ps: StageCutscene = p[0]
	t.root.add_child(ps)
	ps.begin()
	_slow_until_active(ps)
	t.truthy(Engine.time_scale < 1.0, "slow motion running before the pause")
	t.paused = true
	t.near(Engine.time_scale, 1.0, "pausing restores 1.0")
	t.falsy(ps.is_slow_motion(), "the effect is cancelled by the pause")
	t.paused = false
	t.root.remove_child(ps)
	ps.free()
	# Restart: setup runs again on a fresh stage while a slowed one is being replaced.
	var a: Array = _make("2-7-victory")
	var as1: StageCutscene = a[0]
	as1.begin()
	_slow_until_active(as1)
	var b: Array = _make("2-7-victory")
	t.near(Engine.time_scale, 1.0, "setting up the restarted stage restores 1.0")
	as1.free()
	(b[0] as Node).free()
	t.near(Engine.time_scale, 1.0, "the clock is 1.0 at the end")


func _slow_until_active(s: StageCutscene) -> void:
	var el: float = 0.0
	while el < 60.0 and Engine.time_scale >= 1.0 and not s.is_finished():
		s.tick(U.STEP)
		s.on_action_tap()
		el += U.STEP


func _shake(t: TestRunner) -> void:
	var pair: Array = _make("2-7-victory")
	var s: StageCutscene = pair[0]
	s.begin()
	var worst: float = 0.0
	var shook: bool = false
	var el: float = 0.0
	while el < 300.0 and not s.is_finished():
		s.tick(U.STEP)
		s.on_action_tap()
		el += U.STEP
		worst = maxf(worst, s.world.position.length())
		shook = shook or s.world.position.length() > 0.0
	t.truthy(shook, "the THUD shakes the screen")
	t.truthy(worst <= BalanceData.feel("shakeMaxPx") * 1.5, "the shake is bounded (max %s px)" % worst)
	t.eq(s.world.position, Vector2.ZERO, "the screen is still at the end")
	# Out-of-range amounts are clamped.
	s._start_shake(9999.0, 0.5)
	t.near(s._shake_amp, BalanceData.feel("shakeMaxPx"), "a huge shake amount is clamped")
	s.free()


func _line_gating(t: TestRunner) -> void:
	var pair: Array = _make("2-7-victory")
	var s: StageCutscene = pair[0]
	var q: LineQueue = LineQueue.new()
	var shown: Array = []
	var advanced: Array = [0]
	q.line_started.connect(func(_sp: StringName, text: String, _r: String, _h: float, _st: bool) -> void: shown.append(text))
	s.line_requested.connect(func(sp: StringName, tx: String, r: String, id: StringName) -> void: q.request(sp, tx, r, id))
	s.gold_light_requested.connect(q.request_gold)
	s.stage_won.connect(func() -> void: q.when_drained(func() -> void: advanced[0] = int(advanced[0]) + 1))
	s.begin()
	_play(s)
	t.eq(pair[1]["won"], 1, "2.7 won while mashing OK")
	t.eq(advanced[0], 0, "the host does not advance while lines are still waiting")
	t.falsy(q.is_idle(), "lines are still queued when the stage ends")
	var el: float = 0.0
	while advanced[0] == 0 and el < 120.0:
		q.tick(U.STEP)
		el += U.STEP
	t.eq(advanced[0], 1, "advance runs exactly once after the queue drains")
	t.truthy(q.is_idle(), "...and only when the queue is idle")
	var expect: Array = []
	for id in ["c2-7-narr-fall", "c2-7-narr-ran", "c2-7-soldiers", "c2-7-card-complete"]:
		expect.append(str(LineBook.line(StringName(id)).get("text", "")))
	t.eq(shown, expect, "every 2.7 line was shown, in order, ending on the Chapter 2 complete card")
	s.free()


## D-2: the THUD shakes the screen on the soldiers' faces, not on the next narrator beat.
func _thud_on_the_faces(t: TestRunner) -> void:
	var pair: Array = _make("2-7-victory")
	var s: StageCutscene = pair[0]
	s.begin()
	var shake_on_faces: bool = false
	var faces_done: bool = false
	var shake_after: bool = false
	var el: float = 0.0
	while el < 300.0 and not s.is_finished():
		s.tick(U.STEP)
		el += U.STEP
		if s._cutaway == &"faces":
			shake_on_faces = shake_on_faces or s._shake_left > 0.0
		elif shake_on_faces:
			faces_done = true
		if faces_done and s._shake_left > 0.0:
			shake_after = true
		if s.waiting == StageCutscene.Wait.LINE and el > 0.0:
			s.on_action_tap()
	t.truthy(shake_on_faces, "the screen shakes while the soldiers' faces are shown")
	t.falsy(shake_after, "no second shake on the beats after the faces")
	s.free()


func _outcomes(t: TestRunner) -> void:
	# Every mode x Chapter 2 Blessing: each cutscene ends in a win, with the same lines in the same order.
	var reference: Dictionary = {}
	for mode in U.modes():
		for blessing in U.blessings():
			for id in CUTSCENES:
				var pair: Array = _make(id, mode, blessing)
				var s: StageCutscene = pair[0]
				var rec: Dictionary = pair[1]
				s.begin()
				_play(s)
				var tag: String = "%s %s" % [id, U.tag(mode, blessing)]
				t.eq(rec["won"], 1, "%s: won" % tag)
				t.eq(rec["failed"], 0, "%s: never fails" % tag)
				if not reference.has(id):
					reference[id] = (rec["ids"] as Array).duplicate()
					t.truthy((rec["ids"] as Array).size() >= 3, "%s: has its story lines" % tag)
				t.eq(rec["ids"], reference[id], "%s: same lines in the same order" % tag)
				if id == "2-7-victory":
					t.truthy((rec["sfx"] as Array).has(&"thud"), "%s: THUD cue requested" % tag)
				s.free()
	t.near(Engine.time_scale, 1.0, "no outcome run leaves the clock slowed")
