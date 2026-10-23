class_name SafeArea
extends MarginContainer
## Full-rect container with 5% margins (96 px / 54 px at 1920x1080). Applies the shared theme
## to everything below it.

const MARGIN_FRACTION: float = 0.05
const THEME_PATH: String = "res://theme/shepherd-theme.tres"


func _ready() -> void:
	theme = load(THEME_PATH) as Theme
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_apply_margins)
	_apply_margins()


func _apply_margins() -> void:
	var vs: Vector2 = get_viewport_rect().size
	var mx: int = roundi(vs.x * MARGIN_FRACTION)
	var my: int = roundi(vs.y * MARGIN_FRACTION)
	add_theme_constant_override("margin_left", mx)
	add_theme_constant_override("margin_right", mx)
	add_theme_constant_override("margin_top", my)
	add_theme_constant_override("margin_bottom", my)
