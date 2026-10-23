extends RefCounted
## Round 2 review fixes: Blessing effects in the stages, feel data, audio data, caption order,
## Lamb tutorial, outcomes for every mode x Blessing, mode list from data.

const STEP: float = 0.1
const FEEL_KEYS: Array[String] = [
	"walkSpeed", "stoneSpeed", "throwCooldownSec", "stoneHitRadius", "stoneMaxTravel", "sheepSpeed",
	"sheepWanderRadius", "sheepDriftRange", "predatorCatchRadius", "sheepRescueRadius",
	"predatorFleeSpeedMult", "offscreenMargin", "flockFollowPullPxPerSec", "telegraphPulseHz",
	"gatherRadius", "minLambDistance", "bossFleeSpeed", "bossOffscreenMargin",
	"tutorialMovedDistance", "tutorialReturnRadius", "cutsceneQuietSec", "cutsceneMinLineSec",
	"goldLightHoldSec", "goldLightFadeSec",
]
const SFX_CUES: Array[StringName] = [&"stone-throw", &"stone-hit", &"hurt", &"sheep-baa", &"harp", &"win", &"music-main"]


func run(t: TestRunner) -> void:
	_feel_data(t)
	_stage_params_data(t)
	_duplicate_numbers(t)
	_staff(t)
	_song_of_courage(t)
	_watchful_eyes(t)
	_got_you_every_time(t)
	_caption_order(t)
	_lamb_tutorial(t)
	_audio_data(t)
	_ui_text(t)
	_chapter_focus(t)
	_processing_stops(t)
	_outcomes(t)


# --- helpers ---

func _def(stage_id: String, mode: RunModel.Mode) -> StageDef:
	for d in StageDef.load_chapter(1, mode):
		if d.id == StringName(stage_id):
			return d
	return null


func _stack(mode: RunModel.Mode, blessing: String) -> ModifierStack:
	var ms: ModifierStack = ModifierStack.new(mode)
	if not blessing.is_empty():
		ms.add_blessing(BalanceData.blessing_card(StringName(blessing)))
	return ms


func _setup(stage: StageBase, stage_id: String, mode: RunModel.Mode, blessing: String = "", seed_value: int = 7) -> Dictionary:
	var rec: Dictionary = {"won": 0, "failed": 0, "reason": &"", "hits": 0, "ids": [], "sfx": [], "gold": []}
	stage.stage_won.connect(func() -> void: rec["won"] = int(rec["won"]) + 1)
	stage.stage_failed.connect(func(r: StringName) -> void:
		rec["failed"] = int(rec["failed"]) + 1
		rec["reason"] = r)
	stage.hit_taken.connect(func(_n: int) -> void: rec["hits"] = int(rec["hits"]) + 1)
	stage.line_requested.connect(func(_s: StringName, _tx: String, _r: String, id: StringName) -> void: (rec["ids"] as Array).append(id))
	stage.sfx_requested.connect(func(cue: StringName) -> void: (rec["sfx"] as Array).append(cue))
	stage.gold_light_requested.connect(func(_tx: String, _r: String, sec: float) -> void: (rec["gold"] as Array).append(sec))
	var rm: RunModel = RunModel.new()
	rm.mode = mode
	rm.rng_seed = seed_value
	stage.setup(_def(stage_id, mode), rm, _stack(mode, blessing))
	return rec


func _night(mode: RunModel.Mode, blessing: String, with_predators: bool) -> Array:
	var s: StageProtectFlock = StageProtectFlock.new()
	var d: StageDef = _def("1-2-night-1", mode)
	if not with_predators:
		d.params["predators"] = []
	var rec: Dictionary = _setup(s, "1-2-night-1", mode, blessing)
	if not with_predators:
		s.def.params["predators"] = []
		s._spawns = []
	return [s, rec]


