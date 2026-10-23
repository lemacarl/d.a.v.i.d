class_name BalanceData
extends RefCounted
## Cached access to data/balance.json and data/blessings.json. Numbers live in data, never in code.

const BALANCE_PATH: String = "res://data/balance.json"
const BLESSINGS_PATH: String = "res://data/blessings.json"

static var _balance: Dictionary = {}
static var _blessings: Dictionary = {}


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func as_dict(v: Variant) -> Dictionary:
	if v is Dictionary:
		return v as Dictionary
	return {}


static func balance() -> Dictionary:
	if _balance.is_empty():
		_balance = read_json(BALANCE_PATH)
	return _balance


static func hearts_max() -> int:
	return maxi(int(as_dict(balance().get("hearts", {})).get("max", 3)), 1)


static func invulnerable_sec() -> float:
	return float(as_dict(balance().get("hearts", {})).get("invulnerableSec", 1.5))


static func harp_hold_sec() -> float:
	return float(as_dict(balance().get("input", {})).get("harpHoldSec", 2.0))


## A feel number from balance.json `feel` (walk speed, radii, margins). 0.0 when missing;
## the data test asserts every key the code reads is present.
static func feel(key: String) -> float:
	return float(as_dict(balance().get("feel", {})).get(key, 0.0))


static func lamb_completion_unlocks() -> bool:
	return bool(as_dict(balance().get("profile", {})).get("lambCompletionUnlocksNextChapter", true))


## Settings dictionary for a mode key ("normal", "shepherd", "lamb"). Empty if missing.
static func mode_settings(key: String) -> Dictionary:
	return as_dict(as_dict(balance().get("modes", {})).get(key, {}))


static func _blessing_file() -> Dictionary:
	if _blessings.is_empty():
		_blessings = read_json(BLESSINGS_PATH)
	return _blessings


static func offer_count() -> int:
	return maxi(int(_blessing_file().get("offerCount", 3)), 1)


## All Blessing cards in file order (Array of Dictionary).
static func blessing_cards() -> Array:
	var v: Variant = _blessing_file().get("cards", [])
	if v is Array:
		return v as Array
	return []


static func blessing_card(id: StringName) -> Dictionary:
	for c in blessing_cards():
		if c is Dictionary and StringName(str((c as Dictionary).get("id", ""))) == id:
			return c as Dictionary
	return {}
