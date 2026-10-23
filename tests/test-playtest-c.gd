extends RefCounted
## Playtest fixes C: the 1.1 throw tutorial shows the flight, hit and a pause; the sheep walks back;
## every Chapter 1 visual cue draws a scene; Samuel's scene (1.5); lines are shown before a cutscene moves on.

const STEP: float = 0.1


func run(t: TestRunner) -> void:
	_cue_mapping(t)
	_stone_flight(t)
	_lamb_ring(t)
	_sheep_walks_back(t)
	_lines_before_advance(t)
	_samuel_scene(t)
	_hills_scene(t)
	_bounded_nodes(t)


# --- helpers ---

func _make(stage_id: String, mode: RunModel.Mode = RunModel.Mode.NORMAL) -> Array:
	var rec: Dictionary = {"won": 0, "ids": [], "sfx": [], "visuals": [], "gold": 0}
	var s: StageCutscene = StageCutscene.new()
	s.stage_won.connect(func() -> void: rec["won"] = int(rec["won"]) + 1)
	s.line_requested.connect(func(_sp: StringName, _tx: String, _r: String, id: StringName) -> void: (rec["ids"] as Array).append(id))
	s.sfx_requested.connect(func(cue: StringName) -> void: (rec["sfx"] as Array).append(cue))
	s.visual_requested.connect(func(cue: StringName) -> void: (rec["visuals"] as Array).append(cue))
	s.gold_light_requested.connect(func(_tx: String, _r: String, _sec: float) -> void: rec["gold"] = int(rec["gold"]) + 1)
	var rm: RunModel = RunModel.new()
	rm.mode = mode
	rm.rng_seed = 7
	var def: StageDef = null
	for d in StageDef.load_chapter(1, mode):
		if d.id == StringName(stage_id):
			def = d
	s.setup(def, rm, ModifierStack.new(mode))
	return [s, rec]


## Ticks until the cutscene waits on the tutorial step `until` (taps through the lines).
func _to_step(s: StageCutscene, until: String) -> bool:
	for i in 4000:
		if s.waiting == StageCutscene.Wait.TUTORIAL and s._until == until:
			return true
		if s.is_finished():
			return false
		if s.waiting == StageCutscene.Wait.TUTORIAL:
			match s._until:
				"david-moved":
					s.input_dir = Vector2(1, 0)
				"sheep-returned":
					s.david.position = s._stray.position
		else:
			s.input_dir = Vector2.ZERO
		s.tick(STEP)
	return false


# --- cue to scene mapping ---

func _cue_mapping(t: TestRunner) -> void:
	var d: Dictionary = BalanceData.read_json("res://data/cutscenes/ch1.json")
	var count: int = 0
	for cs in (d["cutscenes"] as Array):
		for b in ((cs as Dictionary)["beats"] as Array):
			var beat: Dictionary = b as Dictionary
			if str(beat.get("type", "")) != "visual":
				continue
			var cue: String = str(beat["cue"])
			count += 1
			t.truthy(StageUtil.scene_kind(cue) != &"", "visual cue %s has a drawn scene" % cue)
			t.truthy(StageUtil.scene_action(cue) != &"", "visual cue %s has a scene action" % cue)
			t.truthy(not StageUtil.is_body_cue(cue), "visual cue %s shows no body" % cue)
	t.eq(count, 4, "four Chapter 1 cutscene visual cues are mapped")
	t.eq(StageUtil.scene_kind("some-chapter-2-cue"), &"", "cues without a scene keep the flat backdrop")


# --- #36 the stone throw tutorial ---

func _stone_flight(t: TestRunner) -> void:
	var pair: Array = _make("1-1-opening")
	var s: StageCutscene = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	t.truthy(_to_step(s, "stone-thrown"), "the opening reaches the stone prompt")
	s.input_dir = Vector2.ZERO
	t.truthy(s.david.visible, "David is on screen at the stone prompt")
	t.truthy(s._practice.visible, "a practice target stands in the field")
	t.truthy(s.david.position.distance_to(s._practice.position) > 500.0, "the target is a long throw away")
	s.on_action_tap()
	var stone: ActorStone = null
	for st in s._stones:
		if st.active:
			stone = st
	t.truthy(stone != null, "OK launches a visible stone")
	var start: Vector2 = stone.position
	var el: float = 0.0
	var moved_while_waiting: bool = false
	var david_always_visible: bool = true
	var hit_at: float = -1.0
	var pre_hit_finished: bool = false
	while not s.is_finished() and el < 6.0:
		s.tick(STEP)
		el += STEP
		david_always_visible = david_always_visible and (s.david.visible or s.is_finished())
		if stone.active and stone.position.distance_to(start) > 100.0:
			moved_while_waiting = true
		if hit_at < 0.0 and s._landed:
			hit_at = el
		if hit_at < 0.0 and s.is_finished():
			pre_hit_finished = true
	t.truthy(moved_while_waiting, "the stone visibly flies across the field")
	t.truthy(david_always_visible, "David stays visible during the throw")
	t.truthy(hit_at > 0.3, "the stone takes time to reach the target")
	t.falsy(pre_hit_finished, "the scene does not move on before the stone lands")
	t.truthy(el >= 1.5, "the scene waits at least 1.5 s after the throw")
	t.truthy((rec["sfx"] as Array).has(&"hit"), "the hit plays the impact cue")
	t.eq(rec["won"], 1, "the opening ends after the throw")
	s.free()


