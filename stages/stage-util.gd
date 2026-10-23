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


## A plain coloured rectangle under `parent` (placeholder terrain: road, water, bank, rock).
static func make_rect(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.position = rect.position
	r.size = rect.size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


const BODY_CUE_WORDS: Array[String] = ["body", "corpse", "dead", "ground", "fallen", "lying", "blood", "gore"]


## True for a visual cue that would show a fallen body. Such a cue is never drawn or emitted.
static func is_body_cue(cue: String) -> bool:
	var c: String = cue.to_lower()
	for w in BODY_CUE_WORDS:
		if c.contains(w):
			return true
	return false


## Kind of a timed cut-away visual cue: &"stone" (slow-motion flight), &"faces" (soldiers), or &"".
static func cutaway_kind(cue: String) -> StringName:
	if cue.contains("stone-flies"):
		return &"stone"
	if cue.contains("faces"):
		return &"faces"
	return &""


## Placeholder scene of a visual cue: [kind, action], or [] when the cue has no drawn scene
## (the flat backdrop stays). Kinds: &"hills" (1.1), &"house" (1.5). Cue ids come from data/cutscenes.
const CUE_SCENES: Dictionary = {
	"dawn-hills-bethlehem": [&"hills", &"show"],
	"jesse-house-seven-brothers": [&"house", &"show"],
	"david-runs-in-with-staff": [&"house", &"david-runs-in"],
	"samuel-pours-oil-gold-sparkles": [&"house", &"pour-oil"],
}


static func scene_kind(cue: String) -> StringName:
	if CUE_SCENES.has(cue):
		return (CUE_SCENES[cue] as Array)[0] as StringName
	return &""


static func scene_action(cue: String) -> StringName:
	if CUE_SCENES.has(cue):
		return (CUE_SCENES[cue] as Array)[1] as StringName
	return &""


## A filled disc (placeholder sun, glow, bowl). Built once, never per frame.
static func make_disc(parent: Node, center: Vector2, radius: float, color: Color) -> Polygon2D:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 28:
		pts.append(Vector2.from_angle(TAU * float(i) / 28.0) * radius)
	var d: Polygon2D = Polygon2D.new()
	d.polygon = pts
	d.color = color
	d.position = center
	parent.add_child(d)
	return d
