class_name UiText
extends RefCounted
## Reads screen texts from data/recurring-lines.json (screens section). No story text lives in code.

const LINES_PATH: String = "res://data/recurring-lines.json"
const TITLE_SEPARATOR: String = " — "


static func _screen(id: String) -> Dictionary:
	var screens: Dictionary = BalanceData.as_dict(BalanceData.read_json(LINES_PATH).get("screens", {}))
	return BalanceData.as_dict(screens.get(id, {}))


## [heading, prompt]; prompt is empty if the title text has no separator.
static func title_parts() -> PackedStringArray:
	var text: String = str(_screen("title").get("text", ""))
	var i: int = text.find(TITLE_SEPARATOR)
	if i < 0:
		return PackedStringArray([text, ""])
	return PackedStringArray([text.substr(0, i), text.substr(i + TITLE_SEPARATOR.length())])


static func pause_items() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var v: Variant = _screen("pause-menu").get("items", [])
	if v is Array:
		for item in (v as Array):
			out.append(str(item))
	return out


## Modes in cycle order: [{id, name}] from screens.modes.items. Ids are the save keys.
static func modes() -> Array:
	var out: Array = []
	var v: Variant = _screen("modes").get("items", [])
	if v is Array:
		for m in (v as Array):
			if m is Dictionary:
				out.append({"id": str((m as Dictionary).get("id", "")), "name": str((m as Dictionary).get("name", ""))})
	return out


static func mode_name(id: String) -> String:
	for m in modes():
		if str((m as Dictionary)["id"]) == id:
			return str((m as Dictionary)["name"])
	return id


## The Continue button label (screens.run-summary.continue).
static func continue_label() -> String:
	return str(_screen("run-summary").get("continue", ""))


static func summary_template() -> String:
	return str(_screen("run-summary").get("template", ""))
