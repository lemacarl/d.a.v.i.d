extends RefCounted
## Chapter 3 fix round: Watchful Eyes in every Chapter 3 stage, food in 3.9, the 3.9 hearts-zero restart and
## the softer raiders, the camp (idle David cannot win, a day-3 replay is always winnable), the En-gedi
## prompt, the 3.3 OK glyph, the scatter signal through the host, the HUD pulse.

const U := preload("res://tests/ch3-camp-util.gd")
const S := preload("res://tests/ch3-stages-util.gd")
const EXPOSED: Vector2 = Vector2(1040, 660)

var _made: Array[Node] = []


func run(t: TestRunner) -> void:
	_watchful_ziklag(t)
	_watchful_camp_patrol(t)
	_watchful_sleepers(t)
	_watchful_spear(t)
	_food_in_ziklag(t)
	_gift_reaches_ziklag_in_the_flow(t)
	_ziklag_hearts_zero_restarts_the_stage(t)
	_raiders_are_gentler(t)
	_idle_vs_engaged_camp(t)
	_day_three_is_always_winnable(t)
	_en_gedi_prompt(t)
	_arrow_ok_glyph(t)
	_scatter_through_the_host(t)
	_hud_pulse(t)
	for n in _made:
		n.free()
	RunState.end_run()
	RunState.set_followers(0)


func _ziklag(mode: RunModel.Mode, blessing: String = "", rm: RunModel = null) -> Array:
	var s: StageZiklag = StageZiklag.new()
	_made.append(s)
	var rec: Dictionary = U.build(s, U.stage_def("3-9-ziklag", mode), mode, blessing, rm)
	return [s, rec]


func _run(s: StagePlayBase, seconds: float) -> void:
	var el: float = 0.0
	while el < seconds and not s.is_finished():
		s.tick(U.STEP)
		el += U.STEP


# --- Watchful Eyes (R3-1, D-3) ---

func _watchful_ziklag(t: TestRunner) -> void:
	var plain: StageZiklag = (_ziklag(RunModel.Mode.NORMAL))[0]
	var eyes: StageZiklag = (_ziklag(RunModel.Mode.NORMAL, "watchful-eyes"))[0]
	plain.begin()
	eyes.begin()
	var tele: float = float(eyes.get_feature(&"enemyTelegraphSec", 0.0))
	t.near(tele, 1.0, "Watchful Eyes carries a 1 s warning")
	t.eq(plain.raiders[0].state, ActorRaider.State.CHASE, "without the Blessing the first raider chases at once")
	t.falsy(plain.raiders[0].glow, "...and nothing glows")
	t.eq(eyes.raiders[0].state, ActorRaider.State.WARN, "Watchful Eyes: the first raider waits")
	t.truthy(eyes.raiders[0].glow, "...and glows")
	var p0: Vector2 = eyes.raiders[0].position
	_run(eyes, 0.5)
	t.eq(eyes.raiders[0].position, p0, "a glowing raider stands still")
	_run(eyes, 0.7)
	t.eq(eyes.raiders[0].state, ActorRaider.State.CHASE, "after the warning he chases")
	t.falsy(eyes.raiders[0].glow, "...and the glow is off")
	# Raiders who join the chase later (staggered start) glow for the last second of their wait only.
	var data: float = U.stage_def("3-9-ziklag", RunModel.Mode.NORMAL).param_float("raiderStaggerSec")
	t.truthy(data > 0.0, "the data staggers the raiders' start")
	t.eq(eyes.raiders[1].state, ActorRaider.State.WARN, "the second raider is still waiting")
	t.falsy(eyes.raiders[1].glow, "...without a glow while his turn is far off")
	_run(eyes, data - 1.0)
	t.truthy(eyes.raiders[1].glow, "he glows for the warning time before his turn")
	t.falsy(plain.raiders[1].glow, "no glow without the Blessing")
	# A raider who returns after being repelled glows before he chases again.
	var saw_warn: Array = [false, false]
	var pair_stages: Array = [plain, eyes]
	for k in 2:
		var s: StageZiklag = pair_stages[k]
		var r: ActorRaider = s.raiders[0]
		s.repel(r)
		var el: float = 0.0
		while el < 20.0:
			s.tick(U.STEP)
			el += U.STEP
			if r.state == ActorRaider.State.WARN and r.glow and r.visible:
				saw_warn[k] = true
				break
	t.eq(saw_warn, [false, true], "a returning raider glows with Watchful Eyes only")
	# The rescue is won the same way with or without it.
	for blessing in ["", "watchful-eyes"]:
		var pair: Array = _ziklag(RunModel.Mode.LAMB, blessing)
		var s2: StageZiklag = pair[0]
		s2.begin()
		for i in s2.families.size():
			s2.free_family(i)
		t.eq(pair[1]["won"], 1, "Ziklag is won (%s)" % blessing)