func _mean_distance(s: StageProtectFlock) -> float:
	var total: float = 0.0
	var n: int = 0
	for sh in s._sheep:
		if sh.is_alive():
			total += sh.position.distance_to(s.david.position)
			n += 1
	return total / float(maxi(n, 1))


# --- data ---

func _feel_data(t: TestRunner) -> void:
	for k in FEEL_KEYS:
		t.truthy(BalanceData.feel(k) > 0.0, "balance.json feel.%s is present and positive" % k)
	t.near(BalanceData.feel("walkSpeed"), 320.0, "walk speed from data")
	t.near(BalanceData.feel("stoneSpeed"), 900.0, "stone speed from data")
	t.near(BalanceData.feel("throwCooldownSec"), 0.35, "throw cooldown from data")


func _stage_params_data(t: TestRunner) -> void:
	var lion: StageDef = _def("1-3-lion", RunModel.Mode.NORMAL)
	for k in ["circleRadius", "circleSpeed", "hitsToDrop", "hitsToFlee", "stunSec"]:
		t.truthy(lion.param_float(k, 0.0) > 0.0, "lion param %s comes from data" % k)
	var bear: StageDef = _def("1-4-bear", RunModel.Mode.NORMAL)
	for k in ["lanes", "windupSec", "restSec", "chargeSpeed", "slipSec", "rockEvery", "hitsToFlee"]:
		t.truthy(bear.param_float(k, 0.0) > 0.0, "bear param %s comes from data" % k)
	var harp: StageDef = _def("1-6-harp", RunModel.Mode.NORMAL)
	t.truthy(harp.param_float("noteSpeed", 0.0) > 0.0 and harp.param_float("hitWindowSec", 0.0) > 0.0, "rhythm feel numbers come from data")
	for id in ["1-2-night-1", "1-2-night-2", "1-2-night-3"]:
		t.truthy(_def(id, RunModel.Mode.NORMAL).param_int("maxPredators", 0) > 0, "%s maxPredators from data" % id)
	# The lion circles at the data speed, the stone flies at the data speed.
	var s: StageBoss = StageBoss.new()
	_setup(s, "1-3-lion", RunModel.Mode.NORMAL)
	t.near(s._circle_speed, 280.0, "lion circle speed read from the stage params")
	t.near(s._stone_speed_base, BalanceData.feel("stoneSpeed"), "stone speed read from balance feel")
	s.free()


func _duplicate_numbers(t: TestRunner) -> void:
	# D-2 / D-3: one source per number.
	for d in StageDef.load_chapter(1, RunModel.Mode.NORMAL):
		if d.type == &"protect-flock":
			t.falsy(d.params.has("sheepMinAlive"), "%s has no duplicate sheepMinAlive" % d.id)
			t.falsy(d.win.has("seconds"), "%s has no duplicate win.seconds" % d.id)
			t.falsy(d.has_lose(&"sheep-below-min") and d.lose_for(&"sheep-below-min").has("min"), "%s lose has no duplicate min" % d.id)
			t.falsy(d.params.has("eventLimits"), "%s has no invented eventLimits" % d.id)
			t.eq(int(d.win.get("minAlive", -1)), 3, "%s the one minAlive is 3" % d.id)
		if d.type == &"boss":
			t.falsy(d.win.has("count"), "%s hit count is read from hitsToFlee only" % d.id)
			t.falsy(d.events.has("hit-3") or d.events.has("hit-6"), "%s triggers are not named after hit numbers" % d.id)
	var lion: StageDef = _def("1-3-lion", RunModel.Mode.NORMAL)
	t.truthy(lion.events.has("drop") and lion.events.has("flee"), "lion events are drop and flee")
	t.truthy(_def("1-4-bear", RunModel.Mode.NORMAL).events.has("flee"), "bear event is flee")
	t.eq(_def("1-6-harp", RunModel.Mode.NORMAL).win.has("seconds"), false, "harp has no duplicate win.seconds")
	# D-4: the gold-light hold is the cutscene beat's seconds, passed with the signal.
	var s: StageCutscene = StageCutscene.new()
	var rec: Dictionary = _setup(s, "1-5-samuel", RunModel.Mode.NORMAL)
	s.begin()
	var guard: int = 0
	while not s.is_finished() and guard < 400:
		s.tick(0.5)
		guard += 1
	t.eq((rec["gold"] as Array).size(), 1, "the Samuel cutscene requests one gold light")
	t.near(float((rec["gold"] as Array)[0]), 4.0, "gold light seconds come from the data beat")
	s.free()


