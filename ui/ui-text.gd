class_name UiText
extends RefCounted
## Reads screen texts from data/recurring-lines.json (screens section). No story text lives in code.

const LINES_PATH: String = "res://data/recurring-lines.json"
## Operational label for the one button no data file names.
const CONTINUE_LABEL: String = "Continue"
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


## Mode names in cycle order, taken from the "Change mode (A / B / C)" pause item.
static func mode_names() -> PackedStringArray:
	var items: PackedStringArray = pause_items()
	if items.size() >= 3:
		var s: String = items[2]
		var a: int = s.find("(")
		var b: int = s.find(")")
		if a >= 0 and b > a:
			return s.substr(a + 1, b - a - 1).split(" / ", false)
	return PackedStringArray()


static func summary_template() -> String:
	return str(_screen("run-summary").get("template", ""))
