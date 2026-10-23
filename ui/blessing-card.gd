class_name BlessingCard
extends Button
## One Blessing: name, one-line effect and verse reference. Fields come from data/blessings.json.

const CARD_SIZE: Vector2 = Vector2(540, 460)

var card_id: StringName = &""


func setup(card: Dictionary) -> void:
	card_id = StringName(str(card.get("id", "")))
	custom_minimum_size = CARD_SIZE
	UiFocus.bind(self)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 24)
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	box.add_child(_label(str(card.get("name", "")), 44, Color(1, 0.9, 0.55)))
	var effect: Label = _label(str(card.get("effect", "")), 40, Color.WHITE)
	effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(effect)
	box.add_child(_label(str(card.get("reference", "")), 32, Color(0.8, 0.85, 1)))


func _label(text: String, font_size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
