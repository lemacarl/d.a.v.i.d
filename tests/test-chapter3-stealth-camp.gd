extends RefCounted
## Stage 3.8 (stealth, Saul's camp): both items needed, the dark path, sleepers, thorns with and
## without Goliath's Sword, completable with no Blessing, Hidden in the Rock, Faithful Friend, food.

const U := preload("res://tests/ch3-stages-util.gd")


func run(t: TestRunner) -> void:
	_layout(t)
	_needs_both_items(t)
	_path_rules(t)
	_sleepers(t)
	_thorns(t)
	_completable_everywhere(t)
	_modes(t)
	_hidden_in_the_rock(t)
	_faithful_friend(t)
	_food(t)
	_spared(t)


func _make(mode: RunModel.Mode, blessing: String = "", thorns: int = 2) -> Array:
	var s: StageStealth = StageStealth.new()
	var rec: Dictionary = U.build(s, U.camp_dict(thorns), mode, blessing)
	return [s, rec]


## The centre line of the path with a detour around every thorn patch (no Sword needed).
func _route(s: StageStealth, around_thorns: bool) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var total: float = s._path_length()
	var d: float = 0.0
	while d <= total:
		var p: Vector2 = s._path_point_at(d)
		if around_thorns:
			for th in s.thorns:
				if p.distance_to(th.position) < th.radius + 90.0:
					var a: Vector2 = s._path_point_at(d - 5.0)
					var b: Vector2 = s._path_point_at(d + 5.0)
					p += (b - a).normalized().orthogonal() * (th.radius + 25.0)
					break
		out.append(p)
		d += 25.0
	out.append(s.path_points[s.path_points.size() - 1])
	return out


func _walk_route(s: StageStealth, route: Array[Vector2]) -> void:
	for p in route:
		U.walk_to(s, p, 8.0)
		if s.is_finished():
			return


func _layout(t: TestRunner) -> void:
	var s: StageStealth = (_make(RunModel.Mode.NORMAL))[0]
	s.begin()
	t.eq(s.kind, StageStealth.Kind.CAMP, "3.8 is the camp variant (pickups is a list)")
	t.eq(s.sleepers.size(), 8, "eight sleepers around the camp")
	t.eq(s.items.size(), 2, "the spear and the water jug")
	t.eq(s.items_required, 2, "the far hill needs both items")
	t.eq(s.thorns.size(), 2, "two thorn patches on the path")
	t.eq(s.david.position, s.path_points[0], "David starts at the path start")
	for sl in s.sleepers:
		t.truthy(s.path_distance(sl.position) >= 140.0, "a sleeper lies beside the path, not on it (%s)" % s.path_distance(sl.position))
	for it in s.items:
		t.truthy(s.path_distance(it.position) < 1.0, "the items lie on the path")
	var big: Array = _make(RunModel.Mode.NORMAL, "", 99)
	t.eq((big[0] as StageStealth).thorns.size(), StageStealth.THORN_MAX, "thorn patches are bounded")
	big[0].free()
	s.free()


func _needs_both_items(t: TestRunner) -> void:
	# Straight to the hill with no items: the hill does not win.
	var pair: Array = _make(RunModel.Mode.LAMB, "", 0)
	var s: StageStealth = pair[0]
	s.begin()
	s.david.position = s.goal_rect.get_center()
	s.tick(U.STEP)
	t.eq(pair[1]["won"], 0, "the far hill without the items does not win")
	s.items[0].position = s.david.position
	s.tick(U.STEP)
	t.eq(s.items_taken, 1, "walking onto the spear takes it")
	t.eq(pair[1]["won"], 0, "one item is not enough")
	s.items[1].position = s.david.position
	s.tick(U.STEP)
	t.eq(s.items_taken, 2, "walking onto the jug takes it")
	t.eq(pair[1]["won"], 1, "both items and the hill: won")
	t.truthy(pair[1]["sfx"].has(&"pickup"), "taking an item plays the pickup cue")
	s.free()