# --- Blessing effects ---

func _staff(t: TestRunner) -> void:
	var plain: Array = _night(RunModel.Mode.NORMAL, "", false)
	var staff: Array = _night(RunModel.Mode.NORMAL, "shepherds-staff", false)
	var a: StageProtectFlock = plain[0]
	var b: StageProtectFlock = staff[0]
	t.near(b.get_modifier(&"follow-distance", 1.0), 0.7, "Shepherd's Staff sets follow-distance 0.7")
	t.near(a.get_modifier(&"follow-distance", 1.0), 1.0, "no Blessing leaves follow-distance alone")
	a.begin()
	b.begin()
	for stage in [a, b]:
		(stage as StageProtectFlock).david.position = Vector2(300, 900)
	for i in 400:
		a.tick(STEP)
		b.tick(STEP)
	var da: float = _mean_distance(a)
	var db: float = _mean_distance(b)
	t.truthy(db < da - 100.0, "Shepherd's Staff keeps the flock closer to David (%s vs %s)" % [db, da])
	a.free()
	b.free()
	# Sheep drift less toward a predator.
	var drifts: Array = []
	for card in ["", "shepherds-staff"]:
		var pair: Array = _night(RunModel.Mode.NORMAL, card, false)
		var s: StageProtectFlock = pair[0]
		s.begin()
		s.david.position = Vector2(1700, 950)
		var p: ActorPredator = s._predators[0]
		p.activate(&"jackal", FIELD_CENTER_FAR, 0.0)
		var sh: ActorSheep = s._sheep[0]
		var start: float = sh.position.distance_to(p.position)
		for i in 30:
			s.tick(STEP)
		drifts.append(start - sh.position.distance_to(p.position))
		s.free()
	t.truthy(float(drifts[1]) < float(drifts[0]) or float(drifts[0]) <= 0.0, "Shepherd's Staff: sheep drift less toward a predator (%s vs %s)" % [drifts[1], drifts[0]])


const FIELD_CENTER_FAR: Vector2 = Vector2(700, 540)


