class_name StageUtil
extends RefCounted
## Small shared helpers for stage placeholders. No story text lives here.

const SCREEN: Vector2 = Vector2(1920, 1080)


## Muted placeholder colour derived from a visual cue id.
static func cue_color(cue: String) -> Color:
	var hue: float = float(absi(cue.hash()) % 360) / 360.0
	return Color.from_hsv(hue, 0.35, 0.42)


static func make_backdrop(parent: Node) -> ColorRect:
	var bd: ColorRect = ColorRect.new()
	bd.size = SCREEN
	bd.color = Color(0.1, 0.1, 0.14)
	bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lab: Label = Label.new()
	lab.name = "CueLabel"
	lab.position = Vector2(96, 54)
	lab.add_theme_font_size_override(&"font_size", 32)
	lab.modulate = Color(1, 1, 1, 0.35)
	bd.add_child(lab)
	parent.add_child(bd)
	return bd


## Changes the backdrop colour and label from a cue id (placeholder for real art).
static func set_backdrop(bd: ColorRect, cue: String) -> void:
	if bd == null:
		return
	bd.color = cue_color(cue)
	var lab: Label = bd.get_node_or_null("CueLabel") as Label
	if lab != null:
		lab.visible = false


## {speaker, text, reference} for a line id, or {} when unknown.
static func line_of(line_id: String) -> Dictionary:
	return LineBook.line(StringName(line_id))


static func dist_sq(a: Vector2, b: Vector2) -> float:
	return a.distance_squared_to(b)
