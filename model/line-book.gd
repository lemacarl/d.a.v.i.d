class_name LineBook
extends RefCounted
## Resolves line ids and cutscene ids to data from data/dialogue, data/cutscenes and
## data/recurring-lines.json. Holds no story text itself.

const DIALOGUE_PATH: String = "res://data/dialogue/ch%d.json"
const CUTSCENE_PATH: String = "res://data/cutscenes/ch%d.json"
const RECURRING_PATH: String = "res://data/recurring-lines.json"

static var _lines: Dictionary = {}
static var _cutscenes: Dictionary = {}
static var _loaded_dialogue: Dictionary = {}
static var _loaded_cutscenes: Dictionary = {}
static var _pools: Dictionary = {}
static var _recurring_loaded: bool = false
static var _last_pick: Dictionary = {}


## Returns the line dictionary ({id, speaker, text, reference?, caption?, direction?}) or {}.
static func line(id: StringName) -> Dictionary:
	if _lines.has(id):
		return _lines[id] as Dictionary
	_load_recurring()
	if _lines.has(id):
		return _lines[id] as Dictionary
	var ch: int = _chapter_of_line(String(id))
	if ch > 0 and not _loaded_dialogue.has(ch):
		_loaded_dialogue[ch] = true
		var arr: Variant = BalanceData.read_json(DIALOGUE_PATH % ch).get("lines", [])
		if arr is Array:
			for l in (arr as Array):
				if l is Dictionary:
					_lines[StringName(str((l as Dictionary).get("id", "")))] = l
	if _lines.has(id):
		return _lines[id] as Dictionary
	return {}


## Beat list of a cutscene id such as "1-1-opening", or [].
static func cutscene_beats(cutscene_id: StringName) -> Array:
	var ch: int = int(String(cutscene_id).get_slice("-", 0))
	if ch <= 0:
		return []
	if not _loaded_cutscenes.has(ch):
		_loaded_cutscenes[ch] = true
		var file: Variant = _read_any(CUTSCENE_PATH % ch)
		var arr: Array = []
		if file is Array:
			arr = file as Array
		elif file is Dictionary:
			var v: Variant = (file as Dictionary).get("cutscenes", [])
			if v is Array:
				arr = v as Array
		for c in arr:
			if c is Dictionary:
				_cutscenes[StringName(str((c as Dictionary).get("id", "")))] = c
	if _cutscenes.has(cutscene_id):
		var beats: Variant = (_cutscenes[cutscene_id] as Dictionary).get("beats", [])
		if beats is Array:
			return beats as Array
	return []


## Picks a recurring line from a pool without repeating the previous pick.
static func pick(pool_id: StringName, rng: RandomNumberGenerator) -> Dictionary:
	_load_recurring()
	if not _pools.has(pool_id):
		return {}
	var arr: Array = _pools[pool_id] as Array
	if arr.is_empty():
		return {}
	var idx: int = rng.randi_range(0, arr.size() - 1)
	if arr.size() > 1 and _last_pick.get(pool_id, -1) == idx:
		idx = (idx + 1 + rng.randi_range(0, arr.size() - 2)) % arr.size()
	_last_pick[pool_id] = idx
	return arr[idx] as Dictionary


## Resolves "pool:{id}" or "line:{id}" (the onLose message form) to a line dictionary.
static func resolve(message: String, rng: RandomNumberGenerator) -> Dictionary:
	if message.begins_with("pool:"):
		return pick(StringName(message.substr(5)), rng)
	if message.begins_with("line:"):
		return line(StringName(message.substr(5)))
	return {}


static func _load_recurring() -> void:
	if _recurring_loaded:
		return
	_recurring_loaded = true
	var pools: Variant = BalanceData.read_json(RECURRING_PATH).get("pools", {})
	if not pools is Dictionary:
		return
	for pool_id in (pools as Dictionary):
		var entry: Dictionary = BalanceData.as_dict((pools as Dictionary)[pool_id])
		var arr: Array = []
		var v: Variant = entry.get("lines", [])
		if v is Array:
			arr = v as Array
		_pools[StringName(str(pool_id))] = arr
		for l in arr:
			if l is Dictionary:
				_lines[StringName(str((l as Dictionary).get("id", "")))] = l


static func _chapter_of_line(id: String) -> int:
	if id.length() > 1 and id[0] == "c":
		return int(id.get_slice("-", 0).substr(1))
	return 0


static func _read_any(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())
