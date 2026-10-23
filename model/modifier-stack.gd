class_name ModifierStack
extends RefCounted
## Applies base value -> mode modifier -> Blessing modifiers in pick order.
## Only TUNABLE_KEYS are tunable. Story outcomes are never routed through the stack.

const TUNABLE_KEYS: Array[StringName] = [
	&"walk-speed", &"stone-speed", &"enemy-speed", &"sheep-wander", &"follow-distance",
	&"heart-regen", &"stun-time", &"notice-time", &"enemy-spawn-enabled", &"rest-time",
	&"timer-enabled", &"stones-refill", &"food-start",
]
## Read-only story set. A modifier cannot be asked about these.
const STORY_KEYS: Array[StringName] = [
	&"boss-defeat", &"goliath-falls", &"saul-spared", &"chapter-complete", &"line-played",
]
## Non-story events a modifier may veto.
const EVENTS: Array[StringName] = [&"stage-fail", &"timeout-fail", &"david-fall", &"enemy-spawn"]

var mode_modifier: Modifier = null
var blessing_modifiers: Array[Modifier] = []
## Keys that were asked of the stack but are not tunable (a test failure if non-empty).
var rejected_keys: Array[StringName] = []


func _init(mode: RunModel.Mode = RunModel.Mode.NORMAL) -> void:
	set_mode(mode)


static func is_tunable(key: StringName) -> bool:
	return TUNABLE_KEYS.has(key)


static func is_story(key: StringName) -> bool:
	return STORY_KEYS.has(key)


func set_mode(mode: RunModel.Mode) -> void:
	match mode:
		RunModel.Mode.SHEPHERD:
			mode_modifier = ModeShepherd.new()
		RunModel.Mode.LAMB:
			mode_modifier = ModeLamb.new()
		_:
			mode_modifier = ModeNormal.new()


func clear_blessings() -> void:
	blessing_modifiers.clear()


## Adds a Blessing from its card dictionary. Cards with unregistered keys are refused.
func add_blessing(card: Dictionary) -> bool:
	var m: BlessingModifier = BlessingModifier.new(card)
	if not m.invalid_keys.is_empty():
		for k in m.invalid_keys:
			_reject(k)
		return false
	blessing_modifiers.append(m)
	return true


## Replaces all Blessings with the given ids, in pick order.
func set_blessings(ids: Array[StringName]) -> void:
	blessing_modifiers.clear()
	for bid in ids:
		var card: Dictionary = BalanceData.blessing_card(bid)
		if not card.is_empty():
			add_blessing(card)


## Replaces all Blessings with prebuilt modifiers (pick order).
func set_blessing_modifiers(mods: Array[Modifier]) -> void:
	blessing_modifiers = mods.duplicate()


func apply(key: StringName, base: float, ctx: Variant = null) -> float:
	if not TUNABLE_KEYS.has(key):
		_reject(key)
		return base
	var v: float = mode_modifier.apply(key, base, ctx)
	for m in blessing_modifiers:
		v = m.apply(key, v, ctx)
	return v


func apply_bool(key: StringName, base: bool, ctx: Variant = null) -> bool:
	return apply(key, 1.0 if base else 0.0, ctx) > 0.5


## True unless the mode or a Blessing vetoes a non-story event. Story events are always allowed.
func allows(event: StringName, ctx: Variant = null) -> bool:
	if STORY_KEYS.has(event):
		return true
	if not mode_modifier.allows(event, ctx):
		return false
	for m in blessing_modifiers:
		if not m.allows(event, ctx):
			return false
	return true


## Non-numeric Blessing data (data-schema registry key, e.g. &"companionCount"). First pick wins.
func feature(key: StringName, default: Variant = null) -> Variant:
	for m in blessing_modifiers:
		var v: Variant = m.feature(key, null)
		if v != null:
			return v
	return default


func _reject(key: StringName) -> void:
	if not rejected_keys.has(key):
		rejected_keys.append(key)