func _watchful_camp_patrol(t: TestRunner) -> void:
	var out: Array = []
	for blessing in ["", "watchful-eyes"]:
		var rm: RunModel = RunModel.new()
		rm.followers = 200
		var s: StageSurvivalCamp = StageSurvivalCamp.new()
		_made.append(s)
		U.build(s, U.stage_def("3-5-day-2", RunModel.Mode.NORMAL), RunModel.Mode.NORMAL, blessing, rm)
		s.begin()
		s.david.position = StageSurvivalCamp.CAVE_CENTER
		s._patrol_timer = 3.0
		var warned_at: float = -1.0
		var el: float = 0.0
		while el < 8.0 and s.patrol_phase == ActorCampPatrol.Phase.AWAY:
			s.tick(U.STEP)
			el += U.STEP
			if warned_at < 0.0 and s.patrol_warning():
				warned_at = el
				t.truthy(s._patrol.visible, "the marker is on the field before the patrol walks in")
				t.eq(s.patrol_phase, ActorCampPatrol.Phase.AWAY, "...and the patrol has not come in yet")
		out.append([warned_at > 0.0, snappedf(el, 0.1), s._patrol.lane_y])
		t.falsy(s.patrol_warning(), "the marker is gone once the patrol walks in")
	t.eq(out[0][0], false, "no warning marker without the Blessing")
	t.eq(out[1][0], true, "Watchful Eyes shows the marker before the patrol arrives")
	t.eq(out[0][1], out[1][1], "the patrol arrives at the same time with or without it")
	t.eq(out[0][2], out[1][2], "...on the same row")


func _watchful_sleepers(t: TestRunner) -> void:
	var out: Array = []
	for blessing in ["", "watchful-eyes"]:
		var s: StageStealth = StageStealth.new()
		_made.append(s)
		var rec: Dictionary = S.build(s, S.camp_dict(0), RunModel.Mode.NORMAL, blessing)
		s.begin()
		var sl: ActorSleeper = s.sleepers[0]
		# On the path, a few steps toward the sleeper: inside his wake radius but never off the path.
		var spot: Vector2 = s.path_points[0]
		var best: float = INF
		for i in s.path_points.size() - 1:
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(sl.position, s.path_points[i], s.path_points[i + 1])
			if q.distance_to(sl.position) < best:
				best = q.distance_to(sl.position)
				spot = q
		spot += (sl.position - spot).normalized() * 15.0
		t.truthy(s.path_distance(spot) <= s.path_half and spot.distance_to(sl.position) < 130.0, "the test spot is on the path and inside the wake radius")
		var secs: float = 0.0
		var glowed: bool = false
		while s.sleepers_woken == 0 and secs < 8.0:
			s.david.position = spot
			s.tick(U.STEP)
			secs += U.STEP
			glowed = glowed or sl.glow
		out.append([snappedf(secs, 0.1), glowed])
		t.eq(s.sleepers_woken, 1, "the soldier wakes after the notice time (%s)" % blessing)
		t.eq(rec["failed"], 0, "waking a soldier is never a failure (%s)" % blessing)
		t.eq(s.pushbacks, 1, "...it sends David back to the start (%s)" % blessing)
	t.eq(out[0][1], false, "no glow without the Blessing")
	t.eq(out[1][1], true, "Watchful Eyes: the soldier glows before he can notice David")
	t.truthy(absf((float(out[1][0]) - float(out[0][0])) - 1.0) < 0.15, "...and the warning adds one second before he can notice (%s vs %s)" % [out[0][0], out[1][0]])


