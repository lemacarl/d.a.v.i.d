extends RefCounted
## RunModel and SaveModel round trips, chapter unlock, SaveData file handling.

const TMP_PATH: String = "user://test-save.json"


func run(t: TestRunner) -> void:
	_run_model(t)
	_save_model(t)
	_unlock(t)
	_save_data(t)
	_stage_def(t)


func _run_model(t: TestRunner) -> void:
	var m: RunModel = RunModel.new()
	m.mode = RunModel.Mode.SHEPHERD
	m.start_chapter(3, 3)
	m.stage_index = 2
	m.hearts = 1
	m.stones = 4
	m.followers = 9
	m.blessings.append(&"quick-feet")
	m.cleared_stages.append(&"3-1-song")
	m.sword_unlocked = true
	m.stats["sheep_saved"] = 5
	m.rng_seed = 77
	var back: RunModel = RunModel.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())) as Dictionary)
	t.eq(back.to_dict(), m.to_dict(), "RunModel round trip through JSON")
	t.eq(back.mode, RunModel.Mode.SHEPHERD, "RunModel keeps mode")
	t.eq(back.blessings, m.blessings, "RunModel keeps blessings")
	m.start_chapter(4, 3)
	t.eq(m.mode, RunModel.Mode.SHEPHERD, "start_chapter keeps mode")
	t.eq(m.blessings.size(), 0, "start_chapter clears blessings")
	t.eq(m.stats["sheep_saved"], 0, "start_chapter clears stats")


func _save_model(t: TestRunner) -> void:
	var s: SaveModel = SaveModel.new()
	s.chapters_unlocked = 3
	s.mode = "lamb"
	s.settings["music_volume"] = 0.5
	s.settings["subtitle_scale"] = 1.5
	var parsed: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	t.truthy(SaveModel.validate(parsed), "saved JSON validates")
	var back: SaveModel = SaveModel.from_dict(parsed as Dictionary)
	t.eq(back.to_dict(), s.to_dict(), "SaveModel round trip through JSON")
	t.falsy(SaveModel.validate("junk"), "non-dictionary is invalid")
	t.falsy(SaveModel.validate({"mode": "nightmare"}), "unknown mode is invalid")
	t.falsy(SaveModel.validate({"version": 99}), "future version is invalid")
	t.falsy(SaveModel.validate({"chapters_unlocked": "two"}), "wrong type is invalid")
	var clamped: SaveModel = SaveModel.from_dict({"chapters_unlocked": 99, "settings": {"subtitle_scale": 0.2, "music_volume": 7}})
	t.eq(clamped.chapters_unlocked, 4, "chapters_unlocked capped at 4")
	t.near(float(clamped.settings["subtitle_scale"]), 1.0, "subtitle_scale floor 1.0")
	t.near(float(clamped.settings["music_volume"]), 1.0, "volume capped at 1")


func _unlock(t: TestRunner) -> void:
	var s: SaveModel = SaveModel.new()
	t.truthy(s.is_unlocked(1), "chapter 1 unlocked by default")
	t.falsy(s.is_unlocked(2), "chapter 2 locked by default")
	t.truthy(s.unlock_after(1, "normal", true), "completing 1 unlocks 2")
	t.truthy(s.is_unlocked(2) and not s.is_unlocked(3), "only chapter 2 newly unlocked")
	t.falsy(s.unlock_after(1, "normal", true), "re-completing 1 changes nothing")
	s.unlock_after(2)
	s.unlock_after(3)
	s.unlock_after(4)
	t.eq(s.chapters_unlocked, 4, "unlock capped at chapter 4")
	var l: SaveModel = SaveModel.new()
	t.truthy(l.unlock_after(1, "lamb", true), "Lamb completion unlocks when flag true")
	var l2: SaveModel = SaveModel.new()
	t.falsy(l2.unlock_after(1, "lamb", false), "Lamb completion does not unlock when flag false")
	t.truthy(BalanceData.lamb_completion_unlocks(), "balance.json: Lamb completion unlocks")


