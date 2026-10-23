extends RefCounted
## Chapter 3 Blessings that live in the camp, cutscene and play-base code: Shepherd's Staff, Gift of
## Abigail, Faithful Friend (visual only) and Mighty Men. No Blessing and no mode changes a story outcome.

const U := preload("res://tests/ch3-camp-util.gd")

var _made: Array[Node] = []


## A bare StagePlayBase with a settable stone target (what Ziklag builds on).
class PlayProbe extends StagePlayBase:
	var target: Node2D = null

	func _pick_target() -> Node2D:
		return target


func run(t: TestRunner) -> void:
	_shepherds_staff(t)
	_gift_of_abigail(t)
	_faithful_friend(t)
	_mighty_men(t)
	_outcome_matrix(t)
	for n in _made:
		n.free()


func _camp(day: int, mode: RunModel.Mode, blessing: String, followers: int = 0, granted_food: int = 0) -> Array:
	var s: StageSurvivalCamp = StageSurvivalCamp.new()
	_made.append(s)
	var rm: RunModel = RunModel.new()
	rm.followers = followers
	rm.next_stage_food = granted_food
	var rec: Dictionary = U.build(s, U.stage_def("3-5-day-%d" % day, mode), mode, blessing, rm)
	return [s, rec]


func _shepherds_staff(t: TestRunner) -> void:
	var plain: StageSurvivalCamp = _camp(1, RunModel.Mode.NORMAL, "")[0]
	var staff: StageSurvivalCamp = _camp(1, RunModel.Mode.NORMAL, "shepherds-staff")[0]
	t.truthy(staff.crowd_radius() < plain.crowd_radius(), "Shepherd's Staff keeps the followers closer")
	t.near(staff.crowd_radius(), plain.crowd_radius() * 0.7, "...by the card's followRadiusMult (0.7)")
	t.eq(staff.get_modifier(&"follow-distance", 1.0), 0.7, "follow-distance comes from the card")
	# Every figure sits inside the smaller ring.
	var farthest: float = 0.0
	for f in staff._crowd:
		farthest = maxf(farthest, f.ring.length() * staff.crowd_radius())
	t.truthy(farthest <= staff.crowd_radius() + 0.01, "all figures stand within the closer ring")


func _gift_of_abigail(t: TestRunner) -> void:
	var plain: Array = _camp(1, RunModel.Mode.NORMAL, "")
	(plain[0] as StageSurvivalCamp).begin()
	t.eq((plain[0] as StageSurvivalCamp).food, 0, "no food without the Gift")
	t.eq(plain[1]["heals"], [], "no heal without food")
	var gift: Array = _camp(1, RunModel.Mode.NORMAL, "gift-of-abigail")
	(gift[0] as StageSurvivalCamp).begin()
	t.eq((gift[0] as StageSurvivalCamp).food, 3, "Gift of Abigail starts the stage with 3 food")
	t.eq(gift[1]["heals"], [3], "...and food restores hearts through heal_requested")
	var both: Array = _camp(1, RunModel.Mode.NORMAL, "gift-of-abigail", 0, 3)
	(both[0] as StageSurvivalCamp).begin()
	t.eq((both[0] as StageSurvivalCamp).food, 6, "the scripted grant and the Gift stack")
	t.eq(((both[1]["run"]) as RunModel).next_stage_food, 0, "the scripted grant is consumed once")
	var granted: Array = _camp(1, RunModel.Mode.NORMAL, "", 0, 3)
	(granted[0] as StageSurvivalCamp).begin()
	t.eq((granted[0] as StageSurvivalCamp).food, 3, "a scripted grant alone feeds the stage")