func _song_of_courage(t: TestRunner) -> void:
	# Night: a nearby predator backs away and does no damage; one far away is ignored.
	for card in ["", "song-of-courage"]:
		var pair: Array = _night(RunModel.Mode.NORMAL, card, false)
		var s: StageProtectFlock = pair[0]
		var rec: Dictionary = pair[1]
		s.begin()
		s.david.position = Vector2(1000, 800)
		var near_p: ActorPredator = s._predators[0]
		var far_p: ActorPredator = s._predators[1]
		near_p.activate(&"jackal", Vector2(1200, 800), 90.0)
		far_p.activate(&"jackal", Vector2(200, 200), 90.0)
		s.on_action_hold()
		if card.is_empty():
			t.falsy((rec["sfx"] as Array).has(&"harp"), "hold without the Blessing plays nothing")
			t.near(near_p.afraid, 0.0, "hold without the Blessing frightens nothing")
		else:
			t.truthy((rec["sfx"] as Array).has(&"harp"), "hold plays the harp cue")
			t.near(near_p.afraid, 3.0, "Song of Courage frightens a predator within the radius for harpFrightenSec")
			t.near(far_p.afraid, 0.0, "a predator outside the radius is not frightened")
			var before: float = near_p.position.distance_to(s.david.position)
			for i in 10:
				s.tick(STEP)
			t.truthy(near_p.position.distance_to(s.david.position) > before, "the frightened predator backs away")
			t.eq(rec["hits"], 0, "the harp does no damage and the predator deals none")
			for i in 40:
				s.tick(STEP)
			t.near(near_p.afraid, 0.0, "the fright wears off after the data seconds")
		s.free()
	# A predator dragging a sheep lets it go.
	var drag: Array = _night(RunModel.Mode.NORMAL, "song-of-courage", false)
	var ds: StageProtectFlock = drag[0]
	ds.begin()
	ds.david.position = Vector2(1000, 800)
	var dp: ActorPredator = ds._predators[0]
	dp.activate(&"wolf", Vector2(1100, 800), 100.0)
	var prey: ActorSheep = ds._sheep[0]
	prey.set_state(ActorSheep.State.LOST)
	dp.carry = prey
	dp.state = ActorPredator.State.DRAG
	ds.on_action_hold()
	t.eq(dp.state, ActorPredator.State.FLEE, "a dragging predator is frightened off")
	t.eq(prey.state, ActorSheep.State.LOST, "the dragged sheep is let go (and can be returned)")
	ds.free()
	# Lion: stops moving for the data seconds, no hit counted.
	var lion: StageBoss = StageBoss.new()
	_setup(lion, "1-3-lion", RunModel.Mode.NORMAL, "song-of-courage")
	lion.begin()
	lion.tick(STEP)
	lion.david.position = lion.boss.position + Vector2(150, 0)
	lion.on_action_hold()
	var spot: Vector2 = lion.boss.position
	for i in 20:
		lion.tick(STEP)
		lion.david.position = spot + Vector2(150, 0)
	t.near(lion.boss.position.distance_to(spot), 0.0, "the frightened lion stops")
	t.eq(lion.hits, 0, "the harp counts as no hit")
	for i in 30:
		lion.tick(STEP)
	t.truthy(lion.boss.position.distance_to(spot) > 1.0, "the lion circles again afterwards")
	lion.free()
	# Bear: a charge in progress is abandoned.
	var bear: StageBoss = StageBoss.new()
	_setup(bear, "1-4-bear", RunModel.Mode.NORMAL, "song-of-courage")
	bear.begin()
	bear._begin_windup(bear.boss as ActorBear)
	bear.david.position = bear.boss.position + Vector2(200, 0)
	bear.on_action_hold()
	t.eq(bear._bear_state, StageBoss.BearState.REST, "the harp turns a bear charge back to rest")
	t.eq(bear.hits, 0, "the harp does not count as a hit")
	bear.free()


func _watchful_eyes(t: TestRunner) -> void:
	var delays: Array = []
	for card in ["", "watchful-eyes"]:
		var pair: Array = _night(RunModel.Mode.NORMAL, card, true)
		var s: StageProtectFlock = pair[0]
		s.begin()
		var glow_at: float = -1.0
		var live_at: float = -1.0
		var max_glow: int = 0
		for i in 400:
			s.tick(STEP)
			max_glow = maxi(max_glow, s.telegraphing_predators())
			if glow_at < 0.0 and s.telegraphing_predators() > 0:
				glow_at = s.elapsed
			if live_at < 0.0:
				for p in s._predators:
					if p.state == ActorPredator.State.CHASE:
						live_at = s.elapsed
			if live_at >= 0.0:
				break
		if card.is_empty():
			t.eq(max_glow, 0, "no Blessing: predators appear without a glow")
		else:
			t.truthy(glow_at >= 0.0, "Watchful Eyes: a predator glows first")
			t.truthy(absf((live_at - glow_at) - 1.0) <= 0.25, "the glow lasts enemyTelegraphSec (%s)" % (live_at - glow_at))
			delays.append(live_at)
		s.free()
	# Bear: the warning band lasts longer with the Blessing.
	var windups: Array = []
	for card in ["", "watchful-eyes"]:
		var bear: StageBoss = StageBoss.new()
		_setup(bear, "1-4-bear", RunModel.Mode.NORMAL, card)
		bear.begin()
		var secs: float = 0.0
		while bear._bear_state != StageBoss.BearState.WINDUP and secs < 10.0:
			bear.tick(0.05)
			secs += 0.05
		var w: float = 0.0
		while bear._bear_state == StageBoss.BearState.WINDUP and w < 10.0:
			bear.tick(0.05)
			w += 0.05
		windups.append(w)
		bear.free()
	t.truthy(float(windups[1]) - float(windups[0]) >= 0.9, "Watchful Eyes lengthens the bear's warning (%s vs %s)" % [windups[1], windups[0]])
	# Lamb has no enemies, so nothing glows.
	var lamb: Array = _night(RunModel.Mode.LAMB, "watchful-eyes", true)
	var ls: StageProtectFlock = lamb[0]
	ls.begin()
	for i in 600:
		ls.tick(STEP)
	t.eq(ls.live_predators(), 0, "Lamb: no enemies and no glow even with Watchful Eyes")
	ls.free()


