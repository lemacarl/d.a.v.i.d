extends RefCounted
## Stage 3.9 (boss, variant rescue, Ziklag): families freed, a helper per family, the timer only in
## Normal, no raiders in Lamb, the Mighty Men companion, rope clearing with the Sword, outcomes.

const U := preload("res://tests/ch3-stages-util.gd")


func run(t: TestRunner) -> void:
	_layout(t)
	_freeing(t)
	_helpers(t)
	_raiders(t)
	_timer(t)
	_ropes(t)
	_follow_distance(t)
	_mighty_men(t)
	_gating(t)
	_outcomes(t)
	_lines(t)


## `d` empty: the data-shaped stage where a repelled raider stays away (raiderStunSec 0), which keeps
## the tests that empty the field stable. Pass `U.ziklag_dict()` for the data default (returns after 2 s).
func _make(mode: RunModel.Mode, blessing: String = "", d: Dictionary = {}) -> Array:
	var s: StageZiklag = StageZiklag.new()
	var rec: Dictionary = U.build(s, d if not d.is_empty() else U.ziklag_dict(0.0), mode, blessing)
	return [s, rec]


## A spot `dist` px from family `idx` that is more than 200 px from every other family.
func _spot(s: StageZiklag, idx: int, dist: float) -> Vector2:
	var base: Vector2 = s.families[idx].position
	for k in 16:
		var p: Vector2 = base + Vector2.from_angle(TAU * float(k) / 16.0) * dist
		if not StagePlayBase.FIELD.has_point(p):
			continue
		var clear: bool = true
		for j in s.families.size():
			if j != idx and s.families[j].position.distance_to(p) < 200.0:
				clear = false
		if clear:
			return p
	return base + Vector2(0.0, dist)


func _free_all(s: StageZiklag) -> void:
	var guard: int = 0
	while not s.is_finished() and guard < 20:
		var best: int = -1
		var best_d: float = INF
		for i in s.families.size():
			if not s.families[i].freed:
				var d: float = s.families[i].position.distance_to(s.david.position)
				if d < best_d:
					best_d = d
					best = i
		if best < 0:
			break
		U.walk_to(s, s.families[best].position + Vector2(-50.0, 0.0), 20.0)
		s.on_action_tap()
		guard += 1


func _layout(t: TestRunner) -> void:
	var n: StageZiklag = (_make(RunModel.Mode.NORMAL))[0]
	var sh: StageZiklag = (_make(RunModel.Mode.SHEPHERD))[0]
	var l: StageZiklag = (_make(RunModel.Mode.LAMB))[0]
	t.eq(n.families.size(), 8, "eight families")
	t.eq(n.ropes.size(), 8, "one rope slot per family")
	t.eq(n.roped_count, 4, "obstacles ropes count 4: four families are roped")
	t.eq(n.ropes[1] != null and n.ropes[0] == null, true, "the ropes are spread over the families")
	t.eq(n.raiders.size(), 6, "Normal: six raiders")
	t.near(sh._raider_speed, 90.0, "Shepherd: the raider speed is the slower value written in the data")
	t.truthy(sh._raider_speed < n._raider_speed, "Shepherd raiders are slower than Normal")
	t.eq(l.raiders.size(), 0, "Lamb: raiders removed")
	t.eq(l.families.size(), 8, "Lamb: the families are still there")
	# Spread over a wide field: no two families share a spot, all inside the field.
	var wide: float = 0.0
	for a in n.families:
		t.truthy(StagePlayBase.FIELD.has_point(a.position), "a family lies inside the field")
		for b in n.families:
			if a != b:
				wide = maxf(wide, a.position.distance_to(b.position))
				t.truthy(a.position.distance_to(b.position) > 100.0, "families do not overlap")
	t.truthy(wide > 900.0, "the camp is spread over a wide field (%s)" % wide)
	var big_d: Dictionary = U.ziklag_dict()
	big_d["params"]["families"] = 99
	big_d["params"]["raiders"] = 99
	var big: StageZiklag = (_make(RunModel.Mode.NORMAL, "", big_d))[0]
	t.eq(big.families.size(), StageZiklag.FAMILY_MAX, "families are bounded")
	t.eq(big.raiders.size(), StageZiklag.RAIDER_MAX, "raiders are bounded")
	n.free()
	sh.free()
	l.free()
	big.free()