func _faithful_friend(t: TestRunner) -> void:
	var s: StageCutscene = StageCutscene.new()
	_made.append(s)
	U.build(s, U.stage_def("3-3-arrows", RunModel.Mode.NORMAL), RunModel.Mode.NORMAL, "faithful-friend")
	t.eq(int(s.get_feature(&"arrowHintPerStage", 0)), 1, "Faithful Friend carries arrowHintPerStage 1")
	t.falsy(s.arrow_trail_shown(), "no trail before the arrow flies")
	# The camp ignores it completely.
	var camp: Array = _camp(1, RunModel.Mode.NORMAL, "faithful-friend")
	(camp[0] as StageSurvivalCamp).begin()
	U.run_for(camp[0], 5.0)
	t.eq(int(camp[1]["hits"]), 0, "no side effect in the camp")


func _probe(blessing: String) -> Array:
	var s: PlayProbe = PlayProbe.new()
	_made.append(s)
	var rec: Dictionary = U.build(s, U.stage_def("3-3-arrows", RunModel.Mode.NORMAL), RunModel.Mode.NORMAL, blessing)
	rec["thrown"] = 0
	s.stone_thrown.connect(func() -> void: rec["thrown"] = int(rec["thrown"]) + 1)
	return [s, rec]


func _active_stones(s: StagePlayBase) -> int:
	var n: int = 0
	for st in s._stones:
		if st.active:
			n += 1
	return n


func _mighty_men(t: TestRunner) -> void:
	var none: Array = _probe("")
	var s0: PlayProbe = none[0]
	t.eq(s0.spawn_companion_if_blessed(), null, "no Blessing, no companion")
	t.eq(s0.companion_count(), 0, "companion_count is 0")
	var men: Array = _probe("mighty-men")
	var s1: PlayProbe = men[0]
	var c: ActorCompanion = s1.spawn_companion_if_blessed()
	t.truthy(c != null, "Mighty Men spawns a companion")
	t.eq(s1.companion_count(), 1, "companionCount 1")
	t.eq(s1.spawn_companion_if_blessed(), c, "calling it twice spawns nothing more")
	t.eq(s1.companion_count(), 1, "still one companion")
	# The companion walks with David.
	s1.david.position = Vector2(900, 500)
	for i in 80:
		s1.tick(0.1)
	t.truthy(c.position.distance_to(s1.david.position) <= c.offset.length() + 1.0, "the companion follows David")
	# And throws a stone with every throw, at the same target.
	for pair in [none, men]:
		var s: PlayProbe = pair[0]
		var tgt: Node2D = Node2D.new()
		tgt.position = Vector2(1500, 500)
		s.world.add_child(tgt)
		s.target = tgt
		s.on_action_tap()
	t.eq(_active_stones(s0), 1, "without Mighty Men one stone flies")
	t.eq(_active_stones(s1), 2, "with Mighty Men the companion throws one too")
	t.eq(int(men[1]["thrown"]), 1, "only David's throw is counted")
	# Stones are pooled: bounded nodes however much is thrown.
	var before: int = s1.world.get_child_count()
	for i in 60:
		s1.tick(0.1)
		s1.on_action_tap()
	t.eq(s1.world.get_child_count(), before, "no node is created while throwing")


func _outcome_matrix(t: TestRunner) -> void:
	var baseline: Array = []
	for mode in U.modes():
		for b in U.blessings():
			var rm: RunModel = RunModel.new()
			var ids: Array = []
			var wins: int = 0
			for day in [1, 2, 3]:
				var s: StageSurvivalCamp = StageSurvivalCamp.new()
				_made.append(s)
				var rec: Dictionary = U.build(s, U.stage_def("3-5-day-%d" % day, mode), mode, b, rm)
				s.begin()
				var el: float = 0.0
				while el < 200.0 and not s.is_finished():
					s.tick(U.STEP)
					s.on_action_tap()
					el += U.STEP
				wins += int(rec["won"])
				ids.append_array(rec["ids"])
			var tag: String = U.tag(mode, b)
			t.eq(wins, 3, "%s: all three camp days are won" % tag)
			if baseline.is_empty():
				baseline = ids.duplicate()
			t.eq(ids, baseline, "%s: the camp's story lines are identical" % tag)