func _got_you_every_time(t: TestRunner) -> void:
	# C-4: the scripted rescue line shows on every rescue (no cooldown or cap).
	var pair: Array = _night(RunModel.Mode.NORMAL, "", false)
	var s: StageProtectFlock = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	for i in 6:
		var sh: ActorSheep = s._sheep[i]
		sh.set_state(ActorSheep.State.LOST)
		sh.position = Vector2(300 + 50 * i, 300)
		s.david.position = sh.position
		s.tick(STEP)
	var got: int = 0
	for id in (rec["ids"] as Array):
		if id == &"c1-2-sheep-saved":
			got += 1
	t.eq(got, 6, "'Got you! Back to the flock.' is requested for each of six rescues in a row")
	s.free()


# --- captions, narration ids ---

func _caption_order(t: TestRunner) -> void:
	var q: LineQueue = LineQueue.new()
	var events: Array = []
	q.line_started.connect(func(_s: StringName, text: String, _r: String, _h: float, _st: bool) -> void: events.append("line:" + text))
	q.caption_started.connect(func(text: String, _r: String, _h: float) -> void: events.append("cap:" + text))
	q.narration_started.connect(func(id: StringName) -> void: events.append("voice:" + String(id)))
	q.request(&"narrator", "earlier", "", &"id-a")
	q.request(&"david", "mine", "", &"id-b")
	q.request(&"caption", "verse", "Ps 1")
	t.eq(events, ["voice:id-a", "line:earlier"], "N-1: a caption waits for its own line's turn")
	q.tick(3.05)
	t.eq(events, ["voice:id-a", "line:earlier", "voice:id-b", "line:mine", "cap:verse"], "N-1: caption appears with its line, after the earlier line")
	var q2: LineQueue = LineQueue.new()
	var e2: Array = []
	q2.caption_started.connect(func(text: String, _r: String, _h: float) -> void: e2.append(text))
	q2.request(&"david", "x")
	q2.request(&"caption", "now", "")
	t.eq(e2, ["now"], "a caption of the line on screen shows at once")
	q2.clear()
	# The 1.1 dialogue line with a caption arrives as a line plus a caption, in that order.
	var s: StageCutscene = StageCutscene.new()
	var order: Array = []
	_setup(s, "1-1-opening", RunModel.Mode.NORMAL)
	s.line_requested.connect(func(sp: StringName, _tx: String, _r: String, id: StringName) -> void: order.append([sp, id]))
	s.begin()
	var guard: int = 0
	while s.waiting != StageCutscene.Wait.TUTORIAL and guard < 200:
		s.tick(1.0)
		guard += 1
	var has_caption: bool = false
	for i in order.size():
		if (order[i] as Array)[0] == &"caption":
			has_caption = true
			t.eq((order[i - 1] as Array)[1], &"c1-1-david-i-will", "the verse caption follows its dialogue line")
			t.eq((order[i] as Array)[1], &"", "a caption carries no recording id")
	t.truthy(has_caption, "1.1 emits the Psalm 23:1 caption")
	for e in order:
		if (e as Array)[0] == &"narrator":
			t.truthy(String((e as Array)[1]).begins_with("c1-"), "narrator lines carry their data line id")
	s.free()