func _freeing(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.LAMB)
	var s: StageZiklag = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	s.on_action_tap()
	t.eq(s.freed, 0, "OK with no family close does not free one")
	var f: ActorFamily = s.families[0]
	s.david.position = f.position + Vector2(-60.0, 0.0)
	s.on_action_tap()
	t.eq(s.freed, 1, "standing next to a family and pressing OK frees it")
	t.truthy(f.freed, "that family is freed")
	t.eq(rec["followers"], 1, "freeing a family adds one follower")
	s.david.position = s.families[1].position + Vector2(-60.0, 0.0)
	s.on_action_tap()
	t.falsy(s.ropes[1].visible, "a freed family's rope is gone")
	t.eq(s.freed, 2, "the roped family is freed by standing next to it too")
	s.on_action_tap()
	t.eq(s.freed, 2, "OK next to a freed family frees nothing more")
	t.eq(rec["won"], 0, "one family is not the win")
	_free_all(s)
	t.eq(s.freed, 8, "all eight freed")
	t.eq(rec["won"], 1, "all freed: won")
	t.eq(rec["failed"], 0, "no failure")
	s.free()


func _helpers(t: TestRunner) -> void:
	# One follower per family (helperPerFamily 1), counted through follower_added.
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StageZiklag = pair[0]
	s.begin()
	for i in 3:
		s.david.position = s.families[i].position + Vector2(-60.0, 0.0)
		s.on_action_tap()
		t.eq(pair[1]["followers"], i + 1, "family %d adds a follower" % (i + 1))
	t.eq(s.followers_added, 3, "followers added counted by the stage")
	# They follow David for the rest of the stage and keep near him.
	s.david.position = Vector2(900.0, 500.0)
	U.run_for(s, 8.0)
	for i in 3:
		t.truthy(s.families[i].position.distance_to(s.david.position) < 300.0, "freed family %d follows David (%s px)" % [i + 1, s.families[i].position.distance_to(s.david.position)])
	s.free()
	var d2: Dictionary = U.ziklag_dict()
	d2["params"]["helperPerFamily"] = 2
	var two: Array = _make(RunModel.Mode.NORMAL, "", d2)
	var s2: StageZiklag = two[0]
	s2.begin()
	_free_all(s2)
	t.eq(two[1]["followers"], 16, "helperPerFamily 2: two followers per family")
	s2.free()
	# A helper throws stones at raiders for David.
	var hp: Array = _make(RunModel.Mode.NORMAL)
	var h: StageZiklag = hp[0]
	h.begin()
	var f: ActorFamily = h.families[0]
	h.david.position = f.position + Vector2(-60.0, 0.0)
	h.on_action_tap()
	for r in h.raiders:
		r.position = Vector2(-5000.0, -5000.0)
		r.state = ActorRaider.State.GONE
		r.visible = false
	var target: ActorRaider = h.raiders[0]
	target.state = ActorRaider.State.CHASE
	target.visible = true
	target.position = f.position + Vector2(300.0, 0.0)
	var before: int = h.repelled
	for i in 40:
		target.position = h.david.position + Vector2(280.0, 0.0)
		h.tick(U.STEP)
		if h.repelled > before:
			break
	t.truthy(h.repelled > before, "a freed family throws a stone at a raider and sends him running")
	h.free()
	# Lamb: helpers follow but never throw (no raiders at all).
	var lp: Array = _make(RunModel.Mode.LAMB)
	var l: StageZiklag = lp[0]
	l.begin()
	_free_all(l)
	t.eq(lp[1]["followers"], 8, "Lamb: eight followers for eight families")
	t.eq(lp[1]["hits"], 0, "Lamb: nobody is hurt")
	l.free()


