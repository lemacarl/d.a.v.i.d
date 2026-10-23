extends RefCounted
## Stage 3.6 (stealth, En-gedi): the only action is OK (cut a corner of the robe), being noticed
## resets David and never fails, Saul is always spared, Lamb has no sight.

const U := preload("res://tests/ch3-stages-util.gd")


func run(t: TestRunner) -> void:
	_only_ok(t)
	_noticed_resets(t)
	_sight_rules(t)
	_modes(t)
	_hidden_in_the_rock(t)
	_faithful_friend(t)
	_saul_always_spared(t)
	_lines(t)


func _make(mode: RunModel.Mode, blessing: String = "") -> Array:
	var s: StageStealth = StageStealth.new()
	var rec: Dictionary = U.build(s, U.robe_dict(), mode, blessing)
	return [s, rec]


## The wall route behind Saul, then OK.
func _sneak(s: StageStealth) -> void:
	var top: float = StagePlayBase.FIELD.position.y + 110.0
	U.walk_to(s, Vector2(s.david.position.x + 380.0, top))
	U.walk_to(s, Vector2(s.saul.position.x + 260.0, top))
	U.walk_to(s, s.saul.position + Vector2(72.0, -40.0))
	s.on_action_tap()


func _only_ok(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StageStealth = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	t.eq(s.kind, StageStealth.Kind.ROBE, "3.6 is the robe variant (actions.ok cut-corner-of-robe)")
	var thrown: Array = [0]
	s.stone_thrown.connect(func() -> void: thrown[0] += 1)
	s.on_action_tap()
	s.tick(U.STEP)
	t.eq(thrown[0], 0, "OK far from Saul throws nothing (there is no attack)")
	t.eq(rec["won"], 0, "OK far from Saul does nothing")
	var visible_stones: int = 0
	for st in s._stones:
		if st.visible:
			visible_stones += 1
	t.eq(visible_stones, 0, "no stone is ever in the air in the cave")
	_sneak(s)
	t.eq(rec["won"], 1, "OK next to Saul cuts the robe corner and wins")
	t.truthy(s.robe_cut, "the robe corner is cut")
	t.eq(rec["failed"], 0, "no failure")
	s.free()


func _noticed_resets(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StageStealth = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	var start: Vector2 = s.david.position
	var spot: Vector2 = s.saul.position + Vector2(-250.0, 0.0)
	var secs: float = 0.0
	while s.pushbacks == 0 and secs < 5.0:
		s.david.position = spot
		s.tick(U.STEP)
		secs += U.STEP
	t.eq(s.pushbacks, 1, "being in Saul's sight for noticeSec resets David")
	t.truthy(secs >= 2.4 and secs <= 2.8, "reset after about 2.5 s (got %s)" % secs)
	t.eq(s.david.position, start, "reset-position puts David back at the cave mouth")
	t.eq(rec["failed"], 0, "being noticed is not a failure")
	t.falsy(s.is_finished(), "the stage keeps running after a reset")
	t.eq(rec["hits"], 0, "being noticed costs no heart")
	# A brief glimpse (under noticeSec) is forgiven and decays.
	var s2: StageStealth = (_make(RunModel.Mode.NORMAL))[0]
	s2.begin()
	for i in 10:
		s2.david.position = s2.saul.position + Vector2(-250.0, 0.0)
		s2.tick(U.STEP)
	for i in 40:
		s2.david.position = s2.saul.position + Vector2(0.0, -450.0)
		s2.tick(U.STEP)
	t.eq(s2.pushbacks, 0, "a short glimpse followed by hiding is not noticed")
	t.near(s2.seen_time, 0.0, "the meter decays while unseen")
	s.free()
	s2.free()


func _sight_rules(t: TestRunner) -> void:
	var s: StageStealth = (_make(RunModel.Mode.NORMAL))[0]
	s.begin()
	var sp: Vector2 = s.saul.position
	s.david.position = sp + Vector2(-250.0, 0.0)
	t.truthy(s.saul_sees(), "David straight ahead of Saul is seen")
	s.david.position = sp + Vector2(-230.0, 90.0)
	t.truthy(s.saul_sees(), "David inside the cone is seen")
	s.david.position = sp + Vector2(250.0, 0.0)
	t.falsy(s.saul_sees(), "David behind Saul is never seen")
	s.david.position = sp + Vector2(-100.0, -250.0)
	t.falsy(s.saul_sees(), "David outside the cone is not seen")
	s.david.position = sp + Vector2(-700.0, 0.0)
	t.falsy(s.saul_sees(), "David beyond the sight range is not seen")
	# A pillar between them blocks the view.
	var pillar: ColorRect = s.rocks[0]
	var behind: Vector2 = pillar.position + pillar.size * 0.5
	s.saul.position = behind + Vector2(150.0, 0.0)
	s.david.position = behind + Vector2(-100.0, 0.0)
	t.falsy(s.saul_sees(), "a pillar hides David")
	s.david.position = behind + Vector2(90.0, 0.0)
	t.truthy(s.saul_sees(), "David in front of the pillar is seen again")
	t.truthy(StageStealth.segment_hits_rect(Vector2(0, 0), Vector2(100, 100), Rect2(40, 40, 20, 20)), "segment crosses a rectangle")
	t.falsy(StageStealth.segment_hits_rect(Vector2(0, 0), Vector2(100, 0), Rect2(40, 40, 20, 20)), "segment misses a rectangle")
	s.free()


func _modes(t: TestRunner) -> void:
	var n: StageStealth = (_make(RunModel.Mode.NORMAL))[0]
	var sh: StageStealth = (_make(RunModel.Mode.SHEPHERD))[0]
	var lb: Array = _make(RunModel.Mode.LAMB)
	var l: StageStealth = lb[0]
	t.near(sh.notice_sec, n.notice_sec * 2.0, "Shepherd: noticeSec is doubled in the data")
	l.begin()
	for i in 80:
		l.david.position = l.saul.position + Vector2(-250.0, 0.0)
		l.tick(U.STEP)
	t.eq(l.pushbacks, 0, "Lamb: Saul has no sight, David is never reset")
	t.falsy(l.saul.alert, "Lamb: Saul never turns alert")
	sh.begin()
	var secs: float = 0.0
	while sh.pushbacks == 0 and secs < 9.0:
		sh.david.position = sh.saul.position + Vector2(-250.0, 0.0)
		sh.tick(U.STEP)
		secs += U.STEP
	t.truthy(secs >= 4.9 and secs <= 5.3, "Shepherd: reset after about 5 s (got %s)" % secs)
	n.free()
	sh.free()
	l.free()


func _hidden_in_the_rock(t: TestRunner) -> void:
	var plain: StageStealth = (_make(RunModel.Mode.NORMAL))[0]
	var rock: StageStealth = (_make(RunModel.Mode.NORMAL, "hidden-in-the-rock"))[0]
	for s in [plain, rock]:
		(s as StageStealth).begin()
	var secs: Array[float] = [0.0, 0.0]
	var stages: Array = [plain, rock]
	for k in 2:
		var st: StageStealth = stages[k]
		while st.pushbacks == 0 and secs[k] < 9.0:
			st.david.position = st.saul.position + Vector2(-250.0, 0.0)
			st.tick(U.STEP)
			secs[k] += U.STEP
	t.truthy(secs[1] > secs[0] + 0.5, "Hidden in the Rock lengthens the notice time (%s vs %s)" % [secs[1], secs[0]])
	t.truthy(secs[1] >= 3.6 and secs[1] <= 4.0, "x1.5 of 2.5 s is about 3.75 s (got %s)" % secs[1])
	plain.free()
	rock.free()


func _faithful_friend(t: TestRunner) -> void:
	var none: StageStealth = (_make(RunModel.Mode.NORMAL))[0]
	none.begin()
	for i in 20:
		none.tick(U.STEP)
	t.falsy(none.hint_visible(), "no Faithful Friend: no arrow")
	t.eq(none.hint_uses, 0, "no Faithful Friend: the hint is never used")
	var ff: Array = _make(RunModel.Mode.NORMAL, "faithful-friend")
	var s: StageStealth = ff[0]
	s.begin()
	s.tick(U.STEP)
	t.truthy(s.hint_visible(), "Faithful Friend: the arrow shows after the entry lines")
	t.eq(s.hint_uses, 1, "used once")
	var first_dir: float = s.hint_arrow.rotation
	t.truthy(s.hint_arrow.color.a < 0.8, "the arrow is faint")
	for i in 120:
		s.tick(U.STEP)
	t.falsy(s.hint_visible(), "the arrow fades after hintSec")
	t.eq(s.hint_uses, 1, "the hint shows once per stage")
	# A second look at the stage: it never comes back after a reset either.
	s.david.position = s.saul.position + Vector2(-250.0, 0.0)
	for i in 30:
		s.david.position = s.saul.position + Vector2(-250.0, 0.0)
		s.tick(U.STEP)
	t.falsy(s.hint_visible(), "no second hint after being noticed")
	t.truthy(absf(first_dir) < 1.6, "the first arrow points toward the cave (right)")
	# The arrow waits for the host line queue.
	var w: StageStealth = StageStealth.new()
	U.build(w, U.robe_dict(), RunModel.Mode.NORMAL, "faithful-friend")
	w.wait_for_lines = true
	w.begin()
	for i in 10:
		w.tick(U.STEP)
	t.falsy(w.hint_visible(), "the arrow waits while the entry lines are shown")
	w.on_lines_drained()
	w.tick(U.STEP)
	t.truthy(w.hint_visible(), "the arrow shows once the lines are drained")
	none.free()
	s.free()
	w.free()


func _saul_always_spared(t: TestRunner) -> void:
	for mode in U.modes():
		for blessing in U.BLESSINGS:
			var pair: Array = _make(mode, blessing)
			var s: StageStealth = pair[0]
			var rec: Dictionary = pair[1]
			s.begin()
			_sneak(s)
			var tag: String = U.tag(mode, blessing)
			t.eq(rec["won"], 1, "%s: the robe is cut and the stage is won" % tag)
			t.eq(rec["failed"], 0, "%s: never fails" % tag)
			t.eq(rec["spared"], 1, "%s: Saul is spared, reported once (Mercy gives its heart from this)" % tag)
			t.eq(rec["hits"], 0, "%s: nobody is hurt" % tag)
			t.eq(s.pushbacks, 0, "%s: the wall route is never noticed" % tag)
			s.free()
	var card: Dictionary = BalanceData.blessing_card(&"mercy")
	var ms: ModifierStack = ModifierStack.new(RunModel.Mode.NORMAL)
	ms.add_blessing(card)
	t.eq(int(ms.feature(&"heartOnSpare", 0)), 1, "Mercy turns the spared event into one heart (the host reads heartOnSpare)")
	# Noticed first, then spared: still exactly one spared event.
	var pair2: Array = _make(RunModel.Mode.NORMAL, "mercy")
	var s2: StageStealth = pair2[0]
	s2.begin()
	for i in 30:
		s2.david.position = s2.saul.position + Vector2(-250.0, 0.0)
		s2.tick(U.STEP)
	t.eq(s2.pushbacks, 1, "noticed once")
	_sneak(s2)
	t.eq(pair2[1]["spared"], 1, "noticed, then spared once on the win")
	t.eq(pair2[1]["won"], 1, "still won after a reset")
	s2.free()


func _lines(t: TestRunner) -> void:
	if LineBook.line(&"c3-6-men").is_empty():
		t.skip("Chapter 3 dialogue data not present yet: 3.6 line order not checked")
		return
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StageStealth = pair[0]
	s.begin()
	_sneak(s)
	t.eq(pair[1]["ids"], [&"c3-6-men", &"c3-6-david", &"c3-6-saul"], "3.6 lines: men whisper, then David calls out, then Saul answers")
	s.free()