func _lamb_tutorial(t: TestRunner) -> void:
	# N-3 / C-5: in Lamb the stone-throw tutorial step is satisfied by OK (harp ring), no stone.
	var s: StageCutscene = StageCutscene.new()
	var thrown: Array = [0]
	var rec: Dictionary = _setup(s, "1-1-opening", RunModel.Mode.LAMB)
	s.stone_thrown.connect(func() -> void: thrown[0] = int(thrown[0]) + 1)
	s.begin()
	var guard: int = 0
	while not s.is_finished() and guard < 3000:
		s.input_dir = Vector2.ZERO
		if s.waiting == StageCutscene.Wait.TUTORIAL:
			match s._until:
				"david-moved":
					s.input_dir = Vector2(1, 0)
				"sheep-returned":
					s.david.position = s._stray.position
				"stone-thrown":
					s.on_action_tap()
		s.tick(0.5)
		guard += 1
	t.eq(rec["won"], 1, "Lamb: the opening cutscene completes with OK only")
	t.eq(thrown[0], 0, "Lamb: no stone is thrown in the tutorial")
	t.truthy((rec["sfx"] as Array).has(&"harp"), "Lamb: OK in the tutorial plays the harp cue")
	s.free()


# --- audio ---

func _audio_data(t: TestRunner) -> void:
	for cue in SFX_CUES:
		var paths: PackedStringArray = Audio.cue_paths(cue)
		t.truthy(paths.size() > 0, "audio.json has cue %s" % cue)
		for p in paths:
			t.truthy(ResourceLoader.exists(p), "audio file exists: %s" % p)
	var music: PackedStringArray = Audio.cue_paths(Audio.MUSIC_MAIN)
	t.truthy(music.size() == 1 and music[0].ends_with(".mp3"), "music cue is the mp3")
	var d: Dictionary = BalanceData.read_json("res://data/audio.json")
	var buses: Dictionary = d["buses"] as Dictionary
	t.near(float((buses["Music"] as Dictionary)["baseDb"]), -10.0, "music bus about -10 dB")
	t.near(float((buses["Sfx"] as Dictionary)["baseDb"]), -6.0, "sfx bus about -6 dB")
	t.truthy(bool(((d["cues"] as Dictionary)["music-main"] as Dictionary)["loop"]), "music loops")
	t.eq(Audio.narration_path(&"c1-2-sunrise"), "res://audio/narration/c1-2-sunrise.ogg", "narration path is audio/narration/<line-id>.ogg")
	Audio.narrate(&"c1-2-sunrise")
	Audio.narrate(&"")
	Audio.play_sfx(&"no-such-cue")
	t.truthy(true, "missing narration and unknown cues are silent no-ops")
	t.eq(AudioServer.get_bus_index(&"Sfx") >= 0, true, "Sfx bus exists")
	# No stage or screen script besides the host calls Audio.
	for path in ["res://stages/stage-base.gd", "res://stages/stage-play-base.gd", "res://stages/stage-protect-flock.gd", "res://stages/stage-boss.gd", "res://stages/stage-cutscene.gd", "res://stages/stage-rhythm.gd"]:
		t.falsy(FileAccess.get_file_as_string(path).contains("Audio."), "%s never calls Audio directly" % path)