func _watchful_spear(t: TestRunner) -> void:
	var glow: Array = []
	for blessing in ["", "watchful-eyes"]:
		var s: StageRhythm = StageRhythm.new()
		_made.append(s)
		U.build(s, U.stage_def("3-2-spear", RunModel.Mode.NORMAL), RunModel.Mode.NORMAL, blessing)
		s.begin()
		var ticks: int = 0
		var el: float = 0.0
		while el < 40.0 and s.spear_phase != StageRhythm.Spear.FLY:
			s.tick(U.STEP)
			el += U.STEP
			if s.spear_phase == StageRhythm.Spear.GLOW:
				ticks += 1
		glow.append(float(ticks) * U.STEP)
	t.truthy(absf((glow[1] - glow[0]) - 1.0) < 0.25, "Watchful Eyes: the spear lane glows one second longer (%s vs %s)" % [glow[0], glow[1]])


# --- Food (R3-2, D-4) ---

func _food_in_ziklag(t: TestRunner) -> void:
	var none_rm: RunModel = RunModel.new()
	none_rm.hearts = 1
	var none: Array = _ziklag(RunModel.Mode.NORMAL, "", none_rm)
	(none[0] as StageZiklag).begin()
	t.eq(none[1]["heals"], [], "no food, no heal")
	t.falsy((none[1]["counters"] as Array).has([&"food", 3]), "...and no food counter")
	var rm: RunModel = RunModel.new()
	rm.hearts = 1
	var gift: Array = _ziklag(RunModel.Mode.NORMAL, "gift-of-abigail", rm)
	var s: StageZiklag = gift[0]
	s.begin()
	t.eq(s.food, 3, "Gift of Abigail: the stage starts with 3 food")
	t.eq(gift[1]["heals"], [2], "...food heals the two missing hearts")
	t.truthy((gift[1]["counters"] as Array).has([&"food", 3]), "...and the HUD gets the food counter")
	# The scripted grant (3.7) is consumed once by whichever stage starts next.
	var rm2: RunModel = RunModel.new()
	rm2.hearts = 2
	rm2.next_stage_food = 2
	var granted: Array = _ziklag(RunModel.Mode.NORMAL, "", rm2)
	(granted[0] as StageZiklag).begin()
	t.eq(granted[1]["heals"], [1], "a scripted grant heals what is missing")
	t.eq(rm2.next_stage_food, 0, "...and is used up")
	# The camp days and 3.8 show the counter too.
	var camp_rm: RunModel = RunModel.new()
	var camp: StageSurvivalCamp = StageSurvivalCamp.new()
	_made.append(camp)
	var crec: Dictionary = U.build(camp, U.stage_def("3-5-day-1", RunModel.Mode.NORMAL), RunModel.Mode.NORMAL, "gift-of-abigail", camp_rm)
	camp.begin()
	t.truthy((crec["counters"] as Array).has([&"food", 3]), "3.5 days show the food counter")
	var sd: StageStealth = StageStealth.new()
	_made.append(sd)
	var srm: RunModel = RunModel.new()
	srm.hearts = 2
	srm.next_stage_food = 3
	var srec: Dictionary = U.build(sd, U.stage_def("3-8-camp", RunModel.Mode.NORMAL), RunModel.Mode.NORMAL, "", srm)
	sd.begin()
	t.truthy((srec["counters"] as Array).has([&"food", 3]), "3.8 shows the food counter")
	t.eq(srec["heals"], [1], "3.8 food heals the missing heart")


