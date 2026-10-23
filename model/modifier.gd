class_name Modifier
extends RefCounted
## Base of every mode and Blessing modifier. Tunes numbers on whitelisted keys only.
## Subclasses override apply and allows. They are never asked about story outcomes.

var id: StringName = &""


## Returns the tuned value for a whitelisted key. Default: unchanged. Booleans are 1.0 / 0.0.
func apply(_key: StringName, value: float, _ctx: Variant = null) -> float:
	return value


## May veto a non-story event (see ModifierStack.EVENTS). Default: allowed.
func allows(_event: StringName, _ctx: Variant = null) -> bool:
	return true


## Non-numeric Blessing data (flags, counts, lists) by data-schema key, or default.
func feature(_key: StringName, default: Variant = null) -> Variant:
	return default