func _path_rules(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL, "", 0)
	var s: StageStealth = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	# Take the first item, then wander off the path for noticeSec (2 s).
	s.items[0].position = s.david.position
	s.tick(U.STEP)
	var off: Vector2 = s.path_points[0] + Vector2(0.0, -400.0)
	t.truthy(s.path_distance(off) > s.path_half, "the test point lies off the path")
	var secs: float = 0.0
	while s.pushbacks == 0 and secs < 5.0:
		s.david.position = off
		s.tick(U.STEP)
		secs += U.STEP
	t.eq(s.pushbacks, 1, "off the path for noticeSec: noticed")
	t.truthy(secs >= 1.9 and secs <= 2.3, "noticed after about 2 s (got %s)" % secs)
	t.eq(s.david.position, s.path_points[0], "return-to-path-start")
	t.eq(rec["failed"], 0, "never a failure")
	t.eq(s.items_taken, 1, "items already taken are kept")
	t.eq(s.sleepers_woken, 0, "walking off the path wakes nobody")
	# A step off the path and back is forgiven.
	s._hit_cd = 0.0
	for i in 8:
		s.david.position = off
		s.tick(U.STEP)
	for i in 30:
		s.david.position = s.path_points[0]
		s.tick(U.STEP)
	t.eq(s.pushbacks, 1, "a short step off the path is forgiven")
	s.free()


func _sleepers(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL, "", 0)
	var s: StageStealth = pair[0]
	s.begin()
	var sl: ActorSleeper = s.sleepers[0]
	var secs: float = 0.0
	while s.sleepers_woken == 0 and secs < 5.0:
		s.david.position = sl.position + Vector2(50.0, 0.0)
		s.tick(U.STEP)
		secs += U.STEP
	t.eq(s.sleepers_woken, 1, "standing next to a sleeper wakes him after noticeSec")
	t.eq(s.pushbacks, 1, "waking a soldier sends David back to the path start")
	t.eq(pair[1]["failed"], 0, "no failure")
	t.eq(s.david.position, s.path_points[0], "back at the path start")
	# On the centre line David is never near a sleeper.
	var s2: StageStealth = (_make(RunModel.Mode.NORMAL, "", 0))[0]
	s2.begin()
	var total: float = s2._path_length()
	var d: float = 0.0
	var worst: float = INF
	while d <= total:
		var p: Vector2 = s2._path_point_at(d)
		for k in s2.sleepers:
			worst = minf(worst, k.position.distance_to(p))
		d += 10.0
	t.truthy(worst > 130.0, "the centre line stays outside every wake radius (closest %s)" % worst)
	s.free()
	s2.free()