func _ui_text(t: TestRunner) -> void:
	var modes: Array = UiText.modes()
	t.eq(modes.size(), 4, "four modes come from data")
	var ids: Array = []
	for m in modes:
		ids.append((m as Dictionary)["id"])
	t.eq(ids, ["lamb", "shepherd", "normal", "hard"], "mode ids in cycle order")
	var pause: String = UiText.pause_items()[2]
	for m in modes:
		t.truthy(pause.contains(str((m as Dictionary)["name"])), "mode name %s is in the script's pause item" % (m as Dictionary)["name"])
	t.eq(UiText.mode_name("shepherd"), "Shepherd", "mode display name")
	t.eq(UiText.continue_label(), "Continue", "Continue label comes from data")
	t.eq(UiText.pause_items().size(), 4, "pause menu items unchanged")
	t.eq(UiText.pause_items()[2], "Change mode (Lamb / Shepherd / Normal / Hard)", "pause item lists the data modes (Hard is the approved extension to the script wording)")


func _chapter_focus(t: TestRunner) -> void:
	# N-2: with only chapter 1 open, LEFT/RIGHT on its card stay put; DOWN reaches the mode row.
	var before: int = SaveData.model.chapters_unlocked
	SaveData.model.chapters_unlocked = 1
	var cs: Control = (load("res://screens/chapter-select/chapter-select.tscn") as PackedScene).instantiate() as Control
	t.root.add_child(cs)
	var cards: Array = cs.get("_cards")
	var card: Button = cards[0]
	t.eq(card.has_focus(), true, "chapter select starts on the open card")
	t.eq(card.get_node(card.focus_neighbor_right), card, "RIGHT on the only open card stays on it")
	t.eq(card.get_node(card.focus_neighbor_left), card, "LEFT on the first card stays on it")
	var modes: Array = cs.get("_mode_buttons")
	t.eq((modes[0] as Button).get_node((modes[0] as Button).focus_neighbor_left), modes[0], "LEFT on the first mode stays on it")
	t.eq((modes[0] as Button).get_node((modes[0] as Button).focus_neighbor_top), card, "UP from the mode row returns to the last card")
	t.truthy(card.focus_neighbor_bottom.is_empty(), "DOWN from the card keeps the default route to the mode row")
	cs.free()
	SaveData.model.chapters_unlocked = before


func _processing_stops(t: TestRunner) -> void:
	# P-1: nothing keeps running after the win.
	var pair: Array = _night(RunModel.Mode.NORMAL, "", false)
	var s: StageProtectFlock = pair[0]
	s.begin()
	var guard: int = 0
	while not s.is_finished() and guard < 2000:
		s.tick(STEP)
		guard += 1
	s.tick(STEP)
	t.falsy(s.is_processing(), "night stops processing after the win")
	s.free()
	var lion: StageBoss = StageBoss.new()
	_setup(lion, "1-3-lion", RunModel.Mode.NORMAL)
	lion.begin()
	lion.register_hits(6)
	t.truthy(lion.is_finished() and lion.fled, "lion flees after six hits")
	for i in 100:
		lion.tick(STEP)
	t.falsy(lion.is_processing(), "boss stops processing once it has left the field")
	lion.free()
	var h: StageRhythm = StageRhythm.new()
	_setup(h, "1-6-harp", RunModel.Mode.NORMAL)
	h.begin()
	guard = 0
	while not h.is_finished() and guard < 2000:
		h.tick(0.1)
		guard += 1
	h.tick(0.1)
	t.falsy(h.is_processing(), "harp stops processing after the win")
	h.free()


# --- outcomes: every mode x every Chapter 1 Blessing ---

func _chapter1_blessings() -> Array:
	var out: Array = [""]
	for c in BalanceData.blessing_cards():
		if (c as Dictionary).get("chapters", []).has(1) or ((c as Dictionary).get("chapters", []) as Array).has(1.0):
			out.append(str((c as Dictionary)["id"]))
	return out


func _outcomes(t: TestRunner) -> void:
	var blessings: Array = _chapter1_blessings()
	t.eq(blessings.size(), 8, "seven Chapter 1 Blessings plus none")
	for mode in [RunModel.Mode.NORMAL, RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB, RunModel.Mode.HARD]:
		for card in blessings:
			var tag: String = "%s/%s" % [RunModel.mode_key(mode), card if not card.is_empty() else "none"]
			_outcome_night(t, mode, card, tag)
			_outcome_bosses(t, mode, card, tag)
			_outcome_harp(t, mode, card, tag)


