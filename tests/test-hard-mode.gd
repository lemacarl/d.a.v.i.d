extends RefCounted
## Hard mode (issue #41): Normal rules plus tuned pressure, all from data. Story is identical in every mode.

const U = preload("res://tests/ch2-util.gd")
const SAFE_FRACTION: float = 0.9


func run(t: TestRunner) -> void:
	_data_and_keys(t)
	_hearts(t)
	_fails_like_normal(t)
	_story_identical(t)
	_save_round_trip(t)
	_old_saves(t)
	_pause_cycle(t)
	_chapter_select(t)
	BalanceData.active_mode_key = "normal"


func _data_and_keys(t: TestRunner) -> void:
	t.eq(RunModel.Mode.NORMAL, 0, "Normal keeps its enum value")
	t.eq(RunModel.Mode.SHEPHERD, 1, "Shepherd keeps its enum value")
	t.eq(RunModel.Mode.LAMB, 2, "Lamb keeps its enum value")
	t.eq(RunModel.Mode.HARD, 3, "Hard is appended last")
	t.eq(RunModel.mode_key(RunModel.Mode.HARD), "hard", "Hard key")
	t.eq(RunModel.mode_from_key("hard"), RunModel.Mode.HARD, "Hard from key")
	t.truthy(RunModel.fails_like_normal(RunModel.Mode.HARD), "Hard fails like Normal")
	t.falsy(RunModel.fails_like_normal(RunModel.Mode.SHEPHERD), "Shepherd does not fail like Normal")
	var n: ModifierStack = ModifierStack.new(RunModel.Mode.NORMAL)
	var h: ModifierStack = ModifierStack.new(RunModel.Mode.HARD)
	t.near(h.apply(&"enemy-speed", 100.0), 130.0, "Hard enemy speed x1.3")
	t.near(h.apply(&"sheep-wander", 1.0), 1.25, "Hard sheep wander x1.25")
	t.near(h.apply(&"notice-time", 1.0), 0.7, "Hard notice time x0.7")
	t.near(h.apply(&"stun-time", 2.0), 1.6, "Hard stun time x0.8")
	t.near(n.apply(&"notice-time", 1.0), 1.0, "Normal notice time unchanged")
	t.near(n.apply(&"stun-time", 2.0), 2.0, "Normal stun time unchanged")
	t.near(h.apply(&"walk-speed", 320.0), 320.0, "Hard walk speed unchanged")
	t.near(h.apply(&"rest-time", 0.0), 0.0, "Hard has no rest")
	t.falsy(h.apply_bool(&"stones-refill", false), "Hard stones do not refill")
	t.truthy(h.apply_bool(&"timer-enabled", true), "Hard keeps the time limits")
	t.truthy(h.apply_bool(&"enemy-spawn-enabled", true), "Hard keeps enemies")
	t.eq(h.rejected_keys.size(), 0, "Hard uses only tunable keys")
	# Blessings still stack on top of Hard (order: base, mode, Blessing).
	h.add_blessing(BalanceData.blessing_card(&"watchful-eyes"))
	t.truthy(h.apply(&"notice-time", 1.0) > 0.0, "Blessings still apply on Hard")


func _hearts(t: TestRunner) -> void:
	t.eq(BalanceData.hearts_max("hard"), 2, "Hard has 2 hearts")
	t.eq(BalanceData.hearts_max("normal"), 3, "Normal has 3 hearts")
	t.eq(BalanceData.hearts_max(), 3, "default hearts unchanged")
	BalanceData.active_mode_key = "hard"
	t.near(BalanceData.invulnerable_sec(), 1.0, "Hard invulnerability is shorter")
	BalanceData.active_mode_key = "normal"
	t.near(BalanceData.invulnerable_sec(), 1.5, "Normal invulnerability unchanged")
	BalanceData.active_mode_key = "lamb"
	t.near(BalanceData.invulnerable_sec(), 1.5, "Lamb invulnerability unchanged")
	BalanceData.active_mode_key = "normal"
	var rs: Node = U.new_run_state()
	rs.call("start_chapter", 1, RunModel.Mode.HARD)
	t.eq((rs.get("model") as RunModel).hearts_max, 2, "RunState starts Hard with 2 hearts")
	t.eq((rs.get("model") as RunModel).hearts, 2, "...and full hearts")
	t.near(BalanceData.invulnerable_sec(), 1.0, "RunState selects Hard invulnerability")
	rs.call("set_mode", RunModel.Mode.NORMAL)
	t.eq((rs.get("model") as RunModel).hearts_max, 3, "switching to Normal restores 3 hearts")
	t.near(BalanceData.invulnerable_sec(), 1.5, "...and Normal invulnerability")
	rs.call("set_mode", RunModel.Mode.HARD)
	t.eq((rs.get("model") as RunModel).hearts_max, 2, "switching to Hard sets 2 hearts")
	rs.free()
	BalanceData.active_mode_key = "normal"