## The card is offered after 3.8 and the very next stage (3.9) uses its food.
func _gift_reaches_ziklag_in_the_flow(t: TestRunner) -> void:
	var rs: Node = U.new_run_state()
	rs.call("start_chapter", 3, RunModel.Mode.NORMAL)
	U.go_to(rs, "3-8-camp")
	var ids: Array = []
	for c in rs.call("available_blessings"):
		ids.append(str((c as Dictionary).get("id", "")))
	t.truthy(ids.has("gift-of-abigail"), "Gift of Abigail is offerable once 3.7 is cleared")
	rs.call("advance")
	t.truthy(rs.get("awaiting_blessing"), "a Blessing is offered after 3.8")
	rs.call("add_blessing", &"gift-of-abigail")
	t.eq(U.cur(rs), "3-9-ziklag", "3.9 follows")
	var model: RunModel = rs.get("model")
	model.hearts = 1
	var s: StageZiklag = StageZiklag.new()
	_made.append(s)
	var heals: Array = []
	s.heal_requested.connect(func(n: int) -> void: heals.append(n))
	s.setup(rs.get("current_stage"), model, rs.get("mods"))
	s.begin()
	t.eq(heals, [2], "the Gift's food is eaten at the start of 3.9")
	t.eq(s.food, 3, "...3 food in all")
	rs.free()


# --- 3.9 hearts-zero and the softer raiders (R3-3, D-2) ---

func _ziklag_hearts_zero_restarts_the_stage(t: TestRunner) -> void:
	var d: StageDef = U.stage_def("3-9-ziklag", RunModel.Mode.NORMAL)
	t.eq(d.on_lose_for(&"hearts-zero")["target"], "restart-stage", "3.9 hearts-zero restarts the stage")
	t.eq(d.on_lose_for(&"hearts-zero")["message"], "pool:david-falls", "...with the David-falls message")
	t.eq(d.on_lose_for(&"timeout")["target"], "restart-stage", "the timeout still restarts the stage")
	var rs: Node = U.new_run_state()
	rs.call("start_chapter", 3, RunModel.Mode.NORMAL)
	U.go_to(rs, "3-8-camp")
	var model: RunModel = rs.get("model")
	rs.call("set_followers", 400)
	model.hearts = 1
	U.go_to(rs, "3-9-ziklag")
	t.eq(U.cur(rs), "3-9-ziklag", "in 3.9")
	var entered_hearts: int = model.hearts
	rs.call("add_followers", 3)
	t.eq(rs.call("fail_stage", &"hearts-zero"), &"restart-stage", "out of hearts: the stage restarts")
	t.eq(U.cur(rs), "3-9-ziklag", "...3.9 again, not the chapter start")
	t.eq(model.followers, 400, "...with the 400 men David entered with")
	t.truthy(model.hearts >= entered_hearts and model.hearts == model.hearts_max, "...and hearts back to full (entered with %d)" % entered_hearts)
	t.eq(model.cleared_stages.has(&"3-7-abigail"), true, "the earlier stages stay cleared")
	# Through apply_hit: three touches in Normal.
	for i in 3:
		rs.call("apply_hit", 1)
	t.eq(U.cur(rs), "3-9-ziklag", "three raider touches replay 3.9, not the chapter")
	# Shepherd and Lamb never fall.
	rs.free()
	for mode in [RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB]:
		var rs2: Node = U.new_run_state()
		rs2.call("start_chapter", 3, mode)
		U.go_to(rs2, "3-9-ziklag")
		t.eq(rs2.call("fail_stage", &"hearts-zero"), &"ignored", "%s: 3.9 hearts-zero is ignored" % RunModel.mode_key(mode))
		rs2.free()


