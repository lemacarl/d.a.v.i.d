extends RefCounted
## Stage 3.5, the cave of Adullam: gathering, welcoming, the patrol, scatter, the day-3 goal by mode.

const U := preload("res://tests/ch3-camp-util.gd")
const DAVID_EXPOSED: Vector2 = Vector2(1040, 660)

var _made: Array[Node] = []


func run(t: TestRunner) -> void:
	_data(t)
	_gathering(t)
	_welcome(t)
	_patrol_scatters(t)
	_hidden_is_safe(t)
	_hidden_in_the_rock(t)
	_day_three_goal(t)
	_lamb_and_shepherd_patrol(t)
	_bounded_nodes(t)
	for n in _made:
		n.free()


func _make(day: int, mode: RunModel.Mode, blessing: String = "", followers: int = 0) -> Array:
	var s: StageSurvivalCamp = StageSurvivalCamp.new()
	_made.append(s)
	var rm: RunModel = RunModel.new()
	rm.followers = followers
	var rec: Dictionary = U.build(s, U.stage_def("3-5-day-%d" % day, mode), mode, blessing, rm)
	return [s, rec]


## Plays `seconds` with a bot that welcomes every group that has arrived (David stays in the shelter).
func _play(s: StageSurvivalCamp, seconds: float) -> void:
	var el: float = 0.0
	while el < seconds and not s.is_finished():
		s.tick(U.STEP)
		s.on_action_tap()
		el += U.STEP


func _data(t: TestRunner) -> void:
	for n in [1, 2, 3]:
		var d: StageDef = U.stage_def("3-5-day-%d" % n, RunModel.Mode.NORMAL)
		t.eq(d.type, &"survival-camp", "day %d is a survival-camp stage" % n)
		t.eq(StageHost._scene_key(d), "survival-camp", "day %d uses the survival-camp scene" % n)
	t.truthy(ResourceLoader.exists("res://stage-scenes/stage-survival-camp.tscn"), "the camp scene exists")
	t.eq(U.stage_def("3-5-day-3", RunModel.Mode.NORMAL).win.get("min"), 400, "day 3 needs 400 men")


func _gathering(t: TestRunner) -> void:
	var pair: Array = _make(1, RunModel.Mode.NORMAL)
	var s: StageSurvivalCamp = pair[0]
	s.begin()
	var man: ActorCampMan = s._men[0]
	# OK far from every man selects nobody.
	s.on_action_tap()
	t.eq(man.state, ActorCampMan.State.IDLE, "OK away from the men chooses nobody")
	s.david.position = man.position + Vector2(20, 0)
	s.on_action_tap()
	t.eq(man.state, ActorCampMan.State.SELECTED, "OK next to a man chooses him")
	t.truthy(s.choose_direction(Vector2.UP), "UP sends him")
	t.eq(man.state, ActorCampMan.State.OUT, "he walks out")
	t.eq(man.kind, &"food", "UP is food")
	var man2: ActorCampMan = s._men[1]
	s.david.position = man2.position + Vector2(20, 0)
	s.on_action_tap()
	t.truthy(s.choose_direction(Vector2.DOWN), "DOWN sends the second man")
	t.eq(man2.kind, &"water", "DOWN is water")
	U.run_for(s, 25.0)
	t.eq(s.food, 1, "one food came home")
	t.eq(s.water, 1, "one water came home")
	t.eq(s.meals(), 1, "food and water make a meal")
	t.eq(man.state, ActorCampMan.State.IDLE, "the man is back in camp")
	# Left cancels; a second OK un-chooses.
	s.david.position = man.position
	s.on_action_tap()
	t.falsy(s.choose_direction(Vector2.LEFT), "LEFT cancels")
	t.eq(man.state, ActorCampMan.State.IDLE, "cancelled")
	s.on_action_tap()
	s.on_action_tap()
	t.eq(man.state, ActorCampMan.State.IDLE, "a second OK un-chooses")
	# The selection times out.
	s.on_action_tap()
	U.run_for(s, BalanceData.feel("campSelectWindowSec") + 0.5)
	t.eq(man.state, ActorCampMan.State.IDLE, "an unanswered choice times out")
	# Without the food-and-water tasks nobody can be sent.
	t.truthy(s.def.param_bool("foodWaterTasks"), "the tasks are on in the data")