func _hearts_zero_failures(mode: RunModel.Mode) -> Array:
	var rs: Node = U.new_run_state()
	rs.call("start_chapter", 1, mode)
	var found: bool = false
	for i in 12:
		var cur: StageDef = rs.get("current_stage") as StageDef
		if cur.has_lose(&"hearts-zero"):
			found = true
			break
		rs.call("advance")
		if rs.get("awaiting_blessing"):
			rs.call("skip_blessing")
	var fails: Array = []
	rs.connect("run_failed", func(m: String) -> void: fails.append(m))
	var hits: int = 0
	while fails.is_empty() and hits < 6:
		rs.call("apply_hit", 1)
		hits += 1
	var out: Array = [found, hits, fails.size(), (rs.get("model") as RunModel).hearts, String(rs.call("fail_stage", &"hearts-zero"))]
	rs.free()
	BalanceData.active_mode_key = "normal"
	return out


func _fails_like_normal(t: TestRunner) -> void:
	var n: Array = _hearts_zero_failures(RunModel.Mode.NORMAL)
	var h: Array = _hearts_zero_failures(RunModel.Mode.HARD)
	t.truthy(bool(h[0]), "a Chapter 1 stage with a hearts-zero lose entry exists")
	t.eq(n[1], 3, "Normal falls on the third hit")
	t.eq(h[1], 2, "Hard falls on the second hit")
	t.eq(h[2], n[2], "Hard fails (restarts) exactly like Normal")
	t.eq(h[3], 2, "Hard restarts with full (2) hearts")
	t.eq(h[4], n[4], "Hard fail_stage result matches Normal")
	t.truthy(h[4] != "ignored", "Hard failures are never ignored")
	var rs: Node = U.new_run_state()
	rs.call("start_chapter", 1, RunModel.Mode.HARD)
	t.falsy(bool(rs.call("stones_refill_enabled")), "Hard stones do not refill")
	rs.free()


func _story_identical(t: TestRunner) -> void:
	for ch in range(1, 5):
		var normal: Array[StageDef] = StageDef.load_chapter(ch, RunModel.Mode.NORMAL)
		if normal.is_empty():
			continue
		var hard: Array[StageDef] = StageDef.load_chapter(ch, RunModel.Mode.HARD)
		t.eq(hard.size(), normal.size(), "chapter %d same stage count on Hard" % ch)
		for i in mini(hard.size(), normal.size()):
			t.eq(hard[i].story_line_ids(), normal[i].story_line_ids(), "%s Hard story lines identical" % normal[i].id)
			t.eq(hard[i].next_id, normal[i].next_id, "%s Hard next stage identical" % normal[i].id)
			t.eq(hard[i].win, normal[i].win, "%s Hard falls back to the Normal win" % normal[i].id)
			t.eq(hard[i].params, normal[i].params, "%s Hard falls back to the Normal params" % normal[i].id)
			t.eq(hard[i].lose, normal[i].lose, "%s Hard falls back to the Normal lose rules" % normal[i].id)
	for mode in U.modes():
		var g: StageDef = U.stage_def("2-6-goliath", mode)
		if g != null:
			t.eq(g.win_kind(), &"timing-hit", "Goliath falls on the forehead hit in %s" % RunModel.mode_key(mode))
	# A stage may define a hard block; Hard uses it, other modes do not.
	var raw: Dictionary = {"id": "x", "type": "protect-flock", "params": {"a": 1}, "win": {"kind": "survive-time"}, "modes": {"hard": {"params": {"a": 5}}}}
	t.eq(StageDef.from_dict(raw, RunModel.Mode.HARD).params["a"], 5, "a stage hard block overrides on Hard")
	t.eq(StageDef.from_dict(raw, RunModel.Mode.NORMAL).params["a"], 1, "...and not on Normal")