func _raiders_are_gentler(t: TestRunner) -> void:
	# A raider that touches David costs one heart, runs off, and nobody else can touch inside the window.
	var pair: Array = _ziklag(RunModel.Mode.NORMAL)
	var s: StageZiklag = pair[0]
	s.begin()
	var a: ActorRaider = s.raiders[0]
	var b: ActorRaider = s.raiders[1]
	a.state = ActorRaider.State.CHASE
	b.state = ActorRaider.State.CHASE
	a.position = s.david.position
	b.position = s.david.position + Vector2(10.0, 0.0)
	s.tick(U.STEP)
	t.eq(pair[1]["hits"], 1, "one touch costs one heart")
	t.eq(a.state, ActorRaider.State.AWAY, "the raider that touched him runs off")
	t.eq(s.repelled, 0, "...which is not counted as a stone hit")
	for i in 14:
		s.tick(U.STEP)
	t.eq(pair[1]["hits"], 1, "nothing touches him again inside the 1.5 s window")
	_run(s, 1.0)
	t.truthy(pair[1]["hits"] >= 1, "later touches count again")
	# Raiders come back after raiderStunSec (data) and the field never stays empty.
	var stun: float = s.def.param_float("raiderStunSec")
	t.truthy(stun >= 3.0, "a repelled raider stays away at least 3 s (%s)" % stun)
	# An idle David does not fall in the first ten seconds (real data, several seeds).
	for seed_value in [1, 7, 42, 99, 123]:
		var rm: RunModel = RunModel.new()
		var idle: Array = [StageZiklag.new()]
		var st: StageZiklag = idle[0]
		_made.append(st)
		var rec: Dictionary = U.build(st, U.stage_def("3-9-ziklag", RunModel.Mode.NORMAL), RunModel.Mode.NORMAL, "", rm, seed_value)
		st.begin()
		_run(st, 10.0)
		t.truthy(int(rec["hits"]) < 3, "seed %d: idle David still has a heart after 10 s (%d touches)" % [seed_value, int(rec["hits"])])
		_run(st, 25.0)
		t.truthy(int(rec["hits"]) >= 1, "seed %d: the raiders do come for him" % seed_value)


# --- Camp (R3-4, R3-5) ---

## Plays one camp day. Bot: welcome every group (`welcome`), optionally with `meals` ready for each group,
## and scatter the camp at the listed seconds. Returns the recorder.
func _day(rs: Node, welcome: bool, meals: int = 0, scatter_at: Array = []) -> Dictionary:
	var def: StageDef = rs.get("current_stage")
	var model: RunModel = rs.get("model")
	var s: StageSurvivalCamp = StageSurvivalCamp.new()
	_made.append(s)
	var rec: Dictionary = {"won": 0, "failed": 0, "reason": &""}
	s.stage_won.connect(func() -> void: rec["won"] = int(rec["won"]) + 1)
	s.stage_failed.connect(func(r: StringName) -> void:
		rec["failed"] = int(rec["failed"]) + 1
		rec["reason"] = r)
	s.follower_added.connect(rs.add_followers)
	s.followers_scattered.connect(rs.lose_followers)
	s.setup(def, model, rs.get("mods"))
	s.begin()
	var el: float = 0.0
	while el < 200.0 and not s.is_finished():
		s.tick(U.STEP)
		el += U.STEP
		if welcome:
			if meals > 0:
				s.food = meals
				s.water = meals
			s.on_action_tap()
		for at in scatter_at:
			if absf(el - float(at)) < U.STEP * 0.5:
				s._scatter()
	return rec


func _next(rs: Node) -> void:
	rs.call("advance")
	if rs.get("awaiting_blessing"):
		rs.call("skip_blessing")


