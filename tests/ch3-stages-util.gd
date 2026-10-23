extends RefCounted
## Shared helpers for the Chapter 3 stealth and Ziklag tests (not a test file: the runner only loads
## test-*.gd). The stages are built from inline definitions so the tests do not depend on the
## Chapter 3 data files; a data-driven check at the end of each test file uses the real data when it exists.

const STEP: float = 0.1
const BLESSINGS: Array[String] = ["", "smooth-stones", "shepherds-staff", "quick-feet", "song-of-courage", "watchful-eyes", "still-waters", "hidden-in-the-rock", "faithful-friend", "goliaths-sword", "mighty-men", "gift-of-abigail", "mercy"]


static func modes() -> Array:
	return [RunModel.Mode.NORMAL, RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB]


static func tag(mode: RunModel.Mode, blessing: String) -> String:
	return "%s/%s" % [RunModel.mode_key(mode), blessing if not blessing.is_empty() else "none"]


static func stack(mode: RunModel.Mode, blessing: String) -> ModifierStack:
	var ms: ModifierStack = ModifierStack.new(mode)
	if not blessing.is_empty():
		ms.add_blessing(BalanceData.blessing_card(StringName(blessing)))
	return ms


## 3.6 En-gedi in the shape the data uses (Normal values; Shepherd and Lamb overrides in `modes`).
static func robe_dict() -> Dictionary:
	return {
		"id": "3-6-en-gedi", "scriptRef": "3.6", "chapter": 3, "type": "stealth", "title": "En-gedi",
		"params": {"walkSpeed": 200, "actions": {"ok": "cut-corner-of-robe"}, "attackEnabled": false, "onSeen": "reset-position",
			"sightEnabled": true, "noticeSec": 2.5, "saulSightRangePx": 320, "hidingSpots": {"kind": "shadows", "count": 4}},
		"events": {"enter": [{"type": "dialogue", "line": "c3-6-men"}], "win": [{"type": "dialogue", "line": "c3-6-david"}, {"type": "dialogue", "line": "c3-6-saul"}], "spare": []},
		"win": {"kind": "interact-once", "target": "saul-robe"}, "lose": [],
		"modes": {"shepherd": {"params": {"noticeSec": 5.0}}, "lamb": {"params": {"sightEnabled": false}}},
	}


## 3.8 Saul's camp in the shape the data uses.
static func camp_dict(thorns: int = 2) -> Dictionary:
	return {
		"id": "3-8-camp", "scriptRef": "3.8", "chapter": 3, "type": "stealth", "title": "Camp",
		"params": {"walkSpeed": 280, "onSeen": "return-to-path-start", "noticeSec": 2, "attackEnabled": false,
			"pickups": {"kind": "items", "items": ["spear", "water-jug"]}, "darkPath": {"lengthPx": 2400, "widthPx": 140},
			"sleepers": {"count": 8, "wakes": true}, "obstacles": [{"kind": "thorns", "count": thorns}]},
		"events": {"reach-saul": [{"type": "dialogue", "line": "c3-8-abishai"}, {"type": "dialogue", "line": "c3-8-david-no"}], "spare": [], "win": [{"type": "dialogue", "line": "c3-8-david-hill"}]},
		"win": {"kind": "reach-goal", "goal": "far-hill", "requireItems": ["spear", "water-jug"]}, "lose": [],
		"modes": {"shepherd": {"params": {"noticeSec": 4}}, "lamb": {"params": {"sleepers": {"wakes": false}}}},
	}


## 3.9 Ziklag in the shape the data uses. `stun` is raiderStunSec (0 = a repelled raider stays away).
static func ziklag_dict(stun: float = 2.0) -> Dictionary:
	return {
		"id": "3-9-ziklag", "scriptRef": "3.9", "chapter": 3, "type": "boss", "title": "Ziklag",
		"params": {"variant": "rescue", "timeLimitSec": 180, "families": 8, "raiders": 6, "helperPerFamily": 1, "walkSpeed": 300,
			"raiderSpeed": 150, "raiderStunSec": stun, "helperSpeed": 260, "obstacles": [{"kind": "ropes", "count": 4}]},
		"events": {"enter": [{"type": "narration", "line": "c3-9-narr-raiders"}], "win": [{"type": "narration", "line": "c3-9-end"}, {"type": "end-card", "line": "c3-9-card-complete"}]},
		"win": {"kind": "all-freed", "key": "families"},
		"lose": [{"cond": "timeout", "onLose": {"target": "restart-stage", "message": "pool:david-falls"}}, {"cond": "hearts-zero"}],
		"modes": {"shepherd": {"params": {"raiderSpeed": 90}}, "lamb": {"params": {"raiders": 0}}},
	}


## Calls setup on `s` (not begin) and returns a recorder dictionary wired to its signals.
static func build(s: StageBase, d: Dictionary, mode: RunModel.Mode, blessing: String = "", hearts: int = 3) -> Dictionary:
	var rec: Dictionary = {"won": 0, "failed": 0, "reason": &"", "hits": 0, "ids": [], "sfx": [], "spared": 0, "heals": 0, "followers": 0, "counters": []}
	s.stage_won.connect(func() -> void: rec["won"] = int(rec["won"]) + 1)
	s.stage_failed.connect(func(r: StringName) -> void:
		rec["failed"] = int(rec["failed"]) + 1
		rec["reason"] = r)
	s.hit_taken.connect(func(_n: int) -> void: rec["hits"] = int(rec["hits"]) + 1)
	s.line_requested.connect(func(_sp: StringName, _tx: String, _r: String, id: StringName) -> void: (rec["ids"] as Array).append(id))
	s.sfx_requested.connect(func(cue: StringName) -> void: (rec["sfx"] as Array).append(cue))
	s.spared.connect(func() -> void: rec["spared"] = int(rec["spared"]) + 1)
	s.heal_requested.connect(func(n: int) -> void: rec["heals"] = int(rec["heals"]) + n)
	s.follower_added.connect(func(n: int) -> void: rec["followers"] = int(rec["followers"]) + n)
	s.counter_changed.connect(func(k: StringName, v: int) -> void: (rec["counters"] as Array).append([k, v]))
	var rm: RunModel = RunModel.new()
	rm.mode = mode
	rm.rng_seed = 7
	rm.hearts_max = 3
	rm.hearts = hearts
	s.setup(StageDef.from_dict(d, mode), rm, stack(mode, blessing))
	return rec


static func run_for(s: Object, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds and not (s as StageBase).is_finished():
		s.call("tick", STEP)
		t += STEP


## Walks David toward `target` at the stage's walk speed, one 0.1 s tick at a time.
static func walk_to(s: StagePlayBase, target: Vector2, max_secs: float = 30.0) -> void:
	var t: float = 0.0
	while t < max_secs and not s.is_finished() and s.david.position.distance_to(target) > 4.0:
		var reach: float = s.walk_speed() * STEP
		s.input_dir = ((target - s.david.position) / reach).limit_length(1.0)
		s.tick(STEP)
		t += STEP
	s.input_dir = Vector2.ZERO
