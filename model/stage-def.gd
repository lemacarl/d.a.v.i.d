class_name StageDef
extends RefCounted
## One stage loaded from data/stages/chN.json with the active mode's overrides merged in.
## Merge rules (data-schema 3): params deep-merge; win, lose, onLose replace; events replace per trigger.
## Global mode defaults (balance.json) are applied by ModifierStack, not here.

const STAGES_PATH: String = "res://data/stages/ch%d.json"
const LINE_BEAT_TYPES: Array[String] = ["narration", "dialogue", "caption", "gold-light", "tutorial", "end-card"]

var id: StringName = &""
var script_ref: String = ""
var chapter: int = 0
var title: String = ""
var type: StringName = &""
var params: Dictionary = {}
var win: Dictionary = {}
var lose: Array = []
var on_lose: Dictionary = {}
var events: Dictionary = {}
var references: Array = []
var blessing_after: bool = false
## Empty when the stage is the last of its chapter (null in data).
var next_id: StringName = &""
var mode: RunModel.Mode = RunModel.Mode.NORMAL
var raw: Dictionary = {}


static func from_dict(d: Dictionary, active_mode: RunModel.Mode = RunModel.Mode.NORMAL) -> StageDef:
	var s: StageDef = StageDef.new()
	s.raw = d
	s.mode = active_mode
	s.id = StringName(str(d.get("id", "")))
	s.script_ref = str(d.get("scriptRef", ""))
	s.chapter = int(d.get("chapter", 0))
	s.title = str(d.get("title", ""))
	s.type = StringName(str(d.get("type", "")))
	s.params = _dup_dict(d.get("params", {}))
	s.win = _dup_dict(d.get("win", {}))
	s.lose = _dup_array(d.get("lose", []))
	s.on_lose = _dup_dict(d.get("onLose", {}))
	s.events = _dup_dict(d.get("events", {}))
	s.references = _dup_array(d.get("references", []))
	s.blessing_after = bool(d.get("blessingAfter", false))
	var nx: Variant = d.get("next", null)
	s.next_id = StringName(str(nx)) if nx != null else &""
	var key: String = RunModel.mode_key(active_mode)
	var modes: Dictionary = BalanceData.as_dict(d.get("modes", {}))
	if key != "normal" and modes.has(key):
		var ov: Dictionary = BalanceData.as_dict(modes[key])
		if ov.has("params"):
			s.params = deep_merge(s.params, BalanceData.as_dict(ov["params"]))
		if ov.has("win"):
			s.win = _dup_dict(ov["win"])
		if ov.has("lose"):
			s.lose = _dup_array(ov["lose"])
		if ov.has("onLose"):
			s.on_lose = _dup_dict(ov["onLose"])
		if ov.has("events"):
			var ev: Dictionary = BalanceData.as_dict(ov["events"])
			for trig in ev:
				s.events[trig] = _dup_array(ev[trig])
	return s


## Loads every stage of a chapter file in file order. Returns [] if the file is missing.
static func load_chapter(chapter_number: int, active_mode: RunModel.Mode = RunModel.Mode.NORMAL) -> Array[StageDef]:
	var out: Array[StageDef] = []
	var arr: Variant = BalanceData.read_json(STAGES_PATH % chapter_number).get("stages", [])
	if arr is Array:
		for d in (arr as Array):
			if d is Dictionary:
				out.append(from_dict(d as Dictionary, active_mode))
	return out


static func deep_merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for k in over:
		if out.has(k) and out[k] is Dictionary and over[k] is Dictionary:
			out[k] = deep_merge(out[k] as Dictionary, over[k] as Dictionary)
		else:
			out[k] = over[k].duplicate(true) if (over[k] is Dictionary or over[k] is Array) else over[k]
	return out


## Param lookup with optional dotted path ("phase2.glowSec"). Call in setup, not per frame.
func param(path: String, default: Variant = null) -> Variant:
	if not path.contains("."):
		return params.get(path, default)
	var cur: Variant = params
	for part in path.split("."):
		if cur is Dictionary and (cur as Dictionary).has(part):
			cur = (cur as Dictionary)[part]
		else:
			return default
	return cur


func param_int(path: String, default: int = 0) -> int:
	return int(param(path, default))


func param_float(path: String, default: float = 0.0) -> float:
	return float(param(path, default))


func param_bool(path: String, default: bool = false) -> bool:
	return bool(param(path, default))


func param_string(path: String, default: String = "") -> String:
	return str(param(path, default))


func param_dict(path: String) -> Dictionary:
	return BalanceData.as_dict(param(path, {}))


func param_array(path: String) -> Array:
	var v: Variant = param(path, [])
	if v is Array:
		return v as Array
	return []


func win_kind() -> StringName:
	return StringName(str(win.get("kind", "")))


## Beat list for an event trigger ("start", "win", "enter", ...), or [].
func beats(trigger: StringName) -> Array:
	var v: Variant = events.get(String(trigger), [])
	if v is Array:
		return v as Array
	return []


## Cutscene beats for cutscene stages (params.cutsceneId), loaded from data/cutscenes.
func cutscene_beats() -> Array:
	var cid: String = param_string("cutsceneId")
	if cid.is_empty():
		return []
	return LineBook.cutscene_beats(StringName(cid))


## Ordered line ids of every story beat in events and in the cutscene (used by tests).
func story_line_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for trig in events:
		_collect_lines(beats(StringName(str(trig))), out)
	_collect_lines(cutscene_beats(), out)
	return out


## The lose entry whose cond matches reason, or {}.
func lose_for(reason: StringName) -> Dictionary:
	for e in lose:
		if e is Dictionary and StringName(str((e as Dictionary).get("cond", ""))) == reason:
			return e as Dictionary
	return {}


func has_lose(reason: StringName) -> bool:
	return not lose_for(reason).is_empty()


## Effective onLose for a failure reason: the stage default, overridden by the matching lose entry's onLose.
func on_lose_for(reason: StringName) -> Dictionary:
	var out: Dictionary = on_lose.duplicate(true)
	var entry: Dictionary = lose_for(reason)
	if entry.has("onLose"):
		out.merge(BalanceData.as_dict(entry["onLose"]), true)
	return out


static func _collect_lines(beat_list: Array, out: Array[StringName]) -> void:
	for b in beat_list:
		if b is Dictionary:
			var bd: Dictionary = b as Dictionary
			if LINE_BEAT_TYPES.has(str(bd.get("type", ""))) and bd.has("line"):
				out.append(StringName(str(bd["line"])))


static func _dup_dict(v: Variant) -> Dictionary:
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	return {}


static func _dup_array(v: Variant) -> Array:
	if v is Array:
		return (v as Array).duplicate(true)
	return []
