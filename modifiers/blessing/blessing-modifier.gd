class_name BlessingModifier
extends Modifier
## One data-driven modifier built from a data/blessings.json card. Percent keys multiply,
## Sec/Add keys add, and non-numeric keys are exposed through feature().

## Every key a card may use (data-schema section 5). Anything else is rejected.
const REGISTRY: Array[StringName] = [
	&"stoneSpeedMult", &"followRadiusMult", &"walkSpeedMult", &"harpFrightenEnabled",
	&"harpFrightenRadiusPx", &"harpFrightenSec", &"enemyTelegraphSec", &"heartsRestoreOnStageStart",
	&"bossStunBonusSec", &"patrolNoticeTimeMult", &"arrowHintPerStage", &"actionClearsObstacles",
	&"companionCount", &"companionThrowsStones", &"startFoodAdd", &"heartOnSpare",
]
## Card key -> whitelisted tunable key (multiplied).
const MULT_MAP: Dictionary = {
	&"stoneSpeedMult": &"stone-speed",
	&"followRadiusMult": &"follow-distance",
	&"walkSpeedMult": &"walk-speed",
	&"patrolNoticeTimeMult": &"notice-time",
}
## Card key -> whitelisted tunable key (added).
const ADD_MAP: Dictionary = {
	&"bossStunBonusSec": &"stun-time",
	&"heartsRestoreOnStageStart": &"heart-regen",
	&"startFoodAdd": &"food-start",
}

var card_id: StringName = &""
var invalid_keys: Array[StringName] = []
var _mult: Dictionary = {}
var _add: Dictionary = {}
var _features: Dictionary = {}


func _init(card: Dictionary = {}) -> void:
	card_id = StringName(str(card.get("id", "")))
	id = card_id
	var mods: Dictionary = BalanceData.as_dict(card.get("modifiers", {}))
	for k in mods:
		var key: StringName = StringName(str(k))
		if not REGISTRY.has(key):
			invalid_keys.append(key)
		elif MULT_MAP.has(key):
			_mult[MULT_MAP[key]] = float(mods[k])
		elif ADD_MAP.has(key):
			_add[ADD_MAP[key]] = float(mods[k])
		else:
			_features[key] = mods[k]


func apply(key: StringName, value: float, _ctx: Variant = null) -> float:
	var v: float = value
	if _mult.has(key):
		v *= float(_mult[key])
	if _add.has(key):
		v += float(_add[key])
	return v


func feature(key: StringName, default: Variant = null) -> Variant:
	return _features.get(key, default)
