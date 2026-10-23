class_name UiFocus
extends RefCounted
## Shared focus behaviour: gold outline comes from the theme; this adds the subtle scale
## and enforces the 96 px minimum target height.

const SCALE_ON: float = 1.05
const TWEEN_SEC: float = 0.12
const MIN_HEIGHT: float = 96.0


static func bind(c: Control) -> void:
	c.custom_minimum_size.y = maxf(c.custom_minimum_size.y, MIN_HEIGHT)
	c.focus_entered.connect(_scale_to.bind(c, SCALE_ON))
	c.focus_exited.connect(_scale_to.bind(c, 1.0))


static func _scale_to(c: Control, s: float) -> void:
	if not c.is_inside_tree():
		return
	if c.has_meta(&"focus_tween"):
		var old: Variant = c.get_meta(&"focus_tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	c.pivot_offset = c.size * 0.5
	var tw: Tween = c.create_tween()
	tw.tween_property(c, "scale", Vector2(s, s), TWEEN_SEC)
	c.set_meta(&"focus_tween", tw)