func _lamb_ring(t: TestRunner) -> void:
	var pair: Array = _make("1-1-opening", RunModel.Mode.LAMB)
	var s: StageCutscene = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	t.truthy(_to_step(s, "stone-thrown"), "Lamb reaches the stone prompt")
	s.input_dir = Vector2.ZERO
	s.on_action_tap()
	var el: float = 0.0
	while not s.is_finished() and el < 6.0:
		s.tick(STEP)
		el += STEP
		t.truthy(s.david.visible or s.is_finished(), "Lamb: David stays visible after the harp")
	t.truthy(el >= 1.5, "Lamb: the scene waits at least 1.5 s after the harp")
	t.truthy((rec["sfx"] as Array).has(&"harp"), "Lamb: the harp cue plays")
	t.eq(rec["won"], 1, "Lamb: the opening ends")
	s.free()


# --- the lost sheep walks back ---

func _sheep_walks_back(t: TestRunner) -> void:
	var pair: Array = _make("1-1-opening")
	var s: StageCutscene = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	t.truthy(_to_step(s, "sheep-returned"), "the opening reaches the sheep prompt")
	s.input_dir = Vector2.ZERO
	t.truthy(s._stray.position.y >= StageCutscene.STRAY_MIN_Y - 0.1, "the lost sheep stands on the grass")
	var spot: Vector2 = s.return_spot()
	t.truthy(s._stray.position.distance_to(spot) > 300.0, "the lost sheep is far from the flock")
	# David reaches the sheep and stands still: the sheep must walk back before the step ends.
	s.david.position = s._stray.position + Vector2(60, 0)
	s.tick(STEP)
	t.eq(s._until, "sheep-returned", "the step does not end the moment David reaches the sheep")
	var d_prev: float = s._stray.position.distance_to(spot)
	var closer: bool = true
	var el: float = 0.0
	while s.waiting == StageCutscene.Wait.TUTORIAL and s._until == "sheep-returned" and el < 10.0:
		s.tick(STEP)
		el += STEP
		var d_now: float = s._stray.position.distance_to(spot)
		closer = closer and d_now <= d_prev + 0.01
		d_prev = d_now
	t.truthy(closer, "the picked-up sheep walks steadily toward the flock")
	t.truthy(el > 1.5, "the sheep's walk back is visible for more than a moment")
	t.truthy(s._stray.position.distance_to(spot) <= 4.01, "the sheep ends the step at the flock")
	t.truthy((s._scene as ActorHills).returned_sheep.visible, "the sheep stays with the flock")
	t.truthy(s.david.visible, "David stays on screen during the sheep step")
	s.free()


# --- lines are shown before the cutscene moves on ---

func _lines_before_advance(t: TestRunner) -> void:
	for id in ["1-1-opening", "1-5-samuel"]:
		var pair: Array = _make(id)
		var s: StageCutscene = pair[0]
		var rec: Dictionary = pair[1]
		s.begin()
		var guard: int = 0
		var early_advance: bool = false
		var last_index: int = -1
		while not s.is_finished() and guard < 4000:
			guard += 1
			if s.waiting == StageCutscene.Wait.LINE and s.beat_index != last_index:
				last_index = s.beat_index
				var shown_before: int = (rec["ids"] as Array).size()
				s.on_action_tap()
				if s.beat_index != last_index:
					early_advance = true
				t.truthy(shown_before >= 1, "%s: beat %d requested its line before waiting" % [id, last_index])
			if s.waiting == StageCutscene.Wait.TUTORIAL:
				match s._until:
					"david-moved":
						s.input_dir = Vector2(1, 0)
					"sheep-returned":
						s.david.position = s._stray.position
					"stone-thrown":
						s.on_action_tap()
			else:
				s.input_dir = Vector2.ZERO
			s.tick(STEP)
		t.falsy(early_advance, "%s: a tap straight after a line appears does not skip it" % id)
		t.eq(rec["won"], 1, "%s: still completes" % id)
		s.free()


# --- #40 Samuel's scene ---