func _idle_vs_engaged_camp(t: TestRunner) -> void:
	var results: Dictionary = {}
	for bot in ["idle", "welcome", "meals"]:
		var rs: Node = U.new_run_state()
		rs.call("start_chapter", 3, RunModel.Mode.NORMAL)
		U.go_to(rs, "3-5-day-1")
		var rec: Dictionary = {}
		for day in 3:
			rec = _day(rs, bot != "idle", 1 if bot == "meals" else 0)
			if day < 2:
				_next(rs)
		results[bot] = [(rs.get("model") as RunModel).followers, rec]
		rs.free()
	var idle_men: int = results["idle"][0]
	t.truthy(idle_men < 400, "an idle David ends below 400 in Normal (%d)" % idle_men)
	t.eq(int((results["idle"][1] as Dictionary)["won"]), 0, "...so day 3 is not won")
	t.eq((results["idle"][1] as Dictionary)["reason"], &"men-below-goal-at-end", "...it asks for a replay")
	var welcome_men: int = results["welcome"][0]
	t.truthy(welcome_men >= 400, "welcoming every group reaches 400 (%d)" % welcome_men)
	t.eq(int((results["welcome"][1] as Dictionary)["won"]), 1, "...and wins day 3")
	t.truthy(int(results["meals"][0]) > welcome_men, "a meal for each group adds more men (%d)" % int(results["meals"][0]))
	t.truthy(idle_men <= 360 and welcome_men - idle_men >= 50, "idle ends well short of the goal (%d vs %d)" % [idle_men, welcome_men])
	# An idle group joins with only unwelcomedJoinFraction of its men and no meal bonus.
	var def: StageDef = U.stage_def("3-5-day-1", RunModel.Mode.NORMAL)
	t.near(def.param_float("unwelcomedJoinFraction"), 0.5, "unwelcomedJoinFraction is data (0.5)")
	# Shepherd and Lamb still end at 400 (topUpTo).
	for mode in [RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB]:
		var rs3: Node = U.new_run_state()
		rs3.call("start_chapter", 3, mode)
		U.go_to(rs3, "3-5-day-1")
		var last: Dictionary = {}
		for day in 3:
			last = _day(rs3, false)
			if day < 2:
				_next(rs3)
		t.eq(int(last["won"]), 1, "%s: idle David still finishes day 3" % RunModel.mode_key(mode))
		t.eq((rs3.get("model") as RunModel).followers, 400, "%s: topped up to 400" % RunModel.mode_key(mode))
		rs3.free()


func _day_three_is_always_winnable(t: TestRunner) -> void:
	# Scattered twice on day 1 and twice on day 2, then once on day 3: the first day 3 fails, the replay wins.
	var rs: Node = U.new_run_state()
	rs.call("start_chapter", 3, RunModel.Mode.NORMAL)
	U.go_to(rs, "3-5-day-1")
	var model: RunModel = rs.get("model")
	var r1: Dictionary = _day(rs, true, 0, [60.0, 80.0])
	t.eq(int(r1["won"]), 1, "day 1 is won after two scatters")
	_next(rs)
	var r2: Dictionary = _day(rs, true, 0, [60.0, 80.0])
	t.eq(int(r2["won"]), 1, "day 2 is won after two scatters")
	_next(rs)
	t.eq(U.cur(rs), "3-5-day-3", "day 3 follows")
	var before: int = model.followers
	var min_start: int = (rs.get("current_stage") as StageDef).param_int("minMenAtDayStart")
	t.truthy(min_start >= 200, "day 3 starts with at least %d men" % min_start)
	var r3: Dictionary = _day(rs, true, 0, [60.0])
	t.eq(int(r3["failed"]), 1, "a scatter on day 3 can cost the day")
	t.eq(rs.call("fail_stage", r3["reason"]), &"restart-stage", "...which replays day 3")
	t.eq(model.followers, before, "...with the men carried in")
	var r4: Dictionary = _day(rs, true)
	t.eq(int(r4["won"]), 1, "the replay with normal play wins")
	t.truthy(model.followers >= 400, "...with 400 men (%d)" % model.followers)
	rs.free()
	# The floor is data and rises day by day.
	var floors: Array = []
	for n in [1, 2, 3]:
		floors.append(U.stage_def("3-5-day-%d" % n, RunModel.Mode.NORMAL).param_int("minMenAtDayStart"))
	t.truthy(floors[0] <= floors[1] and floors[1] < floors[2], "minMenAtDayStart rises: %s" % str(floors))
	var per_day: int = U.stage_def("3-5-day-3", RunModel.Mode.NORMAL).param_int("followersPerDay")
	t.truthy(floors[2] + per_day >= 400, "...enough that a welcomed day 3 reaches the goal")
	t.truthy(floors[1] + 2 * per_day >= 400, "...and day 2 already puts 400 in reach")


# --- En-gedi and the 3.3 arrow (D-1) ---