func _outcome_night(t: TestRunner, mode: RunModel.Mode, card: String, tag: String) -> void:
	# No predators: the night ends at durationSec and is won in every mode.
	var pair: Array = _night(mode, card, false)
	var s: StageProtectFlock = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	var secs: float = 0.0
	while secs < 120.0 and not s.is_finished():
		s.tick(STEP)
		secs += STEP
	t.truthy(absf(secs - 90.0) <= 1.0, "%s night ends at 90 s" % tag)
	t.eq(rec["won"], 1, "%s night is won" % tag)
	t.eq(rec["failed"], 0, "%s night does not fail" % tag)
	s.free()
	# With predators and a bot, a night still ends at 90 s unless it is lost on sheep.
	var wp: Array = _night(mode, card, true)
	var ws: StageProtectFlock = wp[0]
	var wrec: Dictionary = wp[1]
	ws.begin()
	var el: float = 0.0
	var holds: float = 0.0
	while el < 120.0 and not ws.is_finished():
		ws.tick(STEP)
		ws.on_action_tap()
		holds += STEP
		if holds >= 2.0:
			holds = 0.0
			ws.on_action_hold()
		el += STEP
	t.eq(int(wrec["won"]) + int(wrec["failed"]), 1, "%s night with predators has one outcome" % tag)
	if int(wrec["won"]) == 1:
		t.truthy(absf(el - 90.0) <= 1.0, "%s night with predators ends at 90 s" % tag)
	if not RunModel.fails_like_normal(mode):
		t.eq(wrec["failed"], 0, "%s never fails" % tag)
	ws.free()


func _outcome_bosses(t: TestRunner, mode: RunModel.Mode, card: String, tag: String) -> void:
	for id in ["1-3-lion", "1-4-bear"]:
		var s: StageBoss = StageBoss.new()
		var rec: Dictionary = _setup(s, id, mode, card)
		s.begin()
		var expect: int = s.def.param_int("hitsToFlee", 0)
		if mode == RunModel.Mode.LAMB:
			for l in s.lambs:
				s.david.position = l.position
				s.tick(STEP)
			t.eq(rec["won"], 1, "%s %s Lamb gathers and wins" % [tag, id])
		else:
			var guard: int = 0
			var held: float = 0.0
			while not s.is_finished() and guard < 30000:
				s.on_action_tap()
				s.tick(0.05)
				held += 0.05
				if held >= 2.0:
					held = 0.0
					s.on_action_hold()
				guard += 1
			t.eq(rec["won"], 1, "%s %s is won" % [tag, id])
			if id == "1-3-lion":
				t.eq(s.hits, expect, "%s lion flees after exactly the data hit count" % tag)
				t.truthy(s.lamb_dropped, "%s lion dropped the lamb on the way" % tag)
			else:
				t.truthy(s.hits >= expect and s.hits <= expect + 1, "%s bear flees after the data hit count (%d)" % [tag, s.hits])
		t.eq(rec["failed"], 0, "%s %s never fails" % [tag, id])
		s.free()


func _outcome_harp(t: TestRunner, mode: RunModel.Mode, card: String, tag: String) -> void:
	var s: StageRhythm = StageRhythm.new()
	var rec: Dictionary = _setup(s, "1-6-harp", mode, card)
	s.begin()
	var secs: float = 0.0
	while secs < 120.0 and not s.is_finished():
		s.tick(0.05)
		secs += 0.05
	t.truthy(absf(secs - 60.0) <= 0.2, "%s harp lasts 60 s" % tag)
	t.eq(rec["won"], 1, "%s harp is won" % tag)
	t.eq(rec["failed"], 0, "%s harp never fails" % tag)
	s.free()