func _welcome(t: TestRunner) -> void:
	# Greeted with a meal ready: group size plus the meal bonus; lines play; follower_added reported.
	var pair: Array = _make(1, RunModel.Mode.NORMAL)
	var s: StageSurvivalCamp = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	s.food = 2
	s.water = 2
	var arrive: float = 90.0 / 4.0 + BalanceData.feel("campArriveWalkSec") + 0.5
	U.run_for(s, arrive)
	s.on_action_tap()
	var group: int = 45
	var bonus: int = 2 * s.def.param_int("mealBonusMen")
	t.eq(s.men, group + bonus, "a greeted group joins and two meals feed more men")
	t.eq(s.meals(), 0, "the meals are used")
	t.eq(int((rec["added"] as Array)[0]), group + bonus, "follower_added(n) reports the arrivals")
	t.eq(rec["ids"], [&"c3-5-narr-cave", &"c3-5-follower", &"c3-5-david-come"], "enter line, then the new follower and David lines")
	t.eq(s.welcomed, 1, "one welcome")
	# Not greeted: joins after the wait, without the bonus, same lines.
	var pair2: Array = _make(2, RunModel.Mode.NORMAL)
	var s2: StageSurvivalCamp = pair2[0]
	s2.begin()
	s2.food = 3
	s2.water = 3
	U.run_for(s2, 90.0 / 4.0 + BalanceData.feel("campArriveWalkSec") + BalanceData.feel("campWelcomeWaitSec") + 1.0)
	var half: int = int(45.0 * s2.def.param_float("unwelcomedJoinFraction"))
	t.eq(s2.men, s2.def.param_int("minMenAtDayStart") + half, "an ungreeted group joins after the wait with its fraction of the men and no bonus")
	t.eq(s2.meals(), 3, "the meals are kept for the next group")
	t.eq((pair2[1]["ids"] as Array), [&"c3-5-follower", &"c3-5-david-come"], "day 2: the arrival lines play")
	# A day's three groups add followersPerDay when nobody gathers.
	var pair3: Array = _make(2, RunModel.Mode.NORMAL)
	var s3: StageSurvivalCamp = pair3[0]
	s3.begin()
	var start3: int = s3.men
	_play(s3, 200.0)
	t.eq(s3.men - start3, 135, "followersPerDay (135) arrive over the day when every group is welcomed")
	t.eq(int(pair3[1]["won"]), 1, "the day ends in a win")
	t.eq(s3.arrivals_joined, 3, "three arrival events")


func _expose(s: StageSurvivalCamp) -> void:
	s.david.position = DAVID_EXPOSED
	s.summon_patrol()


## Seconds from summoning a patrol to the camp being found (or -1).
func _time_to_scatter(s: StageSurvivalCamp, limit: float) -> float:
	var el: float = 0.0
	while el < limit and s.scatters == 0 and not s.is_finished():
		s.tick(U.STEP)
		el += U.STEP
	return el if s.scatters > 0 else -1.0


func _patrol_scatters(t: TestRunner) -> void:
	var pair: Array = _make(2, RunModel.Mode.NORMAL, "", 200)
	var s: StageSurvivalCamp = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	t.truthy(s.patrol_enabled(), "Normal has a patrol")
	t.eq(s.men, 200, "the men carried from day 1 are the run's followers")
	s._arrivals = 0
	_expose(s)
	var el: float = _time_to_scatter(s, 80.0)
	t.truthy(el > 0.0, "a patrol that sees David in the open finds the camp (%.1f s)" % el)
	t.eq(s.scatters, 1, "one scatter")
	t.eq(s.men, 170, "15% of 200 men scatter")
	t.eq((rec["scattered"] as Array), [30], "followers_scattered reports the men lost as a positive count")
	t.falsy((rec["added"] as Array).any(func(n: int) -> bool: return n < 0), "follower_added is never negative")
	t.eq((rec["run"] as RunModel).followers, 170, "the run's followers follow")
	t.eq(s.patrol_phase, ActorCampPatrol.Phase.OUT, "the patrol leaves")
	# Men out gathering are seen too, even when David is hidden.
	var pair2: Array = _make(2, RunModel.Mode.NORMAL, "", 100)
	var s2: StageSurvivalCamp = pair2[0]
	s2.begin()
	var man: ActorCampMan = s2._men[0]
	s2.david.position = man.position
	s2.on_action_tap()
	s2.choose_direction(Vector2.UP)
	var far: Vector2 = s2._food_spots[s2._food_spots.size() - 1]
	man.position = far
	man.state = ActorCampMan.State.WORK
	man.work_left = 500.0
	s2.david.position = StageSurvivalCamp.CAVE_CENTER
	s2.summon_patrol()
	var seen: float = 0.0
	var guard: float = 0.0
	while guard < 60.0 and s2.scatters == 0:
		s2.tick(U.STEP)
		guard += U.STEP
		man.work_left = 500.0
		seen = maxf(seen, s2.exposure())
	t.truthy(seen > 0.0, "a man out in the open builds exposure while David hides")