func _save_round_trip(t: TestRunner) -> void:
	var s: SaveModel = SaveModel.new()
	s.mode = "hard"
	s.chapters_unlocked = 2
	var parsed: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	t.truthy(SaveModel.validate(parsed), "a Hard save validates")
	var back: SaveModel = SaveModel.from_dict(parsed as Dictionary)
	t.eq(back.mode, "hard", "Hard survives the save round trip")
	var rm: RunModel = RunModel.new()
	rm.mode = RunModel.Mode.HARD
	var rb: RunModel = RunModel.from_dict(JSON.parse_string(JSON.stringify(rm.to_dict())) as Dictionary)
	t.eq(rb.mode, RunModel.Mode.HARD, "RunModel keeps Hard")
	t.eq(SaveModel.from_dict({"mode": "extreme"}).mode, "normal", "an unknown mode falls back to Normal")
	t.falsy(SaveModel.validate({"mode": "extreme"}), "an unknown mode does not validate")
	var sd: Node = load("res://autoload/save-data.gd").new() as Node
	sd.call("set_mode", "hard")
	t.eq((sd.get("model") as SaveModel).mode, "hard", "SaveData accepts Hard")
	sd.free()


func _old_saves(t: TestRunner) -> void:
	for key in ["normal", "shepherd", "lamb"]:
		var old: Dictionary = {"version": 1, "chapters_unlocked": 2, "mode": key, "settings": {"music_volume": 0.5, "narration_volume": 1.0, "subtitle_scale": 1.0}}
		t.truthy(SaveModel.validate(old), "an old %s save validates" % key)
		var m: SaveModel = SaveModel.from_dict(old)
		t.eq(m.mode, key, "an old %s save keeps its mode" % key)
		t.eq(m.chapters_unlocked, 2, "an old %s save keeps its progress" % key)
	t.eq(SaveModel.from_dict({"version": 1}).mode, "normal", "a save without mode is Normal")


func _pause_cycle(t: TestRunner) -> void:
	var before: RunModel.Mode = RunState.model.mode
	var order: Array = []
	var pm: Control = (load("res://screens/pause-menu/pause-menu.tscn") as PackedScene).instantiate() as Control
	pm.connect("mode_changed", func(m: RunModel.Mode) -> void: order.append(RunModel.mode_key(m)))
	t.root.add_child(pm)
	var cur: RunModel.Mode = RunModel.Mode.LAMB
	for i in 5:
		RunState.model.mode = cur
		pm.call("_cycle_mode")
		cur = RunModel.mode_from_key(order[order.size() - 1])
	t.eq(order, ["shepherd", "normal", "hard", "lamb", "shepherd"], "the pause menu cycles Lamb, Shepherd, Normal, Hard and wraps")
	var found: bool = false
	for b in pm.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Change mode"):
			found = true
			t.truthy((b as Button).text.begins_with("Change mode (Lamb / Shepherd / Normal / Hard)"), "the pause item lists the four modes")
	t.truthy(found, "the pause menu has the Change mode item")
	pm.free()
	RunState.model.mode = before


func _chapter_select(t: TestRunner) -> void:
	var saved_mode: String = SaveData.model.mode
	var saved_unlocked: int = SaveData.model.chapters_unlocked
	SaveData.model.mode = "hard"
	SaveData.model.chapters_unlocked = 1
	var cs: Control = (load("res://screens/chapter-select/chapter-select.tscn") as PackedScene).instantiate() as Control
	t.root.add_child(cs)
	var buttons: Array = cs.get("_mode_buttons")
	var names: Array = []
	for b in buttons:
		names.append((b as Button).text)
	t.eq(names, ["Lamb", "Shepherd", "Normal", "Hard"], "the mode row shows Lamb, Shepherd, Normal, Hard")
	var pressed: Array = []
	for b in buttons:
		pressed.append((b as Button).button_pressed)
	t.eq(pressed, [false, false, false, true], "the saved mode (Hard) is highlighted")
	t.eq((buttons[3] as Button).get_node((buttons[3] as Button).focus_neighbor_right), buttons[3], "RIGHT on Hard stays on Hard")
	t.eq((buttons[0] as Button).get_node((buttons[0] as Button).focus_neighbor_left), buttons[0], "LEFT on Lamb stays on Lamb")
	var row: Control = (buttons[0] as Button).get_parent() as Control
	var width: float = row.get_combined_minimum_size().x
	t.truthy(width <= 1920.0 * SAFE_FRACTION, "the mode row fits inside the 5%% safe area (%s px)" % width)
	var cards: Control = ((cs.get("_cards") as Array)[0] as Button).get_parent() as Control
	t.truthy(cards.get_combined_minimum_size().x <= 1920.0 * SAFE_FRACTION, "the chapter cards fit inside the safe area")
	cs.free()
	SaveData.model.mode = saved_mode
	SaveData.model.chapters_unlocked = saved_unlocked