func _raiders(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StageZiklag = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	var r: ActorRaider = s.raiders[0]
	var d0: float = r.position.distance_to(s.david.position)
	U.run_for(s, 2.0)
	t.truthy(r.position.distance_to(s.david.position) < d0 - 200.0, "a raider chases David")
	# A stone sends a raider running away, without gore: he leaves the field and does not hurt.
	var hits_before: int = rec["hits"]
	r.position = s.david.position + Vector2(300.0, 0.0)
	r.state = ActorRaider.State.CHASE
	r.visible = true
	var thrown: Array = [0]
	s.stone_thrown.connect(func() -> void: thrown[0] += 1)
	for rr in s.raiders:
		if rr != r:
			rr.state = ActorRaider.State.GONE
			rr.visible = false
	s.on_action_tap()
	t.eq(thrown[0], 1, "OK with no family close throws a stone at the nearest raider")
	var guard: int = 0
	while r.state == ActorRaider.State.CHASE and guard < 30:
		s.tick(U.STEP)
		guard += 1
	t.eq(r.state, ActorRaider.State.AWAY, "a stone hit sends the raider running away")
	t.eq(s.repelled, 1, "one raider repelled")
	U.run_for(s, 3.0)
	t.eq(r.state, ActorRaider.State.GONE, "the raider leaves the field")
	t.falsy(r.visible, "and is out of sight")
	t.eq(rec["failed"], 0, "no failure")
	t.eq(rec["hits"], hits_before, "a repelled raider did not hurt David")
	# Contact hurts: one heart per contact, with the invulnerable window in between.
	var s2: StageZiklag = (_make(RunModel.Mode.NORMAL))[0]
	s2.begin()
	var rec2: Dictionary = {}
	var hit_count: Array = [0]
	s2.hit_taken.connect(func(_n: int) -> void: hit_count[0] += 1)
	s2.raiders[0].position = s2.david.position
	s2.tick(U.STEP)
	t.eq(hit_count[0], 1, "a raider touching David costs a heart")
	s2.tick(U.STEP)
	t.eq(hit_count[0], 1, "not again during the invulnerable window")
	# Raiders who ran off come back after raiderStunSec (2 s in the data).
	var ret: Dictionary = U.ziklag_dict()
	var rp: Array = _make(RunModel.Mode.NORMAL, "", ret)
	var rs: StageZiklag = rp[0]
	rs.begin()
	var back: ActorRaider = rs.raiders[0]
	rs.repel(back)
	U.run_for(rs, 8.0)
	t.eq(back.state, ActorRaider.State.CHASE, "with raiderStunSec the raider returns and chases again")
	# Song of Courage: raiders within the radius run off for harpFrightenSec, then chase again.
	var sc: Array = _make(RunModel.Mode.NORMAL, "song-of-courage")
	var c: StageZiklag = sc[0]
	c.begin()
	var near: ActorRaider = c.raiders[0]
	near.position = c.david.position + Vector2(200.0, 0.0)
	c.on_action_hold()
	t.eq(near.state, ActorRaider.State.AFRAID, "the harp frightens a raider close to David")
	t.eq(c.repelled, 0, "the harp is no hit")
	U.run_for(c, 4.0)
	t.eq(near.state, ActorRaider.State.CHASE, "he chases again after the fright")
	s.free()
	s2.free()
	rs.free()
	c.free()
	rec2.clear()


func _timer(t: TestRunner) -> void:
	# Normal: 180 s and the stage fails with a timeout (the data lose entry restarts the stage).
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StageZiklag = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	t.eq(pair[1]["counters"][0], [&"time", 180], "Normal: the time counter starts at 180")
	for r in s.raiders:
		r.state = ActorRaider.State.GONE
		r.visible = false
	U.run_for(s, 179.0)
	t.eq(rec["failed"], 0, "still running at 179 s")
	U.run_for(s, 2.0)
	t.eq(rec["failed"], 1, "Normal: the time limit fails the stage")
	t.eq(rec["reason"], &"timeout", "the reason is timeout")
	s.free()
	# Shepherd and Lamb ignore the timer.
	for mode in [RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB]:
		var p: Array = _make(mode)
		var m: StageZiklag = p[0]
		m.begin()
		for r in m.raiders:
			r.state = ActorRaider.State.GONE
			r.visible = false
		U.run_for(m, 200.0)
		var key: String = RunModel.mode_key(mode)
		t.eq(p[1]["failed"], 0, "%s: the time limit is ignored" % key)
		t.falsy(m.is_finished(), "%s: the stage keeps running past 180 s" % key)
		t.eq(p[1]["counters"][0], [&"time", -1], "%s: no time counter" % key)
		m.free()
	# Winning in time wins, even close to the limit.
	var w: Array = _make(RunModel.Mode.NORMAL)
	var ws: StageZiklag = w[0]
	ws.begin()
	U.run_for(ws, 170.0)
	for f in ws.families:
		f.freed = true
	ws.freed = ws.family_total
	ws.tick(U.STEP)
	t.eq(w[1]["won"], 1, "all freed at 170 s wins")
	t.eq(w[1]["failed"], 0, "and does not time out")
	ws.free()


func _ropes(t: TestRunner) -> void:
	var s: StageZiklag = (_make(RunModel.Mode.NORMAL))[0]
	s.begin()
	var f: ActorFamily = s.families[1]
	s.david.position = _spot(s, 1, 300.0)
	for r in s.raiders:
		r.state = ActorRaider.State.GONE
		r.visible = false
	s.on_action_tap()
	t.eq(s.freed, 0, "no Sword: OK from range does not cut the rope")
	s.free()
	var sw: Array = _make(RunModel.Mode.NORMAL, "goliaths-sword")
	var w: StageZiklag = sw[0]
	w.begin()
	var g: ActorFamily = w.families[1]
	w.david.position = _spot(w, 1, 300.0)
	w.on_action_tap()
	t.eq(w.freed, 1, "Goliath's Sword: OK from range clears the rope")
	t.falsy(w.ropes[1].visible, "the rope is cleared")
	t.truthy(g.freed, "the roped family is freed")
	t.eq(sw[1]["followers"], 1, "the family follows as usual")
	# A family without a rope still needs the player next to it.
	w.david.position = _spot(w, 0, 300.0)
	w.on_action_tap()
	t.falsy(w.families[0].freed, "the Sword does not free an unroped family from range")
	w.david.position = Vector2(StagePlayBase.FIELD.end.x, StagePlayBase.FIELD.position.y)
	t.truthy(w.families[3].position.distance_to(w.david.position) > 420.0, "the test spot is beyond the rope range")
	var far_before: int = w.freed
	w.on_action_tap()
	t.eq(w.freed, far_before, "beyond the rope range nothing is cleared")
	# The Sword is a shortcut: the rescue is won either way.
	for i in w.families.size():
		var from_range: bool = w.ropes[i] != null
		w.david.position = _spot(w, i, 200.0) if from_range else w.families[i].position + Vector2(-60.0, 0.0)
		w.on_action_tap()
	t.eq(sw[1]["won"], 1, "all families freed with the Sword: won")
	w.free()


func _follow_distance(t: TestRunner) -> void:
	var out: Array[float] = []
	for blessing in ["", "shepherds-staff"]:
		var s: StageZiklag = (_make(RunModel.Mode.LAMB, blessing))[0]
		s.begin()
		s.david.position = Vector2(900.0, 500.0)
		for i in 5:
			s.free_family(i)
		U.run_for(s, 12.0)
		var total: float = 0.0
		for i in 5:
			total += s.families[i].position.distance_to(s.david.position)
		out.append(total / 5.0)
		s.free()
	t.truthy(out[1] < out[0] * 0.85, "Shepherd's Staff keeps the helpers closer (%s vs %s)" % [out[1], out[0]])


func _mighty_men(t: TestRunner) -> void:
	var none: StageZiklag = (_make(RunModel.Mode.NORMAL))[0]
	none.begin()
	t.eq(none.companion_count(), 0, "no Mighty Men: no companion")
	none.free()
	var pair: Array = _make(RunModel.Mode.NORMAL, "mighty-men")
	var s: StageZiklag = pair[0]
	s.begin()
	t.eq(s.companion_count(), 1, "Mighty Men: one companion walks with David")
	t.eq(pair[1]["failed"], 0, "Mighty Men: the stage begins with the companion")
	# The companion's stone follows David's throw at the raider (the same hit handler).
	var r: ActorRaider = s.raiders[0]
	for o in s.raiders:
		if o != r:
			o.state = ActorRaider.State.GONE
			o.visible = false
	r.position = s.david.position + Vector2(300.0, 0.0)
	s.on_action_tap()
	U.run_for(s, 2.0)
	t.eq(s.repelled, 1, "Mighty Men: the raider is repelled once, not once per stone")
	_free_all(s)
	t.eq(pair[1]["won"], 1, "Mighty Men: the rescue is still won")
	t.eq(pair[1]["followers"], 8, "Mighty Men: the freed families add exactly their own followers")
	s.free()


func _gating(t: TestRunner) -> void:
	var s: StageZiklag = StageZiklag.new()
	U.build(s, U.ziklag_dict(), RunModel.Mode.NORMAL)
	s.wait_for_lines = true
	s.begin()
	var r: ActorRaider = s.raiders[0]
	var p0: Vector2 = r.position
	U.run_for(s, 10.0)
	t.eq(r.position, p0, "raiders wait while the entry lines are shown")
	t.near(s.time_left, 180.0, "the timer waits while the entry lines are shown")
	s.on_lines_drained()
	U.run_for(s, 1.0)
	t.truthy(r.position != p0, "raiders move once the lines are done")
	t.truthy(s.time_left < 180.0, "the timer runs once the lines are done")
	s.free()


func _outcomes(t: TestRunner) -> void:
	# A bot that frees every family wins in every mode with every Blessing, never failing.
	for mode in U.modes():
		for blessing in U.BLESSINGS:
			var pair: Array = _make(mode, blessing)
			var s: StageZiklag = pair[0]
			var rec: Dictionary = pair[1]
			s.begin()
			_free_all(s)
			var tag: String = U.tag(mode, blessing)
			t.eq(rec["won"], 1, "%s: Ziklag is won" % tag)
			t.eq(rec["failed"], 0, "%s: never fails" % tag)
			t.eq(rec["followers"], 8, "%s: a follower per family" % tag)
			if mode == RunModel.Mode.LAMB:
				t.eq(rec["hits"], 0, "%s: no raider touches David" % tag)
			s.free()


func _lines(t: TestRunner) -> void:
	if LineBook.line(&"c3-9-end").is_empty():
		t.skip("Chapter 3 dialogue data not present yet: 3.9 lines not checked")
		return
	var pair: Array = _make(RunModel.Mode.LAMB)
	var s: StageZiklag = pair[0]
	s.begin()
	_free_all(s)
	var ids: Array = pair[1]["ids"]
	t.eq(ids[0], &"c3-9-narr-raiders", "3.9 opens with the raiders line")
	t.eq(ids[ids.size() - 2], &"c3-9-end", "3.9 ends with the end line")
	t.eq(ids[ids.size() - 1], &"c3-9-card-complete", "then the chapter complete card")
	s.free()