func _en_gedi_prompt(t: TestRunner) -> void:
	var line: Dictionary = LineBook.line(&"c3-6-prompt-cut")
	t.eq(line.get("text"), "cut a corner of his robe", "the prompt text is the script's")
	t.eq(line.get("speaker"), "ui", "...a ui line")
	for mode in U.modes():
		var s: StageStealth = StageStealth.new()
		_made.append(s)
		var rec: Dictionary = {}
		var rm: RunModel = RunModel.new()
		rec = U.build(s, U.stage_def("3-6-en-gedi", mode), mode, "", rm)
		s.begin()
		var key: String = RunModel.mode_key(mode)
		s.tick(U.STEP)
		t.falsy(s.prompt_visible(), "%s: no prompt far from Saul" % key)
		s.on_action_tap()
		t.eq(s.saul.reach_glow, 1.0, "%s: OK out of reach flashes the reach ring" % key)
		t.falsy(s.robe_cut, "%s: ...and cuts nothing" % key)
		t.eq(int(rec["won"]), 0, "%s: ...and does not end the stage" % key)
		for i in 10:
			s.tick(U.STEP)
		t.truthy(s.saul.reach_glow < 1.0, "%s: the flash fades" % key)
		# Stand behind Saul, inside the reach, out of his sight.
		s.david.position = s.saul.position + Vector2(80.0, 0.0)
		s.tick(U.STEP)
		t.truthy(s.prompt_visible(), "%s: within reach the prompt shows" % key)
		t.eq(s._prompt.text, "cut a corner of his robe", "%s: ...with the script's words" % key)
		s.on_action_tap()
		t.eq(int(rec["won"]), 1, "%s: OK in reach cuts the corner and ends the stage" % key)
		s.tick(U.STEP)
		t.falsy(s.prompt_visible(), "%s: the prompt goes away once the robe is cut" % key)


func _arrow_ok_glyph(t: TestRunner) -> void:
	var s: StageCutscene = StageCutscene.new()
	_made.append(s)
	U.build(s, U.stage_def("3-3-arrows", RunModel.Mode.NORMAL), RunModel.Mode.NORMAL)
	s.begin()
	t.falsy(s.ok_glyph_shown(), "no OK shape at the start")
	var el: float = 0.0
	while el < 120.0 and s.waiting != StageCutscene.Wait.OK:
		s.tick(U.STEP)
		if s.waiting == StageCutscene.Wait.LINE:
			s.on_action_tap()
		if s.waiting == StageCutscene.Wait.WATCH:
			t.falsy(s.ok_glyph_shown(), "no OK shape while the arrow flies")
		el += U.STEP
	t.eq(s.waiting, StageCutscene.Wait.OK, "the scene waits for OK")
	t.truthy(s.ok_glyph_shown(), "the OK shape shows when OK is available")
	s.on_action_tap()
	t.falsy(s.ok_glyph_shown(), "...and goes once OK is pressed")


# --- Scatter through the host, HUD ---

func _scatter_through_the_host(t: TestRunner) -> void:
	RunState.start_chapter(3, RunModel.Mode.NORMAL)
	U.go_to(RunState, "3-5-day-2")
	RunState.set_followers(200)
	var host: StageHost = StageHost.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	host.load_stage(RunState.current_stage)
	var s: StageSurvivalCamp = host._stage as StageSurvivalCamp
	var start: int = RunState.model.followers
	s._scatter()
	t.eq(RunState.model.followers, start - int(round(float(start) * 0.15)), "followers_scattered reaches RunState through the host")
	host.clear_stage()
	host.free()
	Engine.time_scale = 1.0


func _hud_pulse(t: TestRunner) -> void:
	var hud: Hud = Hud.new()
	_made.append(hud)
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	hud._on_hearts(1, 3)
	hud._on_hearts(2, 3)
	t.eq(hud._hearts[1].pivot_offset, Vector2(28.0, 28.0), "a heart gained pulses (the new heart pops)")
	t.eq(hud._hearts[0].pivot_offset, Vector2.ZERO, "...the others do not")
	hud._on_hearts(1, 3)
	t.eq(hud._hearts[1].filled, false, "losing a heart just empties it")