func _samuel_scene(t: TestRunner) -> void:
	var pair: Array = _make("1-5-samuel")
	var s: StageCutscene = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	t.truthy(s._scene is ActorHouse, "1.5 draws Jesse's house")
	var h: ActorHouse = s._scene as ActorHouse
	t.eq(h.brothers.size(), 7, "seven brothers stand in a row")
	var tallest: float = 0.0
	for b in h.brothers:
		tallest = maxf(tallest, b.body_height)
	t.near(h.brothers[0].body_height, tallest, "Eliab is the tallest")
	for i in range(1, 7):
		t.truthy(h.brothers[i].body_height < h.brothers[0].body_height - 40.0, "brother %d is clearly shorter than Eliab" % (i + 1))
		t.truthy(h.brothers[i].position.x > h.brothers[i - 1].position.x, "brother %d stands right of the one before" % (i + 1))
	t.truthy(h.samuel.horn, "Samuel carries the horn")
	t.truthy(not h.david.visible, "David is not in the room yet")
	t.truthy(h.samuel.position.x < h.brothers[0].position.x, "Samuel enters from the left")
	# One pass with no input: lines advance on their own timers.
	var stops: Array[int] = []
	var last_x: float = h.samuel.position.x
	var paused_ticks: int = 0
	var forward_only: bool = true
	var glow_seen: bool = false
	var gold_beat_glow: bool = false
	var oil_seen: bool = false
	var david_seen: bool = false
	var max_sparks: int = 0
	var guard: int = 0
	while not s.is_finished() and guard < 4000:
		guard += 1
		s.tick(STEP)
		if h.phase == ActorHouse.Phase.WALKING:
			forward_only = forward_only and h.samuel.position.x >= last_x - 0.01
			if absf(h.samuel.position.x - last_x) < 0.01:
				paused_ticks += 1
			last_x = h.samuel.position.x
			for i in 7:
				if absf(h.samuel.position.x - h._stop_x(i)) < 1.0 and not stops.has(i):
					stops.append(i)
		glow_seen = glow_seen or h.glow_alpha > 0.1
		if s.waiting == StageCutscene.Wait.LINE and s.beat_index >= 0 and str((s.beats[s.beat_index] as Dictionary).get("type", "")) == "gold-light":
			gold_beat_glow = gold_beat_glow or h.glow_alpha > 0.95
		david_seen = david_seen or h.david.visible
		oil_seen = oil_seen or h.oil_amount > 0.9
		max_sparks = maxi(max_sparks, h.sparkles.alive_count)
	t.eq(stops, [0, 1, 2, 3, 4, 5, 6], "Samuel stops at every brother, in order")
	t.truthy(forward_only, "Samuel only walks forward past the row")
	t.truthy(paused_ticks >= 20, "Samuel pauses at the brothers")
	t.truthy(gold_beat_glow, "gold light fills the screen on the caption beat")
	t.truthy(david_seen, "David runs in at his cue")
	var rec_cues: Array = rec["visuals"]
	t.truthy(rec_cues.has(&"david-runs-in-with-staff"), "the run-in cue was shown")
	t.truthy(rec_cues.has(&"samuel-pours-oil-gold-sparkles"), "the pour cue was shown")
	t.truthy(oil_seen, "oil pours onto David's head")
	t.truthy(max_sparks > 0 and max_sparks <= ActorSparkles.COUNT, "gold sparkles appear, at most %d" % ActorSparkles.COUNT)
	t.eq(rec["won"], 1, "1.5 completes")
	s.free()
	# Direct: the scene cues alone put David in and pour (no stage).
	var house: ActorHouse = ActorHouse.new()
	house.play(&"show")
	house.play(&"david-runs-in")
	for i in 40:
		house.advance(STEP)
	t.truthy(house.david.visible and house.david.position.x < ActorHouse.DOOR_X - 50.0, "David runs in from the doorway")
	house.play(&"pour-oil")
	for i in 80:
		house.advance(STEP)
	t.truthy(house.phase == ActorHouse.Phase.DONE or house.phase == ActorHouse.Phase.POURING, "the pour runs after the run-in")
	house.free()


func _hills_scene(t: TestRunner) -> void:
	var pair: Array = _make("1-1-opening")
	var s: StageCutscene = pair[0]
	s.begin()
	t.truthy(s._scene is ActorHills, "1.1 draws the dawn hills")
	var hills: ActorHills = s._scene as ActorHills
	t.truthy(hills.boy.visible and hills.boy.harp, "a boy sits on a rock with a harp")
	t.eq(hills.sheep.size(), 5, "sheep graze on the hills")
	var sun_y: float = hills._sun.position.y
	for i in 30:
		s.tick(STEP)
		if s.waiting == StageCutscene.Wait.LINE:
			s.on_action_tap()
	t.truthy(hills._sun.position.y < sun_y, "the sun rises")
	_to_step(s, "david-moved")
	t.falsy(hills.boy.visible, "the seated boy hands over to the walking David")
	s.free()


func _bounded_nodes(t: TestRunner) -> void:
	var house: ActorHouse = ActorHouse.new()
	var before: int = _count(house)
	house.play(&"show")
	house.set_glow(true)
	house.play(&"david-runs-in")
	house.play(&"pour-oil")
	for i in 400:
		house.advance(STEP)
	t.eq(_count(house), before, "the house scene creates no nodes while it plays")
	t.truthy(before < 60, "the house scene stays small (%d nodes)" % before)
	house.free()
	var hills: ActorHills = ActorHills.new()
	var hb: int = _count(hills)
	for i in 200:
		hills.advance(STEP)
	t.eq(_count(hills), hb, "the hills scene creates no nodes while it plays")
	hills.free()


func _count(n: Node) -> int:
	var c: int = 1
	for ch in n.get_children():
		c += _count(ch)
	return c