func _save_data(t: TestRunner) -> void:
	var sd: Node = load("res://autoload/save-data.gd").new() as Node
	sd.set("save_path", TMP_PATH)
	DirAccess.remove_absolute(TMP_PATH)
	DirAccess.remove_absolute(TMP_PATH + ".bad")
	sd.call("load_save")
	t.eq((sd.get("model") as SaveModel).chapters_unlocked, 1, "missing file gives defaults")
	sd.call("unlock_after", 2, "normal")
	t.truthy(FileAccess.file_exists(TMP_PATH), "save writes the file")
	t.falsy(FileAccess.file_exists(TMP_PATH + ".tmp"), "tmp file renamed away")
	var sd2: Node = load("res://autoload/save-data.gd").new() as Node
	sd2.set("save_path", TMP_PATH)
	sd2.call("load_save")
	t.eq((sd2.get("model") as SaveModel).chapters_unlocked, 3, "save reloads")
	var f: FileAccess = FileAccess.open(TMP_PATH, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	sd2.call("load_save")
	t.eq((sd2.get("model") as SaveModel).chapters_unlocked, 1, "corrupt file falls back to defaults")
	t.truthy(FileAccess.file_exists(TMP_PATH + ".bad"), "corrupt file kept as .bad")
	DirAccess.remove_absolute(TMP_PATH)
	DirAccess.remove_absolute(TMP_PATH + ".bad")
	sd.free()
	sd2.free()


func _stage_def(t: TestRunner) -> void:
	var raw: Dictionary = {
		"id": "x-1", "chapter": 1, "type": "protect-flock",
		"params": {"durationSec": 90, "predators": [{"speed": 90}], "nested": {"a": 1, "b": 2}},
		"win": {"kind": "survive-time", "seconds": 90, "minAlive": 3},
		"lose": [{"cond": "hearts-zero"}, {"cond": "timeout", "onLose": {"target": "restart-stage"}}],
		"onLose": {"target": "chapter-start", "message": "pool:david-falls"},
		"events": {"start": [{"type": "narration", "line": "l-1"}], "win": [{"type": "dialogue", "line": "l-2"}]},
		"modes": {"shepherd": {"params": {"predators": [{"speed": 54}], "nested": {"b": 9}}, "win": {"kind": "survive-time", "seconds": 90, "minAlive": 0}, "events": {"start": [{"type": "narration", "line": "l-3"}]}}},
		"next": null,
	}
	var n: StageDef = StageDef.from_dict(raw, RunModel.Mode.NORMAL)
	var s: StageDef = StageDef.from_dict(raw, RunModel.Mode.SHEPHERD)
	t.eq(n.param_int("durationSec"), 90, "StageDef param_int")
	t.eq(n.param_int("nested.b"), 2, "StageDef dotted path")
	t.eq(n.next_id, &"", "null next means chapter end")
	t.eq(s.param_int("nested.a"), 1, "mode params deep-merge keeps base keys")
	t.eq(s.param_int("nested.b"), 9, "mode params override")
	t.eq(s.param_array("predators").size(), 1, "arrays replace")
	t.eq(int((s.param_array("predators")[0] as Dictionary)["speed"]), 54, "shepherd predators applied")
	t.eq(int(s.win["minAlive"]), 0, "mode win replaces")
	t.eq(int(n.win["minAlive"]), 3, "normal win untouched")
	t.eq(s.beats(&"start").size(), 1, "events replace per trigger")
	t.eq(str((s.beats(&"start")[0] as Dictionary)["line"]), "l-3", "shepherd start event replaced")
	t.eq(str((s.beats(&"win")[0] as Dictionary)["line"]), "l-2", "other triggers kept")
	t.eq(str(n.on_lose_for(&"timeout")["target"]), "restart-stage", "lose entry onLose overrides default")
	t.eq(str(n.on_lose_for(&"hearts-zero")["target"]), "chapter-start", "default onLose used")
	t.eq(int((raw["params"] as Dictionary)["durationSec"]), 90, "source dictionary not mutated")