func _thorns(t: TestRunner) -> void:
	# Without the Sword straight ahead is blocked, around is open.
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StageStealth = pair[0]
	s.begin()
	var th: ActorThorn = s.thorns[0]
	s.david.position = th.position + Vector2(-200.0, 0.0)
	var ahead: Vector2 = th.position + Vector2(200.0, 0.0)
	s._hit_cd = 0.0
	U.walk_to(s, ahead, 10.0)
	t.truthy(s.david.position.x < th.position.x, "a thorn patch blocks David walking straight through it")
	t.truthy(s.david.position.distance_to(th.position) >= th.radius, "David is not inside the patch")
	# OK without the Sword clears nothing.
	s.on_action_tap()
	t.eq(s.thorns_cleared, 0, "no Sword: OK does not clear a thorn")
	t.falsy(th.cleared, "the patch is still there")
	# Around it is open (inside the path width).
	var around: Vector2 = th.position + Vector2(0.0, th.radius + 25.0)
	t.truthy(s.path_distance(around) <= s.path_half, "the detour stays on the dark path")
	s.free()
	# With the Sword OK clears the adjacent patch.
	var sw: Array = _make(RunModel.Mode.NORMAL, "goliaths-sword")
	var w: StageStealth = sw[0]
	w.begin()
	var th2: ActorThorn = w.thorns[0]
	w.david.position = th2.position + Vector2(-(th2.radius + w.david.radius + 20.0), 0.0)
	w.on_action_tap()
	t.eq(w.thorns_cleared, 1, "Goliath's Sword: OK clears the adjacent thorn patch")
	t.truthy(th2.cleared and not th2.visible, "the cleared patch is gone")
	U.walk_to(w, th2.position + Vector2(200.0, 0.0), 10.0)
	t.truthy(w.david.position.x > th2.position.x, "David walks straight through the cleared path")
	# Not adjacent: nothing happens.
	var far_th: ActorThorn = w.thorns[1]
	w.david.position = far_th.position + Vector2(-600.0, 0.0)
	w.on_action_tap()
	t.eq(w.thorns_cleared, 1, "OK far from a patch clears nothing")
	t.eq(sw[1]["failed"], 0, "no failure")
	w.free()
	# The Sword shortcut: straight down the centre line, clearing the two patches, still wins.
	var sc: Array = _make(RunModel.Mode.NORMAL, "goliaths-sword")
	var c: StageStealth = sc[0]
	c.begin()
	for p in _route(c, false):
		for patch in c.thorns:
			if not patch.cleared and c.david.position.distance_to(patch.position) < patch.radius + c.david.radius + 60.0:
				c.on_action_tap()
		U.walk_to(c, p, 8.0)
		if c.is_finished():
			break
	t.eq(c.thorns_cleared, 2, "the Sword bot cleared both patches")
	t.eq(sc[1]["won"], 1, "the Sword shortcut wins")
	c.free()


func _completable_everywhere(t: TestRunner) -> void:
	# A bot that goes around the thorns and keeps to the centre line wins in every mode with every
	# Blessing; the Blessing is a shortcut and never a requirement.
	for mode in U.modes():
		for blessing in U.BLESSINGS:
			var pair: Array = _make(mode, blessing)
			var s: StageStealth = pair[0]
			var rec: Dictionary = pair[1]
			s.begin()
			_walk_route(s, _route(s, true))
			var tag: String = U.tag(mode, blessing)
			t.eq(rec["won"], 1, "%s: the camp is won" % tag)
			t.eq(rec["failed"], 0, "%s: never fails" % tag)
			t.eq(s.items_taken, 2, "%s: both items taken" % tag)
			t.eq(s.pushbacks, 0, "%s: the centre line is never noticed" % tag)
			s.free()


func _modes(t: TestRunner) -> void:
	var s: StageStealth = (_make(RunModel.Mode.SHEPHERD, "", 0))[0]
	s.begin()
	var off: Vector2 = s.path_points[0] + Vector2(0.0, -400.0)
	var secs: float = 0.0
	while s.pushbacks == 0 and secs < 8.0:
		s.david.position = off
		s.tick(U.STEP)
		secs += U.STEP
	t.truthy(secs >= 3.9 and secs <= 4.3, "Shepherd: noticeSec doubled in the data, about 4 s (got %s)" % secs)
	var l: StageStealth = (_make(RunModel.Mode.LAMB, "", 0))[0]
	l.begin()
	for i in 100:
		l.david.position = off if i < 50 else l.sleepers[0].position
		l.tick(U.STEP)
	t.eq(l.pushbacks, 0, "Lamb: the soldiers do not wake and nothing notices David off the path")
	t.eq(l.sleepers_woken, 0, "Lamb: no sleeper wakes")
	s.free()
	l.free()


func _hidden_in_the_rock(t: TestRunner) -> void:
	var plain: StageStealth = (_make(RunModel.Mode.NORMAL, "", 0))[0]
	var rock: StageStealth = (_make(RunModel.Mode.NORMAL, "hidden-in-the-rock", 0))[0]
	plain.begin()
	rock.begin()
	var secs: Array[float] = [0.0, 0.0]
	var stages: Array = [plain, rock]
	for k in 2:
		var st: StageStealth = stages[k]
		while st.pushbacks == 0 and secs[k] < 10.0:
			st.david.position = st.path_points[0] + Vector2(0.0, -400.0)
			st.tick(U.STEP)
			secs[k] += U.STEP
	t.truthy(secs[1] > secs[0] + 0.7, "Hidden in the Rock lengthens the notice time (%s vs %s)" % [secs[1], secs[0]])
	t.truthy(secs[1] >= 2.9 and secs[1] <= 3.3, "x1.5 of 2 s is about 3 s (got %s)" % secs[1])
	plain.free()
	rock.free()