func _hidden_is_safe(t: TestRunner) -> void:
	var pair: Array = _make(2, RunModel.Mode.NORMAL, "", 200)
	var s: StageSurvivalCamp = pair[0]
	s.begin()
	s.david.position = StageSurvivalCamp.CAVE_CENTER + Vector2(120, 60)
	t.truthy(s.david_hidden(), "David in the cave's shelter is hidden")
	s.summon_patrol()
	var saw_patrol: bool = false
	var el: float = 0.0
	while el < 80.0 and not s.is_finished():
		s.tick(U.STEP)
		el += U.STEP
		saw_patrol = saw_patrol or s.patrol_phase == ActorCampPatrol.Phase.LOOK
		if s.elapsed > 60.0:
			break
	t.truthy(saw_patrol, "the patrol walked in and looked around")
	t.eq(s.scatters, 0, "staying in the shelter keeps the camp hidden")
	t.truthy(s.men >= 200, "no man scattered")
	# A brush hides David too.
	s.david.position = StageSurvivalCamp.BRUSHES[0] + Vector2(30, 10)
	t.truthy(s.david_hidden(), "David by a brush is hidden")
	s.david.position = DAVID_EXPOSED
	t.falsy(s.david_hidden(), "David in the open is not hidden")


func _hidden_in_the_rock(t: TestRunner) -> void:
	var p1: Array = _make(2, RunModel.Mode.NORMAL, "", 200)
	var plain: StageSurvivalCamp = p1[0]
	plain.begin()
	_expose(plain)
	var t_plain: float = _time_to_scatter(plain, 80.0)
	var p2: Array = _make(2, RunModel.Mode.NORMAL, "hidden-in-the-rock", 200)
	var rock: StageSurvivalCamp = p2[0]
	rock.begin()
	_expose(rock)
	var t_rock: float = _time_to_scatter(rock, 80.0)
	var notice: float = U.stage_def("3-5-day-2", RunModel.Mode.NORMAL).param_float("patrol.noticeSec")
	t.truthy(t_plain > 0.0 and t_rock > 0.0, "both camps are found")
	t.truthy(absf((t_rock - t_plain) - notice * 0.5) < 0.3, "Hidden in the Rock lengthens the notice time by half (%.1f vs %.1f s)" % [t_rock, t_plain])


func _day_three_goal(t: TestRunner) -> void:
	# Normal: 399 men at the end restarts the day (fail reason), 400 wins with the narrator line.
	var low: Array = _make(3, RunModel.Mode.NORMAL, "", 399)
	var s: StageSurvivalCamp = low[0]
	s.begin()
	s._per_day = 0
	_play(s, 100.0)
	t.eq(int(low[1]["failed"]), 1, "Normal: 399 at the end of day 3 fails")
	t.eq(low[1]["reason"], &"men-below-goal-at-end", "reason men-below-goal-at-end")
	t.eq(int(low[1]["won"]), 0, "no win")
	var ok: Array = _make(3, RunModel.Mode.NORMAL, "", 400)
	var s2: StageSurvivalCamp = ok[0]
	s2.begin()
	s2._per_day = 0
	_play(s2, 100.0)
	t.eq(int(ok[1]["won"]), 1, "Normal: 400 wins")
	t.eq((ok[1]["ids"] as Array).back(), &"c3-5-day3-end", "the narrator line closes day 3")
	for mode in [RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB]:
		var tp: Array = _make(3, mode, "", 150)
		var s3: StageSurvivalCamp = tp[0]
		s3.begin()
		s3._per_day = 0
		_play(s3, 100.0)
		var key: String = RunModel.mode_key(mode)
		t.eq(int(tp[1]["won"]), 1, "%s: day 3 is won" % key)
		t.eq(int(tp[1]["failed"]), 0, "%s: day 3 never fails" % key)
		t.eq(s3.men, 400, "%s: topped up to 400" % key)
		t.eq((tp[1]["run"] as RunModel).followers, 400, "%s: the run has 400 followers" % key)
		t.eq((tp[1]["ids"] as Array).back(), &"c3-5-day3-end", "%s: the same closing line" % key)


func _lamb_and_shepherd_patrol(t: TestRunner) -> void:
	var lamb: Array = _make(1, RunModel.Mode.LAMB)
	var l: StageSurvivalCamp = lamb[0]
	l.begin()
	t.falsy(l.patrol_enabled(), "Lamb: the patrols are removed")
	_expose(l)
	U.run_for(l, 80.0)
	t.eq(l.scatters, 0, "Lamb: nobody is ever found")
	t.eq(l.patrol_phase, ActorCampPatrol.Phase.AWAY, "Lamb: no patrol appears")
	var sh: StageDef = U.stage_def("3-5-day-1", RunModel.Mode.SHEPHERD)
	var nm: StageDef = U.stage_def("3-5-day-1", RunModel.Mode.NORMAL)
	t.truthy(sh.param_float("patrol.speed") < nm.param_float("patrol.speed"), "Shepherd patrols are slower")
	t.truthy(sh.param_float("patrol.noticeSec") > nm.param_float("patrol.noticeSec"), "Shepherd notice time is longer")


func _bounded_nodes(t: TestRunner) -> void:
	var pair: Array = _make(2, RunModel.Mode.NORMAL, "", 100)
	var s: StageSurvivalCamp = pair[0]
	s.begin()
	var before: int = s.world.get_child_count()
	_expose(s)
	_play(s, 120.0)
	t.eq(s.world.get_child_count(), before, "no node is created while the camp plays")