func _faithful_friend(t: TestRunner) -> void:
	var s: StageStealth = (_make(RunModel.Mode.NORMAL, "faithful-friend"))[0]
	s.begin()
	s.tick(U.STEP)
	t.truthy(s.hint_visible(), "Faithful Friend: an arrow shows along the safe path")
	var to_next: Vector2 = s.path_points[1] - s.david.position
	t.truthy(absf(s.hint_arrow.rotation - to_next.angle()) < 0.01, "the arrow points to the next waypoint of the dark path")
	for i in 120:
		s.tick(U.STEP)
	t.falsy(s.hint_visible(), "the arrow fades")
	t.eq(s.hint_uses, 1, "once per stage")
	s.free()
	var l: StageStealth = (_make(RunModel.Mode.LAMB, "faithful-friend"))[0]
	l.begin()
	l.tick(U.STEP)
	t.truthy(l.hint_visible(), "Faithful Friend also shows in Lamb")
	l.free()


func _food(t: TestRunner) -> void:
	var s: StageStealth = StageStealth.new()
	var rec: Dictionary = U.build(s, U.camp_dict(), RunModel.Mode.NORMAL, "", 1)
	s.run.next_stage_food = 1
	s.begin()
	t.eq(rec["heals"], 1, "the scripted food restores one missing heart")
	t.eq(s.run.next_stage_food, 0, "the grant is consumed")
	s.free()
	var g: StageStealth = StageStealth.new()
	var rec2: Dictionary = U.build(g, U.camp_dict(), RunModel.Mode.NORMAL, "gift-of-abigail", 1)
	g.run.next_stage_food = 1
	g.begin()
	t.eq(rec2["heals"], 2, "Gift of Abigail adds food on top, capped by the hearts missing")
	g.free()
	var f: StageStealth = StageStealth.new()
	var rec3: Dictionary = U.build(f, U.camp_dict(), RunModel.Mode.NORMAL, "gift-of-abigail", 3)
	f.begin()
	t.eq(rec3["heals"], 0, "full hearts: nothing to heal")
	f.free()


func _spared(t: TestRunner) -> void:
	# Both items taken without waking anyone: spared once (Mercy gives its heart from this).
	var pair: Array = _make(RunModel.Mode.NORMAL, "mercy")
	var s: StageStealth = pair[0]
	s.begin()
	_walk_route(s, _route(s, true))
	t.eq(pair[1]["spared"], 1, "pickups taken without waking anyone: spared once")
	s.free()
	# A soldier woke first: no spared event.
	var p2: Array = _make(RunModel.Mode.NORMAL, "mercy")
	var w: StageStealth = p2[0]
	w.begin()
	var secs: float = 0.0
	while w.sleepers_woken == 0 and secs < 5.0:
		w.david.position = w.sleepers[0].position + Vector2(40.0, 0.0)
		w.tick(U.STEP)
		secs += U.STEP
	_walk_route(w, _route(w, true))
	t.eq(w.sleepers_woken, 1, "a soldier woke")
	t.eq(p2[1]["won"], 1, "the stage is still won")
	t.eq(p2[1]["spared"], 0, "no spared event once someone woke")
	w.free()
	# Lamb: nobody can wake, so the pickups always spare.
	var p3: Array = _make(RunModel.Mode.LAMB)
	var l: StageStealth = p3[0]
	l.begin()
	_walk_route(l, _route(l, true))
	t.eq(p3[1]["spared"], 1, "Lamb: spared")
	l.free()
